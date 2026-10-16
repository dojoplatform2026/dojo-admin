# DOJO WALK — Regular Walk Company-Controlled Operations

**Date:** 2026-10-16  
**Decision status:** User-confirmed product requirement; design only  
**Applies to:** Customer, Partner, Admin, and shared backend

## Product rule
Regular Walk operations are controlled by the company. The company controls both (1) assignment of walkers to recurring customer plans and (2) when/where walkers are available to receive company assignments. Walkers do not self-assign recurring plans and cannot bypass company assignment.

## Proposed company workflow

1. Customer submits a Regular Walk plan. The booking is created as a request with `status=pending` and a separate plan-review state such as `planStatus=pending_confirmation`.
2. Company/Admin reviews the requested schedule, service area, pet/pickup details, plan capacity and price.
3. Company checks the walker availability roster: active/approved, documents verified, assigned service area, available time slots, workload/capacity, time-off/unavailability and overlapping bookings.
4. Company selects a suitable walker and assigns the plan. The assignment is written to the booking/plan by a trusted company-authorized action.
5. Walker receives the assignment and may acknowledge it according to company policy. Acknowledgement is not self-assignment and does not let the walker change the assigned customer or plan.
6. If the walker declines, becomes unavailable, or misses an acknowledgement deadline, the plan returns to the company assignment queue for reassignment/backup.
7. Company monitors recurring occurrences, absences, complaints, pauses, replacements and cancellation. Every assignment/reassignment is audit logged.

## Availability is company-managed
Recommended availability record (schema proposal, not implemented):
- `walkerId`
- `serviceAreaIds` / approved service location IDs
- `weeklyAvailability` with local-time windows
- `unavailableIntervals` / leave
- `maxConcurrentBookings` or capacity policy
- `activeForAssignment`
- `lastReviewedAt`, `reviewedBy`
- timestamps and audit metadata

Availability must not mean merely `isOnline=true`: online presence is live-operation telemetry, while recurring work availability is a planned, company-managed roster.

## Authority boundaries
- **Customer:** request/modify/cancel plan within published rules; cannot select or force a walker assignment.
- **Walker/Partner:** view assigned work and report availability/leave or accept/decline only if the company enables that policy; cannot write arbitrary `walkerId`, change plan ownership, or assign themselves.
- **Company/Admin:** approve plans, manage availability, assign/reassign, set backup, pause/resume plans, and inspect assignment history.
- **Backend/Security Rules:** enforce authorization and valid state transitions; hiding buttons in the UI is not security.

## Regular plan vs individual occurrence
Keep the recurring plan distinct from its daily walk occurrences. Proposed model:
- Plan: customer, pet, service area, approved schedule template, plan status, assigned primary walker, optional backup, effective dates.
- Occurrence: plan ID, scheduled date/time, assigned walker for that occurrence, status, check-in/walk/return evidence, completion outcome.
This avoids one recurring booking document being overloaded with every daily execution and allows an approved backup for a single missed day. Final schema must be reconciled against current customer/partner Firestore fields before implementation.

## Required safeguards/tests
- Only an authorized company role can assign/reassign a Regular Walk.
- Reject assignment to unapproved/inactive walkers, outside their service area, during unavailable windows, or beyond capacity.
- Detect overlapping assignments, including recurring time slots.
- Prevent duplicate occurrence creation and duplicate completion writes.
- Record who assigned/reassigned, when, previous walker, new walker, reason and plan/occurrence IDs.
- Test unauthorized customer/walker assignment attempts and valid/invalid Admin flows in Firestore Emulator.
- Do not deploy rules, indexes, Functions, or migrate Production data until tests and schema reconciliation pass.

## Implementation status
This file records the requirement and proposed workflow only. No application code, rules, Production data, or deployment configuration was changed.


## Priority clarification: time-to-time execution (highest priority)

The primary success criterion is that each scheduled walk is delivered on time, not merely that a recurring plan has a walker assigned.

