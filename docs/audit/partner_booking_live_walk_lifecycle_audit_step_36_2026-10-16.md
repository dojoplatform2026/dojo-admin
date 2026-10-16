# DOJO WALK Partner Booking / Live Walk Lifecycle Audit — Step 36

**Date:** 2026-10-16  
**Repository:** `dojoplatform2026/dojo-partner`  
**Source ref:** `main` (files fetched through GitHub API)  
**Report repository/branch:** `dojoplatform2026/dojo-admin` / `audit/zone-service-area-mapping-2026-10-16`

## Files inspected

- `lib/features/live_walk/screens/live_walk_screen.dart`
- `lib/screens/home/partner_home_screen.dart`

## Confirmed behavior

### Partner Home booking list

The checked-in Partner Home query uses `bookings` filtered by `walkerId == current UID`, then filters to today's records using `date`, accepts statuses `assigned`, `accepted`, `picked_up`, and `walking`, and sorts by `startTime`. It extracts the Firestore document ID as `bookingId`.

This contract does not match the customer booking fields found in Step 35 in several places: Customer creates `scheduledAt`, `preferredTime`, `walkSchedules` and `dateSchedules`; Partner Home expects `date` and `startTime` for its today list/sort. As checked in, this creates a schema mismatch risk: customer-created bookings may not appear or sort as expected unless another trusted process normalizes the fields.

### Live Walk document

When a walk ends, `LiveWalkScreen` creates a new `walks/{walkDocumentId}` record with:
- `walkerId`
- `bookingId` when provided
- `dogName`, `walkType`, `scheduledTime`, `duration`, `distance`, `location`
- `peeCount`, `poopCount`
- `startedAt`, `endedAt`
- `status: completed`
- `dogReturned`, `returnLocationVerified`
- timestamps and compacted `route`
- optional `startLocation` and `endLocation`

It then updates the parent booking to `status: completed` and records `completedAt`, `dogReturned`, `returnLocationVerified`, and `updatedAt`.

### Identity and lifecycle gaps

- Live Walk stores `bookingId` but no `occurrenceId`; therefore it cannot uniquely link to one individual walk occurrence inside a multi-walk booking or a regular daily template.
- `walks/{walkDocumentId}` is created with a newly generated document ID when the Live Walk screen instance initializes; that ID is not a shared customer schedule occurrence ID.
- The live-walk record's `scheduledTime` is display data, not an immutable scheduled start timestamp.
- The code shown does not persist a dedicated pre-start/post-completion confirmation response or popup state.
- Partner Home's current booking filter/sort uses legacy-style `date` and `startTime` fields while Customer's confirmed writer uses `scheduledAt` and nested schedules.
- This audit did not identify a canonical Leave field or verify how Leave/suspension blocks new assignments.

## Popup requirement implications

1. Do not implement popup targeting using only `bookingId` for bookings containing multiple scheduled walks.
2. Do not use display strings such as `scheduledTime` / `preferredTime` as the durable identity.
3. Introduce one agreed occurrence contract across Customer, Partner, Admin, and trusted backend logic before building notifications.
4. Before showing a pre-start prompt, verify the signed-in UID is the authoritative `walkerId` for that occurrence and the walker is eligible (approved, active, not on leave/suspended).
5. Do not show the confirmation popup during an active walk. The post-completion prompt must be keyed to that same occurrence and completion event.
6. If a previously accepted booking becomes ineligible due to Leave/suspension, preserve the accepted assignment record and require an explicit Admin reassignment/escalation rather than silently dropping it.

## Next actions

1. Audit Admin booking assignment, reassignment, and walker Leave/suspension source fields.
2. Reconcile Customer vs Partner booking field names and time/date semantics.
3. Define canonical occurrence records and response persistence, including idempotency.
4. Verify deployed Firestore Rules and trusted backend functions.
5. Implement only after contract approval; add tests for multi-walk, regular daily, customized dates, reassignment, leave/suspension, no response, and pre-start/live/post-completion gates.

## Status

- Partner Home and Live Walk source audit: completed for the two files above.
- Cross-app contract: incomplete; schema mismatch risk identified.
- Code/Rules/Functions changes: none.
- Tests: not run.
- Deployed Firebase behavior: not verified.
- Ready to deploy: no.
