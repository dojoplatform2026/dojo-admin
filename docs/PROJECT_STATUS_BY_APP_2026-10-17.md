# DOJO WALK — Status by App
Last updated: 2026-10-17
Branch for this status record: `step-119-boundary-geometry`

> This document separates the latest known project status by Admin, Customer and Partner. It is a status summary, not a claim that every repository has been freshly built or tested today. Use linked CI runs for test evidence. No PR merge, production import, activation, or deployment is authorized by this document.

## 1. Admin app
Repository: [DOJO-WALK-Admin](https://github.com/dojoplatform2026/DOJO-WALK-Admin)
Review branch: `step-119-boundary-geometry`
PR: [#7 — draft/open/unmerged](https://github.com/dojoplatform2026/DOJO-WALK-Admin/pull/7)

### Done on review branch
- Service Location screen and hierarchy controls are present.
- CSV upload/paste parser and preview validate required State, District, City and Area columns, malformed quoting, duplicate headers/combinations and row widths.
- India reference Dart files are restored on the review branch: states (36), districts (785), sub-districts (7,151), with integrity tests. These counts are previously audited local-file counts, not confirmation of the latest official LGD release.
- Geometry helper/tests and boundary-map improvements exist on the review branch.
- Latest recorded full-project checks passed at code commit `2366912dde77e98b94abad75f134f1c5fda604ba`: `flutter analyze`, `flutter test`, and no-deploy `flutter build web --release`. [CI run](https://github.com/dojoplatform2026/DOJO-WALK-Admin/actions/runs/39049905720). Recheck CI against the current branch head before release.

### Remaining / blocked
- LGD staging parser and automated tests are **designed but not implemented/run**; see [staging design](LOCATION_LGD_STAGING_DESIGN.md).
- Official LGD release freshness/reconciliation remains pending; available sub-district snapshot is dated 2024-10-07.
- Current schema has no separate District entity or explicit LGD source-code fields. Do not silently map District to an active City or Sub-District to an active service Area.
- CSV import remains preview-only; safe transactional import, parent mapping, duplicate handling, rollback and emulator tests are pending.
- Real UP/NCR GIS boundary accuracy and City–Area containment need authoritative-data review. Synthetic tests alone do not establish real-world boundary correctness.
- Trusted backend activation integration, deployment order and production safeguards need confirmation.
- PR #6 remains open/non-mergeable; its reference data has been copied into PR #7's review branch. Do not merge PR #6 separately without reconciling overlapping files.

## 2. Customer app
Repository: [dojo-walk-customer](https://github.com/dojoplatform2026/dojo-walk-customer)

### Existing behavior / reviewed compatibility
- Customer saved addresses are stored under `users/{uid}/addresses`.
- Address model uses free-text area/city/pincode and optional latitude/longitude.
- The reviewed Customer address code does not depend on the new Service Location IDs.
- This means Service Location setup can continue separately, but address migration is **not done** and must not be silently applied.

### Remaining / needs fresh verification
- Recheck the latest Customer branch/head, current CI, and app build before marking the app fully complete; this summary does not claim a fresh Customer build/test run.
- Decide and implement any future address-to-Service-Location linkage only after the City/District/Area schema is approved.
- Add compatibility tests if Customer begins storing service location IDs; preserve existing free-text addresses during any migration.
- Confirm end-to-end booking behavior against current Firestore schema and Admin/Firebase changes before release.

## 3. Partner app
Repository: [dojo-partner](https://github.com/dojoplatform2026/dojo-partner)

### Existing behavior / reviewed compatibility
- Partner `WorkLocationScreen` still reads active legacy `zones`.
- It saves state/city/area and zone IDs in the walker profile.
- It does **not yet consume** the new `service_cities` / `service_areas` hierarchy.
- Latest product direction recorded earlier: document-photo onboarding rather than OTP verification; existing phone/OTP flow was still present at the time of the prior audit. Do not mark this flow migrated without a fresh code check.

### Remaining / needs fresh verification
- Plan and implement a controlled migration from legacy `zones` to approved Service Location IDs.
- Keep the old path compatible until the new Admin/Firebase schema and data are ready; do not remove legacy reads prematurely.
- Recheck current branch/head, CI, app build, onboarding and work-zone selection; no fresh Partner test/build is claimed here.
- Test walker eligibility and booking assignment across active/inactive service locations before rollout.

## 4. Shared Firebase / release dependency
Repository: [DOJO-WALK-Firebase](https://github.com/dojoplatform2026/DOJO-WALK-Firebase)
PR: [#1 — draft/open/unmerged](https://github.com/dojoplatform2026/DOJO-WALK-Firebase/pull/1)
Branch: `feature/trusted-location-activation`

- Functions and Firestore Rules need coordinated review and deployment sequencing with Admin before Admin production use.
- Rules use explicit collection/field allowlists; schema additions such as separate District parents or LGD source codes require an approved cross-repository design.
- Do not deploy stricter Rules before the required trusted callables are deployed and verified.
- Production environment required-reviewer settings have not been independently verified.
- No Functions/Rules/Hosting deployment, production import, service-location activation, or PR merge has been performed or authorized.

## 5. Recommended order
1. Admin: implement read-only LGD staging parser + automated tests; no Firebase writes.
2. Reconcile the staging output against a fresh official LGD export and record source dates/hashes.
3. Approve one shared State → District → City → Area model across Admin, Firebase and dependent apps.
4. Verify authoritative City/Area polygons and trusted activation validation.
5. Implement transactional CSV import and emulator/rollback tests.
6. Migrate Partner zone selection with a compatibility plan; decide Customer address linkage separately.
7. Verify CI and production safeguards, then request explicit approval before any merge/deploy/import/activation.

## Status language
- **Done** means code/data is present in the named branch or a linked run demonstrates the check.
- **Pending** means work is not complete.
- **Not verified** means there is no current evidence sufficient to claim it passed.
- Do not infer completion percentages until the scope and acceptance criteria are fixed.
