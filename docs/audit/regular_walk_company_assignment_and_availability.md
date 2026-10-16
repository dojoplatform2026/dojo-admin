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


## Emergency leave: auto-reassign first, Admin decision if no backup

- For an emergency leave/unavailability event, the system should immediately attempt **automatic reassignment** of the affected walk occurrences to eligible, available backup walkers.
- Auto-reassignment is allowed only after server-side checks confirm the backup is active/approved, covers the required area and time slot, has no schedule conflict, and can reasonably reach the walk. Assignment changes must be atomic/idempotent and recorded in the audit trail.
- If a suitable backup is found, automatically reassign the not-yet-started affected occurrences, record the reason as emergency coverage, and notify Operations and affected customers with confirmed information. The event remains visible to Operations for oversight.
- If no suitable backup is available, auto-assignment fails, or a required validation cannot be completed, **escalate immediately to Admin/Operations approval**. Do not leave affected walks silently unassigned, and do not treat the emergency request as routine approved leave without an Admin decision.
- Admin/Operations then decides the safe plan for each uncovered occurrence: manual backup assignment, customer-approved reschedule, or the approved cancellation/refund process. Record the decision, responsible Admin, timestamp and customer communication outcome.
- This automated reassignment of future walks must never transfer custody of a dog already on an active walk. For an active walk, the current walker remains responsible for the dog until safe return to the authorized customer/guardian or an Operations-authorized and recipient-confirmed handover. If neither can be safely arranged immediately, raise a critical incident and keep the dog attended in a safe location while Operations coordinates help.
- Emergency handling must not force a person in immediate medical danger to continue working. Escalation and human safety are immediate; dog custody and customer care must be coordinated in parallel.

### Acceptance checks
1. Emergency event + eligible backup available: remaining not-yet-started walks are automatically reassigned and audited.
2. Emergency event + no eligible backup: Admin/Operations receives an immediate actionable alert; the uncovered occurrences remain visible until resolved.
3. Auto-assignment errors or ambiguous availability do not silently mark the walker on leave or leave bookings unowned.
4. Active dog custody is not changed by future-walk auto-reassignment.
5. Customer notifications reflect confirmed changes only.

### Implementation status
This is the intended policy documented for implementation. Automated emergency reassignment, availability checks, alerts, Admin approval UI and server-side enforcement are not yet verified as implemented.


## Separate leave policies: during-duty emergency, full-day leave, and multi-day planned leave

Leave requests must be classified by **when they happen and how long the walker is unavailable**. Do not apply one identical approval flow to every leave type.

### A. Emergency leave during an active duty slot / active walk
- This is an immediate safety/medical/personal emergency while the walker is already on duty; it is not a routine planned-leave request.
- Prioritize immediate human safety and alert Operations at once. Do not require the walker to wait for routine Admin approval before seeking urgent help.
- If the walker has not yet picked up a dog and only future walks are affected, immediately try eligible automatic reassignment for the remaining not-yet-started occurrences.
- If the walker currently has a dog, separately start the urgent safe-return/authorized-handover procedure. The dog must not be abandoned or left unattended; future-walk auto-reassignment does not change active custody.
- If eligible backup assignment succeeds for future walks, record it and notify Operations/customers. If no backup is found, validation fails, or active custody needs human coordination, escalate immediately to Admin/Operations for a safe decision.
- Record emergency type, report time, affected occurrence IDs, assignment/handover actions, decision-maker and final outcomes. Emergency reports must not be silently treated as ordinary leave approval.

### B. Full-day leave (one complete day)
- A walker may request a planned full-day leave before the day starts.
- Admin/Operations checks every assigned occurrence for that date, including morning, afternoon and evening slots.
- Approve when all affected walks have eligible confirmed coverage or an explicitly approved customer outcome (such as rescheduling/cancellation under policy). If any occurrence remains uncovered, keep the request pending and route it to Admin/Operations; do not silently approve.
- Once approved, mark the walker unavailable for the approved date and prevent new assignments for that period. Preserve completed records and audit the approval.

