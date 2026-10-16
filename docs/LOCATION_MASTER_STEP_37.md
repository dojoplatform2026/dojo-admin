# DOJO WALK Location Master — Step 37 Status

Date: 2026-10-17  
Branch: `restore/india-location-reference-data`

## Country and State hierarchy safety tests

- [x] Country deactivation is rejected while an active State exists; Country remains active.
- [x] State deactivation is rejected while an active City exists; State remains active.
- [x] State activation is rejected when its parent Country is inactive; State remains inactive.
- [x] Tests use `FakeFirebaseFirestore`; no production Firebase data is read or modified.
- [ ] CI validation is pending for the latest test commit. Do not mark Step 37 PASS until Python tests, Flutter analyze/tests, Firestore Emulator smoke test, and Flutter Web release build all succeed.

## Next remaining gates

- Add further wrong-parent and reparenting tests across all hierarchy levels.
- Official current LGD row-level reconciliation remains pending; do not change data based only on aggregate counts.
- Polygon checks remain basic planar validation; authoritative boundary source, containment, adjacency, and contiguous coverage are not proven.
- Keep PR #6 open. No production import, activation, or deployment.
