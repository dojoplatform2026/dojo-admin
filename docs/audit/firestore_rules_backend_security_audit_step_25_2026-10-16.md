# DOJO WALK — Firestore Rules and Backend Security Audit
## Step 25 — Booking assignment, occurrences, and GPS privacy
Date: 2026-10-16
Repositories inspected: `dojoplatform2026/dojo-partner` (`main` Rules); Customer repo Rules file at root was not found at the inspected path.
Type: Source audit and security plan only

## Executive summary
The inspected Partner `firestore.rules` is not ready to enforce the agreed booking/occurrence lifecycle on its own. It denies client booking creation, allows assigned walkers to update the parent booking's `status` without restricting allowed values, and has no explicit match for `walks/{walkId}` or `bookings/{bookingId}/occurrences/{occurrenceId}`. With the default-deny rule, those unmatched paths are denied unless another overlapping rule exists. This means current app writes may fail under these Rules, while the parent booking update rule is broader than the desired state machine. The deployed Rules and any trusted backend functions were not verified.

## Findings
### 1. Booking creation conflict
`firestore.rules` has `allow create: if false` under `/bookings/{bookingId}`. Customer code has previously been observed writing booking documents directly. If this exact Rules file is deployed, that client-side create is denied. A secure design should either validate creation through a trusted backend or provide a tightly validated customer-create rule aligned with the exact Customer payload. Do not simply change this to `allow create: if signedIn()`.

### 2. Parent booking status can be over-written by assigned walker
The assigned-walker update rule checks that the existing `walkerId` equals the authenticated UID and restricts changed keys to a list including `status`, `updatedAt`, `walkSchedules`, and walk counters. It does not constrain `status` to an allowed transition and does not prevent a walker from setting parent status to `completed`, `cancelled`, `pending`, or another arbitrary string. It also allows mutation of `walkSchedules`, which should generally be booking-plan data, not walker progress data.

### 3. No atomic acceptance path is defined in these Rules
The current booking update rule does not authorize an unassigned walker to claim a pending booking, and the admin-only rule does not provide the desired atomic, first-walker-wins acceptance operation. Firestore Rules alone cannot implement a robust multi-document transaction workflow with all eligibility checks. Use a trusted callable/backend transaction for acceptance, or design and test a narrowly constrained atomic update with careful race-condition handling and authoritative eligibility checks.

### 4. Occurrence collection has no explicit Rules match
No explicit `/bookings/{bookingId}/occurrences/{occurrenceId}` match appears in the inspected file. The default-deny rule therefore denies client reads/writes to occurrences unless another overlapping match is added. Rules must verify the parent booking relationship, authenticated customer or assigned walker, allowed changed fields, and occurrence state transitions. Clients must not be allowed to rewrite `bookingId`, `customerId`, `walkerId`, scheduled time, or duration after assignment except through a trusted authorized operation.

### 5. GPS and walk-result access has no explicit match
No explicit `/walks/{walkId}` match appears in the inspected file. The default-deny rule therefore denies direct client access to walk records unless another overlapping match exists. This is privacy-protective by default, but incompatible with direct client writes/reads unless a proper policy is added. The intended policy should restrict GPS route access to the assigned walker during the active walk, the booking customer according to the product's post-walk history policy, and authorized admins/support. Avoid broad reads for all signed-in users.

### 6. Booking visibility is based on customerId/walkerId
Booking get/list is allowed to admin, matching `customerId`, or matching `walkerId`. This is a useful baseline, but verify query compatibility and ensure sensitive exact pickup coordinates, access instructions, and live route data are not exposed through any broader profile or list endpoint before acceptance. If the booking document itself includes exact pickup details, the walker should only receive the minimum fields required before acceptance; Rules cannot redact individual fields from a document read.

### 7. Customer Rules file could not be confirmed
A root `firestore.rules` file was not found in the inspected Customer repository path. This does not prove that the Customer app has no Rules file; it means the matching source/deployment path must be identified before any cross-app Rules change. Do not assume the Partner Rules are the deployed project's complete Rules configuration.

## Required target security contract
- Booking creation: validated customer identity, required fields, approved pricing/schedule constraints, and safe initial status `pending`; preferably via trusted backend.
- Acceptance: trusted atomic operation checks booking is pending/unassigned, walker is authenticated, active/approved and service-area eligible; sets `walkerId`, parent `status: assigned`, `acceptedAt`, and `updatedAt` exactly once.
- Occurrences: separate per-slot documents with stable IDs. Customer/assigned walker/admin reads only as permitted; client progress updates are limited to valid occurrence transitions and allowed result fields.
- Walk results/GPS: link each `walks/{walkId}` to both `bookingId` and `occurrenceId`; deny writes by unrelated users; apply time/state checks and retention/access rules for precise coordinates.
- Parent booking: assigned walker must not be able to mark the whole booking `completed` by finishing one occurrence. Prefer trusted backend transitions for parent lifecycle and sensitive assignment fields.
- Admin actions: scoped to authorized active admin roles; preserve audit trail for assignment, cancellation, support access, and status overrides.

## Validation plan before implementation/merge
1. Identify the authoritative deployed Firestore Rules file and any Cloud Functions/Cloud Run/API responsible for bookings.
2. Compare exact Customer booking-create payload against the proposed schema and existing Rules.
3. Add emulator tests for customer create, unauthorized create, acceptance race, assigned-walker ownership, parent-status tampering, occurrence transitions, wrong occurrence IDs, walk-result/GPS access, and post-walk customer history access.
4. Confirm denied operations fail safely in UI and do not falsely navigate to pickup/live walk.
5. Run Rules tests and review the final diff before any deployment; do not deploy during audit.

## Scope and verification
Only source files were inspected. No Firestore Rules, backend code, app code, production database, or deployment were changed. No emulator/security tests were run. Findings describe the inspected repository source, not verified deployed behavior.
