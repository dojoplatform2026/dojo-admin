# DOJO WALK — No-Response, Duplicate Delivery and Expiry Audit
## Step 44 • 2026-10-16

**Status:** Source audit and proposed handling contract only. No implementation.

## 1. Source evidence reviewed
- Partner `lib/screens/home/partner_home_screen.dart` on main.
- Prior documented audits of customer booking serialization, live-walk lifecycle, Firestore Rules source, and Functions entrypoint (Steps 35, 36, 39, 40, 42, 43).

## 2. Current-source findings
- Partner Home queries parent `bookings` assigned to the UID, then filters by `date`, active statuses, and sorts by `startTime`.
- The inspected flow does not show a persisted occurrence-level confirmation response, response deadline, expiry state, or idempotency key for popup delivery.
- The inspected live-walk flow creates a `walks/{walkDocumentId}` record and updates the parent booking; no canonical `occurrenceId` link was identified.
- Previously inspected Functions entrypoint exposes only `checkBackend`; no scheduled popup delivery, response deadline worker, or expiry processor was found there.
- Source Rules checked earlier do not establish a validated occurrence-response write contract. Deployed Rules/Functions were not verified.

## 3. Proposed response state machine
Keep response state separate from booking lifecycle:
- `pending`: no valid response recorded yet.
- `confirmed`: eligible assigned walker confirmed this exact occurrence before the deadline.
- `reason_submitted`: eligible walker declined/raised a reason, with required reason code and non-empty text.
- `expired`: deadline passed with no valid response, set by trusted backend.
- `superseded`: assignment version changed; old prompt/response token is stale.
- `cancelled`: occurrence itself was cancelled.

No response must remain pending until the backend deadline policy expires it; it must never be converted to confirmed by timeout or popup dismissal.

## 4. Duplicate and stale response protections
- Give every scheduled walk an immutable `occurrenceId`; use `assignmentVersion` to identify each authoritative assignment.
- Derive a deterministic delivery key from occurrence ID + assignment version + confirmation phase. Persist dispatch/attempt state server-side so trigger retries do not create duplicate logical prompts.
- On response submission, transactionally validate occurrence ID, current `walkerId`, assignment version, eligible walker status, current phase, and deadline.
- Accept only one terminal response for a given occurrence/version/phase. Repeated taps/retries should return the existing result without writing a second incident.
- If reassigned, mark the old assignment/prompt superseded; the former walker must not confirm or decline the new assignment.
- Treat FCM or client display as best-effort delivery, not proof that a popup was seen or answered.

## 5. Deadline and escalation behavior (policy pending)
- Define an approved response window relative to `scheduledStartAt`; do not invent fixed global clock times.
- A trusted backend job/trigger should expire unanswered prompts and create an auditable Admin follow-up/escalation.
- If a walk has started, is active, completed, or cancelled, suppress the pre-start confirmation prompt.
- A completed walk may have a separate post-completion attendance prompt only if product policy explicitly requires it; it must not overwrite pre-start confirmation.
- For immediate/ASAP walks, use a separate schedule-relative rule rather than forcing a past deadline.
- If backend processing is delayed, recompute current state before acting; never send stale prompts for expired, cancelled, completed, or reassigned occurrences.

## 6. Audit and operational fields to consider
For each phase/dispatch record, consider `occurrenceId`, `assignmentVersion`, `phase`, `deliveryKey`, `attemptCount`, `lastAttemptAt`, `deadlineAt`, `responseStatus`, `respondedAt`, `responseBy`, `expiredAt`, `supersededAt`, and server timestamps. Final schema and retention rules need review before implementation.

## 7. Open decisions
1. Exact lead time and response deadline/grace period.
2. Whether post-completion confirmation is required.
3. Which Admin queue and incident severity apply to expired/unanswered prompts.
4. Whether delivery uses FCM, in-app polling, or both.
5. Retention and privacy rules for reason text and delivery logs.

## 8. Verification boundary
This is documentation only. No source code, Firestore Rules, Functions, schema, or deployment changed. Tests were not run. Findings describe checked-in source, not verified deployed behavior.