### Proposed time-control rules
- Every planned walk occurrence must have a local date, start time, duration, pickup/service area and a clear status.
- Store scheduled timestamps consistently (Firestore Timestamp in UTC); display and schedule using the service location's local time zone (India: `Asia/Kolkata` for current launch areas).
- Availability windows must cover the full walk duration plus configurable travel/buffer time.
- Before assignment, check overlapping jobs, travel feasibility, approved area, leave and daily workload.
- Generate a separate occurrence for each scheduled walk; use an idempotent occurrence key so retries do not create duplicate walks.
- Set reminder/alert thresholds as company configuration (for example, upcoming, due, late and missed); these are proposed configurable thresholds, not fixed product promises.
- If the primary walker has not acknowledged or arrived within the configured window, alert operations and route the case to the company's reassignment/backup queue.
- Keep planned availability separate from online presence and live GPS. Track GPS only during an active walk under the app's location policy.
- Record scheduled time, actual arrival, actual start/end, delay reason, reassignment and who handled each action for operational reporting.

### Time-based states to consider
`scheduled` -> `assigned` -> `accepted` -> `walker_arriving` -> `picked_up` -> `walking` -> `completed`

Exception states should include company-managed `reassignment_required`, `delayed`, `missed`, `cancelled`, and `rescheduled` as separately modelled fields or controlled statuses after final state design. Do not mix plan status with an individual occurrence status.

### Required time-related tests
- Assignment at an overlapping slot is rejected.
- Assignment is rejected if travel/buffer time makes the next job infeasible.
- A walk crossing midnight or a daylight/time-zone boundary is handled consistently.
- Reminder and late alerts fire once per occurrence despite retries.
- Delayed/missed occurrences enter the company operations queue.
- Reassignment preserves the original audit history and prevents two walkers being treated as active assignees.
- Schedule edits do not silently rewrite already completed occurrences.

**Implementation status:** requirements added to this audit design only. No code, database, Rules, Functions, or Production configuration changed.


## Weekly off and leave management (user-confirmed requirement; design only)

### Weekly off
- Every active walker gets one planned weekly off day per seven-day roster cycle.
- Walker may request a preferred day, but the company approves the final day after checking area/time-slot demand, minimum staffing, assigned Regular Walk occurrences, and backup coverage.
- If the preferred day leaves a coverage gap, suggest another day. Staffing limits are configurable by area and time window.
- Do not assign new work on an approved off day. Any existing occurrence must be explicitly reassigned or rescheduled before the off day is finalized; retain the audit trail.

### Emergency leave
- Partner app lets a walker report/request emergency leave with start/end time, a reason category, and optional note.
- Urgent submissions alert company operations immediately. Submission does not silently cancel customer walks; operations checks affected occurrences and arranges backup/reassignment, then communicates service changes to affected customers when needed.
- For genuine immediate emergencies, allow a controlled report first and company review afterward. Record reporter, timestamps, reviewer, decision, and all affected booking changes.

### Village/home visit or multi-day leave
- Support a leave date/time range, reason category (including village/home visit), and optional note. Encourage advance notice.
- Company checks commitments, area coverage, staffing and backups before approval. Approved leave blocks assignments for the entire interval, including travel days when included in the request.
- If existing walks overlap, each affected occurrence needs a documented reassignment/reschedule plan before approval.

### Proposed records and safeguards
- Leave request fields: `leaveRequestId`, `walkerId`, `leaveType` (`weekly_off`, `emergency`, `extended`), `startAt`, `endAt`, `reasonCategory`, optional `note`, `status`, `requestedAt`, `reviewedAt`, `reviewedBy`, `decisionReason`.
- Keep leave separate from online presence and walk attendance. Only authorized company roles approve/reject. Prevent overlapping approved leave and assignments during approved leave.
- Keep personal leave notes private; customer messages should explain service reassignment without revealing private reasons.
- Test concurrent leave requests, staffing minimums, emergency escalation, long leave, overlapping bookings, backup failure and timezone handling.

**Implementation status:** design only; no app code, Firestore data, Rules, Functions, or deployment settings changed.


