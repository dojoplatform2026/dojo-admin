# DOJO WALK — Shared Booking Data Contract Structure
## Step 26 — Customer, Partner, Admin, Rules and Backend alignment
Date: 2026-10-16
Type: Contract structure / audit proposal only

## Goal
Define one shared contract before modifying app code or security Rules. The Customer app creates the booking, Partner accepts and executes individual walks, Admin monitors the parent booking and its occurrences, and trusted backend/Rules enforce ownership and lifecycle. The contract below is proposed from the inspected source and the previously confirmed business decisions; it is not yet implemented.

## 1. Parent booking: `bookings/{bookingId}`
### Canonical fields
- Identity/ownership: `bookingId`, `customerId`, `walkerId` (null until assignment).
- Plan: `walkType`, `bookingPlan` (`one_time`, `regular`, `customize`), `serviceType`, `serviceName`.
- Pet reference/snapshot: `dogId`, `petName`, `petDetails`.
- Pickup reference/details: `pickupAddressId`, `pickupAddress` (field shape must be normalized; exact coordinates and instructions need acceptance-based access policy).
- Booking plan/schedule: `walkCount`, `walkSchedules`, and for regular/custom plans the approved plan fields (`frequency`, `walksPerDay`, `dailyWalkTemplate`, `selectedDates`, `dateSchedules`, plus explicit `startDate`/`endDate` to be finalized).
- Lifecycle: `status`, `cancelRequest`, `createdAt`, `updatedAt`, `acceptedAt`, optional `cancelledAt` and final `completedAt`.
- Pricing: one canonical server-validated pricing breakdown and total field names must be chosen; current Admin UI checks `amount`, `totalAmount`, or `price`, while Customer's inspected writer does not visibly write these canonical totals. Do not trust client-supplied prices without validation.

### Parent status values
- `pending`: awaiting assignment/acceptance.
- `assigned`: one eligible walker accepted the entire booking.
- `cancelled`: booking-wide cancellation was approved/processed.
- `completed`: booking period ended and all required occurrences have been reconciled under the agreed policy.
- Do not store `accepted`, `picked_up`, `walking`, or per-walk `completed` as parent lifecycle states. Any legacy states require a migration/read-compatibility plan.

## 2. Occurrence: `bookings/{bookingId}/occurrences/{occurrenceId}`
Each dated slot is a separate record. Suggested fields:
- `occurrenceId`, `bookingId`, `customerId`, `walkerId`.
- `slotKey` (stable slot identity), `slotLabel` (Morning/Afternoon/Evening or custom label), `scheduledAt`, `durationMinutes`, timezone/locale convention.
- `status`: `scheduled`, `in_progress`, `completed`, plus policy-approved `cancelled`, `rescheduled`, `missed` or `skipped` states.
- `startedAt`, `completedAt`, `updatedAt`, optional `rescheduledFromOccurrenceId`, and `walkId` result reference.
- Approved outcome counters/notes may be stored here or in the linked result document; define one source of truth to avoid duplicated conflicting values.

### Occurrence transition rules
- Scheduled slot -> `in_progress` only by the assigned walker and only for the matching occurrence after required pickup checks.
- In-progress slot -> `completed` only after the approved return/completion workflow succeeds.
- A completed occurrence cannot be reopened by a normal client update.
- One occurrence completion must never mark the parent booking `completed` while future required occurrences remain.
- Missed/cancelled/rescheduled policy and whether each state counts as reconciled remain a business decision before implementation.

## 3. Walk result / GPS record: `walks/{walkId}`
- Must include `bookingId` and `occurrenceId`.
- Store route points, actual start/end, duration/distance, pee/poop counters, return verification and result metadata here only as needed.
- A result must not be accepted as completion for a different booking or occurrence.
- Restrict precise GPS reads/writes to the assigned walker during the active occurrence, the booking customer under the approved history policy, and authorized admin/support access. Define retention and support-access audit policy.

