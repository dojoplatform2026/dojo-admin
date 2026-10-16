# DOJO WALK — Canonical Booking and Walk Occurrence Field Dictionary
## Step 28 — Shared field names, types, and ownership
Date: 2026-10-16
Type: Proposed schema contract; not implemented

## Purpose
This document turns Steps 23, 26, and 27 into a single field-level contract for Customer, Partner, Admin, Firestore Rules, and backend. It is a proposed implementation baseline, not a statement that these fields already exist in production. Existing legacy fields must be preserved until a tested migration is approved.

## A. Parent document — `bookings/{bookingId}`
| Field | Proposed type | Authority / rule |
|---|---|---|
| `customerId` | string (Firebase UID) | Set from authenticated customer by trusted create path; immutable |
| `walkerId` | string or null | Null before assignment; set only by atomic acceptance/backend or authorized admin workflow |
| `status` | string enum | `pending`, `assigned`, `cancelled`, `completed`; trusted transitions only |
| `bookingPlan` | string enum | `one_time`, `regular`, `customize`; validated at create |
| `serviceType` | string enum | Existing product contract values; validate against approved service catalog |
| `walkType` | string | Legacy compatibility only until its exact meaning is standardized |
| `dogId` | string | Customer-owned pet reference; validate ownership |
| `petDetails` | map | Snapshot shape must be explicitly versioned/normalized; don't assume Partner's legacy `dog` field |
| `pickupAddressId` | string or null | Reference to customer address where supported |
| `pickupAddress` | map during compatibility phase | Canonical structured address; never assume a string; exact coordinates/instructions require acceptance-based privacy design |
| `walkCount` | integer | Validated count for the booking/request; clarify whether it means requested slots or total occurrences before relying on it for regular plans |
| `walkSchedules` | array of maps | Legacy/request snapshot during migration; not a mutable source of truth after occurrences are materialized |
| `frequency` | string/enum | Regular-plan compatibility field; allowed values to be standardized |
| `walksPerDay` | integer | Regular-plan validated value; consistent with occurrence generation |
| `dailyWalkTemplate` | array of maps | Template only; not a dated completed walk |
| `selectedDates` | array of date strings or timestamps | Legacy custom-plan input; one canonical representation must be chosen |
| `dateSchedules` | array of maps | Legacy custom-plan input; preserve until backfill/read migration passes |
| `startDate` / `endDate` | timestamp or date-only type (decision pending) | Required for bounded regular plans; choose one timezone/date convention before implementation |
| `createdAt` / `updatedAt` | Firestore Timestamp | Trusted server timestamps; `updatedAt` required on every accepted mutation |
| `acceptedAt` | Firestore Timestamp or absent | Set by trusted atomic acceptance only |
| `cancelRequest` | map or null | Request metadata only; not the same as final booking cancellation |
| `cancelledAt` / `completedAt` | Timestamp or absent | Set only by authorized trusted lifecycle transition |
| `currency` | string, initially `INR` | Server-controlled |
| `priceBreakdown` | map | Server-calculated; canonical components and tax/discount rules need pricing contract |
| `totalAmountPaise` | integer | Proposed integer minor units (₹1 = 100 paise); server-calculated, avoids floating-point currency errors |
| `schemaVersion` | integer | Set for new contract records; legacy records require tolerant readers |

## B. Occurrence subdocument — `bookings/{bookingId}/occurrences/{occurrenceId}`
| Field | Proposed type | Authority / rule |
|---|---|---|
| `occurrenceId` | string | Equals document ID; stable and never regenerated on rebuild/render |
| `bookingId` | string | Must match parent path |
| `customerId` | string | Must match parent |
| `walkerId` | string or null | Must match assigned parent walker except authorized reassignment policy |
| `slotKey` | string | Stable key for a slot, not a localized display label |
| `slotLabel` | string | UI label such as Morning; display-only |
| `scheduledAt` | Firestore Timestamp | Date/time for this exact occurrence; timezone policy required |
| `durationMinutes` | integer | Validated approved range and price rules |
| `status` | enum | `scheduled`, `in_progress`, `completed`; additional terminal states only after policy approval |
| `startedAt` / `completedAt` | Timestamp or absent | Set through authorized state transition |
| `walkId` | string or null | Reference to detailed `walks/{walkId}` result |
| `createdAt` / `updatedAt` | Firestore Timestamp | Server timestamps |
| `rescheduledFromOccurrenceId` | string or null | Optional lineage for reschedules; only if reschedule workflow is approved |

