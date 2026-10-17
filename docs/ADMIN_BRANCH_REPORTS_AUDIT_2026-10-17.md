# DOJO WALK Admin — Cross-Branch Reports & Status Audit

Audit date: 2026-10-17  
Repository: `dojoplatform2026/DOJO-WALK-Admin`  
Audit branch: `step-119-boundary-geometry`

## Executive result

The Admin repository has four branches. Reports and status are **not consolidated**. Do not merge a branch solely to bring its reports into `main`; first reconcile code, historical reports and the master tracker. No merge, deployment or production data mutation was performed during this audit.

## Branch inventory

| Branch | Latest observed commit | Files in branch tree | Report/status inventory | Current meaning |
|---|---|---:|---|---|
| `main` | `a03f0cbb41b49e23e65ab81fa9aa3f5deafde474` | 43 | `docs/LOCATION_MASTER_STATUS.md` and `docs/LOCATION_MASTER_STEP_45.md` | Main's location status is stale: it says the three India reference Dart files are absent and the restore/build checks are pending. |
| `restore/india-location-reference-data` | `1644667cdfae7b3987f4bd2acab951a3ed27bc62` | 131 | Location Master steps 36–49 and 63–118, Company Flow Master Status, Company Flow steps 48–49 and supporting audits | Most extensive location history. Its latest checkpoint is Step 118; it predates the latest Step 119 branch work. Contains India reference data files. |
| `audit/zone-service-area-mapping-2026-10-16` | `83d7bad6066eb67fa6163b75b096ee645b5bbc61` | 90 | 51 files under `docs/audit/`, numbered audit reports covering Steps 1–44 with gaps, plus Steps 51–52; separate architecture/ID audit | Cross-app company flow, booking/status, security, walker availability and zone/service-area audit. Static-audit evidence only for many items; it is not the Service Location Step 119 branch. |
| `step-119-boundary-geometry` | `de66da2bf4f121e0f843d20d6beef92052bde560` | 58 | Current `docs/ADMIN_COMPLETION_AUDIT_2026-10-17.md`, `docs/LOCATION_MASTER_STATUS.md`, Step 45 file and recent code/test changes | Current Service Location review branch. Contains the restored reference files and current audit; still not production-ready. |

## Pull requests

- [PR #7 — Step 119 service-location boundary geometry validation](https://github.com/dojoplatform2026/DOJO-WALK-Admin/pull/7): open, Draft, not merged. Its branch contains the latest Service Location code and consolidated completion audit.
- [PR #6 — Restore India location reference data](https://github.com/dojoplatform2026/DOJO-WALK-Admin/pull/6): open and reported non-mergeable. The exact reference files and integrity test were copied to the PR #7 review branch. Do not merge PR #6 separately until its duplicate/conflicting file changes are reconciled.
- No pull request was found for `audit/zone-service-area-mapping-2026-10-16`. Its reports are therefore not included in `main` or PR #7 automatically.

## Master tracker mismatch

GitHub Issue #1, [DOJO WALK Company Project — Master Tracker & Status](https://github.com/dojoplatform2026/DOJO-WALK-Admin/issues/1), still says the overall project is at Step 1 and lists Steps 1–10 as unchecked. Its text says automated tests have not yet run for that company-flow project and production import is not cleared. Issue #2 likewise says the cross-app ID audit is in progress. Those tracker statements have not been reconciled with the later location Step 118/119 work. They are different workstreams, so they must not be marked complete just because the Location Master tests pass.

Issues #3–#5 remain open design/audit work:
- #3 emergency walker reassignment and safe dog custody;
- #4 unified Walk Now/Temporary/Regular booking operations;
- #5 Super Admin-controlled admin joining and role permissions.

The Company Flow master status on `restore/india-location-reference-data` lists Steps 47–52 as audit/design or pending work; its Step 49 compatibility audit is pending, and it explicitly says production rules deployment state is unknown. This is consistent with the open company-flow issues and is not covered by the Service Location geometry test suite.

## Report numbering gaps observed

- `audit/zone-service-area-mapping-2026-10-16`: numbered reports exist for Steps 1–44 except Step 4 and Step 30, plus Steps 51 and 52. Separate report files for Steps 45–50 were not present in that branch tree. These gaps may mean reports are absent or recorded under another filename; they are not proof that the work itself was never done.
- `restore/india-location-reference-data`: separate report files cover Steps 36–49, 63–76 and 79–118. Steps 50–62 and 77–78 have no matching numbered report files in this branch tree; older steps 1–35 are also not represented there. Treat this as a documentation/history gap, not a claim that no work occurred.
- `main`: only Step 45 has a separate numbered Location Master report. The main status document is behind the current review branch.

## Conflicts / important distinctions

1. The Company Flow audit branch is a cross-app audit/design workstream. It records findings such as inconsistent booking statuses, no confirmed Admin booking-assignment action in the inspected paths, and authorization gaps that need trusted backend/Rules verification. These are not resolved by the location geometry changes.
2. The Location Master branch is a data/boundary/activation workstream. It has focused geometry and reference-data tests, but that does not verify the full cross-app booking, role permissions, walker custody or production Rules lifecycle.
3. The reference CSV snapshot was audited as dated 2024-10-07. Internal counts/checks do not prove it is the latest official LGD release; authoritative source reconciliation remains pending.
4. Current Firestore hierarchy models City/District together, while the import source distinguishes State, District, City and Area/Sub-district. A safe import must remain blocked until the schema and dependent apps are reconciled.
5. `main` still needs the review branch changes and the status correction through an approved PR. No branch should be merged merely to combine reports.

## Recommended order to finish Admin

1. Keep PR #7 as the primary Service Location integration/review branch and finish its latest no-deploy full-project analysis, tests and Web build checks.
2. Resolve the District-versus-City schema and safe CSV import design across Admin, Firebase Rules/callables and dependent apps. Do not enable writes based only on name matching.
3. Review `audit/zone-service-area-mapping-2026-10-16` report-by-report and convert each actionable finding into a tracked issue/acceptance test; do not bulk-merge its 90-file branch.
4. Update Issue #1 and Company Flow Master Status with links to the newer location work while keeping company-flow steps genuinely pending until separately evidenced.
5. Reconcile PR #6 with PR #7, refresh the main-branch status after review, then request explicit merge approval. Production import, activation and deployment remain separate approval gates.

## Safety status

No PR was merged, no production data was imported, no service location was activated, and no Firebase Functions/Rules/Hosting deployment was triggered by this audit.
