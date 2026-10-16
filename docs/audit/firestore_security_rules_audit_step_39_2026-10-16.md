# DOJO WALK — Firestore Security Rules Audit
## Step 39 • 2026-10-16

**Status:** Source-repository audit completed for files discoverable in the checked branches; deployed Rules remain unverified.  
**Scope:** Customer, Partner and Admin repositories, with focus on booking assignment, occurrence confirmations and live-walk data.  
**Branch for this report:** `audit/zone-service-area-mapping-2026-10-16`

## 1. Repository/configuration evidence

- `dojo-partner/main/firestore.rules` exists and was inspected.
- `dojo-partner/main/firebase.json` configures Functions source only; it does not declare a Firestore rules file in the inspected contents.
- `dojo-admin` audit branch root has `firebase.json` with Hosting configuration only and no root `firestore.rules` file in the inspected listing.
- `dojo-walk-customer/main` root listing did not show a root `firebase.json` or `firestore.rules` file.
- Admin `.firebaserc` identifies default project `dojo-platform-b68a3`; this alone does not prove which Rules are deployed.

**Important:** Missing from a repository root listing does not prove that no rules exist in Firebase Console or another deployment repository. Deployed rules were not queried or verified.

## 2. Partner source Rules findings

Inspected `dojo-partner/main/firestore.rules`:
- `/bookings/{bookingId}` permits reads to Admin, the booking customer, or the currently assigned walker.
- Booking creation is explicitly denied (`allow create: if false`) in this rules file. If this exact ruleset is deployed without another matching allow rule, customer booking creation will fail.
- Customer booking updates are limited to `cancelRequest` and `updatedAt` for eligible statuses.
- Assigned walkers can update a restricted field set including `status`, `walkSchedules`, `walkNotes`, `peeCount`, `poopCount`, `distance`, and `durationActual`. This does not yet express the proposed occurrence-specific confirmation contract or an assignment-version check.
- Admin can update/delete bookings under the `isAdmin()` helper.
- `/walk_requests/{requestId}` is explicitly denied for all reads/writes.
- `/audit_logs/{logId}` is read-only for Admin and client writes are denied.
- The inspected rules contain no explicit match for `/walks/{walkId}` or the proposed `/walk_occurrences/{occurrenceId}`; the final recursive default denies unmatched reads/writes unless another matching allow rule exists.
- Walker profile updates permit an `availability` field, and a generic private subcollection rule allows the walker to create/update `walkers/{uid}/availability/{documentId}`. This is not yet a validated authoritative Leave contract; client-writable availability must not by itself authorize or suppress trusted assignment prompts.

## 3. Cross-app gaps / risks

1. **No confirmed shared Rules deployment path:** Customer and Admin repo listings did not expose root Rules files; the Partner repo does, but its `firebase.json` does not declare `firestore.rules`.
2. **Booking create conflict:** Partner source Rules deny client booking creation. Verify actual deployed Rules and the intended trusted booking creation path before changing anything.
3. **Occurrence confirmation absent:** No explicit occurrence collection match, phase validation, response schema validation, or `assignmentVersion` check appears in the inspected Partner Rules.
4. **Live walk persistence risk:** The source Rules shown would default-deny `walks` writes unless another matching rule exists elsewhere in the deployed ruleset.
5. **Trust boundary:** Walker clients must not set authoritative assignment, approval, suspension, completion adjudication, or occurrence identity. Rules and trusted backend must validate these transitions.
6. **Admin authority:** `isAdmin()` in the inspected Partner rules requires an active `admin_users/{uid}` record with role `super_admin`; confirm this aligns with Admin app role policy and production rules.
7. **No deployment proof:** Source-control contents are not evidence of the currently deployed Firestore Rules.

## 4. Required verification before implementation

- Identify the single authoritative Rules source for each Firebase project and confirm project IDs for Customer, Partner and Admin.
- Read current deployed Rules in Firebase Console/CLI under authorized project access; compare them with version-controlled source.
- Decide whether booking creation is trusted-backend-only or client-created with strict validation.
- Add and test narrow occurrence-specific read/write permissions only after the canonical schema is approved.
- Keep assignment changes, occurrence creation, confirmation transitions and reassignment authority in trusted backend/Admin paths.
- Add emulator tests for owner vs assigned walker vs unrelated walker vs active super-admin; test denied spoofed walker IDs, stale assignment versions, invalid reason fields, live-walk popup attempts, and default-deny behavior.
- Never deploy proposed Rules solely from this audit report.

## 5. Verification boundary

This was a source/documentation audit only. No application code, Firestore Rules, Cloud Functions, Firebase Console configuration or deployed project was changed. No emulator tests were run. Deployed Rules and runtime access outcomes remain unverified.