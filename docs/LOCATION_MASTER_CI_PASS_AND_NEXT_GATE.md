# DOJO WALK Location Master — CI Pass and Next Gate

Date: 2026-10-17  
Branch: `restore/india-location-reference-data`  
Pull request: [#6 — Restore India location reference data](https://github.com/dojoplatform2026/dojo-admin/pull/6)

## Step 23 — Firestore Emulator smoke test and Flutter Web CI

**Result: PASS** for commit `5fd05c561fe1ba18bc7442c17c86ee81360f6f81`.

Verified GitHub Actions run: [38958559004](https://github.com/dojoplatform2026/dojo-admin/actions/runs/38958559004)  
A second run for the same commit also passed: [38958552086](https://github.com/dojoplatform2026/dojo-admin/actions/runs/38958552086).

The workflow's `validate` job completed with `success`. The workflow includes Flutter dependency resolution, static analysis, unit tests, Firestore Emulator REST smoke test, and Flutter Web release build.

### What this pass proves

- CI completed successfully on the recorded commit.
- The emulator-only REST smoke test can save, reload, and clear LGD-code fields for test State, District, and Sub-district documents.
- The workflow does not deploy the app or modify production Firebase.

### Important limitation

The REST smoke test checks Firestore Emulator persistence/field clearing; it is **not** a full end-to-end test of the Flutter service classes against Firebase. Keep this distinction in reports.

## Step 24 — Official LGD reconciliation (NEXT; not yet passed)

The restored local reference snapshot has these internally checked counts:

| Dataset | Local snapshot count |
|---|---:|
| States / Union Territories | 36 |
| Districts | 785 |
| Sub-districts | 7,151 |

These counts and parent links are internal consistency checks only; they do not establish current official completeness.

The official LGD portal's state-wise administrative-unit report surfaced in the web review is dated 29 June 2025 and reports **777 districts** and **7,244 sub-districts**. It is older than the catalog updates previously identified for October 2026 and is not a suitable replacement for the latest downloadable export. The difference is a **reconciliation flag**, not proof that either dataset is correct or incorrect. Source: [official LGD state-wise report](https://lgdirectory.gov.in/demo/reportonStatewiseEntityDetails.do).

Required before approving the reference data:
1. Obtain the latest official LGD export from the Government of India LGD portal / official OGD catalogue. Use the portal's normal download flow; do not bypass CAPTCHA.
2. Record export date, source page, file name, and SHA-256 checksum.
3. Compare state/UT, district, and sub-district codes and parent relationships against the restored Dart files; report additions, removals, renames, duplicate codes, and parent changes.
4. Independently review NCR records after the official reconciliation.
5. Keep production import and activation blocked until data and map boundaries are verified.

## Step 25 — Geographic boundary verification (BLOCKED / pending)

- Verify each service area has a valid, contiguous polygon boundary; do not substitute a radius approximation.
- Check parent/child containment and map/API behavior in the admin UI.
- No production import or service activation is authorized by the CI pass.

## Merge gate

PR #6 remains open and unmerged. Do **not** merge solely because CI passed. Official LGD reconciliation, boundary verification, and the remaining integration/API review must be completed first.
