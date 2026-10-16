# DOJO WALK — Canonical Booking Status & Transition Matrix (Step 5)

**Date:** 2026-10-16  
**Status:** Proposed contract based on static source audit; NOT yet implemented or emulator-tested  
**Branch:** `audit/zone-service-area-mapping-2026-10-16`

## Why this step
The three apps currently use overlapping but inconsistent status vocabularies. This document proposes one machine-readable vocabulary and role-specific transitions. It must be reviewed against all booking screens, notifications, analytics, cancellation rules, and any backend functions before code or Security Rules change.

## 1. Proposed canonical status values

Use lowercase snake_case only in Firestore. UI labels are presentation-only and must not be stored as status values.

| Canonical value | Customer label | Operational meaning |
|---|---|---|
| `pending` | Booking Received | Booking created; not yet assigned |
| `finding_walker` | Finding a Walker | Assignment process underway |
| `assigned` | Walker Assigned | A trusted assignment has set `walkerId` |
| `accepted` | Walker Accepted | Assigned walker accepted the job |
| `walker_arriving` | Walker on the Way | Walker is navigating to pickup |
| `picked_up` | Dog Picked Up | Walker confirms dog handover |
| `walking` | Walk in Progress | Walk has started |
| `completed` | Completed | Walk completed and required completion data validated |
| `cancel_requested` | Cancellation Requested | Customer has requested cancellation; admin/automation resolves it |
| `cancelled` | Cancelled | Booking cancelled by an authorized transition |
| `assignment_failed` | Finding Another Walker | Assignment attempt failed; eligible for retry/reassignment |
| `needs_support` | Needs Support | Operational exception requiring review |

## 2. Proposed transitions by actor

| From | To | Authorized actor | Guard conditions |
|---|---|---|---|
| (new document) | `pending` | Customer | Auth UID equals `customerId`; valid booking schema; `walkerId == null` |
| `pending` | `finding_walker` | Trusted backend/Admin | Valid service area and booking |
| `finding_walker` | `assigned` | Trusted backend/Admin | Walker active, approved, eligible, available, and valid service area; set `walkerId` to Auth UID |
| `pending` / `finding_walker` | `cancel_requested` | Customer | Booking belongs to customer and is cancellable |
| `assigned` | `accepted` | Assigned walker | Existing `walkerId == request.auth.uid` |
| `assigned` / `accepted` | `cancel_requested` | Customer | Cancellation policy allows request; walker state preserved |
| `accepted` | `walker_arriving` | Assigned walker | Booking is assigned to caller; valid transition |
| `walker_arriving` | `picked_up` | Assigned walker | Pickup/handover confirmation captured |
| `picked_up` | `walking` | Assigned walker | Walk start metadata captured |
| `walking` | `completed` | Assigned walker via validated transaction/backend | End metadata, duration/distance bounds, dog return and required checks validated |
| `cancel_requested` | `cancelled` | Trusted backend/Admin | Cancellation policy applied and action logged |
| `finding_walker` | `assignment_failed` | Trusted backend/Admin | No eligible walker; reason logged |
| `assignment_failed` | `finding_walker` | Trusted backend/Admin | Retry policy permits |
| Any active state | `needs_support` | Trusted backend/Admin or explicit incident workflow | Reason required; preserve history |
| `needs_support` | approved resolution state | Trusted backend/Admin | Resolution note and audit record required |

These are proposals, not permission to make the transitions immediately. The exact cancellation policy and whether walkers can request cancellation need product decisions.

## 3. Legacy status normalization candidates

Static source audit found values/labels such as:
- `pending`, `finding_walker`, `walker_assigned`, `walker_arriving`, `confirmed`, `assigned`, `accepted`, `in_progress`, `in progress`, `picked_up`, `walking`, `completed`, `cancelled`, `canceled`, `active_walk`, `walk_started`, plus human-readable Admin labels.

Suggested mappings for migration review:
- `walker_assigned` -> `assigned`
- `confirmed` -> review semantics before mapping; it may mean booking confirmation rather than walker acceptance
- `in_progress`, `in progress`, `active_walk`, `walk_started` -> review by source and lifecycle semantics before mapping to `walking`
- `canceled` -> `cancelled`
- `picked_up` -> retain if it is an actual stored value
- display labels such as `Walker Assigned`, `Walk In Progress` must be converted to canonical values in UI filter logic, not stored or compared raw.

Do not bulk-rewrite existing production records until sample data, all readers, and rollback strategy are audited.

## 4. Security invariants

- Only trusted assignment logic may set/change `walkerId`.
- `customerId`, `bookingId`, price, payment state, service plan and original creation time are immutable to customers/walkers.
- Customer cancellation is a request, not a direct status override.
- Walker can mutate only the currently assigned booking and only permitted transition fields.
- A walker cannot set `completed` unless the booking is currently `walking` and all required completion fields pass validation.
- A verified/active walker must be eligible for the booking's service area.
- Any reassignment requires an explicit authorized flow and an audit log.
- UI labels are localized separately from machine statuses.

## 5. Implementation gates
Before implementation:
1. Audit all status writes/reads across all three repositories and backend Functions.
2. Confirm cancellation, no-show, customer unavailable, dog-return verification, and backup-walker policy.
3. Implement shared status constants/helpers in each app (or a versioned shared package).
4. Update UI filters and query logic to use canonical values.
5. Write Firestore Emulator tests for each permitted and denied transition.
6. Test existing production-like fixtures and migration mapping.
7. Add indexes only when emulator/real query errors demonstrate they are required.
8. Prepare a staged rollout and rollback plan.

## 6. Current result
This is a design artifact only. No app code, booking documents, Firestore Rules, indexes, Firebase configuration, Hosting, or Functions were changed. Production rules/status distribution remains unverified.
