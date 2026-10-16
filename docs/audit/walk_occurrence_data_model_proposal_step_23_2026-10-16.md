# DOJO WALK — Walk Occurrence Data Model Proposal
## Step 23 — Recommended schema before code changes
Date: 2026-10-16
Repository: dojoplatform2026/dojo-admin
Branch: audit/zone-service-area-mapping-2026-10-16
Type: Schema proposal only; implementation not applied

## Why a schema decision is needed
Source inspection shows Customer booking creation currently stores schedules in the parent booking document: `walkSchedules`, and for regular bookings `dailyWalkTemplate`; customized dates use `selectedDates` and `dateSchedules`. Partner live-walk completion creates a separate top-level `walks/{walkId}` record but also writes `bookings/{bookingId}.status = completed`. That parent write can incorrectly finish a multi-day booking after one walk. Current live-walk payload does not include a stable occurrence ID.

## Recommended model
Keep one parent document at `bookings/{bookingId}` and create one stable child document per scheduled occurrence at `bookings/{bookingId}/occurrences/{occurrenceId}`. This is a proposal to validate, not a claim that the collection already exists.

### Parent booking document
Keep booking-wide fields here, including `bookingId`, `customerId`, `walkerId`, `bookingPlan`, `serviceType`, booking period/start/end information (field names must be finalized after auditing schedule selection), `status`, assignment timestamps, cancellation request, and audit timestamps.
- `status: pending` before acceptance.
- `status: assigned` after a walker successfully accepts the whole booking.
- Keep `assigned` while future required occurrences remain.
- Use `cancelled` when the overall booking is cancelled according to policy.
- Set `completed` only after the booking period has ended and every required occurrence has an allowed final outcome under the approved business rules.

### One occurrence document per date and slot
Suggested path: `bookings/{bookingId}/occurrences/{occurrenceId}`.
Suggested fields:
- `occurrenceId`: stable ID (prefer deterministic date + slot key where safe, or generate once at booking creation; never generate a new ID on each screen render).
- `bookingId`, `customerId`, `walkerId` (keep consistent with parent assignment).
- `scheduledAt`: timestamp for this specific date and time.
- `durationMinutes`: validated duration for this slot.
- `slotKey` / `slotLabel`: stable slot identity such as morning/afternoon/evening where available; do not rely on label alone as the ID.
- `status`: `scheduled`, `in_progress`, `completed`, or an explicitly approved cancellation/reschedule state.
- `startedAt`, `completedAt`, `updatedAt` timestamps as applicable.
- Walk-result fields or references: actual duration, distance, pee/poop counts, notes, and the linked `walks/{walkId}` record. Keep detailed GPS route in the protected walk record, not duplicated unnecessarily into the parent booking.
- Store only the fields needed by the workflow; validate names/types against the existing app and Rules before implementation.

## Lifecycle
1. Customer creates booking: parent status `pending`; create all currently known dated occurrences as `scheduled` where dates are known.
2. For a regular daily plan, first confirm the booking period and materialization strategy. If the whole date range is known, create the required occurrences for that period. If future dates are generated gradually, record that policy explicitly so final completion can be calculated correctly.
3. Walker accepts the whole booking atomically: parent status becomes `assigned`, `walkerId` is set, and eligible occurrence records become associated with the assigned walker.
4. Starting a walk changes only that occurrence to `in_progress`.
5. Finishing a walk changes only that occurrence to `completed` and links its walk result. Do not set parent booking `completed` from this action alone.
6. A trusted backend/admin completion process evaluates the end of the booking period and all required occurrences before setting parent `completed`.

## Legacy compatibility and migration safeguards
- Preserve current `walkSchedules`, `dailyWalkTemplate`, `selectedDates`, and `dateSchedules` during the migration window; do not delete or rename these fields in a blind replacement.
- Plan a migration/backfill for existing bookings, including one-time bookings and old regular bookings. Define how already completed, cancelled, or ambiguous records map to occurrence documents.
- Avoid dual-write inconsistencies: specify which source is authoritative during migration and add reconciliation checks before switching readers.
- Use a Firestore transaction or trusted backend for assignment and occurrence transitions, with server/rules checks that prevent two walkers accepting the same booking.
- Rules must prevent customers/walkers from forging parent completion, changing another occurrence, reading unauthorized GPS routes, or retaining access after reassignment.
- The currently inspected Partner Rules have `allow create: if false` for bookings while the Customer app writes booking documents directly. This is a source-level compatibility conflict requiring a full shared-rules/backend review; deployed Rules were not verified.

## Decisions required before implementation
1. What is the exact regular booking period and its start/end field schema?
2. Are all occurrence documents created upfront, or are future occurrences generated by a trusted scheduled process?
3. What happens to missed/skipped/cancelled/rescheduled occurrences at the end of a paid booking?
4. Can a booking be partially completed or extended?
5. Should a top-level `walks/{walkId}` record remain the detailed route/result record with a required `occurrenceId` field? Recommended: yes, link it to both `bookingId` and `occurrenceId`.

## Verification scope
Customer booking writer, Partner live-walk completion code, and Partner Firestore Rules were inspected on their main branches. This report proposes a data model only. No code, Rules, production data, migration, deployment, or tests were changed/run. Production behavior remains unverified.