### C. Multi-day planned leave
- A walker submits start date, end date, reason/category and any required supporting information under company policy.
- Admin/Operations checks all affected occurrences across the entire date range, including all same-day slots on the first and last days.
- Each occurrence must have eligible confirmed backup coverage or a recorded, policy-approved customer outcome. If any occurrence is uncovered, the leave remains pending unless an authorized Admin explicitly approves a documented exception and its safe customer/dog-care plan.
- After approval, mark the walker unavailable for the approved date range and prevent new assignments during that range. Store the approver, decision timestamp, range, affected occurrence IDs, replacements/exceptions and communication outcomes.
- A pending or rejected request must not remove assignments or mark the walker on leave.

### D. Shared safeguards
- Weekly-off preference/approval remains a separate recurring scheduling process; it is not a substitute for emergency, full-day or multi-day leave handling.
- Auto-assignment must check walker eligibility, active status, area, time-slot availability, overlap and reasonable travel feasibility, with server-side atomic/idempotent assignment and an audit trail.
- If auto-assignment cannot safely resolve coverage, Admin/Operations must decide. Never leave an occurrence silently unassigned.
- Admin exceptions must identify the uncovered occurrence(s), reason, approver, timestamp and approved customer/dog-care outcome.
- Customer notifications must state only confirmed changes. A leave/availability flag alone is not proof that coverage or dog custody has been resolved.

### Acceptance checks
1. Emergency reported mid-shift before dog pickup: auto-assign remaining walks where eligible; otherwise immediately escalate.
2. Emergency reported during an active walk: future walks may be reassigned, but active dog custody is resolved separately and safely.
3. Full-day leave request checks every assigned walk on that date before approval.
4. Multi-day leave checks all occurrences across the entire requested range, including same-day walks at both ends.
5. Any uncovered occurrence blocks routine approval until coverage/customer outcome is resolved or an explicit authorized Admin exception is recorded.
6. Pending/rejected leave never silently removes assignments or changes the walker to unavailable.

### Implementation status
These distinct policies are now documented as requirements. The app/backend flows, leave UI, notifications, server-side assignment safeguards and automated tests still require implementation and verification.


## Walker attendance activity, unique identity, and performance tiers

### 1. Weekly off versus extra leave
- The standard company benefit is one approved weekly off per walker per week, scheduled with staffing and customer coverage in mind.
- Any additional day/shift away from work beyond that approved weekly off must appear in the walker's attendance/activity history with dates, category, request/approval status, reason where permitted, and affected walk occurrences.
- Distinguish planned full-day leave, multi-day leave, emergency leave during duty, unapproved absence, late arrival, missed walk, and approved weekly off. Do not label an emergency as misconduct automatically; show the recorded event and its reviewed outcome.
- Pending or rejected leave does not count as approved leave and must not silently change assignments. Admin can review repeat or unusual absence patterns using consistent company policy.
- Only authorized Admin/Operations users may view sensitive leave reasons; ordinary public/customer-facing profiles must not expose private leave details.

### 2. Stable walker identity
- Every walker must have one unique, permanent company walkerId in addition to their Firebase/auth UID. The auth UID remains the internal authentication key; walkerId is the readable operational ID displayed in the Admin panel and walker profile.
- Generate walkerId centrally and uniquely (never from a name or phone number, and never reuse an ID after a walker leaves). Example display format: DW-WKR-000123; the exact sequence/prefix is configurable, but uniqueness and permanence are mandatory.
- Keep identity separate from rank: a walker's ID never changes when their performance tier changes.

