# DOJO WALK Firebase Rules Authority and Emulator Readiness — Step 9
Date: 2026-10-16
Branch: audit/zone-service-area-mapping-2026-10-16
Status: Repository-source audit only. No live Firebase access or emulator execution occurred.

## 1. Evidence checked
- dojo-admin/firebase.json contains Hosting configuration only.
- dojo-admin/.github/workflows/build_web.yml builds Flutter Web and deploys Hosting to dojo-platform-b68a3; it does not deploy Firestore or Storage Rules.
- dojo-admin/firestore.rules was not found at that exact path in the accessible repository ref.
- dojo-partner/firebase.json declares Functions source functions with runtime nodejs22; it does not declare Firestore/Storage Rules or Emulator configuration.
- dojo-partner/.github/workflows/deploy-functions.yml runs firebase deploy --only functions --project dojo-platform-b68a3. This deploys Functions only.
- dojo-partner/firestore.rules exists and contains booking access rules, but the repository does not prove these rules are deployed.
- dojo-walk-customer/firebase.json and firestore.rules were not found at those exact paths in the accessible repository ref.

## 2. Conclusion
The authoritative deployed Firestore Rules are not established from accessible source evidence. Do not deploy or replace Rules until the project owner confirms the production source of truth and deployed Rules are retrieved through authorized Firebase access.

Source-level risks in the inspected Partner Rules:
- Booking creation is denied.
- Customer cancellation updates are limited to specific existing statuses.
- Assigned-walker updates allow the status field but the inspected rule does not validate a defined transition graph.
These are source risks only, not proof of live production behavior.

## 3. Emulator-only preparation plan
1. Confirm the Firebase project and repository that owns production Rules.
2. Retrieve the deployed Rules through authorized Console/CLI access and compare them with repository copies.
3. Use a separate test project ID and Firebase Emulator; never point tests at production.
4. Use synthetic fixtures and Auth Emulator identities for customer, assigned walker, unassigned walker, scoped admin, and Super Admin.
5. Add test configuration only after the authoritative Rules source is confirmed.
6. Test booking creation and ownership; assigned-walker-only progress; invalid status jumps; cancellation policy; protected assignment/payment/audit fields; idempotent completion; partial-failure recovery; admin scope; legacy fixtures.
7. Save the exact command, versions, commit, test output and pass/fail results. Do not claim tests passed before running them.

## 4. Checklist
- [x] Reviewed accessible Firebase configs and deployment workflows.
- [x] Recorded exact Rules-path availability in accessible refs.
- [x] Prepared Emulator test plan.
- [ ] Confirm authoritative deployed Rules.
- [ ] Implement isolated Emulator configuration.
- [ ] Run and record tests.
- [ ] Separately review any proposed production deployment.

No app code, Rules, live documents, or deployments were changed.
