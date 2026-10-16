# DOJO WALK Location Master — Step 39

Date: 2026-10-17  
Branch: `restore/india-location-reference-data`  
Pull request: [#6 — Restore India location reference data](https://github.com/dojoplatform2026/dojo-admin/pull/6)

## Step 38 — City hierarchy guards: PASS

GitHub Actions run [38973476430](https://github.com/dojoplatform2026/dojo-admin/actions/runs/38973476430) completed successfully. Python reconciliation-tool tests, Flutter dependency resolution, static analysis, Flutter unit tests, Firestore Emulator persistence smoke test, and Flutter Web release build all passed.

Added coverage:
- City cannot be deactivated while an active Area exists.
- Saving a City is rejected when its selected State belongs to a different Country.

## Step 39 — State reparent guard: PASS

Code review found that `saveState` verified the target Country exists but did not prevent moving a saved State to another Country while child Cities still referenced that State. This could leave the hierarchy's stored country/state chain inconsistent.

Changes made:
- `saveState` now checks whether an existing State's Country is changing.
- If the Country changes, the save is rejected while any child City exists (active or inactive).
- Added a regression test asserting that the move is rejected and the original Country ID remains unchanged.

GitHub Actions run [38973920698](https://github.com/dojoplatform2026/dojo-admin/actions/runs/38973920698) completed successfully. Python reconciliation-tool tests, Flutter dependency resolution, static analysis, Flutter unit tests, Firestore Emulator persistence smoke test, and Flutter Web release build all passed.

## Remaining gates

- Official LGD record-level reconciliation is still pending.
- Verified contiguous service-area polygon boundaries and parent/child geographic validation are still pending.
- Keep PR #6 open and do not import or activate these reference records in production Firebase until the data, boundary, and integration/API gates pass.
