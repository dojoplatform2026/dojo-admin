# DOJO WALK Location Master — Step 44 Report

Date: 2026-10-17  
Branch: `restore/india-location-reference-data`

## Result: SERVICE-LAYER TESTS PASS

Added `test/service_location_boundary_verification_test.dart` to exercise the parent-containment guard in `ServiceLocationBoundaryService.markVerified()`.

Coverage:
- An Area polygon fully inside its referenced verified City boundary can be marked verified.
- An Area polygon outside the City boundary is rejected and remains pending.
- Area verification is rejected when the City has no verified boundary reference.
- A Locality polygon inside its referenced verified Area can be marked verified.
- A City boundary reference pointing to a different City is rejected.

CI:
- [Workflow run 38976622599](https://github.com/dojoplatform2026/dojo-admin/actions/runs/38976622599) completed successfully for test commit `af9b4040ffc812dcf616414e406db69aa25bcfbd`.
- Its validation job completed Python reference-data tests, Flutter analysis, Flutter unit tests, Firestore Emulator REST smoke test, and Flutter Web build successfully.
- A second duplicate workflow run for the same commit was still completing post-job cleanup when checked; the completed successful run above is the reported result.

## Important test-scope limitation

These new Dart tests use `fake_cloud_firestore` (in-memory Firestore), not the Firestore Emulator server. They validate service-layer transaction logic and assertions, but are **not emulator-backed integration tests**. The separate Node REST smoke test verifies emulator document persistence but does not invoke `markVerified()`. A dedicated emulator-backed service test remains a follow-up if the project introduces a supported test harness for authenticated Dart service calls against the emulator.

## Remaining blockers

- Official LGD row-level data reconciliation is still pending; local aggregate counts differ from the Ministry dashboard and must not be silently normalized.
- Real authoritative contiguous polygon source/provenance and parent-child geographic containment need external verification.
- Geometry uses planar longitude/latitude checks and is not geodesic or antimeridian-safe.
- Firestore security rules and the admin authorization path still require a dedicated security review before production activation.

No production Firebase writes, location imports, activations, or deployments were performed. Keep PR #6 open.
