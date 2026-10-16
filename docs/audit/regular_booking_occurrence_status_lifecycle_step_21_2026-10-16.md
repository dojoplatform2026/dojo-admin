# DOJO WALK — Regular Booking and Walk Occurrence Status Rules
## Step 21 — User-confirmed status lifecycle
**Date:** 2026-10-16  
**Repository:** dojoplatform2026/dojo-admin  
**Branch:** audit/zone-service-area-mapping-2026-10-16  
**Type:** Audit / product-contract decision record only

## Confirmed product rule
The user approved separating the overall booking status from the status of each individual walk occurrence.

When a walker accepts a whole booking, the booking status becomes `assigned`. Acceptance is for the booking as a whole, not separately for every slot.

For a regular booking, completing today's walks must not mark the overall booking `completed` while future walks remain scheduled.

## Proposed status model

### Booking-level status
- `pending`: waiting for a walker to accept.
- `assigned`: a walker has accepted the booking and is assigned; the booking period is still active.
- `cancelled`: the booking has been cancelled according to the cancellation rules.
- `completed`: the booking period has ended and all required walk occurrences have been verified as complete.

The booking should remain `assigned` between daily walks while its regular schedule is still active. A booking must not become `completed` just because one occurrence—or all occurrences for one day—finished.

### Occurrence-level status
Each dated/time-specific walk has its own independent status:
- `scheduled`: the occurrence is awaiting its start.
- `in_progress`: that occurrence's walk has started.
- `completed`: that occurrence's walk has ended successfully.
- `cancelled`: that occurrence was cancelled under the applicable rules.

These occurrence values are a proposed schema contract and must be checked against existing stored data and all three apps before implementation.

## Example: 30-day regular booking, two walks per day
- Walker accepts the booking: booking = `assigned`; each occurrence starts as `scheduled`.
- Today's morning walk finishes: today's morning occurrence = `completed`; booking remains `assigned`.
- Today's evening walk finishes: today's evening occurrence = `completed`; booking remains `assigned` because future dates remain.
- Tomorrow's walks remain `scheduled` until they start.
- At the end of the booking period, mark the booking `completed` only after verifying that all required occurrences have reached an allowed terminal outcome under the final business rules. Do not silently treat a missed or unfinished walk as completed.

## Required engineering safeguards before implementation
1. Keep booking-level and occurrence-level status fields separate.
2. On walker acceptance, atomically verify the booking is still available and eligible, then set `walkerId`, booking `status: assigned`, and acceptance/update timestamps. Prevent two walkers from claiming the same booking.
3. Start/complete actions must target the specific occurrence ID, not just the parent booking.
4. Completing an occurrence must not overwrite the parent booking status to `completed` while future required occurrences remain.
5. Define how missed, skipped, partially completed, cancelled, and rescheduled occurrences affect final booking completion.
6. Align Customer, Partner, Admin, backend logic, and Firestore Rules with one agreed schema before code changes.

## Source-level mismatch already observed
The inspected Partner booking-details flow currently writes booking `status: accepted` on acceptance. This conflicts with the user-confirmed booking status `assigned` and needs alignment in a future implementation step.

## Scope and verification
This commit records the approved product rule and proposed state model only. No app code, Firestore Rules, production data, deployment, or tests were changed/run by this step. Existing source/schema compatibility and deployed behavior remain unverified.
