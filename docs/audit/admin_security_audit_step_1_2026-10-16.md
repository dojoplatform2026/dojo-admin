# DOJO WALK Admin Security Audit — Step 1

**Date:** 2026-10-16  
**Status:** Partial read-only repository audit; deployed security not verified  
**Branch:** `audit/zone-service-area-mapping-2026-10-16`

## Scope checked
Repositories checked: `dojoplatform2026/dojo-admin`, `dojoplatform2026/dojo-partner`, and `dojoplatform2026/dojo-walk-customer`.

## Findings

1. **Admin Firebase config:** `dojo-admin/firebase.json` contains Firebase Hosting configuration only (public directory `build/web` and SPA rewrite). It does not declare a Firestore rules file or Cloud Functions source in that file.
2. **Partner Firebase config:** `dojo-partner/firebase.json` declares a Cloud Functions source directory `functions` with Node.js 22 runtime. This proves a Functions deployment configuration exists in the repository, but does not by itself establish what is deployed or whether admin authorization is enforced.
3. **Rules file discovery:** GitHub code search did not locate a file named `firestore.rules` in the checked repositories. The same search did not locate one across the accessible `dojoplatform2026` organization. This is a repository-search result only; it does **not** prove that no rules exist elsewhere, in a differently named file, in Firebase Console, or in another deployment repository.
4. **Admin authorization in Flutter:** The previously inspected `auth_service.dart` and `auth_gate.dart` check the `admin_users/{uid}` document and `isActive == true`. The inspected code does not establish a complete role/action/scope permission matrix.
5. **Admin joining:** Search did not find an existing invitation/approval flow in the inspected Admin repository search results. This is not a complete proof that no related implementation exists; further source inspection is needed before changes.
6. **Backend/production state:** No Firebase Console access, deployed rules retrieval, live Firestore data access, Cloud Functions deployment inspection, emulator test, or production mutation was performed. Therefore the actual production security posture remains **unverified**.

## Required next checks

- Inspect the full `dojo-partner/functions` source tree and identify callable/HTTP functions that can change bookings, walker assignments, attendance, completion, or admin-related records.
- Locate the authoritative Firestore/Storage rules and Firebase project/deployment configuration used by CI and production. Do not infer deployed rules from absence in the Admin repo.
- Inspect rules and backend code for: authenticated identity, active-admin check, role allowlist, area scope, immutable UID/role/status fields for ordinary users, server-only privileged writes, audit log protection, and deny-by-default behavior.
- Reconcile rule paths and deployment project IDs with repository CI workflows before testing.
- Add emulator tests for unauthenticated access, inactive admin, pending invitation, role escalation, self-approval, cross-area access, unauthorized assignment, and revoked access.
- Do not deploy, modify production access, create admin accounts, or migrate records until source-of-truth rules are identified and tests pass.

## Decision

**Security audit is not signed off.** The available repository evidence is insufficient to claim that production rules are missing or insecure, and insufficient to claim that they are secure. Continue with read-only source/deployment discovery. No app code, Rules, Functions, admin account, Firestore data, or production setting was changed in this step.