## Weather, heavy rain, waterlogging and flood safety

**Product requirement proposed for company operations; design only, not implemented.**

- Treat weather and route safety as a separate operational override, not ordinary walker leave or a punctuality failure.
- Support area-level weather/safety advisories with severity, affected service areas/routes, start/end or next-review time, source/reporter, review status and audit history.
- Light rain: walks may proceed only when local conditions, route and pet/walker safety are acceptable.
- Heavy rain, lightning, severe wind or unsafe visibility: operations may pause, delay or reschedule affected walks. Do not pressure walkers to continue in unsafe conditions.
- Flooding, dangerous waterlogging, official evacuation/advisory or an impassable route: pause affected-area assignments and do not dispatch a backup into the same hazard.
- Walker can report unsafe conditions from Partner app; urgent reports alert operations and flag affected occurrences for review. GPS/location must not be used to force a worker into a hazardous route.
- Company chooses among safe options: wait and reassess, reschedule, cancel/refund or apply a weather policy approved by the business. Do not promise automatic refunds or specific compensation until policy is defined.
- Notify affected customers with a concise reason and next update/action. Share only necessary safety information; preserve a timestamped event and decision record.
- Before restarting service, operations rechecks conditions and clears the area/route. Recovery must not create impossible overlapping schedules; calculate travel/buffer and prioritize safety.
- Weather provider data can be an alert input but must not be treated as proof that an individual street or route is safe. Support human reports and official local advisories too.

### Weather-safety tests
- Heavy rain/lightning alert pauses or flags affected occurrences according to configured policy.
- Flood/waterlogging blocks dispatch into the affected area until cleared by authorized operations.
- A backup walker is not assigned through a flagged hazardous route.
- Duplicate weather alerts do not send repeated customer notifications for the same event.
- Affected bookings retain original schedule and audit history when delayed/rescheduled/cancelled.
- Restart requires an authorized clearance and revalidation of staffing and time feasibility.

**Implementation status:** requirements documented for design only. No app code, Firestore data, Rules, Functions, weather provider, or Production configuration was changed.


## Consolidated Company Operations Flow Rules

These are design requirements for cross-app reconciliation, not implemented production rules.

1. **Company authority:** only authorized company roles can approve Regular Walk plans, assign/reassign walkers, approve leave, override weather holds, and clear an affected area for service. UI controls alone are not authorization; backend and Firestore rules must enforce permissions.
2. **Weekly off:** each active walker gets one planned weekly off in each seven-day roster cycle. Walker may request a preferred day; company approval depends on area/time-window staffing, demand and affected occurrences. Avoid simultaneous leave that breaches coverage requirements.
3. **Leave lifecycle:** requested -> approved/rejected; support cancellation according to policy and emergency report with immediate alert plus later review. Extended/village leave records a date/time range. Only approved leave blocks planned assignments, but an emergency report triggers immediate safety/operations review.
4. **Coverage before approval:** before approving leave or weekly off, identify all affected occurrences and record reassignment/rescheduling or an approved service-change decision. Do not silently drop customer walks.
5. **Assignment eligibility:** assign only an active, approved, appropriately verified walker who covers the service area and has capacity for the full duration plus travel/buffer. Check leave, overlap, availability and current workload.
6. **Punctuality:** every occurrence has one scheduled local date/time, duration, service area, current owner, status and audit history. Track actual arrival/start/end separately from scheduled time. Delays/missed walks enter the company operations queue and trigger configured alerts.
7. **Weather/safety override:** severe weather, lightning, flood, dangerous waterlogging or an official hazard can place an area/route on hold. Do not dispatch a primary or backup into a known unsafe route. Only authorized operations clears the hold after reassessment.
8. **Customer communication:** send a timely, clear notice for delays, reassignment, rescheduling or cancellation. Do not expose a walker's private leave reason. Refund/credit behaviour must follow a separately approved policy.
9. **Backup and recovery:** backups must independently pass area, time, leave, overlap and safety checks. If no safe feasible backup exists, notify the customer and use the approved reschedule/cancellation policy.
10. **Auditability and concurrency:** record actor, action, reason, timestamps, prior/new assignment and impacted occurrence IDs. Approval and assignment transactions must recheck staffing/capacity atomically to prevent two concurrent approvals from breaking the minimum coverage rule.
11. **Privacy and location:** planned availability is separate from online status and GPS. Location tracking follows the active-walk policy; do not use GPS to compel unsafe travel. Restrict access to personal leave notes.
12. **Cross-app consistency:** Customer requests and receives status/notifications; Partner reports availability, leave and safety incidents and sees assigned work; Admin owns approvals, assignment, backup, area holds and audit history. Canonical status values and transitions must be reconciled across all repositories before implementation.
13. **Testing and rollout:** add emulator/backend tests for unauthorized actions, concurrent leave approvals, overlap/capacity, backup failure, weather holds, idempotent alerts, rescheduling, and status transitions. Do not deploy rules, functions, indexes or migrate production until schema reconciliation and tests pass.