### 3. Performance score and visible tiers
- Each walker has a performance profile computed from verified operational records, not self-entered claims alone. Candidate signals: on-time arrival/start, walk completion, attendance reliability, customer feedback, safety/custody compliance, incident outcomes and adherence to company procedures.
- Do not rank walkers solely by number of completed walks or raw customer ratings; account for eligible work opportunities and sample size so new/low-volume walkers are not unfairly penalized. Show “Not enough data” until the minimum evidence threshold is met.
- Suggested display tiers: **Crown** (top tier), **Gold**, **Silver**, **Standard**, and **Under Review** where an unresolved serious issue requires review. These are proposed labels and should be driven by published, measurable thresholds rather than arbitrary manual preference.
- The Admin dashboard should show a sortable leaderboard with rank, walkerId, display name, tier badge, score, completed/assigned walks, on-time rate, attendance/absence summary, customer rating with sample count, and safety/incident status. Filters should include date range, city/area, active status and tier.
- The walker app may show the individual walker's own tier, score trend, key metric breakdown and improvement guidance. Do not expose other walkers' private leave/incident details to walkers or customers.
- Performance should be recalculated on a defined schedule and after verified material events; retain historical snapshots so ranks can be explained and audited. Apply transparent review/appeal handling for disputed incidents or ratings.
- A serious safety/custody breach must trigger a human review/eligibility safeguard; a high numeric score must never override safety restrictions or active suspension.

### 4. Fairness and anti-gaming controls
- Use only verified, policy-approved data. Exclude duplicate/cancelled/test walks and system-caused failures from the wrong person's performance metrics.
- Separate approved weekly off and approved leave from unapproved absence. Approved time off should not be scored as a missed walk; extra leave must be visible as an activity record, but should not automatically lower performance without a clear, consistently applied policy.
- Prevent self-editing of score, tier, ranking and verified attendance events. Log Admin adjustments with actor, timestamp, reason and before/after values.
- Publish score definitions and measurement window to walkers. Support correction of inaccurate records and audit all score/tier changes.

### Acceptance checks
1. A walker has one permanent unique walkerId, unaffected by tier or rank changes.
2. Weekly off, extra approved leave, pending/rejected requests, emergency absence and unapproved absence appear as distinct activity types.
3. Approved leave and weekly off are not miscounted as missed walks; verified unapproved absence is handled by a documented policy.
4. Leaderboard can sort by score/tier and filter by time window/area; each score has explainable metric components and sufficient-data status.
5. New walkers are not labelled low-performing solely due to limited sample size.
6. Customers and other walkers cannot see private leave reasons or confidential incident details.
7. Serious safety controls override leaderboard rank.

### Implementation status
This is a documented product specification. The current Admin/Partner apps, Firebase schema, scoring backend, permanent ID generator, activity screens and leaderboard have not yet been verified as implementing these requirements.


## Excessive absence: progressive notice and fair corrective action

- The company should use a documented, consistent attendance policy. Approved weekly off, approved leave, and genuine emergencies must be distinguished from unapproved absence, repeated last-minute leave, no-show, late arrival and accepted walks missed without valid notice.
- Use progressive, evidence-based steps rather than an automatic penalty for every leave event:
  1. **First occurrence / pattern detected:** private in-app notice explaining the attendance record and policy, reminding the walker to request leave early where possible and to notify Operations immediately in emergencies.
  2. **Repeated verified incidents:** formal warning with dates and affected occurrences, explanation of the impact on customers/team, and a way for the walker to respond or correct inaccurate records.
  3. **Continued pattern after warning:** Admin review and a documented corrective plan, such as temporary restriction from accepting new regular-walk assignments or additional training, where lawful and proportionate.
  4. **Serious misconduct or repeated unresolved incidents:** authorized Admin review may suspend assignments or deactivate the account according to published policy, with reasons, evidence, review/appeal path and decision audit.
- Do not automatically deduct money, withhold already-earned pay, demote a walker, or suspend them solely because they took approved leave or reported a genuine emergency. Financial consequences must be separately reviewed for legal compliance and must not be used as an undisclosed punishment.
- For each notice/action record the policy code, verified incident IDs, actor, timestamp, message delivered/read status where available, walker's response, decision, review date and appeal outcome.
- Emergency or safety incidents require immediate operational handling, not a routine warning-first sequence. No discipline should force a walker to continue in an unsafe medical situation or abandon a dog.
- Keep private health/leave reasons restricted to authorized Admin/Operations; notices to the walker should disclose only the information needed to explain the action.

### Suggested notification copy
“Your attendance record shows repeated short-notice absence or missed assigned walks. This affects customer commitments and backup planning. Please request planned leave in advance and report emergencies immediately. Approved weekly off and approved leave are not counted as misconduct. If any record is incorrect, submit a response for review. Further verified incidents may lead to an Admin review and restrictions under the company attendance policy.”

