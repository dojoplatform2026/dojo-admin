# DOJO WALK — Partner Booking & Live Walk Mutation Audit (Step 3)

**Date:** 2026-10-16  
**Status:** Static source audit; not emulator-tested  
**Branch:** `audit/zone-service-area-mapping-2026-10-16`  
**Scope:** Partner navigation, walk details, live walk writes, inspected Partner Firestore rules, Admin walker service.

## Executive summary

The inspected Partner app writes booking status changes at pickup, dog handover, walk start and walk completion. The completion path also creates a separate `walks/{walkId}` document. The inspected `firestore.rules` permits only a narrower set of fields for walker booking updates and has a default-deny catch-all. No explicit `match /walks/{walkId}` block was found in the inspected rules excerpt. If this rules file is deployed as the active ruleset, important live-walk writes are likely to be denied. Production deployment status is unverified.

## 1. Booking status updates from Partner

### Navigation screen
`lib/screens/home/navigation_screen.dart` updates `bookings/{bookingId}` with:
- `status = accepted` when the walker marks arrival;
- `status = picked_up` when the dog is received;
- `status = walking` when the walk starts;
- `updatedAt = serverTimestamp()` for each operation.

### Walk details screen
`lib/screens/home/walk_details_screen.dart` also writes `status = accepted` and `updatedAt` when navigating to pickup. Errors are swallowed and navigation continues, so the UI can proceed even if the status update fails.

### Live walk completion
`lib/features/live_walk/screens/live_walk_screen.dart` writes the booking:
- `status = completed`
- `completedAt = serverTimestamp()`
- `dogReturned = true`
- `returnLocationVerified = <boolean>`
- `updatedAt = serverTimestamp()`

## 2. Separate `walks` document written at completion

The Partner live-walk completion method creates `walks/{autoId}` with fields including:
- `walkerId`, optional `bookingId`, `dogName`, `walkType`, `scheduledTime`;
- `duration` (seconds), `distance` (kilometres), `location`;
- `peeCount`, `poopCount`, `startedAt`, `endedAt`, `status=completed`;
- `dogReturned`, `returnLocationVerified`, `createdAt`, `updatedAt`;
- optional `startLocation`, `endLocation`, and `route`.

The live-walk method writes the `walks` document first, then updates the booking. If the second write fails, the first document may already exist; these writes are not atomic in the inspected code. A retry can create a second walk document because the ID is generated for the screen instance.

## 3. Comparison with inspected Partner Firestore rules

The inspected `firestore.rules` booking block permits walker updates only when the existing booking's `walkerId` equals the authenticated UID and changed fields are limited to:
`status`, `updatedAt`, `walkSchedules`, `walkNotes`, `peeCount`, `poopCount`, `distance`, `durationActual`.

Findings:
1. `accepted`, `picked_up`, and `walking` only change allowed keys (`status`, `updatedAt`) but still depend on booking assignment and status-transition logic.
2. The completion update adds `completedAt`, `dogReturned`, and `returnLocationVerified`, which are not in the inspected allowlist. If these rules are active, the completion booking update is denied.
3. The completion creates `walks/{walkId}`, but no explicit `match /walks/{walkId}` rule was found in the inspected file. The final catch-all denies unmatched reads/writes; if this file is active, the write is denied.
4. The inspected walker booking update rule does not enforce an explicit allowed status transition sequence. Merely limiting changed keys is insufficient to stop a walker from changing status to an inappropriate value on an assigned booking.
5. Rules must also validate numeric bounds/types for duration, distance, counters, timestamps and route size if client writes remain permitted.

## 4. Assignment and Admin observations

The Admin `WalkerAdminService` inspected source supports walker lifecycle actions (approve, reject, suspend, reactivate, request correction) and reads bookings; the inspected service excerpt does not establish a complete booking-assignment action. The booking list screen is not proof that no assignment workflow exists elsewhere. Search/audit the entire repository for writes to `bookings/{id}`, especially setting `walkerId` and changing pending/assigned statuses, before finalizing Admin permissions.

The Partner booking screens trust the supplied `bookingId` when writing. Firestore Rules must enforce that the signed-in walker is the currently assigned `walkerId`; UI navigation state is not authorization.

## 5. Required design decisions before implementation

- Define canonical status values and legal transitions, for example pending -> assigned -> accepted -> picked_up -> walking -> completed, with cancellation/error branches explicitly decided by product owners.
- Confirm the canonical assignment identity: current Partner checks generally compare `bookings.walkerId` with Firebase Auth UID. Ensure Admin assignment writes that same UID, not a display ID.
- Decide whether `walks` is the canonical history record, and whether its ID should be stable per booking/walk number to prevent duplicate completion records.
- Make walk creation and booking completion atomic with a transaction/batch where valid, or design a retry-safe backend workflow.
- Add explicit, restrictive `walks` read/create/update rules; do not broadly allow all signed-in users.
- Expand booking completion fields only after exact type/value checks and permitted transition validation are written.
- Audit route storage size and customer visibility requirements before granting access to GPS route history.

## 6. Emulator tests required

Positive:
- Assigned walker can progress through the agreed status sequence.
- Assigned walker can create a valid walk record linked to their assigned booking.
- Completion saves booking and walk history according to the agreed atomic/retry-safe design.
- Active super admin can assign a verified/eligible walker and audit the change.

Negative:
- Unassigned walker cannot update booking or create a walk linked to it.
- Walker A cannot mutate Walker B's booking or walk record.
- Walker cannot self-assign, change customerId, price/payment fields, or use invalid status transitions.
- Walker cannot spoof unbounded distance, duration, counters, route points, or timestamps.
- Customer cannot write a `walks` document or mark their booking completed.
- Inactive/non-admin account cannot perform Admin assignment or override status.

**Safety boundary:** This is a static audit document. No app source, Firestore rules/indexes, Production data, Hosting, or Functions were changed. Production rules remain unverified.
