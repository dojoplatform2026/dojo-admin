# DOJO WALK Emulator Test Readiness Inventory — Step 10
Date: 2026-10-16
Branch: audit/zone-service-area-mapping-2026-10-16
Status: Readiness inventory only; no Emulator or application tests executed.

## 1. Files checked
- dojo-partner/functions/package.json
- dojo-partner/functions/index.js
- dojo-partner/firebase.json
- dojo-partner/firestore.rules
- dojo-admin/firebase.json, .firebaserc, pubspec.yaml, .github/workflows/build_web.yml
- dojo-walk-customer/pubspec.yaml
- dojo-partner/pubspec.yaml and .github/workflows/deploy-functions.yml

## 2. Current test readiness
- Partner Functions package only defines `lint: node --check index.js`; dependencies shown are firebase-admin and firebase-functions.
- Partner Functions source exports only an authenticated `checkBackend` callable function in the inspected file. It does not implement booking lifecycle operations there.
- The three Flutter pubspec files include Flutter's unit-test framework, but this alone does not demonstrate Firebase Emulator or Firestore Rules tests.
- The inspected Partner `firebase.json` declares Functions only; it does not declare Firestore Rules or Emulator ports/config.
- Admin `.firebaserc` defaults to `dojo-platform-b68a3`. This makes explicit project safeguards especially important before any local CLI command.
- The production Rules source of truth remains unconfirmed (Step 9). Therefore, do not create or test against a guessed Rules copy as if it were authoritative.

## 3. Decision for Step 10
Do not add Emulator configuration or test dependencies yet. First confirm the deployed Rules and the repository that owns them. Adding a speculative Rules test harness now could produce green tests against the wrong file and create false confidence.

## 4. Proposed next safe implementation after source confirmation
1. Create a dedicated test directory and Emulator configuration on the audit branch.
2. Pin test dependencies, including a compatible Firebase Rules testing library if appropriate.
3. Add explicit test-project safeguards so commands fail if the target project is `dojo-platform-b68a3`.
4. Load the confirmed Rules file into the Firestore Emulator with synthetic fixtures only.
5. Test authenticated/unauthenticated access, customer booking create and ownership, assigned/unassigned walker actions, invalid status transitions, cancellation policy, protected fields, admin scope, and legacy fixtures.
6. Run the suite locally/CI against the Emulator, then record exact command, dependency versions, commit SHA, test totals and output.
7. Keep any eventual production Rules deployment as a separate, reviewed, explicitly approved action.

## 5. Checklist
- [x] Inspected available package/config/workflow files.
- [x] Identified that existing Functions lint is not a Rules test suite.
- [x] Recorded why a guessed test harness would be unsafe.
- [ ] Confirm authoritative deployed Rules and source owner.
- [ ] Add isolated Emulator config and tests.
- [ ] Execute tests and attach evidence.
- [ ] Review any production deployment separately.

No source code, Rules, configuration, secrets, live data, or deployment was changed.