**Status:** consolidated design recorded; no app code, Firestore data, security rules, backend functions or production settings were changed.


## Sudden personal emergency and field-team leadership

**Product requirement proposal; design only, not implemented.**

### Sudden emergency: worker must leave immediately
- Provide a one-tap **Emergency / I must leave now** report in the Partner app. A worker must not be trapped in an approval flow when an urgent family or personal emergency requires immediate departure.
- Capture only the minimum needed: current time, affected assigned occurrence(s), broad reason category (personal/family/medical/other), optional note, and whether the worker is safe. Do not require detailed private family or medical information.
- Immediately notify the central Operations/Admin team and the designated area/team lead. Mark the worker temporarily unavailable from the reported time pending review; prevent new assignments during that interval.
- Show the affected walk(s) to Operations and trigger a coverage workflow: primary walker unavailable -> check same-area eligible backup -> check other approved available walker with feasible travel time -> if none, contact customer and apply approved reschedule/cancellation policy.
- Do not silently cancel a booking or automatically mark it completed. Preserve the original assignee and record each replacement, reason, timestamp and actor.
- If the emergency occurs during an active dog walk, prioritize immediate safety: the walker contacts Operations, follows the safe handover/return procedure, and does not leave the dog unattended. Operations arranges a safe handover to an authorized replacement/customer according to company policy.
- Operations may review and classify the incident afterward; the field worker's urgent report itself should trigger immediate coverage handling. Repeated abuse can be reviewed separately and must not delay a genuine emergency response.

### Proposed team structure: Area/Field Lead (not a substitute for company control)
- **Company Operations/Admin:** owns policies, final leave decisions, staffing minimums, walker approvals, assignment authority, customer exceptions, and audit review.
- **Area/Field Lead (proposed “Head Walker” role):** a trusted, approved senior field worker or supervisor for a defined service area/shift. Receives urgent alerts, helps coordinate safe handovers, checks attendance/coverage, and communicates field conditions to Operations.
- **Field Walkers:** perform assigned walks, update attendance/status, report delays, hazards and leave/emergencies, and follow safety procedures.
- Start with the clearer role name **Area Lead** or **Field Team Lead** rather than “Head Walker,” because it defines area/shift responsibility and avoids implying company-wide authority.
- The Area Lead may coordinate and recommend a backup, but must not independently approve their own leave, override weather holds, change customer pricing, or permanently reassign bookings unless the company explicitly grants a narrowly scoped permission. All authoritative changes remain company-controlled and audited.
- Provide a backup lead/on-call Operations contact so emergencies are handled outside one person's working hours. Do not assume the Area Lead is always online or available.

### Required safeguards/tests
- Emergency report works when worker has poor connectivity: save a pending report locally and retry; clearly indicate when the server confirms receipt. Provide an alternate company contact procedure if the app cannot connect.
- One emergency alert per incident/occurrence through retries; do not duplicate reassignment jobs.
- No new assignment after reported emergency start time unless Operations explicitly resolves/updates the availability interval.
- Verify Area Lead can view only assigned service areas and cannot perform unauthorized Admin actions.
- Active-walk emergency requires a recorded safe dog handover/return outcome before closure.
- If no backup exists, raise a high-priority Operations queue item and customer communication; never pretend coverage is confirmed.

