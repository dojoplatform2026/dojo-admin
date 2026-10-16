# DOJO WALK Location Master — Step 38 Status

Date: 2026-10-17  
Branch: `restore/india-location-reference-data`

## City hierarchy safety tests added

- [x] City cannot be deactivated while an active Area exists; City remains active.
- [x] Saving a City is rejected if the selected State belongs to a different Country.
- [x] Tests use `FakeFirebaseFirestore`; no production Firebase data is read or modified.
- [ ] GitHub Actions validation is pending. Do not mark Step 38 PASS until all CI checks succeed.

## Overall safety and data gates

- Step 36 hierarchy tests passed CI; report: https://github.com/dojoplatform2026/dojo-admin/actions/runs/38972812619
- Step 37 added Country/State hierarchy tests; CI run: https://github.com/dojoplatform2026/dojo-admin/actions/runs/38973236381 (final Flutter Web build still pending at last check).
- Official current LGD row-level reconciliation remains pending.
- Polygon validation remains basic planar geometry validation; authoritative source, containment, adjacency, and contiguous coverage are not yet proven.
- Keep PR #6 open; no production import, activation, or deployment.