## 4. Source-to-contract mismatch register
### Customer writer (`dojo-walk-customer/main/lib/features/booking/screens/booking_confirmation_screen.dart`)
- Writes a new `bookings/{id}` document directly from the client.
- Writes `customerId`, `dogId`, `petDetails`, map-valued `pickupAddress`, `scheduledAt`, `duration` as text, `preferredTime`, `walkCount`, `walkSchedules`, `status: pending`, `walkerId: null`, `cancelRequest`, `createdAt`.
- Regular plan writes `frequency`, `walksPerWeek`, `walksPerDay`, `planStatus`, `dailyWalkTemplate`.
- Custom dates plan writes `selectedDates`, `dateSchedules`.
- Does not visibly write `updatedAt`, canonical `customerName`, `dog`, string `pickupAddress`, or the Admin-recognized pricing total fields in the inspected write block. Server timestamp and validated price should be handled consistently.
- This client write conflicts with the inspected Partner `firestore.rules`, which has `allow create: if false` for `/bookings/{bookingId}` if that exact Rules file is deployed.

### Partner reader/writer (`dojo-partner/main`)
- `walk_details_screen.dart` reads `customer`, `dog`, `customerName`, `dogBreed`, `dogSize`, and expects `pickupAddress` as a string. Customer writer currently uses `petDetails` and map-valued `pickupAddress`.
- Acceptance currently writes parent `status: accepted` and does not visibly set `walkerId` in that write.
- `navigation_screen.dart` writes `accepted`, `picked_up`, and `walking` to the parent document.
- `live_walk_screen.dart` writes a `walks/{walkId}` result and then sets parent `status: completed`, without stable `occurrenceId` linkage.
- Partner booking query/source files and exact query requirements must be identified in the next file-level pass; do not assume the home screen filename from a previous summary.

### Admin reader (`dojo-admin/audit/zone-service-area-mapping-2026-10-16/lib/screens/bookings/bookings_screen.dart`)
- Displays parent `status`, `customerName`/`customerId`, `walkerName`/`walkerId`, created time, walk time from `walkDateTime`/`scheduledAt`/`bookingDate`, and amount from `amount`/`totalAmount`/`price`.
- It currently presents one status per booking and does not visibly summarize per-occurrence status. Future dashboard should distinguish parent booking counts from occurrence counts.

### Rules source
- Inspected Partner `firestore.rules` denies direct client booking creation, permits assigned walker updates to parent `status` without an allowed-value transition check, and permits changes to `walkSchedules` in the walker update allowlist.
- No explicit match for `/bookings/{bookingId}/occurrences/{occurrenceId}` or `/walks/{walkId}` was found in that file; default deny applies unless another overlapping match exists.
- A root `firestore.rules` file was not found at the inspected path in the Customer repository; authoritative deployed Rules location is not confirmed.

## 5. Responsibility boundary
- Customer client: collect/submit request and display parent + occurrence progress; must not authoritatively assign walkers or set trusted lifecycle timestamps/prices.
- Partner client: request acceptance, start, and completion actions for a specific occurrence; no unrestricted parent status writes.
- Trusted backend: validate booking create/price/schedule; atomically accept booking; authorize occurrence transitions; link walk result; determine parent final completion/cancellation.
- Firestore Rules: enforce ownership, allowed fields, roles, and deny unauthorized access even if the UI is bypassed.
- Admin: view booking lifecycle and occurrence-level operations; sensitive overrides require role checks and audit trail.

## 6. Implementation order after contract approval
1. Confirm authoritative Firebase project Rules deployment source and any backend functions.
2. Freeze canonical field names/types, parent statuses, occurrence statuses, timezone handling, price fields, and regular start/end dates.
3. Implement backend operations and Rules tests first, without deployment.
4. Update Customer writer/display to use the approved contract and occurrence schema.
5. Update Partner acceptance/navigation/live-walk flow to use `assigned` and occurrence IDs.
6. Update Admin list/dashboard for parent versus occurrence views.
7. Run emulator/unit/integration tests across all three apps; review diffs and only then consider a separately approved deployment.

## Decisions still required before implementation
- For regular plans, what exact start date and end date/term is purchased?
- Create all occurrence docs at booking time or generate them with a trusted scheduler?
- How do missed, skipped, cancelled, and rescheduled occurrences affect final parent completion and billing?
- What is the approved customer access window for GPS route history?
- What canonical price breakdown and total fields should all apps use?
- Which exact deployed Rules file/backend deployment is authoritative?

## Scope
This is a structure and audit document only. No application source, Rules, backend, data, or deployment was changed. No tests were run. Repository source findings do not prove production deployment state.
