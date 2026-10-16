# DOJO WALK — Walker Daily Confirmation & Attendance/Performance Audit (Step 31)

**Date:** 2026-10-16  
**Branch:** `audit/zone-service-area-mapping-2026-10-16`  
**Scope:** Read-only source audit of Partner availability/schedule, Firestore Rules, and Admin walker performance display.  
**Important:** This is an audit report only. No application code, Firestore Rules, backend, live data, or deployment was changed. No tests were run.

## 1. Product decision recorded

- Service operating window: 04:00 to 24:00 (India local time).
- Walker does **not** choose fresh slots every day.
- Walker confirms **today whether they will be available tomorrow**.
- Choices: “Yes, I will be available” or “No, I will not be available.”
- If “No”, collect a reason; provide a free-text reason for “Other”.
- If a walker confirms and then is absent without an accepted reason, apply a substantial negative performance impact only after attendance facts are checked and the walker has a chance to respond.
- If the walker has already accepted a booking, a daily availability response must not erase that booking responsibility.
- No-confirmation status should be visible to operations and should prevent offering new bookings for that date until the required confirmation is received.

## 2. Partner app source findings

### Existing working schedule screen
File: `lib/screens/home/working_schedule_screen.dart`  
Observed on repository default-branch source revision `e9f13b0627c5a07f2c5b3a0af09734cd007bb26c`.

The screen already lets a walker configure a recurring weekly schedule:
- Days Monday–Sunday.
- Per-day enabled/off toggle.
- Start and end times.
- Save to `walkers/{uid}.workingSchedule` with `status: active` and a `days` map.

It is therefore a **recurring schedule editor**, not the requested next-day confirmation workflow. Its initial UI defaults every day to enabled with 07:00–19:00; those defaults do not match the product's service window and must not be mistaken for an approved individual walker's real availability.

### Home screen
File: `lib/screens/home/partner_home_screen.dart`  
The home screen reads the `workingSchedule` field to decide whether a schedule has been set. The inspected code does not establish a daily tomorrow-confirmation flow.

### Gap
No `attendance`/daily confirmation implementation was found in the Partner code search for the `attendance` term. The requested workflow appears not to exist in the inspected source.

## 3. Firestore Rules compatibility blocker

File: `firestore.rules`  
Observed source revision: `7b02a8bfb4fe80ab04d72f59966e2e09c848ffd0`.

The `/walkers/{walkerUid}` owner-update allowlist includes the top-level field `availability`, but does **not** include `workingSchedule` or a proposed daily confirmation field. The existing schedule screen writes `workingSchedule` to the walker root document, so this write is not permitted by the inspected Rules unless another deployed Rules source differs.

The Rules separately permit the walker to create/update documents in the private `walkers/{walkerUid}/availability/{documentId}` subcollection. A future implementation could consider a date-keyed confirmation document there, but the exact schema, immutable history, write permissions, server-side validation, and deployed Rules must be reviewed before implementation.

**Do not assume the checked-in Rules are the deployed Rules.** Step 27 already found that the authoritative deployed Rules/backend source and project linkage are not confirmed.

## 4. Admin app findings

### Walker Management dashboard
File: `lib/features/walkers/screens/walker_management_dashboard_screen.dart`  
Observed source revision: `20da5d3ec38513bfa784d7a8c263c86156c28f2b`.

The current tabs are Available, Running, Verification, Rejected, and All Walkers. “Available” is based on approval eligibility and whether the walker is attached to a running booking; it does not represent a date-specific tomorrow confirmation.

### Performance Snapshot
File: `lib/features/walkers/widgets/walker_details_sections.dart`  
Observed source revision: `e51fb0c028622c0c6cba9c3cf897437872f728ca`.

The current performance panel reads pre-existing profile fields for total walks, completed walks, average rating, and cancelled walks. It does not display:
- Tomorrow confirmation state/date.
- Confirmed availability versus actual attendance.
- No-show count or reviewed no-show count.
- Reason/appeal status.
- Performance deductions or their audit trail.

### Admin service
File: `lib/features/walkers/services/walker_admin_service.dart`  
Observed source revision: `d87d248ff8cc7f1b265c0db0c8f5abd52b6a3eb5`.

The service has admin approve/reject/suspend/reactivate/correction actions and writes walker decision audit logs. The inspected action model does not implement attendance confirmation, no-show adjudication, or a performance score ledger.

## 5. Recommended future data contract (proposal only)

Prefer a date-specific record rather than overwriting a single boolean. Example candidate path:
`walkers/{walkerUid}/availability/{YYYY-MM-DD}`

Candidate fields:
- `walkerId`
- `serviceDate` (the date being confirmed, not the date the button was pressed)
- `response`: `available` | `unavailable` | `not_confirmed`
- `reasonCode` (required for unavailable; enumerated choices)
- `reasonText` (optional, required for Other)
- `confirmedAt`
- `updatedAt`
- `status`: `submitted` | `review_required` (only if a reason review is needed)
- server-controlled audit fields as approved by the backend contract

This is only a proposed schema. Use India local date/time consistently, with a defined timezone such as `Asia/Kolkata`. Do not allow a walker to set their own attendance outcome or performance penalty.

## 6. Attendance and performance safety rules

1. Availability confirmation is a declaration of expected availability, not proof of attendance.
2. Record actual attendance from a separately defined, auditable signal/process.
3. A missed confirmation is `not_confirmed`, not automatically a no-show.
4. A confirmed absence should be marked as a potential incident only after the relevant shift/accepted booking window has passed.
5. Before a severe performance deduction, record the incident evidence, reason supplied by the walker, review outcome, decision maker, and timestamp.
6. A confirmed availability response must not cancel an already accepted booking; that needs an explicit reassignment/escalation flow.
7. Restrict who can read sensitive absence reasons; show Admin only to authorized roles.
8. Use server-authoritative validation for penalty calculation and prevent client-side score tampering.
9. Do not silently impose a penalty for emergencies or verified technical/service disruptions; support review/appeal.
10. Retain an append-only audit trail for confirmation edits, incident creation, reviews, and score changes.

## 7. Required implementation sequence

1. Confirm the Firebase project used by Partner and identify the actually deployed Firestore Rules/Functions.
2. Resolve the existing mismatch between the schedule screen's root-level `workingSchedule` write and the checked-in Rules allowlist.
3. Agree the canonical date-specific confirmation schema and reason codes.
4. Implement the Partner “Tomorrow availability” card with Yes/No, reason selection, submit confirmation, and clear confirmation state.
5. Implement Admin visibility for per-date response, unconfirmed walkers, reviewed no-shows, reason/review status, and performance history.
6. Add trusted backend validation/audit for attendance incidents and performance deductions; do not let the client calculate or write its own penalty.
7. Add emulator/unit/widget tests and cross-app integration tests before deployment.

## 8. Verification status

- Source files inspected: Partner schedule screen, Partner home screen, Partner Firestore Rules, Admin walker dashboard, Admin walker details performance section, Admin walker service.
- Code changed: No.
- Firestore Rules changed: No.
- Backend/deployment changed: No.
- Tests run: No.
- Deployed behavior verified: No.
- Main blocker: deployed Firebase configuration and authoritative Rules/backend remain unverified; existing schedule write appears incompatible with the checked-in Rules.
