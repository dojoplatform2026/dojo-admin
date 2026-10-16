# DOJO WALK Cross-App Data Read/Write Inventory — Step 6
**Date:** 2026-10-16  
**Branch:** `audit/zone-service-area-mapping-2026-10-16`  
**Status:** Partial source inventory from GitHub code search. Not a complete repository-wide static analysis; no runtime or production data access.

## 1. Objective
Identify confirmed source locations that read/write shared Firestore collections before schema or Rules changes. Paths below were found through GitHub code search; links point to the inspected source revisions. Confirm current branch heads and search all direct and indirect access before implementation.

## 2. Inventory found

| App | File | Collection / fields | Source-level observation | Risk / next action |
|---|---|---|---|---|
| Customer | [booking_confirmation_screen.dart](https://github.com/dojoplatform2026/dojo-walk-customer/blob/c99fcad14822cbf53b439abc4857fbdb7464a664/lib/features/booking/screens/booking_confirmation_screen.dart) | `bookings`; `bookingId`, `customerId`, `bookingPlan`, `serviceType`, schedule fields | Creates the booking payload; date-selection branch includes `selectedDates` and `dateSchedules`. | Inventory all plan branches and exact timestamp/address/status fields before contract changes. |
| Customer | [my_bookings_screen.dart](https://github.com/dojoplatform2026/dojo-walk-customer/blob/c99fcad14822cbf53b439abc4857fbdb7464a664/lib/features/booking/screens/my_bookings_screen.dart) | Reads booking data such as `pickupAddress`, `bookingPlan`, `serviceType` | Customer display logic depends on existing plan/type fields. | Preserve compatibility or explicitly migrate display logic and historical documents. |
| Partner | [partner_home_screen.dart](https://github.com/dojoplatform2026/dojo-partner/blob/cf7760bd393c3c0bbac8bfb7ed5689a203815f7d/lib/screens/home/partner_home_screen.dart) | Queries `bookings` by `walkerId`; filters today's bookings using `date` in inspected source; queries `walks` by `walkerId` | Reader may expect top-level `date` while customer writer has schedule/date fields that need reconciliation. | Confirm complete filtering code and actual legacy docs; choose compatibility strategy before renaming fields. |
| Partner | [live_walk_screen.dart](https://github.com/dojoplatform2026/dojo-partner/blob/cf7760bd393c3c0bbac8bfb7ed5689a203815f7d/lib/features/live_walk/screens/live_walk_screen.dart) | Writes `walks/{id}`, then updates `bookings/{bookingId}` | Two separate writes appear in the completion path. | Design idempotency/recovery or trusted transaction; test partial failure and duplicate retries. |
| Partner | [navigation_screen.dart](https://github.com/dojoplatform2026/dojo-partner/blob/cf7760bd393c3c0bbac8bfb7ed5689a203815f7d/lib/screens/home/navigation_screen.dart) | Updates `bookings/{bookingId}` status | Another status-write path exists. | Inventory all allowed status transitions and verify server/rules enforcement. |
| Partner | [firestore.rules](https://github.com/dojoplatform2026/dojo-partner/blob/cf7760bd393c3c0bbac8bfb7ed5689a203815f7d/firestore.rules) | Rules for `bookings` and walker assignment | Source rules include assigned-walker checks; customer booking create is explicitly denied in this file. Deployment authority remains unknown. | Do not deploy or assume this is the active production ruleset until Firebase config/deployment is verified. |
| Admin | [auth_gate.dart](https://github.com/dojoplatform2026/dojo-admin/blob/369842ba91602c23941fbc5aeb97f98d68d996d9/lib/screens/auth/auth_gate.dart) | Reads `admin_users/{uid}` | Gate checks the current admin document; shell access is not a complete action-level scope policy. | Inventory all admin actions and centralize server/rules-side role + scope checks. |
| Admin | [walker_admin_service.dart](https://github.com/dojoplatform2026/dojo-admin/blob/369842ba91602c23941fbc5aeb97f98d68d996d9/lib/features/walkers/services/walker_admin_service.dart) | Reads `admin_users` | Sensitive walker operations check active status and `super_admin` role in inspected code. | Preserve Super Admin compatibility; check every sensitive service and UI path. |
| Admin | [service_location_service.dart](https://github.com/dojoplatform2026/dojo-admin/blob/369842ba91602c23941fbc5aeb97f98d68d996d9/lib/features/service_location/services/service_location_service.dart) | `service_areas`, `service_location_boundaries`, `service_location_imports`, `service_location_name_indexes` | Service uses named collections for area records, boundaries, imports, and name indexes. | Fetch full service/model files and inventory all country/state/city/locality paths and mutation methods before Rules changes. |
| Admin | [service_location_models.dart](https://github.com/dojoplatform2026/dojo-admin/blob/369842ba91602c23941fbc5aeb97f98d68d996d9/lib/features/service_location/models/service_location_models.dart) | `service_areas`, `verifiedBoundaryId` | Model documents boundary reference. | Verify boundary document schema, verification metadata, and activation conditions. |

## 3. Invitation flow
Search did not identify a source implementation for `admin_invitations`/expiry in the searched Admin code. This is not proof that no implementation exists elsewhere. Treat invitations, expiry, approval, and reminders as **specification-only** until a broader file inventory confirms implementation.

## 4. Key compatibility risks
1. **Booking time/date:** customer schedule data and Partner's `date` filtering may not agree. Do not replace either field until all readers/writers and historical documents are checked.
2. **Status ownership:** Customer, Partner navigation, live-walk completion, and Admin workflows may all touch booking state. Define a state-transition matrix and restrict trusted transitions.
3. **Dual writes:** walk completion can update two documents separately; retries may create duplicate or inconsistent records.
4. **Rules deployment:** the existence of a source Rules file does not establish that Firebase is currently using it.
5. **Location security:** boundary and location collections need a documented scope matrix; UI hiding is not sufficient enforcement.
6. **Admin access:** preserve active `super_admin` behavior while preventing self-promotion and out-of-scope changes.

## 5. Step 6 completion status
- [x] Identified representative Customer booking writer and reader.
- [x] Identified Partner booking query, walk writer, and another booking status writer.
- [x] Identified Admin AuthGate and sensitive admin service.
- [x] Identified core Service Location collection references.
- [x] Recorded compatibility risks and next checks.
- [ ] Exhaustive search of all three repositories and all collection access sites.
- [ ] Read exact full contents of every relevant file at a single consistent branch/commit.
- [ ] Confirm actual deployed Firestore/Storage Rules and indexes.
- [ ] Inspect anonymized legacy schema fixtures or authorized data export.
- [ ] Implement/run emulator tests.

## 6. Next step
Complete the repository-wide read/write inventory and document the booking status transition matrix. Then add a disposable Firebase Emulator test configuration and test fixtures. No production code, rules, data, or deployment was changed in this step.
