# DOJO WALK — Daily Availability Data Contract & Security Plan (Step 32)

**Date:** 2026-10-16  
**Branch:** `audit/zone-service-area-mapping-2026-10-16`  
**Related audit:** Step 31, `walker_daily_confirmation_attendance_performance_audit_step_31_2026-10-16.md`

**Scope:** Proposed data contract and security/validation plan for the walker’s next-day availability confirmation. This is documentation only. No app code, Firestore Rules, Functions, live data, or deployment was changed. No tests were run.

## 1. Confirmed product behavior

- DOJO WALK service window is 04:00–24:00 India time.
- A walker does not choose new time slots every day as part of this confirmation flow.
- Today, the walker submits whether they expect to be available tomorrow.
- UI choices: `Available` (“Yes, I will be available”) and `Unavailable` (“No, I will not be available”).
- Choosing unavailable requires a reason; “Other” permits a short explanation.
- If no response is submitted, the date remains `not_confirmed`.
- A confirmation is not proof of attendance. An absence after confirmation is only a potential incident until reviewed.
- An availability response must not remove responsibility for any booking the walker has already accepted.
- A severe performance impact requires an auditable review, evidence, the walker's explanation opportunity, and an authorized decision.

## 2. Proposed document location

Candidate path:

`walkers/{walkerUid}/availability/{serviceDate}`

Where `serviceDate` is the date being confirmed, formatted as `YYYY-MM-DD` in `Asia/Kolkata`; it is not the date the button was pressed.

Use a stable document ID for one walker and one service date to prevent duplicate daily confirmations. If edits are permitted before the operational cutoff, record each change in an append-only audit log rather than silently replacing the history.

## 3. Proposed confirmation fields

| Field | Type | Rule |
|---|---|---|
| `walkerId` | string | Must match the parent walker UID. |
| `serviceDate` | string | Required `YYYY-MM-DD`, interpreted in `Asia/Kolkata`. |
| `response` | enum | `available` or `unavailable`; missing document/response is interpreted as `not_confirmed`. |
| `reasonCode` | enum/string | Required for `unavailable`; use approved reason codes. |
| `reasonText` | string | Optional except when reason code is `other`; apply length limits. |
| `confirmedAt` | timestamp | Server timestamp; never trust a client-supplied timestamp for audit. |
| `updatedAt` | timestamp | Server timestamp for each accepted change. |
| `schemaVersion` | integer | Allows future migrations. |

Candidate reason codes: `personal_work`, `illness`, `family_responsibility`, `travel`, `planned_leave`, `emergency`, `other`. These are proposals, not final policy. Avoid requesting sensitive medical details; the reason should be brief and operational.

## 4. State interpretation

- `available`: walker has explicitly confirmed availability for that service date.
- `unavailable`: walker has explicitly reported they will not be available; reason required.
- `not_confirmed`: no valid confirmation exists by the configured cutoff. Prefer deriving this from the missing/invalid record or an operations query instead of letting the client set it.
- `potential_no_show`: separate operations incident, never a value the walker can write into the availability document.
- `reviewed`: incident has been reviewed by an authorized person; keep this in the incident record, not as a replacement for the original response.

Do not mark someone as a no-show merely because they did not confirm. Do not mark someone as absent solely because they did not open the app. Define the actual attendance signal separately.

## 5. Proposed no-show/performance incident record

Candidate collection:

`walker_attendance_incidents/{incidentId}`

Proposed fields:
- `walkerId`, `serviceDate`, optional `bookingId` and `occurrenceId`
- `incidentType`: `confirmed_unavailability`, `missed_accepted_booking`, or another approved type
- `evidenceSummary` and references to trusted event IDs (avoid copying unnecessary customer personal data)
- `reportedAt`, `reviewStatus`: `pending`, `walker_response_requested`, `under_review`, `substantiated`, `not_substantiated`, `appealed`, `closed`
- `walkerResponse` / response timestamp, with controlled access
- `reviewedBy`, `reviewedAt`, `decisionReason`
- if policy authorizes an adjustment: `performanceAdjustment`, `policyVersion`, `decidedBy`, `decidedAt`
- append-only audit events for every status/decision change

This is a proposal only. Never let a Partner client create or edit a substantiated finding or write its own score deduction. Trusted backend/admin authorization must enforce this.

## 6. Security boundaries

1. A walker can read their own availability records and submit their own response only.
2. A walker cannot submit for another UID, another service date, or alter another walker's record.
3. Validate enum values, required reason, text length, allowed service date, and permitted change window server-side.
4. Use server timestamps for authoritative event time.
5. Restrict reasons and incident evidence to authorized operations/admin roles; do not expose one walker's reason to other walkers or customers.
6. A daily response cannot update booking assignment, occurrence status, walk completion, customer address visibility, or performance score.
7. A walker’s `available` response makes them eligible for matching only; it is not a promise that a booking will be assigned.
8. Existing accepted bookings must remain visible and actionable even if the walker later reports unavailable; operations must handle reassignment/escalation explicitly.
9. Prevent client-side score tampering; score adjustments should be generated by trusted backend or audited authorized admin action.
10. Confirm which Firebase project and Rules/Functions are deployed before enabling this feature.

## 7. UI proposal

Partner Home card:
- Heading: “Confirm tomorrow’s availability”
- Date shown in India local date.
- Buttons: “Yes, I’ll be available” and “No, I won’t be available”.
- On “No”, show reason choices and an “Other” text box.
- Review screen summarizing date and response, then explicit submit.
- After submission, show `Confirmed available` or `Unavailable reported`, with the date.
- If no submission by the configured cutoff, show `Not confirmed` and a reminder.
- If edits are allowed, clearly display the cutoff and warn that changing availability does not cancel already accepted bookings.

Admin operations view:
- Filter by service date and service area.
- Counts for Available, Unavailable, Not confirmed.
- Reason visible only to authorized roles.
- Separate attendance incident queue with evidence, walker response, review status, and decision audit.
- Do not conflate availability confirmation with actual attendance.

## 8. Decisions still required before coding

1. Confirmation cutoff: what time today should tomorrow’s availability close? Do not invent a deadline in code.
2. Can a walker change an answer before the cutoff? After the cutoff, what exception process applies?
3. Should “No” require a reason every time, and which reason choices are approved?
4. How is actual attendance objectively determined: accepted booking start, check-in, location event, or operations confirmation?
5. Which backend/Rules are authoritative for the production Firebase project?
6. Which roles may review incidents and authorize performance adjustments?
7. What is the performance score formula and maximum adjustment? Keep unconfigured until policy is approved.

## 9. Verification status

- Data contract drafted: Yes, proposal only.
- Code changed: No.
- Firestore Rules/Functions changed: No.
- Deployed Firebase configuration verified: No.
- Tests run: No.
- Ready to deploy: No; cutoff, attendance evidence, review roles, scoring policy, and deployed backend remain unresolved.