## C. Walk result document — `walks/{walkId}`
Required linkage: `bookingId`, `occurrenceId`, `customerId`, `walkerId`. Suggested result fields: `status`, `startedAt`, `completedAt`, `actualDurationSeconds`, `distanceMeters`, `peeCount`, `poopCount`, `routePoints` or protected route reference, `returnVerifiedAt`, `createdAt`, `updatedAt`. Types, route sampling, retention, and whether route points live inline or in a separate protected collection must be finalized before implementation. A walk result cannot independently change the parent booking lifecycle.

## D. Canonical lifecycle contract
### Parent booking
- `pending` -> `assigned` after one atomic eligible-walker acceptance.
- `pending` -> `cancelled` only through approved cancellation flow.
- `assigned` remains `assigned` while required occurrences are still upcoming or unresolved.
- `assigned` -> `cancelled` only through approved booking-wide cancellation policy.
- `assigned` -> `completed` only after the end of the booking period and reconciliation of all required occurrences.
- Do not write `accepted`, `picked_up`, `walking`, or single-walk `completed` as parent status.

### Occurrence
- `scheduled` -> `in_progress` by the assigned walker for that exact occurrence, after required checks.
- `in_progress` -> `completed` after completion checks and linked result save.
- Completed occurrences are immutable to normal clients; corrections require audited privileged action.
- `missed`, `skipped`, `cancelled`, and `rescheduled` are not approved enum values yet. Do not implement their final semantics until the business policy is decided.

## E. Ownership / field writer matrix
- Customer app: submits booking request data and reads permitted status; must not authoritatively set `walkerId`, acceptance timestamps, server price, final completion, or walk result status.
- Partner app: requests acceptance/start/complete operations; must not directly overwrite booking-wide lifecycle or another occurrence.
- Backend: validates booking create and pricing, atomically assigns a walker, transitions occurrences, links walk results, and computes final parent completion.
- Firestore Rules: enforce authentication, ownership, role, field allowlists, path-parent consistency, and privacy. Rules do not replace server-side pricing or multi-step business validation.
- Admin: read/operate within explicit active role permissions; overrides need audit metadata.

## F. Compatibility mapping — no blind renames
- Customer `duration` (text) -> future `durationMinutes` (integer) only after parsing/validation; preserve original during migration.
- Customer `pickupAddress` map vs Partner's expected string -> update readers to support normalized map and legacy string; do not change data blindly.
- Customer `petDetails` vs Partner's expected `dog`/`dogBreed`/`dogSize` -> normalize through a defined snapshot mapper or trusted read model.
- Admin `amount`/`totalAmount`/`price` -> future `totalAmountPaise`; keep legacy read fallback until verified migration complete.
- Legacy parent statuses `accepted`, `picked_up`, `walking`, `completed` need a per-record migration mapping; `completed` cannot be safely interpreted as booking-complete without inspecting its history.
- Existing `walkSchedules`, `dailyWalkTemplate`, `selectedDates`, `dateSchedules` stay until the occurrence backfill and reconciliation pass is verified.

## G. Decisions still required before code implementation
1. Regular booking duration/term and whether start/end are timestamps or local date-only values.
2. Occurrence creation upfront versus trusted scheduled generation.
3. Outcomes and billing for missed/skipped/cancelled/rescheduled slots.
4. Exact price breakdown fields, taxes/discounts, and server pricing source.
5. GPS route storage, customer history window, retention, and privileged support access.
6. Whether custom `durationMinutes` bounds are 1–240 minutes or a narrower approved list, and how price scales.
7. Canonical `serviceType` values and exact `walkType` meaning.
8. Authoritative deployed Rules/backend source and project confirmation.

## Scope / verification
This is a schema proposal only. No application code, Rules, backend, database, migration, or deployment was changed. No tests were run. Field types and enums must be reviewed against existing payloads and approved business policy before implementation.