### Acceptance checks
1. Approved leave/weekly off and genuine emergency are not automatically categorized as misconduct.
2. Repeated verified unapproved absence can trigger escalating private notices and an Admin-reviewed action.
3. Walker can see relevant dates/records and submit a correction or appeal.
4. No automatic wage deduction or withholding of earned money is triggered by attendance status alone.
5. All actions are auditable and restricted to authorized roles.


## Walker payment and settlement model

### Recommended initial model: pay per verified completed walk, with transparent settlement
- Treat walker earnings as **per-walk earnings / service payout**, not a fixed salary by default, unless the company deliberately hires a walker as an employee under a separate employment and payroll arrangement. Legal classification and wage obligations must be reviewed for the actual working relationship and applicable Indian law.
- Each completed eligible walk creates a server-controlled earning ledger entry linked to a stable walk-occurrence ID, booking ID, walker ID, service type, duration/rate snapshot, gross walker earning, approved bonus/adjustment, net payable amount, status and timestamps.
- Only the trusted backend/Admin-approved workflow may calculate or alter payouts; the walker app must not be able to edit payout amount, commission, settlement status or paid timestamp.
- A walk should become payable only after the completion and safe-return/custody outcome is verified under the booking's workflow. A transfer or interrupted walk must follow explicit split/credit rules; never pay two walkers for the same full occurrence by accident.
- Show a clear earnings screen: Today / This Week / This Month, completed payable walks, pending verification, approved adjustments, payable balance, last settlement and transaction history.
- Suggested statuses: pending_verification, approved, payable, settlement_processing, paid, held_for_review, adjusted and reversed. A reversal requires an auditable reason; never erase the original ledger entry.
- Run a regular settlement cycle (for example weekly) after reconciliation; keep a configurable minimum payout threshold only if operationally necessary and disclosed in advance. Publish the payment day, bank/UPI method, failure/retry path and settlement reference. Avoid promising a payout schedule until finance and legal operations confirm it.
- Keep separate ledger entries for customer gross revenue, walker earnings, company revenue/commission, bonuses/incentives, refunds and approved corrections. Do not mix company revenue with the amount owed to the walker.
- Existing prior examples such as a ₹75 walker payout per walk and customer prices such as ₹149/30 minutes are drafts, not approved production rates. Keep rates configurable and versioned; snapshot the applicable rate on each booking/occurrence so later price changes do not rewrite past earnings.
- Any deductions, penalties, refunds or disputed-incident holds must follow published terms, legal review and Admin approval. Never make a silent or arbitrary deduction; preserve the original entry and show the reason and dispute process.
- If the business chooses a salary/shift-pay model instead, define guaranteed wage, duty hours, overtime, weekly rest, statutory benefits and payroll compliance separately; do not mix salary and per-walk payout without a clear written policy.

### Suggested initial configurable rate structure
1. walkerBasePayout per eligible walk, configurable by service type and duration.
2. Explicit approved extras: distance/travel allowance, peak/late slot allowance or difficult-service supplement if company policy uses them.
3. Quality/attendance incentive only from verified metrics and transparent rules; never penalize approved leave by secretly lowering the per-walk rate.
4. Admin-approved correction entries with reason and audit history.
5. Weekly settlement report: opening balance + approved walk earnings + incentives + authorized adjustments − previous payments = closing payable balance.

### Acceptance checks
1. One eligible occurrence creates at most one base earning entry; retries do not duplicate it.
2. The rate used is the booking's versioned snapshot and the walker can see its breakdown.
3. Unverified, cancelled, duplicate or test walks do not create normal completed-walk earnings.
4. Settlement cannot be marked paid without a confirmed payment reference/result; failures remain visible for retry.
5. Admin edits require authorization, reason and immutable audit history.
6. Approved earned amounts cannot be silently withheld or reduced due to unrelated leave/disciplinary status.
7. Transfer, partial service, refund and dispute cases have explicit payout rules before launch.

### Implementation status
These are policy/product requirements only. The live payout calculation, earning ledger, bank/UPI settlement, attendance notifications and disciplinary workflow have not been verified as implemented. Rates and settlement cadence remain configurable pending business, legal and finance approval.


