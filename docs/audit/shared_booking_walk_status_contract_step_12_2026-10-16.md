# DOJO WALK Shared Booking & Walk Status Contract — Step 12
Date: 2026-10-16
Branch: audit/zone-service-area-mapping-2026-10-16
Status: Proposed contract for review; not implemented. Deployed Rules and runtime behavior remain unverified.

## 1. Design rule
Separate the **booking/order lifecycle** from each **scheduled walk occurrence**. A recurring booking may contain many walks, so completing one walk must not automatically mark the entire parent booking completed.

## 2. Proposed canonical parent booking statuses
- `pending`: booking submitted; not yet assigned.
- `confirmed`: booking accepted by operations/company but not yet fully assigned (optional only if product needs this distinct stage).
- `assigned`: a walker is assigned; upcoming occurrence(s) remain.
- `in_progress`: at least one occurrence is currently active.
- `completed`: all required occurrences for the booking plan are completed or otherwise resolved according to the approved policy.
- `cancelled`: whole booking cancelled under the approved policy.
- `rejected`: booking declined before service.
- `expired`: booking timed out before assignment/acceptance, if expiry is implemented.

Legacy UI aliases such as `finding_walker`, `walker_assigned`, `walker_arriving`, `accepted`, `canceled`, and `in progress` should be mapped for display during migration only; do not continue writing aliases indefinitely.

## 3. Proposed canonical occurrence statuses
Each scheduled walk should have a stable `occurrenceId` and its own status:
- `pending` → `assigned` → `accepted` → `picked_up` → `walking` → `completed`
- Allowed alternate endings: `cancelled`, `missed`, or `failed`, subject to approved policy.
- An occurrence in a terminal state cannot be reopened by a client. An audited privileged recovery flow, if required, must be separate.

Definitions:
- `assigned`: a specific walker is selected for this occurrence.
- `accepted`: that assigned walker explicitly accepts the occurrence.
- `picked_up`: required pickup/identity checks are complete and the dog is in the walker's care.
- `walking`: active walk tracking has started.
- `completed`: trusted completion conditions pass and summary is recorded.

## 4. Transition authority proposal
| Transition/action | Actor allowed | Required checks |
|---|---|---|
| Create booking as `pending` | Customer client or approved backend | Auth UID matches customerId; payload schema, schedules, price snapshot and timestamps validated |
| Assign occurrence | Company/authorized scoped Admin or backend | Walker is active/approved, within service scope and available; assignment audit written |
| Accept occurrence | Assigned walker or backend | Auth UID matches assigned walker; current status is assigned |
| Mark picked_up | Assigned walker/backend | Current status accepted; pickup/required verification checks passed |
| Start walking | Assigned walker/backend | Current status picked_up; active walk session established |
| Complete occurrence | Backend preferred; or tightly validated assigned-walker action | Current status walking; summary, duration, distance and completion time validated; idempotent stable occurrence ID |
| Request cancellation | Customer | Owns booking; policy permits cancellation at current state; request stored separately from approved cancellation outcome |
| Approve/reject cancellation | Authorized operations/backend | Policy, reason, timestamps and audit event validated |
| Change parent aggregate status | Backend/transactional service preferred | Derived from all occurrence statuses; client cannot set aggregate directly |
| Privileged recovery | Super Admin/backend only | Explicit reason, append-only audit trail and no silent terminal-state reopening |

## 5. Data model recommendation
- Keep `bookings/{bookingId}` as the order/plan.
- Use `bookings/{bookingId}/occurrences/{occurrenceId}` or a top-level `walk_occurrences/{occurrenceId}` consistently; choose one canonical model before implementation.
- Every occurrence stores `bookingId`, `customerId`, `walkerId`, `scheduledAt`, `durationPlanned`, `status`, `createdAt`, `updatedAt`, and relevant assignment/start/completion timestamps.
- `walks/{walkId}` should be either a tracking/session record linked 1:1 to `occurrenceId`, or replaced by the canonical occurrence model; avoid competing status authorities.
- Completion must be idempotent by `occurrenceId`; duplicate requests must not create a second completion record or payout.
- Parent status should be calculated from all required occurrences and updated transactionally or by a trusted backend.

## 6. Compatibility and migration
- Do not bulk-rewrite existing production statuses before deployed schema and records are reviewed.
- First build a read-only inventory of actual status values, missing fields, regular bookings, custom/date-selected bookings, and separate `walks` records.
- Implement a display mapping for legacy values, then dual-read only as long as needed.
- Do not allow legacy aliases as new writes after migration is approved.
- Preserve historical records and document any manual mapping; never infer that a booking is complete from one occurrence's completion alone.

## 7. Must be decided before implementation
1. Should `confirmed` remain a distinct parent status, or should assignment move directly from `pending` to `assigned`?
2. Does walker acceptance apply to the whole booking or to each individual occurrence? Proposal: per occurrence.
3. What cancellation cutoff/fees apply before assignment, after assignment, after acceptance, and after pickup?
4. What is the policy for `missed` and `failed` occurrences, including rescheduling/refunds?
5. Which occurrence storage path is canonical: booking subcollection or top-level `walk_occurrences`?
6. Is walker-side completion allowed directly, or must a trusted backend validate it?
7. How should partial regular plans aggregate when some occurrences are completed and others cancelled/missed?

## 8. Checklist
- [x] Proposed parent and occurrence state machines.
- [x] Separated booking-level and occurrence-level status authority.
- [x] Defined actor/validation matrix and idempotent completion requirement.
- [x] Listed business decisions needed before implementation.
- [ ] Product owner approves decisions above.
- [ ] Confirm deployed Rules and actual data shape.
- [ ] Implement contract in a dedicated reviewed change.
- [ ] Add Emulator tests and execute them.
- [ ] Plan migration and production deployment separately.

No app code, Rules, production data, secrets, or deployments were changed.
