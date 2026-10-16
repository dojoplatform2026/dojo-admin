# DOJO WALK — Confirm / Reason Popup Audit
## Step 42 • 2026-10-16

**Status:** Source audit and validation proposal only; no implementation.

## 1. Files inspected
- Partner `lib/screens/home/partner_home_screen.dart` (main)
- Partner `firestore.rules` (main)
- Partner `lib/features/live_walk/screens/live_walk_screen.dart` (main)

## 2. Findings from inspected source

1. Partner Home loads bookings where `walkerId == current UID`, then filters today's bookings by `date` and active statuses `assigned`, `accepted`, `picked_up`, and `walking`. It sorts using `startTime`.
2. In the inspected Home flow, no dedicated pre-walk Confirm/Reason popup or persisted reason-code/text response was identified. The active booking list is not equivalent to a confirmation workflow.
3. The inspected Firestore Rules permit an assigned walker to update only a limited set of booking fields: `status`, `updatedAt`, `walkSchedules`, `walkNotes`, `peeCount`, `poopCount`, `distance`, and `durationActual`. Confirmation response fields such as `confirmationStatus`, `reasonCode`, `reasonText`, `respondedAt`, and `assignmentVersion` are not included in that walker allowlist.
4. The Rules file explicitly denies booking creation for customers in the checked-in source. This remains a broader compatibility issue already recorded in earlier audits; do not assume the checked-in rules are deployed.
5. Live Walk includes a customer return/OTP completion flow, but that is not a pre-walk attendance confirmation or a decline-with-reason workflow.
6. No canonical reason-code enum or shared validation contract was identified in these inspected files.

## 3. Proposed Confirm / Reason contract (not yet implemented)

### Confirm
- Save a response only for the current assigned walker and exact immutable `occurrenceId`.
- Include `bookingId`, `occurrenceId`, `walkerId`, `assignmentVersion`, `response`, `respondedAt`, and schema version.
- Backend validates assignment, eligibility, response window, and current assignment version before accepting the response.
- Repeated identical submission should be idempotent; stale or duplicate conflicting submissions should be rejected and logged.

### Reason
- Reason is a separate response outcome, not a successful confirmation.
- Require both a supported `reasonCode` and non-empty `reasonText`.
- For `other`, require a meaningful text description; trim whitespace and enforce a documented maximum length.
- Suggested reason-code candidates: `schedule_conflict`, `illness_or_emergency`, `travel_issue`, `safety_concern`, `unable_to_contact_customer`, `other`. Product owner must approve the final list.
- Keep raw reason text private to authorized operations staff; do not expose it to unrelated walkers or customers.
- Reason submission should create or update an explicit operations review item; it must not silently cancel the booking.

### No response
- No response remains `pending` until a configured deadline.
- Expiry/escalation timing must be derived from the occurrence's scheduled start and product policy, not a fixed global clock time.
- No response alone must not be treated as a successful confirmation or automatic proof of a no-show.

## 4. Required backend and Rules work before release
- Add a canonical per-occurrence confirmation response schema and server-side validation.
- Use trusted backend logic/transaction to enforce current `walkerId` + `assignmentVersion` + occurrence lifecycle.
- Update Firestore Rules only after the shared customer/partner/admin contract is reviewed; do not simply widen the walker field allowlist.
- Add tests for missing reason, whitespace-only reason, `other` without text, unauthorized walker, stale assignment version, duplicate submission, completed/cancelled occurrence, and response during a live walk.

## 5. Verification boundary
This is a documentation-only audit. No app code, Firestore Rules, Cloud Functions, database schema, or deployed configuration was changed. Tests were not run. Deployed behavior remains unverified.