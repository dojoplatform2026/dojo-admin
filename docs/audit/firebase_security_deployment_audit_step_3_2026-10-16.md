# DOJO WALK Firebase Security & Deployment Audit — Step 3
Date: 2026-10-16
Branch: audit/zone-service-area-mapping-2026-10-16
Status: Repository configuration audit completed; deployed Firebase state is not directly accessible from this audit.

## Executive summary
The source repositories identify Firebase project ID dojo-platform-b68a3 and contain separate workflows for Admin Hosting and Partner Functions. The inspected deployment configuration does not declare Firestore Rules or Storage Rules deployment. A Firestore rules file exists in the Partner repository, but its presence in source does not prove that it is deployed to the shared project.

## Confirmed repository evidence
1. Admin .firebaserc maps default to dojo-platform-b68a3.
2. Admin firebase.json declares Hosting only (build/web and SPA rewrite); it does not declare firestore.rules or storage rules.
3. Admin .github/workflows/build_web.yml builds Flutter Web and deploys Hosting to project dojo-platform-b68a3 on pushes to main or manual workflow dispatch. It does not run a Firestore/Storage Rules deploy.
4. Partner firebase.json declares Functions source only (functions, Node.js 22); it does not declare Firestore/Storage Rules deployment.
5. Partner .github/workflows/deploy-functions.yml deploys only Firebase Functions to dojo-platform-b68a3 when function files/config/workflow change on main or manually.
6. Partner firestore.rules exists in the main branch. The inspected rules define isAdmin as an active admin_users/{uid} record with role super_admin; several admin collection actions depend on that helper. The rules also explicitly deny booking creation and deny access to walk_requests. This file may be an incomplete/legacy or non-authoritative ruleset; do not deploy it without full compatibility review.
7. Partner Functions index.js currently exports only checkBackend, which requires authentication. No invitation, approval, expiry, reminder, notification or admin-scope callable/scheduled workflow was found in that file.
8. Searches of the accessible repositories did not locate Storage Rules or a confirmed emulator rules test configuration. Search limitations and inaccessible repositories mean this is not proof none exists elsewhere.
9. The Admin Hosting workflow references a GitHub secret named FIREBASE_SERVICE_ACCOUNT_DOJO_PLATFORM_B68A3. Secret contents were not read and must not be exposed. This audit did not access Firebase Console, read deployed rules, inspect deployed Functions, or run a production command.

## Security implications (source/configuration only)
- The current repository workflows do not provide an auditable Rules deployment path for Firestore/Storage.
- The Partner rules file is not referenced by the inspected Partner firebase.json, so its deployment status cannot be inferred from that repo workflow.
- Admin client code's isActive check and hidden menu items are not a substitute for server-side role, permission and location-scope enforcement.
- The existing rules contain booking-create denial; if these were authoritative deployed rules, customer booking creation would be blocked. Deployed state is unverified, so this is a source-level risk, not a claim about production behavior.
- Do not make the Partner rules file authoritative or deploy it as-is. First reconcile Customer, Partner and Admin read/write needs and existing production data, then test in Firebase Emulator.

## Required safe next steps
1. Identify the authoritative production Firestore Rules and Storage Rules source/project and inspect deployed configuration through authorized Firebase Console/CLI access.
2. Reconcile all three apps' data contracts (bookings, users, walkers, admin_users, service_locations, notifications, audit_logs) and current admin documents.
3. Create a reviewed shared Rules source and explicit firebase.json declarations only after compatibility review.
4. Add Firebase Emulator tests for customer booking creation, customer/walker data isolation, admin_users self-escalation prevention, role/permission/scope enforcement, Service Location parent-child checks, invitation claim/expiry/replay, and audit-log write denial from clients.
5. Implement invitation backend (trusted callables + scheduled expiry/reminders) and notification delivery with deduplication/idempotency.
6. Run tests and review diffs on the audit branch; do not deploy production rules/functions until explicit approval and successful tests.

## Status
- Repository deployment-config review: completed.
- Deployed Rules/Functions verification: not completed (no Firebase Console/CLI production access used).
- Invitation UI/backend/reminders: not implemented.
- Production changes: none.