## Time-based walker pay: guaranteed base plus verified duration

### Recommended model
- Use a **guaranteed base amount per assigned duty/walk slot plus a transparent time-based component** for eligible actual service time. The exact structure (per walk, per duty slot, or per shift) must be chosen before launch and checked against applicable wage/employment rules.
- The base guarantees a clearly stated minimum for the defined eligible unit; the time component increases payment according to verified eligible minutes/hours. Do not describe a base as a guaranteed salary unless the contractual employment/payroll model actually provides one.
- Example for discussion only: a 30-minute walk has a configured base of ₹X covering the first 30 eligible minutes. If an approved service takes longer, additional eligible minutes are paid at ₹Y per minute (or a disclosed hourly rate). A 45-minute eligible walk would then earn ₹X + 15 × ₹Y, subject to the published rounding and authorization rules. ₹X and ₹Y are not yet approved rates.
- Set separate versioned rates by service type and planned duration if needed (e.g. 20/30/45/60 minutes), and snapshot the applicable rate when the occurrence is assigned/confirmed. Later rate changes must not rewrite earlier earnings.
- Count only verified service time according to policy: actual start after authorized pickup/start, approved pause rules, and completion/safe-return or authorized handover. Travel time, waiting, weather delays, customer delay and emergency interruptions need explicit treatment in the published rate card; do not silently count or exclude them.
- If actual duration exceeds the booking due to customer/company-approved extension or a safety-related delay, record the reason and approval/evidence before calculating the extra component. Never encourage a walker to extend a walk merely to increase pay.
- Define a minimum base for a cancelled, interrupted, transferred or partially completed walk before launch. Credit only the correct walker(s) for verified eligible work; never duplicate full payment to two walkers for one occurrence.
- Store an immutable earning ledger entry per occurrence with base amount, eligible minutes, time rate, extras/allowances, approved adjustments, gross/net payable, rate version, evidence source, status and timestamps. Retries must be idempotent; only trusted backend/Admin workflows can change rates or settlement status.
- Show the walker a breakdown for each walk: base, eligible duration, time-based amount, approved extras/adjustments and final amount. Admin should see the same breakdown and an audit trail.
- Pay on a disclosed settlement cycle (weekly is a possible starting proposal, subject to finance/legal approval), with payment reference, failed-payment retry and dispute process.
- Do not use unapproved leave, rank, or disciplinary status to silently reduce earned pay. Bonuses/incentives should be separate ledger entries with clear published eligibility. Any deductions/holds require disclosed policy, authorized review and legal compliance.
- Keep customer charges, walker earnings, company commission/revenue, refunds and payment processing costs in separate ledgers. A customer's total price is not automatically the amount owed to the walker.

### Decisions required before rates are activated
1. What unit receives the base: each completed walk, each assigned slot, or each paid duty shift?
2. Which planned duration is covered by the base (for example, the first 30 minutes)?
3. What is the additional eligible time rate, and how are partial minutes rounded?
4. Which travel/wait/pause periods count as payable time?
5. What are the rules for overtime, customer-approved extensions, interruption, cancellation, transfer and weather safety pauses?
6. What settlement day and payment method will Finance support?

### Acceptance checks
1. Base and time components are shown separately and reconcile to the total.
2. Only verified eligible time affects the time-based component; extension requires an auditable reason/approval when policy requires it.
3. Rates are versioned and historical earnings remain unchanged after future rate edits.
4. Partial/transfer/interrupted cases follow explicit rules and cannot create duplicate payouts.
5. A walk completion retry cannot create duplicate earning entries.
6. Walker and Admin can review the breakdown and raise a dispute.
7. Rates and settlement rules are not activated in production before business and legal approval.

### Implementation status
This is the proposed pay-policy specification only. No live rate, payout ledger, time-tracking payroll calculation, or settlement integration has been implemented or verified by this documentation update. Existing ₹75 per walk and ₹149 customer price examples remain drafts and must not be treated as approved rates.


## Unified booking-card and company operations flow — 2026-10-16

