# DOJO WALK — Backend, Firestore Rules and Cross-App Test Plan
## Step 29 — Security and lifecycle verification matrix
Date: 2026-10-16
Type: Test plan only; no tests executed

## Objective
Define a repeatable test matrix before implementation of the shared Booking / Occurrence contract. This plan is based on source audits in Steps 25–28. It does not assert that the current app passes any test, and it does not prove which Firebase Rules or Functions are deployed.

## Test layers
1. Unit tests: status transition validator, price calculation, schedule/occurrence generation, date/time conversion, legacy payload normalization.
2. Firestore Emulator Rules tests: authentication, ownership, allowed fields, role checks, denied writes, parent/child path consistency.
3. Backend integration tests: booking creation, price authority, atomic acceptance, occurrence start/complete, result linkage, final parent reconciliation.
4. Cross-app integration tests: Customer creates/reads, Partner accepts/executes, Admin views parent and per-occurrence state.
5. Release gate: run against a clean emulator dataset; review diffs and Rules coverage. Production deployment remains a separately approved action.

## A. Booking creation and pricing
| ID | Scenario | Expected result |
|---|---|---|
| BK-01 | Signed-out user submits booking | Denied |
| BK-02 | Authenticated customer creates valid booking for own pet/address | Accepted only through the approved trusted create path |
| BK-03 | Customer attempts to set walkerId at creation | Rejected or overwritten by trusted backend |
| BK-04 | Customer submits status assigned or completed | Rejected; new booking starts pending |
| BK-05 | Customer tampers with amount, discount or payout | Server-calculated price wins; tampered values rejected/ignored |
| BK-06 | Invalid duration, count, date or service type | Rejected with validation error |
| BK-07 | Customer references another customer's pet/address | Denied |
| BK-08 | Duplicate/replayed create request | Idempotent handling prevents unintended duplicate bookings |
| BK-09 | Legacy payload uses text duration or map pickupAddress | Compatibility reader handles only approved legacy shape; no unsafe cast/crash |
| BK-10 | Customer direct Firestore create while Rules disallow it | Denied; test must verify the approved trusted create endpoint is configured |

## B. Atomic whole-booking walker acceptance
| ID | Scenario | Expected result |
|---|---|---|
| AC-01 | Eligible walker accepts a pending booking | Exactly one successful atomic transition to assigned; walkerId and acceptedAt set |
| AC-02 | Two walkers accept simultaneously | One winner only; other receives conflict/already-assigned result |
| AC-03 | Walker accepts booking already assigned, cancelled or completed | Rejected |
| AC-04 | Ineligible, inactive or wrong-service-area walker accepts | Rejected |
| AC-05 | Unauthenticated or unrelated customer calls acceptance | Denied |
| AC-06 | Partner attempts parent status accepted, picked_up or walking | Rejected by canonical contract |
| AC-07 | Client attempts to alter customerId, pricing or assignment timestamps | Denied |
| AC-08 | Retry after network timeout | Idempotent response; no duplicate assignment side effects |

## C. Occurrence start and completion
| ID | Scenario | Expected result |
|---|---|---|
| OC-01 | Assigned walker starts a scheduled occurrence belonging to this booking | Only that occurrence moves to in_progress |
| OC-02 | Different walker starts occurrence | Denied |
| OC-03 | Walker starts occurrence under another booking path or mismatched bookingId | Denied |
| OC-04 | Start same occurrence twice | Idempotent or explicit conflict; no duplicate active walk |
| OC-05 | Complete occurrence without valid active start/result | Rejected |
| OC-06 | Complete active occurrence and link its walk result | Occurrence becomes completed; timestamps and references consistent |
| OC-07 | Modify completed occurrence as ordinary client | Denied |
| OC-08 | Complete today's walk while future occurrences remain | Occurrence completed; parent remains assigned |
| OC-09 | Parent completion attempted by Partner client | Denied |
| OC-10 | All required occurrences reconciled after booking period ends | Trusted reconciliation may set parent completed |
| OC-11 | Missing, duplicate, or orphan occurrence | Reconciliation flags record; must not silently mark parent completed |
| OC-12 | Missed, cancelled, skipped, or rescheduled occurrence | Expected result blocked until business policy is approved |

## D. Walk result and GPS privacy
| ID | Scenario | Expected result |
|---|---|---|
| GPS-01 | Assigned walker accesses precise pickup details before acceptance | Only approved minimum fields exposed; exact-coordinate policy must be verified |
| GPS-02 | Assigned walker reads/writes route during their active occurrence | Allowed only within approved ownership and lifecycle limits |
| GPS-03 | Unassigned walker requests route or pickup instructions | Denied |
| GPS-04 | Unrelated customer requests another customer's route | Denied |
| GPS-05 | Customer reads own completed walk history | Allowed only within approved history/retention policy |
| GPS-06 | Walker changes route points for different bookingId/occurrenceId | Denied |
| GPS-07 | Client forges completedAt, distance or completion status | Trusted validation required; untrusted completion fields denied |
| GPS-08 | Admin/support reads sensitive GPS data | Role-gated; sensitive access should be auditable |
| GPS-09 | Route retention expiry | Deletion/retention job behavior verified after policy approval |

## E. Admin and cross-app consistency
| ID | Scenario | Expected result |
|---|---|---|
| X-01 | Admin lists booking with legacy fields | Screen remains resilient; fallback mappings explicit |
| X-02 | Admin views recurring booking after one occurrence completes | Parent status assigned; occurrence counts show completed and remaining slots separately |
| X-03 | Partner list queries assigned bookings | Query matches canonical walkerId and parent status; required indexes documented |
| X-04 | Customer booking detail displays status | Shows parent status separately from today's occurrence status |
| X-05 | Customer and Partner disagree on petDetails/dog or address shape | Shared mapper handles supported legacy shapes without crashing or leaking fields |
| X-06 | One-time booking completes | Parent completes only after its single required occurrence is reconciled |
| X-07 | Timezone/date boundary | Occurrence appears at intended local date/time and is not duplicated or shifted |
| X-08 | Reassignment, cancellation, or reschedule | Access and references follow approved policy; no stale walker GPS access |

## F. Required test infrastructure and evidence
- Identify authoritative Firebase project and Rules/Functions deployment source before interpreting results.
- Add a dedicated emulator configuration and deterministic fixture data; tests must never use production customer/walker records.
- Use Firebase Rules unit-testing support for allow/deny cases and backend unit/integration tests for trusted operations.
- Capture command, toolchain versions, test counts, failures, and commit SHA in a report.
- Add negative tests first for booking creation, assignment race, parent completion forgery, occurrence path mismatch, and GPS privacy.
- A green UI test alone does not prove Firestore Rules or backend security.
- Never deploy Rules/Functions or mutate production data as part of these tests.

## G. Blockers before tests can be meaningfully executed
1. Confirm authoritative deployed Rules and Functions source/project; repository source alone is insufficient.
2. Approve the Step 28 canonical contract and compatibility behavior.
3. Decide regular booking term, occurrence generation strategy, timezone convention, and missed/skipped/cancelled/rescheduled semantics.
4. Approve canonical server-side price fields/calculation.
5. Approve pre-acceptance pickup visibility and GPS route history/retention policy.
6. Implement trusted backend endpoints and Rules before expecting the full matrix to pass.
7. Add emulator/test configuration and inspect dependency versions in each repository.

## Scope and verification
This is a test plan, not test evidence. No emulator, unit, integration, UI, or production test was run. No application code, Rules, Functions, database, settings, or deployment was changed. Every scenario above remains unverified until executed against the reviewed implementation and recorded with results.
