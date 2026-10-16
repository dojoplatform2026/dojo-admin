# DOJO WALK Booking & Walk Status Transition Matrix — Step 7
**Date:** 2026-10-16  
**Branch:** `audit/zone-service-area-mapping-2026-10-16`  
**Status:** Source-level transition proposal; no application code, rules, or production data changed. Runtime behavior and deployed Rules are not verified.

## 1. Goal
Map the status values found in source and propose a controlled state machine before implementing shared validation or Firebase Emulator tests.

## 2. Statuses observed in source
The following values were found in the inspected Customer/Partner/Admin source. This is not yet an exhaustive list across all branches, old records, or production data.

| Entity | Status value | Evidence / interpretation |
|---|---|---|
| Booking | `pending` | Customer booking writer initializes a booking as pending (observed in earlier source audit; re-check full payload before implementation). |
| Booking | `accepted` | Partner Walk Details / pickup flow updates booking status to accepted. |
| Booking | `picked_up` | Partner Navigation flow records that the dog was picked up. |
| Booking | `walking` | Partner Navigation flow updates booking when the walk starts. |
| Booking | `completed` | Partner Live Walk completion updates parent booking. |
| Booking | `rejected` | Admin Walker service contains terminal-status handling, but that method is part of walker administration and must not be assumed to define booking status without further inspection. |
| Booking / other | Other values may exist | Cancellation, refund, assignment, regular-plan, and legacy values require repository-wide inventory. Do not normalize or delete unknown values yet. |
| Walk record | `completed` | Partner Home reads completed walk records; Live Walk writes a separate `walks` record. |

## 3. Current source-observed Partner flow
The inspected Partner screens imply this sequence:

`pending` → `accepted` → `picked_up` → `walking` → `completed`

- Walk Details writes `accepted` before opening pickup navigation; errors are caught and navigation still proceeds.
- Navigation can write `accepted` again when arrival is marked, then `picked_up`, then `walking`.
- Live Walk writes a separate `walks/{walkId}` document and later updates `bookings/{bookingId}` to `completed`.
- These are source observations, not proof that every transition is authorized or succeeds in production.
- The `accepted` state is written at more than one point. Product semantics need confirmation: acceptance/assignment and physical arrival should ideally not be conflated unless the existing product intentionally defines them that way.

## 4. Recommended transition matrix (proposal only)
Use server/rules-side validation; UI button visibility is not authorization.

| From | To | Actor proposed | Conditions |
|---|---|---|---|
| New / absent | `pending` | Customer booking submission (validated backend/rules) | Authenticated customer owns request; valid plan, schedule, address snapshot, and permitted fields. |
| `pending` | `accepted` | Assigned walker or authorized operations/admin workflow | Booking is assigned to that walker; no conflicting assignment; record transition audit. |
| `accepted` | `picked_up` | Assigned walker | Pickup prerequisites satisfied; only permitted lifecycle fields change. |
| `picked_up` | `walking` | Assigned walker | Required pickup confirmation satisfied; occurrence/booking identity checked. |
| `walking` | `completed` | Trusted completion handler, or strictly validated assigned-walker action if backend is not yet available | Walk has a stable ID; completion is idempotent; required summary/route fields validated; parent/occurrence consistency is recoverable. |
| `pending` | `cancelled` | Customer under policy or authorized operations | Cancellation window/policy confirmed; record reason and audit. |
| `accepted` | `cancelled` | Authorized operations; customer only if policy permits | Define impact on assigned walker and notifications; do not allow arbitrary client status changes. |
| Any terminal state | Any active state | Nobody by default | Reopen/retry only via explicit audited recovery action. |
| Any state | `rejected`, `expired`, `refunded`, or other value | Not yet defined | Confirm actual business meaning and all current writers before adding these transitions. |

**Important:** `cancelled`, `expired`, and `refunded` are proposed candidates to validate, not confirmed current booking values. Do not assume they already exist.

## 5. Data consistency rules to test
1. A walker cannot change `walkerId` or claim a booking assigned to another walker.
2. Customer cannot write assignment, walk completion, trusted payment/payout, or audit fields.
3. Status transition must be allowed from the current stored state; arbitrary jumps (for example `pending` → `completed`) are denied.
4. Status and `updatedAt` are updated together using trusted server timestamps where appropriate.
5. Completion retry for the same occurrence does not create another completed walk or duplicate payout.
6. A walk record must refer to a real parent booking and stable occurrence ID where multi-walk schedules are supported.
7. If walk record creation succeeds but parent update fails, retry/recovery repairs the parent without duplicating the walk record.
8. Terminal states cannot be silently reopened; recovery requires authorized action and an audit entry.
9. Regular/custom multi-date bookings need occurrence-level states so completing one walk does not accidentally complete the entire parent booking.
10. Rules and backend checks must agree; UI logic alone is insufficient.

## 6. Emulator test cases
- Customer creates valid pending booking; invalid/foreign customerId denied.
- Unassigned walker cannot accept; assigned walker can accept only a pending booking.
- Invalid transition jumps are denied.
- Assigned walker can progress only through permitted pickup/start transitions.
- Customer cannot mark completed or change assignment/payout.
- Completion repeated twice yields one stable occurrence and one effective completion.
- Simulate failure after walk-document write but before parent-booking update; retry repairs state without duplicates.
- Complete one occurrence in a multi-date booking; other occurrences remain open.
- Terminal/cancelled booking cannot be restarted by an ordinary client.
- Admin actions require active role and location scope; Super Admin compatibility remains covered.
- Test against both new and representative legacy document fixtures.
- Run only against an isolated Firebase Emulator project, never production.

## 7. Before implementation
- [ ] Search all three repositories for every `status` write/read and every `bookings`/`walks` access.
- [ ] Confirm cancellation, rejection, assignment, expiry, and regular-plan semantics with actual UI/service code.
- [ ] Inspect deployed Rules and current indexes using authorized Firebase access.
- [ ] Agree whether status belongs to parent booking, each occurrence, or both.
- [ ] Decide trusted backend vs client write architecture for lifecycle transitions.
- [ ] Add isolated Emulator configuration, fixtures, and automated tests.
- [ ] Record actual test output before claiming any tests passed.

## 8. Step 7 status
- [x] Captured Partner lifecycle values visible in inspected source.
- [x] Drafted a transition matrix with actors and guards.
- [x] Documented duplicate-write and partial-failure test cases.
- [ ] Exhaustive repository-wide status inventory.
- [ ] Business policy confirmation and legacy-data compatibility plan.
- [ ] Emulator tests implemented and executed.
- [ ] Any production change approved and separately reviewed.

No production code, Firestore rules, live documents, or deployment was changed.