**Implementation status:** requirements only; no application code, database, rules, functions, or Production settings changed.


## Mandatory dog custody and QR-verified walker-to-walker handover

**User-confirmed non-negotiable safety rule; design only, not implemented.**

- A walker must never abandon, leave unattended, or leave a dog at an arbitrary place. An emergency does not remove the duty to keep the dog safe and arrange a controlled handover/return.
- A dog may be handed from one walker to another only when the company/Operations authorizes the replacement and the receiving walker is verified as eligible for that booking.
- Require a one-time, booking-specific QR handover confirmation generated by the trusted company system. The outgoing walker scans the receiving walker's authorized QR or the receiving walker scans a short-lived company-issued handover QR; exact direction should be selected during UX design, but it must be one-time, time-limited, non-reusable and tied to the booking/occurrence and both walker IDs.
- Do not accept a screenshot/static reusable QR as sufficient proof. Validate the token server-side and atomically mark it used so concurrent/replayed scans cannot complete a second handover.
- Handover is complete only after the receiving walker confirms custody and the system records the outgoing walker, receiving walker, booking/occurrence, timestamp, and handover location when available under the active-walk location policy. Keep the full audit trail.
- Until confirmation succeeds, the original walker remains responsible for safe custody and must not leave the dog. If QR/network/app verification fails, contact Operations and follow a documented safe fallback with explicit company authorization and recorded evidence; never treat a failed scan as successful handover.
- Customer/authorized guardian confirmation may be required by company policy for certain cases, but it does not replace company authorization and receiving-walker confirmation.
- After successful handover, update the canonical occurrence assignment and live-walk ownership atomically or through an idempotent trusted backend action; prevent both walkers from being active custodians at once and prevent duplicate handover events.
- Test unauthorized recipient, wrong booking QR, expired/replayed QR, network retry, concurrent scans, no signal, emergency during active walk, and attempted departure before confirmed handover.

**Implementation status:** design requirement recorded only. No application code, QR generation/validation, Firestore data, Rules, Functions, or Production configuration was changed.


## Incident escalation, customer communication and closure

### 1. One operational record per affected walk occurrence
- Every scheduled Regular Walk must have a stable occurrence ID linked to the parent booking, scheduled slot, assigned walker, service area and customer.
- Availability, leave, weather, late arrival, failed contact, backup dispatch, cancellation and dog handover events must be recorded against that occurrence; do not rely only on chat messages or a parent booking status.
- Every change records actor, timestamp, prior state, new state, reason and any related approval/incident ID. Server timestamps are authoritative.

### 2. Incident ownership and escalation
- Each active occurrence has one clearly identified Operations owner/on-call queue. Area Lead may triage, contact walkers, propose a backup and submit evidence within assigned scope; company Operations retains final authority for assignment changes, safety overrides, customer-impacting reschedules/cancellations and custody handover authorization.
- Configure response targets by incident severity and operating hours. Do not hard-code one universal response time for every incident.
- If the assigned walker is unreachable, late, reports an emergency, or a customer reports a missed walk, create an incident and escalate to the on-call lead/Operations according to the configured target. Escalation must not silently mark the walk complete.
- For immediate danger, dog-custody risk, severe weather or a possible unattended dog, raise the highest-priority alert immediately; safety action must not wait for a routine SLA timer.

### 3. Customer updates and recovery
- Notify the customer when assignment changes, a walker is delayed, weather/safety pauses a walk, a replacement is dispatched, a walk is rescheduled/cancelled, or a custody handover is initiated/completed, according to the approved communication policy.
- Messages must distinguish confirmed facts from estimates. Do not promise a replacement or completion time until Operations has confirmed the replacement and slot.
- If no safe, eligible backup is available, Operations contacts the customer and applies the approved return/reschedule/cancel/refund policy. Never pressure a walker to continue into a hazardous situation to meet a slot.
- Keep a delivery outcome per occurrence: completed with required evidence, safely returned/handed over, customer-approved reschedule, company cancellation, or unresolved incident. Unresolved incidents remain visible in Operations until explicitly closed.

