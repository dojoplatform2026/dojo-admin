# DOJO WALK — Authoritative Firebase Rules and Backend Source Audit
## Step 27 — Repository deployment configuration and backend entry-point check
Date: 2026-10-16
Type: Source/configuration audit only

## Executive result
The repository sources do not yet establish one authoritative, shared deployment setup for Firestore Rules and booking backend operations. The Partner repository contains a Firebase Functions folder, but the inspected `functions/index.js` exports only an authenticated `checkBackend` health-check callable. No booking acceptance, booking creation, occurrence transition, or walk-completion callable was found in that entry-point file. This is a source inspection, not proof of what is currently deployed in Firebase.

## Findings by repository
### A. `dojoplatform2026/dojo-admin` (`main`)
- `.firebaserc` names default Firebase project `dojo-platform-b68a3`.
- `firebase.json` configures Hosting only (`public: build/web`, SPA rewrite to `/index.html`). It does not declare a Firestore Rules file or Functions source.
- Root listing inspected did not show a `firestore.rules` file or `functions/` directory.
- Therefore this repository's checked-in Firebase configuration does not identify the authoritative Firestore Rules/backend deployment source.

### B. `dojoplatform2026/dojo-partner` (`main`)
- Root contains `firebase.json`, `firestore.rules`, and `functions/`.
- `firebase.json` declares Functions source `functions` with runtime `nodejs22`; it does not declare a `firestore.rules` path.
- No root `.firebaserc` was found at the inspected path, so this repository does not explicitly pin its default project in that file.
- `functions/package.json` uses Node 22 and includes `firebase-admin` and `firebase-functions`.
- `functions/index.js` initializes Firebase Admin and exports only `checkBackend`, which requires authentication and returns a connectivity message. The inspected file contains no booking or occurrence lifecycle operations.
- `firestore.rules` is present as source, but without a declared Rules entry in this `firebase.json`, the inspected configuration alone does not show that this Rules file is deployed by this repository's Firebase CLI configuration.

### C. `dojoplatform2026/dojo-walk-customer` (`main`)
- The inspected repository root listing did not show `firebase.json`, `.firebaserc`, or `firestore.rules`.
- Customer `pubspec.yaml` contains Firebase client SDK dependencies. Its booking confirmation source writes `bookings/{bookingId}` directly from the client.
- Absence from this inspected root listing does not prove no separate deployment repository or external configuration exists; it means this repository path does not identify the authoritative Rules/backend setup.

## Confirmed cross-repository risk
1. Customer client writes booking documents directly.
2. Partner Rules source denies booking creation under `/bookings/{bookingId}`.
3. Partner Functions source currently exposes only a health-check callable in the inspected entry point.
4. Admin repository's Firebase config only declares Hosting.
5. No repository inspected proves which Rules version or Functions version is deployed to project `dojo-platform-b68a3`.

## Required next actions (do not deploy yet)
1. In Firebase Console / project settings, confirm the active project ID and the deployed Firestore Rules version/last deployment details.
2. Identify the single source of truth for `firestore.rules` and set the explicit Rules path in the approved deployment configuration.
3. Confirm whether `dojo-partner/functions` is the intended shared backend. If so, add booking operations there only after contract approval and tests; otherwise create/identify a dedicated backend repository.
4. Pin the intended Firebase project for the chosen deployment repository using the correct project configuration, after verifying environment separation.
5. Add emulator tests for booking create, atomic acceptance, occurrence transitions, GPS access, and unauthorized updates.
6. Deploy only after a reviewed change and explicit release approval. Do not infer deployed state from repository source alone.

## Decision boundary
This step confirms repository configuration and the checked-in Functions entry point only. It does not query Firebase Console, deployed Rules, deployed Functions, production data, or runtime logs. No code, Rules, Firebase settings, data, or deployment was changed. No tests were run.
