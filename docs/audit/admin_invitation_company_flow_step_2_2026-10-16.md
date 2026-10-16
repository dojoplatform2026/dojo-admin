# DOJO WALK Admin Invitation & Company Flow — Step 2
Date: 2026-10-16
Status: Design/specification only; implementation and production configuration are not verified.

## 1. Repository evidence reviewed
- Admin navigation is in lib/screens/dashboard/admin_shell.dart. It has a Notifications menu item, while Customers, Pets, Support, and Settings currently route to generic “coming soon” content in the inspected file. There is no Admin Joining / Invitations menu item in this file.
- Existing Service Location hierarchy is represented by Firestore collections service_countries, service_states, service_cities, and service_areas; models use document IDs and parent IDs. Area-level scope can reference the selected active area document ID. Locality is not required for the requested admin scope.
- Admin login checks admin_users/{uid} and isActive == true; inspected client code does not enforce a complete role/permission/location-scope matrix.
- The inspected Partner Functions entry point contains only an authenticated checkBackend callable; no invitation lifecycle or reminder automation was found there.
- Searches in the accessible three repositories did not find a file named firestore.rules. This is not proof that deployed rules are missing; authoritative deployed Rules and project configuration remain unverified.

## 2. Selection-first invitation form
Required inputs:
- Full name: text (identity field).
- Email: email input (identity field).
- Role: dropdown.
- Access level: dropdown (State, City/District, Service Area).
- Country, State, City/District and Service Area: dependent dropdowns sourced from the Service Location Master; show only the fields required by the selected access level.
- Permissions: controlled multi-select/checkbox list derived from the selected role; no free-form permission strings.
- Invitation expiry: predefined duration dropdown plus optional date/time picker for authorized roles.
- Reminder policy: predefined schedule dropdown.
- Notification channels: controlled multi-select, limited to configured/verified channels.
- Invitation reason: predefined dropdown. Selecting Other may reveal one optional text field.
- Status and timestamps: system-generated/read-only; do not let invite form authors directly set active status.

Only name and email are routine free-text fields. Optional explanatory text is shown only when a permitted Other choice requires it.

## 3. Scope validation
- State scope: country ID + state ID required.
- City/District scope: country ID + state ID + city/district document ID required.
- Service Area scope: country ID + state ID + city/district ID + active service-area document ID required.
- Every selected child must be verified to belong to the selected parent on the trusted backend. Client-side dropdown filtering is for usability only.
- Persist stable document IDs, not location display names. Never infer scope solely from a role label.
- Existing Super Admin access must be preserved during any migration. Do not change existing documents until current records and authoritative rules are backed up/reconciled.

## 4. Invitation lifecycle
Proposed states:
1. invited — invitation created/sent.
2. pending_acceptance — invitee has not claimed it.
3. pending_approval — invitee claimed it, approval remains.
4. active — approval and activation checks passed.
5. expired — expiry time reached before successful claim/activation as policy defines.
6. rejected — approval denied.
7. revoked — authorized inviter/approver revoked it.

The product must specify whether an already-claimed invitation can still be approved after its original claim expiry; invitation expiry must never silently activate access. Invitation acceptance, approval, and activation are distinct transitions. A rejected or revoked invitation cannot be reused.

## 5. Reminder policy (proposed defaults; not yet approved/configured)
- On send: delivery result to inviter; invitation message to invitee.
- 24 hours after send if still pending acceptance: reminder to inviter; optionally resend invitee reminder only if channel policy permits.
- 48 hours after send if still pending acceptance: second reminder to inviter.
- 24 hours before expiry: notify inviter and invitee if still unclaimed.
- At expiry: mark expired using trusted server time and notify inviter.
- Pending approval: separate configurable cadence (suggested every 24 hours, capped to avoid noise), notify the authorized approver and optionally the inviter.
- On accept, approve/reject, activation, revoke: notify relevant actors and update dashboard counters.
- Stop reminders immediately when the relevant pending state ends. Use a deterministic event/delivery key to prevent duplicates and retry safely after transient failures.
- Dashboard shows counts for Pending Acceptance, Pending Approval, Expiring Soon, Expired, Rejected and Revoked, plus next reminder/expiry times.

The 24/48-hour intervals are proposals, not implemented business policy. Final cadence should be configurable from approved options, not free text.

## 6. Backend and audit requirements
- Trusted backend validates inviter authorization, target email, one-time claim, expiry, selected scope hierarchy, role-permission mapping and approver authorization.
- Store only a hash/reference for invitation secrets; never store plaintext secrets or passwords.
- Use server timestamps and scheduled backend work for expiry/reminders. Client clocks and UI state must not be authoritative.
- Firestore/Storage Rules must independently enforce access; hiding menu items is not security.
- Scope enforcement must apply to reads and writes across all relevant collections, not just the invitation form.
- Audit append-only events for invite created/sent, delivery attempts, claim, approval/rejection, expiry, role/scope change, suspension and revocation.
- Add tests for expired/replayed claims, wrong email, wrong scope/parent IDs, inactive inviter, unauthorized approver, duplicate scheduled delivery and legacy Super Admin compatibility.

## 7. Status / next gate
- Step 2 source review and specification: completed.
- UI, invitation collections, backend callable/scheduled functions, notification delivery, Security Rules, tests and production setup: not implemented/verified.
- Before implementation: locate the authoritative Firebase project/rules source and deployment workflow; inspect existing admin_users schema and preserve current Super Admin; confirm final reminder cadence, channels and expiry semantics. Then implement on the audit branch and run tests/emulator checks before requesting review.
