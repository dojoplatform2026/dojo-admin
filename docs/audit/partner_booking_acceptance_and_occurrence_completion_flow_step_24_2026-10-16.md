# DOJO WALK — Partner Acceptance and Walk Completion Flow Audit
## Step 24 — State-transition plan
Date: 2026-10-16
Repository: dojoplatform2026/dojo-admin
Branch: audit/zone-service-area-mapping-2026-10-16
Type: Source audit and implementation plan only

## Confirmed product contract
- Accepting a booking accepts the whole booking once.
- On successful acceptance, parent booking status must be `assigned`, with the accepting walker assigned.
- Starting and completing a dated walk must update that specific occurrence, not the parent booking lifecycle.
- A regular parent booking remains `assigned` while future required walks remain. Parent `completed` is allowed only after the booking period ends and the required occurrences are reconciled.

## Partner source findings
1. `lib/screens/home/walk_details_screen.dart`
   - `_navigateToPickup()` currently writes `status: accepted` to the parent booking.
   - The inspected update does not visibly write `walkerId` or a stable acceptance timestamp in that update.
   - The flow catches write errors, so the navigation/error path must be checked to ensure a failed acceptance never looks successful.
2. `lib/screens/home/navigation_screen.dart`
   - `_updateBookingStatus(status)` writes a supplied status directly to the parent booking.
   - The flow calls it with `accepted`, then `picked_up`, then `walking`.
   - These are not safe parent states for a recurring booking; pickup and walking are occurrence-level progress.
3. `lib/features/live_walk/screens/live_walk_screen.dart`
   - `_endWalk()` creates a top-level `walks/{walkId}` record with `status: completed` and `bookingId`.
   - It then unconditionally updates the parent booking to `status: completed` when a booking ID exists.
   - The live-walk payload currently does not include a stable `occurrenceId`, so the completed route/result cannot reliably identify which scheduled occurrence it fulfils.
4. `firestore.rules`
   - Booking updates for an assigned walker permit several progress fields but do not by themselves enforce the full atomic acceptance/occurrence transition contract described here.
   - The same Rules file currently denies client booking creation (`allow create: if false`) while the Customer source writes booking documents directly. This is a separate source-level cross-app conflict and needs a complete shared Rules/backend review.

## Recommended transition design
### A. Whole-booking acceptance
Use a trusted backend callable/transaction or another server-authorized atomic operation. It must verify authenticated walker identity, walker eligibility/approval, booking exists, booking is still `pending` and unassigned, and the walker is eligible for the service area. If all checks pass, atomically set `walkerId`, `status: assigned`, `acceptedAt`, `updatedAt`, and a consistent accepting-walker audit field if required. A second concurrent acceptance must fail without overwriting the first assignment. Do not navigate to an accepted booking state when the write fails.

### B. Pick-up and start
Resolve the exact scheduled occurrence ID before beginning a walk. Update that occurrence to `in_progress` with `startedAt` only after the required pickup/return verification workflow succeeds. Do not set parent booking status to `picked_up` or `walking`. If those labels are needed for UI, derive them from the active occurrence, or use a separate UI-only progress label rather than overloading parent status.

### C. Walk completion
Write the route/result with both `bookingId` and `occurrenceId`, and update the matching occurrence to `completed` with completion timestamp, actual duration/distance, and approved walk counters. Use an atomic transaction or trusted backend to prevent duplicate completion and to link the result consistently. Do not write parent `status: completed` from a single occurrence completion. The parent remains `assigned` if future required occurrences remain.

### D. Final parent completion
A trusted completion check should run only after the booking period ends. It must inspect the authoritative occurrence set and apply the final policy for completed, missed, skipped, cancelled, and rescheduled occurrences. Do not infer success solely from a date or the number of saved `walks` documents.

## File-level implementation order
1. Finalize occurrence schema from Step 23 and decide how regular date ranges are materialized.
2. Update `walk_details_screen.dart` to call secure whole-booking acceptance; remove direct `accepted` parent write.
3. Update `navigation_screen.dart` to address one occurrence and stop writing `picked_up`/`walking` to the parent booking.
4. Update `live_walk_screen.dart` to require `occurrenceId`, save a linked walk result, and complete only that occurrence.
5. Review/align `firestore.rules` and trusted backend functions, including booking creation, assignment, occurrence access, and GPS-route access.
6. Update Customer/Admin readers and dashboard metrics to separate booking status from occurrence status.

## Required tests before merge
- One-time booking acceptance sets parent `assigned` and assigns exactly one walker.
- Two walkers attempt acceptance concurrently; only one succeeds.
- Failed acceptance does not open pickup/live-walk flow.
- One occurrence moves `scheduled` -> `in_progress` -> `completed` without changing parent `assigned`.
- Completing today's last occurrence leaves a multi-day regular booking `assigned` when future occurrences remain.
- Wrong walker, wrong booking, or wrong occurrence cannot start/complete a walk.
- Duplicate completion is rejected/idempotent and does not duplicate route/result records.
- End-of-period completion is blocked while required occurrences are unresolved.
- Firestore Rules deny unauthorized reads/writes, including GPS route access after reassignment.

## Scope and verification
This report is an audit/implementation plan only. No app source, Firestore Rules, backend functions, database documents, or deployment were changed. Tests were not run. Source-level observations do not confirm the currently deployed production configuration.
