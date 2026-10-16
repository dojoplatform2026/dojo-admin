# DOJO WALK — Shared Firestore Security Rules Design (Draft)

**Date:** 2026-10-16  
**Status:** DESIGN ONLY — not production rules, not deployment-ready  
**Branch:** audit/zone-service-area-mapping-2026-10-16

## Purpose
Define the authorization model that must be implemented and tested consistently across Customer, Partner, and Admin before any Firestore rules are deployed. The active Production rules have not been independently verified.

## Core security principles
1. Firestore Rules are authoritative. Client-side checks and hidden UI controls are not authorization.
2. Default deny: unmatched paths must remain denied.
3. Do not grant broad public write access to any collection.
4. Admin privileges must come from a server-controlled admin record (for example, `admin_users/{uid}` with `isActive == true` and an approved role), not user-editable profile fields.
5. Validate allowed fields, types, ownership, immutable identifiers, and permitted status transitions on every create/update.
6. Rules are not filters: queries must include constraints that prove every returned document is readable.
7. Use the Firestore Emulator and automated positive/negative tests before deployment.

## Collection access matrix (proposal; requires schema reconciliation)

| Collection | Customer | Partner/Walker | Admin |
|---|---|---|---|
| `users/{uid}` | Read/update own allowed profile fields | Read only explicitly shared customer fields for an assigned booking; no broad user listing | Read/update according to admin role and audited need |
| `users/{uid}/pets/{petId}` | Own pets only | Read only the pet data needed for a booking assigned to that walker | Admin access only where operationally required |
| `users/{uid}/addresses/{addressId}` | Own addresses only | Read pickup details only for assigned active booking, if data model permits | Restricted operational access |
| `bookings/{bookingId}` | Create for self with strict schema; read own; request cancellation through limited fields | Read assigned bookings; update only permitted walk progress fields for own assignment | Manage assignments and approved transitions |
| `walks/{walkId}` | Read only associated walk summary if product requires | Create/update only own walk tied to an assigned booking | Read/manage for support and audit |
| `walkers/{walkerId}` | Read only approved public walker fields where needed | Read/update own permitted profile fields; cannot self-approve | Approve/reject/suspend and manage roles |
| `service_countries`, `service_states`, `service_cities`, `service_areas`, `service_localities` | Read only active serviceable locations needed for booking | Read only active serviceable locations needed for work-zone selection | Authorized location administration |
| `service_location_boundaries` | Read only verified boundaries needed by customer flows | Read verified boundaries needed by work/route flows | Create/edit pending or rejected; verify/reject through authorized admin action; verified geometry immutable |
| `service_location_imports` | No access | No access | Authorized import operators only |
| `service_location_name_indexes` | No direct access | No direct access | Admin/service writes only; transaction integrity required |
| `audit_logs` | No access | No access | Restricted append/read access; prevent client alteration/deletion |
| `zones` (legacy) | Read only if still used and intentionally public | Read only if still used | Admin writes; migrate only after all consumers audited |

## Booking create validation
A future customer create rule should require:
- authenticated UID equals `customerId`;
- allowed keys only, with required fields and correct types;
- `status == 'pending'` and `walkerId == null` on initial create;
- document ID and embedded `bookingId` consistency if the application retains both;
- valid schedule shape/count, supported service/plan values, valid customer pet/address ownership, and server timestamps where feasible;
- no client-supplied assignment, completion, payout, verification, or admin-only fields.

Do not simply change `allow create: if false` to `true`. It must be replaced by full schema validation after comparing actual Customer payloads.

## Booking update validation
- Customer may only request cancellation on eligible statuses and may only modify the agreed cancellation fields.
- Assigned walker may only update an explicitly enumerated set of progress fields on a booking whose `walkerId` equals their UID.
- Walker must not assign themselves, change `customerId`, price, payment, booking plan, or another walker's booking.
- Admin assignment/status transitions must require active admin authorization and explicit allowed transition checks.
- Align status spelling/casing across all apps before enforcing transition rules (currently code shows inconsistent labels such as `pending` vs `Pending`, and `in_progress` vs `Walk In Progress`).

## Service-location boundary validation
Application validation currently checks polygon point count/ranges and source metadata, but that does not prove official-source authenticity, polygon topology, contiguity, or authoritative accuracy. Rules should validate role, allowed fields, and verification transitions; a trusted backend/admin workflow should verify boundary provenance and geometry. Verified boundary documents should be immutable to ordinary clients.

## Indexes and queries
Inventory composite indexes from actual query combinations in all apps, including:
- bookings filtered by `customerId` and ordered by `createdAt` where used;
- bookings filtered by `walkerId` and schedule/date fields;
- any admin filters combining status, createdAt, walkerId, or city/area IDs.
Do not guess index definitions. Run each query against the Firestore Emulator and add only indexes required by observed query plans/errors. Store the canonical index file in the deployment repository and configure CI to deploy it intentionally.

## Deployment blockers / unknowns
- Active Production Firestore Rules and Indexes are not verified.
- The inspected Admin workflow deploys Hosting only; inspected Partner workflow deploys Functions only.
- Exact customer deployment configuration and any out-of-repository deployment mechanism remain unknown.
- Existing schema/status/date mismatches must be reconciled before final rules can be written.
- No rule or index changes should be deployed until emulator tests pass and a rollback plan is prepared.

## Required test checklist
1. Unauthenticated users cannot read/write private data.
2. Customer A cannot read/update Customer B's profile, pets, addresses, or bookings.
3. Customer cannot set `walkerId`, approve a walker, or mark a walk completed.
4. Walker A cannot read/update Walker B's assigned booking or alter booking ownership/pricing.
5. Walker cannot update an unassigned booking or create an arbitrary `walks` record unrelated to an assignment.
6. Non-admin cannot create/verify/activate service locations, edit name indexes, or write imports.
7. Non-admin cannot verify or modify a verified boundary.
8. Inactive admin and unauthorized admin roles are denied.
9. Valid customer booking create, cancellation request, walker progress update, and admin assignment succeed.
10. Queries from all three apps pass Rules evaluation and required index checks.

**No production rules, indexes, data, or deployment were changed while preparing this draft.**
