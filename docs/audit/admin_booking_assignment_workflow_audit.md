# DOJO WALK — Admin Assignment Workflow Audit (Step 4)

**Date:** 2026-10-16  
**Status:** Static repository search and source inspection; not emulator-tested  
**Branch:** `audit/zone-service-area-mapping-2026-10-16`

## Scope inspected
- `lib/features/walkers/services/walker_admin_service.dart`
- `lib/screens/live/live_operations_screen.dart`
- `lib/features/walkers/screens/walker_management_dashboard_screen.dart`
- `lib/screens/bookings/bookings_screen.dart` (previous step)
- Repository search for `walkerId`, `assignWalker`, booking collection writes and booking updates.

## Findings

### 1. WalkerAdminService is not a booking assignment service
The inspected service exposes:
- `watchWalkers()` and `watchWalker(uid)`;
- `watchBookings()` and `watchWalkerBookings(walkerId)`;
- walker approval/rejection/suspension/reactivation/correction actions;
- audit-log writes for walker lifecycle actions.

Its `runAdminAction()` transaction updates `walkers/{walkerId}` and creates `audit_logs/{id}`; it does not assign a booking or set `bookings/{bookingId}.walkerId`.

### 2. Live Operations displays online walkers and routes
`live_operations_screen.dart` listens to `walkers` where `isOnline == true`, maps `currentLocation`, and loads route points from `walk_locations` filtered by `walkerId`, ordered by `timestamp`, with a limit of 300. The inspected screen excerpt is monitoring/display behavior, not booking assignment.

### 3. Walker Management dashboard detects running statuses
The dashboard treats `in_progress`, `active_walk`, `walking`, and `walk_started` as running-booking statuses. This is inconsistent with some other observed Customer/Admin labels and Partner live-walk values. Normalize machine statuses before building transition rules.

### 4. Assignment action was not found in inspected paths
Repository search and the inspected Admin booking screen/service did not identify a concrete Admin action that writes `bookings/{bookingId}.walkerId`. This is a bounded finding, not proof that no such action exists anywhere in the full repository; additional files/branches and any backend workflow must be checked.

## Current workflow gap / risk

The Partner app authorizes its own booking updates by comparing the authenticated UID with the existing booking's `walkerId`. That is a sound ownership check only if the trusted assignment workflow writes the correct Firebase Auth UID to that field. Without an identified, tested assignment writer, the end-to-end flow is not yet established.

The current inspected Admin code verifies `admin_users/{uid}` exists, `isActive == true`, and `role == 'super_admin'` before walker lifecycle changes. Any future assignment action should enforce equivalent server-side authorization in Firestore Rules or a trusted backend; UI visibility is not sufficient.

## Recommended canonical assignment operation (design only)

1. Admin selects an eligible, approved and active walker.
2. Trusted assignment operation reads the booking, walker, and active admin authorization.
3. It confirms booking is in an assignable state, walker is eligible/available and belongs to the service area, and no conflicting assignment exists.
4. In one transaction, set `walkerId` to the walker's Firebase Auth UID, set the canonical assigned status, and update timestamps.
5. Write an immutable audit record with actor UID, booking ID, walker UID, previous/new status, and timestamp.
6. Require idempotency or a clear reassignment flow; do not silently overwrite an existing walker.
7. Partner queries only bookings where `walkerId == auth.uid`; rules enforce the same constraint.
8. If client-side Admin writes are used, the Rules must validate the whole transition and eligibility. Prefer a trusted backend for complex assignment and audit enforcement.

## Required decisions and tests
- Decide whether assignment is manual, automatic, or both.
- Canonical status values and allowed transitions.
- Eligibility/availability and service-area checks.
- Reassignment, cancellation and backup-walker behavior.
- Test that non-admin cannot assign; inactive admin cannot assign; an ineligible walker cannot be assigned; assignment cannot overwrite an existing walker without an explicit authorized transition; assigned walker UID must match Firebase Auth UID; duplicate retries are idempotent.

## Safety boundary
No assignment action, source code, Firestore rules/indexes, Production data, Hosting, or Functions were changed. This is an audit/design artifact only; active Production rules and backend workflows remain unverified.
