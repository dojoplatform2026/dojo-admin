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