### 4. Safe closure and audit
- An incident may be closed only by an authorized role after required checks are satisfied: dog custody resolved, customer informed where required, occurrence outcome recorded, and any required handover/return evidence attached.
- Prevent duplicate active assignments and concurrent custody transfers with server-side transaction/atomic validation and idempotency keys. Retrying a request must not create a second dispatch, duplicate handover or duplicate completion.
- Restrict incident notes, customer contact details, precise location and route evidence to roles with a legitimate operational need; retain them only under the approved retention policy.
- Test late/no-show escalation, emergency leave mid-walk, no backup available, customer notification failure, weather pause, offline QR handover fallback, duplicate retries and unauthorized closure.

### Implementation status
This section records the required workflow only. Incident documents, escalation timers, notifications, idempotency controls, security rules and tests have not been implemented or production-verified by this documentation change.


## Mandatory walk completion before leaving duty

- Normal rule: a walker must finish every assigned walk occurrence and safely return the dog to the approved customer/guardian handover point before ending that walk, leaving the assigned duty slot, or marking the occurrence complete.
- A walk is not complete merely because its planned time has passed, the route was started, the walker tapped Complete, or the walker is leaving the area. Completion requires the dog to be safely returned to the authorized customer/guardian and the required completion record to be saved.
- The app must keep the occurrence visibly **In Progress / Dog in Walker Custody** until the approved return or authorized walker-to-walker handover is confirmed. Do not allow normal shift-end/leave completion while a dog remains in the walker's custody.
- If the walker cannot safely finish because of a sudden medical/personal emergency, danger, severe weather or another exceptional event, do not force the walker to continue unsafely and do not leave the dog unattended. Immediately contact Operations. The dog must be safely returned to the customer/guardian or handed to an eligible receiving walker only after Operations authorizes the transfer and the required confirmation succeeds.
- If the app/network/QR fails, the walker must stay with the dog in a safe place and contact Operations for an explicitly authorized fallback. No silent self-transfer, unattended drop-off, or assumed handover is permitted.
- Operations must keep the incident open and arrange a safe return/backup if the first plan fails. A walk may be recorded as **Interrupted / Safely Returned** or **Transferred to Authorized Backup** rather than falsely marked **Completed**. Apply customer notification and the approved reschedule/cancellation policy.
- Server-side validation must prevent completion or shift-end actions while custody is unresolved; the same walk must not be completed twice, assigned to two active walkers, or have two simultaneous custodians. Record who confirmed return/transfer, when, and supporting evidence required by policy.

### Acceptance checks
1. Normal completion is blocked until customer/guardian return confirmation is recorded.
2. A walker cannot end duty with a dog still in their custody.
3. An emergency creates an immediate Operations alert and preserves the custody state until safe return/authorized transfer.
4. An authorized handover changes custody atomically only after recipient confirmation; failed QR/network attempts do not silently transfer custody.
5. The system never labels an interrupted walk as successfully completed without the required completion and return evidence.

### Implementation status
This is a mandatory product and safety requirement added to the audit design. It does not mean the mobile apps, Firestore rules, backend validation or tests already enforce it; those require a separate implementation and verification step.


## Same-day reassignment of remaining walks

