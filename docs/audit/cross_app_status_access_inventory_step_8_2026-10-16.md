# DOJO WALK Cross-App Status & Access Inventory — Step 8
**Date:** 2026-10-16  
**Branch:** `audit/zone-service-area-mapping-2026-10-16`  
**Status:** Expanded source search; still not exhaustive and not runtime/deployed verification.

## 1. Files inspected / searched
- Customer: `lib/features/booking/screens/booking_confirmation_screen.dart`
- Customer: `lib/features/booking/screens/my_bookings_screen.dart`
- Partner: `lib/screens/home/walk_details_screen.dart`
- Partner: `lib/screens/home/navigation_screen.dart`
- Partner: `lib/features/live_walk/screens/live_walk_screen.dart`
- Partner: `lib/screens/home/partner_home_screen.dart` (search excerpts)
- Partner: `firestore.rules`
- Admin: `lib/features/walkers/services/walker_admin_service.dart`
- Admin: `firebase.json`

Search results span different repository commits/refs. The Partner files were fetched from the repository's default branch, while Admin audit documents are on the audit branch. Therefore this inventory is evidence of source patterns, not a single synchronized release snapshot.

## 2. Status values and lifecycle behavior found

### Customer booking submission
The Customer confirmation screen creates a new document in `bookings` and writes `status: pending` and `walkerId: null`. It stores schedules in fields including `walkSchedules`; the choose-dates path also stores `dateSchedules` and related schedule fields (from prior source review).

### Customer My Bookings
The UI recognizes these status strings for display/upcoming classification:
- `pending`
- `finding_walker`
- `walker_assigned`
- `walker_arriving`
- `confirmed`
- `assigned`
- `accepted`
- `in_progress` / `in progress`
- `completed`
- `cancelled` / `canceled`

This is a display compatibility list, not proof that every status is actively written. The cancellation UI writes a nested `cancelRequest` object with `status: pending`, `requestedBy: customer`, `customerId`, and `requestedAt`; it does not simply set the parent booking status to cancelled in the inspected excerpt.

### Partner booking progress
Observed writes:
- `walk_details_screen.dart`: updates parent booking to `accepted` before navigating; errors are caught and navigation continues.
- `navigation_screen.dart`: writes `accepted` when arrival is marked, `picked_up` after dog pickup, and `walking` before opening Live Walk.
- `live_walk_screen.dart`: creates a separate `walks/{walkId}` record, then updates parent booking to `completed` with `completedAt` and other progress fields in the inspected source. The separate writes can fail independently.
- `partner_home_screen.dart`: reads completed walk records and can update a walk's review fields (e.g. `reviewStatus: skipped`); this is a walk review workflow, not booking lifecycle status.

### Admin
The inspected `WalkerAdminService` watches bookings and walker-related audit data. This inspection did not establish an Admin booking-status mutation workflow. Do not infer that the walker-approval state machine is the booking state machine.

## 3. Firestore Rules source risk (not deployed verification)
The inspected Partner repository `firestore.rules`:
- explicitly denies all `bookings` creates;
- allows booking reads to active super-admins, the customer whose UID matches `customerId`, or the walker whose UID matches `walkerId`;
- allows customer updates only to `cancelRequest` and `updatedAt`, and only when existing status is one of `pending`, `confirmed`, `assigned`;
- allows assigned-walker updates to a limited key list including `status`, `updatedAt`, schedules/notes/counts/distance/duration, but the shown rule does not validate the specific allowed status transition;
- allows an active `super_admin` to manage bookings.

Implications if this file were deployed as the authoritative Rules:
1. Customer booking creation would be blocked.
2. Customer cancellation requests may fail for UI-recognized statuses such as `finding_walker`, `walker_assigned`, `walker_arriving`, `accepted`, or `in_progress`, because the rule's allowed source-status list is narrower.
3. Assigned walkers could potentially set arbitrary status strings if other validations do not constrain them.
4. `firebase.json` in the inspected Admin repository only declares Hosting, so it does not demonstrate that these Partner rules are deployed.

These are source-level risks only. Actual deployed Rules remain unknown. Do not deploy this Rules file as a fix without a coordinated contract and tests.

## 4. Key mismatches / open questions
- Customer UI supports `confirmed`, `assigned`, `finding_walker`, etc., while Partner flow writes `accepted`, `picked_up`, `walking`, `completed`. Define canonical values and legacy aliases before migration.
- Customer cancellation is a nested request workflow; who reviews/approves it and how parent status changes needs confirmation.
- `accepted` is written both before navigation and at arrival. Decide whether acceptance and arrival should be distinct.
- Completion writes a separate walk record and parent booking separately. Idempotency/recovery is needed.
- Multi-date / regular bookings need occurrence-level lifecycle statuses; parent `completed` should not imply every occurrence is complete unless that is intended.
- Walk document rules and all walk field writers still require a complete inventory.
- Repository-wide search is not exhaustive; search connector returned limited matching excerpts. This is not a complete audit of every status occurrence.

## 5. Proposed next actions (no code changes in this step)
1. Freeze a canonical lifecycle dictionary with legacy aliases and cancellation semantics.
2. Inspect the full `walks` Rules block and all writers/readers across synchronized refs.
3. Confirm which Rules file is authoritative and retrieve deployed Rules with authorized Firebase access.
4. Build a separate Emulator-only test project/config, with fixtures for new and legacy bookings.
5. Test customer create/read/cancel-request, assigned walker transitions, arbitrary status jumps, admin scope, completion retries, and partial failure recovery.
6. Run and record tests before implementing or deploying any change.

## 6. Step 8 checklist
- [x] Expanded search across Customer, Partner, and Admin status-related source.
- [x] Recorded source-observed values and cancellation-request structure.
- [x] Compared UI-supported statuses with Partner writes.
- [x] Recorded source-level Rules risks and deployment uncertainty.
- [ ] Exhaustive all-file status/walk Rules inventory.
- [ ] Confirm authoritative/deployed Rules.
- [ ] Emulator tests implemented and executed.
- [ ] Production change approved and separately reviewed.

No production code, Firestore Rules, live documents, or deployment was changed.