### Customer booking cards
- **Walk Now**: one immediate/near-term walk. Create one booking and one walk occurrence; search for an eligible available walker and escalate visibly if no eligible walker is found.
- **Temporary Walk**: a finite set of dates/times. Validate availability across the entire requested period before confirmation; create a separate occurrence for each scheduled walk.
- **Regular Walk**: a repeating schedule. Validate the requested recurring slots and coverage; create/maintain a separate occurrence for every due walk, with explicit rules for schedule edits, pauses and cancellation.
- Keep the customer-facing booking cards separate and simple, but use one shared company assignment, attendance, verified-duration and earnings pipeline behind all three types.

### Canonical records and IDs
- A customer booking has one stable `bookingId`; each scheduled execution has a unique stable `walkOccurrenceId` and its own lifecycle, assigned walker, timestamps, safety/custody outcome and earnings state.
- Suggested illustrative IDs only: `DW-BOOK-...` and `DW-WALK-...`. The final ID format must be checked against current repository conventions before implementation; do not rename or rewrite existing IDs blindly.
- Retries must be idempotent. One occurrence must not have two active assignments, duplicate completion, duplicate earnings, or simultaneous custodians.

### Shared occurrence lifecycle (draft)
`scheduled → assignment_pending → assigned → accepted → in_progress → completed_pending_verification → verified → payable → paid`.
- Add explicit exception paths for `cancelled`, `assignment_failed/escalated`, `interrupted`, `transfer_pending`, `held_for_review` and `reassigned`; define allowed transitions and authorization before implementation.
- The exact status names must be reconciled with existing customer, partner, admin and backend code before any schema change.

### Assignment and coverage rules
- Walk Now prioritizes a prompt eligible assignment; Temporary validates all requested occurrences; Regular validates recurring slots and keeps future occurrences visible to Operations.
- Eligibility must consider active/approved walker status, activated service-area coverage, slot availability, schedule conflicts and feasible travel time. Client-side checks alone are not authoritative.
- A leave/absence event triggers review of affected not-yet-started occurrences. Completed occurrences remain unchanged. If no eligible backup is available, escalate to Operations/Admin; never silently leave a walk unassigned.
- During an active walk, assignment changes do not transfer dog custody. Resolve safe return or an authorized, recipient-confirmed handover as a separate controlled workflow.

### Shared attendance and earnings pipeline
- Record start/completion evidence and eligible duration per occurrence. Publish rules for travel, waiting, pauses, extensions, weather, cancellation, interruption and handover before enabling time-based pay.
- Proposed earnings model: a configurable base for a defined eligible walk/slot plus a transparent amount for verified eligible extra time. The base unit, rate values, duration coverage, rounding and settlement cadence remain undecided pending business/finance/legal approval.
- Earnings are derived from the occurrence and a versioned rate snapshot, recorded in an idempotent server-authoritative ledger. Customer charges, walker earnings, company revenue, refunds and adjustments remain separate.

### Admin cards (proposed UI, not claimed implemented)
- Live Operations; Walk Now; Temporary Bookings; Regular Walks; Walker Attendance; Leave & Weekly Off; Backup & Reassignment; Walker Performance; Walker Earnings; Payments & Settlements.
- Every exception card should expose owner, severity, affected occurrence(s), next action, timestamps and audit history.

### Audit/implementation sequence
1. Read-only audit of existing booking creation, schedule generation, assignment, start/complete actions and Firestore document shapes across Admin, Customer and Partner.
2. Build a field-by-field compatibility matrix before choosing canonical field names or migrating legacy data.
3. Define the occurrence status/transition matrix, permissions, idempotency and custody/transfer rules.
4. Define the base-plus-time pay unit and all edge-case rules; keep rates disabled until approved.
5. Implement only on a feature branch, add automated tests, run analysis/tests, and report exact evidence.
6. No production data migration, deployed rules, merge to main or deployment without explicit approval.

### Status
**Design recorded; implementation not yet verified.** No claim is made that the three booking cards, unified occurrence lifecycle, reassignment workflow, earnings ledger or payout calculation are currently implemented. Existing Firestore schema and IDs must be audited before code changes.