- If a walker cannot continue duty for any reason, Operations must review **all of that walker's assignments for the remainder of the current day**, not just the walk currently in progress.
- Walk occurrences already completed remain completed and are not reassigned. Every not-yet-started occurrence still assigned to the unavailable walker must be placed into a reassignment queue and assigned by Operations to an eligible, available backup walker who is authorized for that service area and time slot.
- Prioritize each occurrence by its scheduled time, customer impact, dog-care needs and safe travel time. Check that the backup's existing assignments do not overlap and that the new route/time is feasible. Area Lead may recommend the backup; Operations confirms the reassignment.
- For a walk already in progress, first resolve the current dog's custody: the original walker must safely return the dog to the authorized customer/guardian or complete an Operations-authorized, recipient-confirmed handover. Do not treat reassignment of later walks as permission to abandon the dog or transfer custody without confirmation.
- Update each affected occurrence's assigned walker and assignment history atomically on the server. Keep the original walker, replacement walker, reason, authorizing Operations user, timestamps and customer-notification result in the audit trail. Prevent two walkers from being actively assigned to the same occurrence.
- Notify affected customers of the replacement walker and any revised ETA/time, using confirmed information. If no qualified backup is available for one or more occurrences, Operations must contact the customer and apply the approved reschedule/cancellation policy; never leave the occurrence silently unassigned.
- Emergency absence should trigger this review immediately. Planned leave should trigger a pre-leave coverage check so assignments can be redistributed before the leave begins.

### Acceptance checks
1. If one walker has six walks assigned today and becomes unavailable after completing two, the four remaining occurrences are all reviewed for reassignment; none is silently left with the unavailable walker.
2. Completed occurrences remain unchanged; not-yet-started occurrences can be reassigned only to eligible available walkers.
3. The active walk remains under the current walker's custody responsibility until safe return or an authorized and confirmed handover.
4. Overlapping schedules, ineligible area coverage and duplicate active assignments are rejected server-side.
5. Customer updates and any unfilled occurrence remain visible to Operations until resolved.

### Implementation status
This is a documented requirement only. Automated same-day reassignment, backup eligibility checks, atomic assignment updates, customer notifications and tests are not yet verified as implemented.


## Leave approval requires same-day walk coverage or explicit Admin exception

- A walker may submit planned leave, but the leave request must remain **Pending Admin Approval** until an authorized Admin explicitly approves it. Submitting a request, informing an Area Lead, or marking oneself unavailable does not by itself approve leave.
- Before approval, Operations/Admin must review every walk occurrence assigned to that walker for the requested date/time range, including all remaining same-day walks, and arrange eligible backup coverage or an approved customer reschedule/cancellation for each affected occurrence.
- If no eligible, available backup walker can accept one or more occurrences, the request must be escalated to Admin. **Do not approve leave while any affected occurrence remains silently unassigned or has no recorded safe customer outcome**, unless an authorized Admin records an explicit exception with a reason and customer-care plan.
- Admin approval must record the approving Admin UID, decision timestamp, requested leave range, coverage plan, affected occurrence IDs, replacement walker IDs or explicit exception, and reason. Notify the walker only after the decision is saved successfully.
- The system must block the walker from being marked as on approved leave and prevent new assignments in the approved leave window until approval is recorded. A pending/rejected request must not silently change assignment eligibility.
- Emergency exception: if a genuine immediate medical, personal-safety or other urgent event prevents the walker from continuing, do not trap or endanger the person or dog by enforcing routine approval first. The walker must alert Operations immediately; Operations/Admin activates the emergency coverage workflow, resolves dog custody safely, and records the emergency decision. This is an emergency response, not automatic approval of planned leave.
- Planned leave should be requested early enough for coverage planning. Admin may approve, reject, or ask for changes based on staffing, service-area coverage, schedule overlap and customer impact. Approval must not be delegated to the walker themselves.

### Acceptance checks
1. A planned leave request stays pending until an authorized Admin approval is saved.
2. If no backup is available for a scheduled walk, the request is routed to Admin and cannot be silently auto-approved.
3. Admin can see all affected occurrences and their coverage/outcome before deciding.
4. Pending or rejected leave does not remove the walker's assignments or mark the walker on leave.
5. An urgent emergency can trigger immediate safety handling without waiting for ordinary planned-leave approval, with an auditable Operations/Admin record.

### Implementation status
This policy is documented here only. The leave-request UI, Admin approval workflow, coverage gate, server-side enforcement and tests have not yet been implemented or verified.
