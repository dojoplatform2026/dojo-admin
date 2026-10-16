# DOJO WALK Location Master — Step 41

Date: 2026-10-17  
Branch: `restore/india-location-reference-data`  
Pull request: [#6 — Restore India location reference data](https://github.com/dojoplatform2026/dojo-admin/pull/6)

## Step 40 — Boundary-required activation tests: PASS

GitHub Actions run [38974326242](https://github.com/dojoplatform2026/dojo-admin/actions/runs/38974326242) passed the full validation workflow.

## Step 41 — Imported coordinate validation: PASS

Initial tests attempted to construct invalid `GeoPoint` constants; `flutter analyze` correctly rejected them because the constructor throws. Updated the model to validate imported map coordinates before constructing `GeoPoint`, skipping invalid coordinates safely. Reworked regression tests to feed invalid raw map values through `fromMap()`.

Fix commits: `645f0162f58e1b7c114cc2c58507ad82abef5ad4` (model) and `55e78c8690d994b73d3cec792adf4bc8ba99425a` (tests).

The first Step 41 run [38974751388](https://github.com/dojoplatform2026/dojo-admin/actions/runs/38974751388) failed at `flutter analyze` due to invalid const `GeoPoint` fixtures. The corrected code and tests passed the full workflow in [run 38975166322](https://github.com/dojoplatform2026/dojo-admin/actions/runs/38975166322) and [run 38975162943](https://github.com/dojoplatform2026/dojo-admin/actions/runs/38975162943), including Python reference-data tests, Flutter analysis/tests, Firestore Emulator REST smoke test, and Flutter Web release build.

These tests check input validation only. They do not establish official boundary provenance, contiguity, containment, adjacency, or geodesic correctness.

## Remaining gates

- Official LGD row-level reconciliation is pending.
- Authoritative contiguous polygon verification and parent/child geographic containment checks are pending.
- Integration/API review remains pending.
- Keep PR #6 open and do not import or activate reference records in production Firebase until these gates pass.
