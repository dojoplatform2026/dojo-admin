# DOJO WALK — Leave, Suspension and Reassignment Policy Audit
## Step 41 • 2026-10-16

**Status:** Source audit + proposed policy; not implemented.  
**Files inspected:** Admin WalkerAdminService, WalkerAdminModel, WalkerAdminHelpers, BookingsScreen on `audit/zone-service-area-mapping-2026-10-16`.

## 1. Current source findings

- Admin action enum contains `approve`, `reject`, `suspend`, `reactivate`, and `requestCorrection`.
- The walker model includes account/verification status and identity fields, but no typed Leave start/end range, Leave approval status, or Leave reason contract was found in the inspected model.
- Helper logic recognizes unavailable account statuses including rejected, suspended, inactive, left, unverified, and unapproved states.
- BookingsScreen is a booking monitoring/listing screen; no dedicated authoritative reassignment workflow was identified in the inspected screen.
- The inspected Admin service reads/updates walker and booking documents and writes audit logs for administrative actions, but no dedicated leave lifecycle or explicit reassignment transaction was identified in this audit.

## 2. Proposed policy (needs product approval)

### A. Eligibility for a new assignment/popup
A walker is eligible only if all applicable checks pass:
- account is approved, active, and verified;
- account is not suspended, rejected, inactive, or marked left;
- no approved Leave interval overlaps the occurrence's scheduled time;
- walker is still the current assigned UID and assignment version matches;
- occurrence has not been cancelled, completed, or superseded.

No new-walk prompt should be sent to an ineligible walker. These checks must be authoritative backend checks, not only UI filters.

### B. Leave contract proposal
A Leave request should have an explicit state machine, for example:
`pending` → `approved` or `rejected`; approved Leave may later be `cancelled` according to policy.

Candidate fields (not yet selected for a production schema):
- `leaveId`, `walkerId`
- `startAt`, `endAt` as timestamps, with explicit timezone handling
- `status` (`pending`, `approved`, `rejected`, `cancelled`)
- `reasonCode`, `reasonText`
- `requestedAt`, `decidedAt`, `decidedBy`, `updatedAt`, `schemaVersion`

Do not treat the existing generic `availability` field/subcollection as authoritative Leave until the schema and access rules are explicitly approved. Proposed storage location remains open.

### C. Suspension/Leave after assignment acceptance
- Do not silently delete, cancel, or hide an already accepted occurrence.
- Mark affected future occurrence(s) `reassignment_required` or create an equivalent explicit Admin queue item.
- Keep the old assignment and action history auditable.
- Admin must assign a replacement through a validated transaction; update `walkerId`, increment `assignmentVersion`, record actor/reason/time, and invalidate old popup/response tokens.
- A walk already in progress must follow an explicit safety/operations escalation path; do not automatically reassign a live walk.
- Do not count a no-response/no-show against a walker until policy and evidence criteria are met.

### D. Popup and response safety
- Re-check Leave/account status immediately before dispatch and again when accepting a response.
- Responses from a prior assignment version must be rejected.
- An unavailable walker should not receive a fresh pre-start prompt; any existing accepted assignment requires Admin triage.
- Missing response remains pending until a defined deadline and escalation rule is approved.

## 3. Open decisions before coding

1. Who may request Leave, and who may approve/reject it?
2. Is Leave interval inclusive of both start/end timestamps? Which timezone is authoritative?
3. What is the minimum notice/cutoff for Leave and how are same-day cases handled?
4. Which statuses require reassignment, and what happens if the walk is already in progress?
5. Who receives escalations and what SLA applies?
6. What evidence is required before a no-show/performance incident can be recorded?
7. Which collection/path and Firestore Rules will be canonical?

## 4. Required follow-up audits

- Step 42: inspect Confirm/Reason UI and define reason-code/text validation.
- Step 43: audit schedule-relative popup timing and live-walk suppression.
- Step 44: audit no-response, duplicate delivery, expiry, and stale assignment response handling.
- Step 45: validate occurrence generation for one-time, regular, and customize plans.
- Step 47: implement only after decisions are approved, then run emulator/unit/integration tests.

## 5. Verification boundary

This report documents source findings and a proposed policy only. No Flutter code, Rules, Cloud Functions, schema, or deployed Firebase state was changed. No tests were run. Deployed behavior remains unverified.