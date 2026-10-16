# DOJO WALK Shared Data Contract & Emulator Test Plan — Step 5
**Date:** 2026-10-16  
**Repository:** `dojoplatform2026/dojo-admin`  
**Branch:** `audit/zone-service-area-mapping-2026-10-16`  
**Status:** Design proposal only — not production implementation, not deployed, and not emulator-tested.

## 1. Purpose
Record a cautious shared contract for Customer, Partner, and Admin before changing Firestore data or security rules. Findings below come from source-level review. Confirm the deployed Firebase rules, existing production document shapes, all writers/readers, and legacy data before applying migrations.

## 2. Source-level risks carried forward
1. Customer booking creation writes `bookings` with `scheduledAt` and schedule details.
2. Partner home filtering reads top-level `date` for today's bookings. This may not match customer-created documents that use `scheduledAt`; check all code paths and legacy documents before choosing a canonical field.
3. Partner live walk appears to write a `walks` document and update its parent booking separately. Partial failure can leave records inconsistent.
4. Admin AuthGate checks `admin_users/{uid}.isActive == true` to enter the shell; it is not, by itself, a complete role/permission/location authorization policy.
5. Partner source rules explicitly deny booking creation and `walk_requests`; the partner Firebase config inspected does not declare a Firestore rules deployment. Whether those rules are deployed is unknown.
6. Service Location collection names and boundary document paths must be reconciled against the current implementation before rules are written.

## 3. Proposed shared booking contract (not implemented)
### Parent document: `bookings/{bookingId}`
- `bookingId`: stable document identifier.
- `customerId`: authenticated owner UID.
- `walkerId`: nullable UID; assignment is server/admin-controlled.
- `bookingPlan`: existing-compatible enum, currently observed values include `one_time`, `regular`, `customize`; reconcile actual writers before standardizing.
- `serviceType`: preserve existing-compatible values, currently observed include `temporary_walk`, `regular_walk`, `custom_walk`.
- `scheduledAt`: canonical timestamp for a single booking; for multi-date/regular plans, retain validated schedule/template fields until a migration is designed.
- `duration`, `status`, and address snapshot: preserve existing semantics after code/data audit.
- `createdAt`, `updatedAt`: server timestamps for trusted state changes.
- Do not silently remove `date`, `walkSchedules`, `selectedDates`, `dateSchedules`, or other legacy fields until all readers and historical documents are inventoried.

### Walk occurrence
For each scheduled occurrence, prefer a stable occurrence ID and explicit parent reference:
- `occurrenceId`, `bookingId`, `scheduledAt`, `duration`, `status`, and optional `walkerId`.
- Avoid duplicating authoritative assignment/payment fields across client-controlled documents.
- If the current product uses embedded schedule arrays, choose a migration/compatibility plan first; do not introduce a second representation without a defined source of truth.

### Authorization invariants
- Customer: may read their own bookings and submit only validated booking requests; cannot assign walkers or set trusted completion/payment/audit state.
- Partner: may access only assigned work and write only permitted walk-progress fields; cannot self-assign or modify price/payout/admin state.
- Admin: authorization must check active status, role/permissions, and location scope server-side/rules-side, not only hide UI.
- Super Admin: preserve the existing active `super_admin` workflow while preventing self-escalation and unauthorized scope changes.
- Audit events and payment/payout outcomes must not be client-writable.

## 4. Service Location security prerequisites
Before writing rules, confirm exact paths, document fields, and boundary storage for:
`service_countries`, `service_states`, `service_cities`, `service_areas`, `service_localities`, `service_location_imports`, `service_location_name_indexes`, and any `service_location_boundaries` collection/path.
Require verified polygon boundaries and parent/scope validation for activation. Enforce active-child and reparenting constraints in trusted code where rules cannot safely enforce cross-document invariants.

## 5. Firebase Emulator test plan (not yet run)
Run tests against a disposable emulator project/config only after the authoritative rules and config are identified. Never point destructive tests at production.

### Identity and admin authorization
- Unauthenticated reads/writes denied where intended.
- Inactive admin denied.
- Non-admin cannot create or activate an admin record.
- Admin cannot change their own role, permissions, or scope.
- Authorized active Super Admin can perform explicitly permitted admin actions.
- State, City/District, and Area scopes cannot read or mutate out-of-scope locations or records.

### Customer bookings
- Customer can submit a valid booking for their own UID.
- Customer cannot spoof another `customerId`, set `walkerId`, mark a walk complete, or set payout/final-charge/audit fields.
- Invalid plan/type, malformed timestamps, invalid duration, or inconsistent schedule counts are rejected by trusted validation.
- Existing legacy booking shapes have explicit compatibility tests.

### Partner assignments and walk lifecycle
- Assigned walker can read permitted booking fields and update only allowed progress fields.
- Unassigned walker cannot read/update the booking or occurrence.
- Partner cannot assign themselves, change customer/address/pricing, or edit admin/audit fields.
- Repeated completion/retry is idempotent.
- Simulated failure between occurrence write and parent update is recoverable without duplicate completion/payout.

### Service Locations
- Allowed admin can create/update only within authorized scope.
- Unverified boundary cannot be activated.
- Invalid/missing parent, duplicate normalized name, or prohibited reparenting is rejected.
- Active parent/child deactivation constraints are tested.
- Boundary reads/writes obey role and scope; default-deny behavior is verified.

### Invitations and reminders
- Wrong email, expired invitation, reused token, revoked invitation, and unauthorized claimant are denied.
- Claim is one-time and safe under repeated requests.
- Reminder processing is idempotent and stops when invitation status changes.
- Client cannot directly set approval or trusted invitation state.

### Deployment guardrails
- Confirm which rules files are actually deployed and by which workflow.
- Add emulator configuration and automated rules tests before any rules deployment.
- Review rules diffs and deploy through a controlled, reviewed change.
- Do not claim deployment or runtime safety until test output and deployed project/rules are independently verified.

## 6. Required evidence before implementation
1. Read current files from all three repositories at the exact branch/commit to be changed.
2. Retrieve/inspect authoritative Firebase project rules and indexes with authorized Firebase access; if unavailable, mark deployment status unknown.
3. Inventory every writer/reader for `bookings`, `walks`, admin records, invitations, and Service Location collections.
4. Create emulator fixtures for new and legacy documents and record pass/fail output.
5. Agree on canonical schedule/occurrence representation and migration/backfill strategy.
6. Only then propose a separate implementation PR; no production rules, live data, or deployment changes are authorized by this design document.

## 7. Status checklist
- [x] Source-level cross-app risks documented.
- [x] Proposed contract and emulator test matrix drafted.
- [ ] Deployed Firestore/Storage rules verified.
- [ ] All schema writers/readers inventoried.
- [ ] Emulator config and tests implemented.
- [ ] Emulator tests executed and results recorded.
- [ ] Migration plan approved.
- [ ] Implementation PR reviewed.
- [ ] Production deployment explicitly approved and verified.
