# DOJO WALK Booking/Walk Contract Decision Proposal — Step 13
Date: 2026-10-16
Branch: audit/zone-service-area-mapping-2026-10-16
Status: Recommended defaults for product-owner review; not approved or implemented.

## 1. Why this step
Step 12 identified unresolved product choices. This report recommends concrete defaults based on the existing company-controlled Regular Walk design and the source inventory. These are proposals, not user-approved policy and not a production implementation.

## 2. Recommended decisions

### D1 — Walker acceptance applies per occurrence
**Recommendation:** Company/Admin assigns a walker to each scheduled occurrence (or to a recurring roster/template which creates explicit per-date assignments). The assigned walker accepts each occurrence. Do not treat one acceptance as automatic acceptance of every future date unless a separately approved roster policy explicitly defines that behavior.

**Reason:** Individual occurrences may be rescheduled, reassigned, or unavailable independently. Company retains assignment control for Regular Walks.

### D2 — Keep cancellation request separate from cancellation outcome
**Recommendation:** Customer creates a `cancelRequest` with requested time/reason. The request does not itself mutate the authoritative booking/occurrence status. A policy engine or authorized operations user approves/denies it and writes an audit event.

Proposed policy pending business approval:
- Before assignment: cancellation can be automatically approved.
- After assignment but before walker acceptance: operations may auto-approve if replacement/capacity policy permits.
- After acceptance but before pickup: route to operations, with fee/refund determined by published terms.
- After pickup or while walking: customer cannot directly cancel the active occurrence; urgent stop/refund handling requires operations and a reasoned audit trail.
- Regular plan cancellation is distinct from cancelling one occurrence; plan termination must record effective date and disposition of future occurrences.

Do not implement fees, penalties, refunds, or cutoffs until the business owner approves explicit terms.

### D3 — Canonical occurrence storage
**Recommendation:** Use top-level `walk_occurrences/{occurrenceId}` as the canonical scheduled-walk record, with a stable ID, and retain `bookings/{bookingId}` as the customer order/plan. This is the recommended option, not an existing confirmed schema.

Required linkage/fields:
- `occurrenceId`, `bookingId`, `customerId`, `walkerId` (nullable until assigned)
- `scheduledAt`, `durationPlanned`, `status`
- `createdAt`, `updatedAt`, assignment/acceptance/start/pickup/completion timestamps as relevant
- source reference to legacy schedule index/date if migrated
- no secrets or unnecessary sensitive data copied into occurrence documents

Benefits: easier querying by assigned walker and date, independent per-day lifecycle, clear idempotency key, and avoids marking a month-long booking complete after one walk.

### D4 — Keep `walks/{walkId}` only as an active tracking/session record
**Recommendation:** If live GPS needs a separate record, `walks/{walkId}` is the live session/telemetry summary and must carry `occurrenceId` and `bookingId`. It is not the second authority for scheduled occurrence status. One occurrence may have at most one active session; completion is committed once against the occurrence through a trusted, idempotent operation.

Before adopting this, inspect all writers/readers and confirm whether existing walk documents contain history/analytics that must be preserved.

### D5 — Parent booking status is derived
**Recommendation:** Backend/transactional logic updates parent status from occurrence statuses. A regular booking remains active while required future occurrences remain. Parent `completed` is allowed only when all required occurrences are completed or explicitly resolved under an approved policy. Do not let a client directly write parent `completed`.

## 3. Recommended state transitions
Occurrence:
- `pending → assigned → accepted → picked_up → walking → completed`
- Pre-service alternate outcomes: `cancelled`, `missed`, `failed` only through authorized policy handlers.
- Reassignment is an audited operation and must not silently reset an accepted/in-progress occurrence.
- Terminal states cannot be reopened by ordinary clients.

Parent booking:
- `pending → assigned` (or `confirmed` first only if operations needs a separate review stage)
- `assigned/in_progress → completed` only when aggregate occurrence policy is satisfied.
- `cancelled` for whole-plan termination, not as a synonym for cancelling one occurrence.

## 4. Migration safety
1. Do not rewrite live records at this stage.
2. Inventory actual `bookings`, `walks`, regular plans, `walkSchedules`, `dateSchedules`, and legacy aliases read-only.
3. Define deterministic occurrence IDs for new records; use an explicit mapping table for legacy records where IDs are absent.
4. Preserve historical data and build a read compatibility layer before any write migration.
5. Use Emulator fixtures to test old and new records side-by-side.
6. Add Rules only after authoritative deployed Rules and backend ownership are confirmed.
7. Do not deploy a migration or Rules update without a separate review and explicit authorization.

## 5. Product-owner decisions still required
- Approve/revise per-occurrence walker acceptance.
- Approve cancellation stages, cutoff, fee/refund terms and whole-plan termination behavior.
- Approve `walk_occurrences` as canonical collection versus booking subcollection.
- Confirm `walks` session record ownership and retention requirements.
- Confirm whether `confirmed` is needed between `pending` and assignment.
- Define handling for missed/failed walks, rescheduling, refunds, and partial regular plans.

## 6. Checklist
- [x] Converted Step 12 open questions into concrete recommendations.
- [x] Aligned Regular Walk assignment with company-controlled operations.
- [x] Separated booking, occurrence, and tracking-session responsibilities.
- [x] Documented migration guardrails.
- [ ] Product owner approval.
- [ ] Read-only production schema verification through authorized access.
- [ ] Implement model/backend/Rules changes after approval.
- [ ] Run Emulator and app tests.
- [ ] Separately review any production deployment.

No app code, Rules, live data, secrets, or deployment was changed.