## Step 1 — Read-only cross-app code audit findings (2026-10-16)

### Files inspected
- Customer: `lib/features/booking/screens/booking_confirmation_screen.dart` and `lib/features/booking/screens/my_bookings_screen.dart` on `main`.
- Partner: `lib/screens/home/partner_home_screen.dart` and `lib/features/live_walk/screens/live_walk_screen.dart` on `main`.
- Admin: `lib/screens/bookings/bookings_screen.dart` and `lib/features/walkers/services/walker_admin_service.dart` on `main`.
- This was a source-code read-only inspection; no runtime tests, Firestore data inspection, Security Rules audit, or production behavior verification was performed.

### Confirmed code observations
1. Customer confirmation creates one document in `bookings` and writes fields including `bookingId`, `customerId`, `bookingPlan`, `serviceType`, `scheduledAt`, `duration`, `preferredTime`, `walkCount`, `walkSchedules`, `status: pending`, and `walkerId: null`.
2. Regular booking currently writes `frequency: daily`, `walksPerWeek: 7`, `walksPerDay`, `planStatus: pending_confirmation`, and `dailyWalkTemplate`.
3. Date-selection booking currently stores a parent booking with `selectedDates` and `dateSchedules`, and a `walks` list under each date. It does not create a separate booking occurrence document for each scheduled walk in the inspected confirmation code.
4. The confirmation code maps `_isChooseDates` to `bookingPlan: customize` and `serviceType: custom_walk`; the user-facing product decision is a finite-period Temporary Walk. This naming/semantic mapping needs review before changing data or UI, and existing records must remain compatible.
5. Partner home reads `bookings` filtered by `walkerId`, then filters today's bookings using `data['date']` and active status. Customer confirmation code shown above writes `scheduledAt` and does not set a top-level `date` in the booking payload. This is a likely cross-app scheduling compatibility risk that needs full helper/status inspection and tests before concluding runtime impact.
6. Partner live-walk completion writes a separate document to `walks`, with a `bookingId` when provided, then updates the parent `bookings/{bookingId}` status to `completed`. The walk record contains `walkerId`, duration seconds, distance, start/end timestamps, route and return flags; the inspected code does not attach a stable per-scheduled-occurrence ID.
7. In the inspected live-walk code, `walkType` on the completed walk record is hardcoded to `Regular Walk`, regardless of the booking's actual service type. Confirm whether other paths override this before implementation.
8. Admin bookings screen streams the `bookings` collection and displays booking-level status, walker and a walk time derived from `walkDateTime`, `scheduledAt` or `bookingDate`. The inspected screen does not expose per-occurrence rows for `walkSchedules`/`dateSchedules`.
9. `WalkerAdminService` reads `bookings` and walker records; its admin approve/reject/suspend/reactivate/correction actions use a Firestore transaction for walker status plus an `audit_logs` record. This is useful existing behavior, but it is not the booking assignment/reassignment engine.

### Risks to resolve before implementation
- One parent booking may represent several scheduled walks, while Partner completion updates the parent booking to `completed`. We must verify how multiple daily walks and repeated dates are currently handled to avoid completing a whole plan after only one walk.
- Top-level schedule field conventions may differ across Customer (`scheduledAt`) and Partner's today filter (`date`). Audit all date parsers, active-status helpers, and existing legacy records before choosing canonical fields.
- `walks` completion records and parent booking status are written in separate operations in the inspected code. A partial failure could leave the two records inconsistent; idempotent server-authoritative completion is a design requirement, not yet verified as implemented.
- `dogReturned: true` is written alongside `returnLocationVerified: _sameReturnLocation`; verify the product/safety meaning when the return location differs. A boolean return claim must not be treated as proof of safe custody handover.
- Booking status vocabulary and per-occurrence lifecycle need a compatibility matrix before any schema migration.

### Step 1 status
**Partial read-only audit complete for the named files only.** Cross-app schema compatibility is not yet signed off. Next audit: inspect the full schedule/status helper functions, booking list mapping, assignment actions, Firestore Security Rules and repository tests. No files in Customer or Partner were changed; no production data was read or changed; no tests were run in this step.
