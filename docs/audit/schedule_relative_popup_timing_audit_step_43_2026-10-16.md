# DOJO WALK — Schedule-Relative Popup Timing Audit
## Step 43 • 2026-10-16

**Status:** Source audit and timing proposal only; not implemented.

## 1. Source reviewed
- Partner `lib/screens/home/partner_home_screen.dart` (main)
- Partner `lib/features/live_walk/screens/live_walk_screen.dart` (main)
- Customer `lib/features/booking/screens/booking_confirmation_screen.dart` (main)

## 2. Findings

- Partner Home filters bookings to the device's local calendar day using `date`, accepts statuses `assigned`, `accepted`, `picked_up`, and `walking`, and sorts by `startTime`.
- Customer booking creation stores `scheduledAt` and other parent-level schedule fields. Partner Home's inspected daily list reads `date` and `startTime`. This is a field/normalization mismatch risk: schedule-relative notifications cannot be reliable until the backend creates a canonical per-walk occurrence timestamp.
- Live Walk records `startedAt` and `endedAt` and runs a timer while the walk is active. No shared occurrence confirmation phase or popup suppression contract was identified in the inspected files.
- The inspected files did not reveal a pre-start/post-completion confirmation popup driven by a schedule-relative backend trigger.
- One-time immediate bookings use the current time for `scheduledAt`; a notification policy must distinguish immediate requests from future scheduled walks.
- No tests were run and deployed trigger/notification behavior was not verified.

## 3. Proposed timing rules (require approval)

Use a canonical occurrence document with immutable `occurrenceId`, `scheduledStartAt`, `scheduledEndAt`, `walkerId`, `assignmentVersion`, and lifecycle status. All times should be absolute timestamps; service-date display and daily grouping should consistently use Asia/Kolkata.

### Pre-start prompt
- Trigger from the occurrence schedule and a configurable lead-time policy; do not hard-code global wall-clock times such as 6 PM, 9 PM, or 11 PM.
- Before dispatch, verify current assignment, assignment version, walker eligibility, occurrence status, and approved Leave overlap.
- Do not send if the occurrence is cancelled/completed/superseded or a walk for that occurrence is already in progress.
- Delivery should be idempotent so retries do not create duplicate prompts.

### Live-walk suppression
- Treat an authoritative active walk state/record linked to the same `occurrenceId` as a hard block for confirmation prompts.
- Re-check state when opening the prompt and when submitting the response; hiding a client popup alone is insufficient.
- A live walk must not be interrupted by a late pre-start prompt.

### Late / post-completion handling
- If the scheduled start has passed without a response, mark the confirmation `expired` or keep it in a clearly defined escalation state according to approved policy; never imply that it was confirmed.
- A post-completion prompt, if needed for a separate attendance/performance record, must be a distinct phase and must not overwrite pre-start confirmation.
- Completion should be tied to the same `occurrenceId`; parent booking status alone cannot distinguish repeated daily walks.

## 4. Timing policy decisions needed
1. Approved lead time before each scheduled occurrence.
2. Response deadline and grace period after scheduled start.
3. Whether a post-completion confirmation is required and its purpose.
4. Handling of ASAP/immediate walks where the lead-time window may already have passed.
5. Canonical backend trigger/queue and retry/de-duplication strategy.

## 5. Verification boundary
Documentation only. No code, Firestore Rules, Cloud Functions, database schema, or deployed configuration changed. Tests were not run. Deployed behavior remains unverified.