# DOJO WALK — Backend and Popup Delivery Audit
## Step 40 • 2026-10-16

**Status:** Source audit completed for the Partner backend entrypoint; runtime/deployment unverified.  
**Repository checked:** `dojoplatform2026/dojo-partner`, branch `main`  
**Audit report branch:** `audit/zone-service-area-mapping-2026-10-16`

## 1. Backend files inspected

- `functions/index.js`
- `functions/package.json`
- root `firebase.json`

## 2. Findings

### Cloud Functions entrypoint

The inspected `functions/index.js` initializes Firebase Admin and exports only a callable function named `checkBackend`. It requires an authenticated request and returns a simple success message. The inspected file does not define:
- scheduled functions (`onSchedule`);
- booking or occurrence document triggers (`onDocumentCreated` / `onDocumentUpdated`);
- a scheduled popup/confirmation workflow;
- FCM push notification sending;
- occurrence creation or ID assignment;
- confirmation/reason validation or persistence;
- assignment-version checks or stale-response protection;
- Leave/suspension eligibility checks;
- reassignment escalation or attendance incident creation.

### Package / deployment configuration

- `functions/package.json` sets Node.js 22 and has a `lint` script running `node --check index.js`.
- Root `firebase.json` configures the Functions source as `functions`, runtime Node.js 22.
- These files show intended source configuration only; they do not prove that this exact source is deployed or that a deployed function is active.
- GitHub search in the inspected repositories did not return matching scheduled-trigger/FCM implementation results. Search absence is not proof that no implementation exists elsewhere.

## 3. Popup system status from available source

**Not implemented in the inspected Functions entrypoint.** There is no evidence in this entrypoint for pre-start or post-completion popup scheduling, correct-walker recipient filtering, response persistence, or duplicate delivery protection.

This is a source finding, not a live Firebase deployment claim. Notifications could theoretically be sent by another service or app path not found in this audit.

## 4. Required design before implementation

1. Approve the canonical occurrence contract from Step 38.
2. Select a trusted trigger strategy: schedule/time-based dispatch plus authoritative lifecycle events; do not rely on a client timer as the source of truth.
3. Before sending, re-read the occurrence and current walker assignment, assignment version, status, scheduled timestamps, live-walk state, and eligibility/Leave status.
4. Use an idempotency key based on occurrence ID, phase and assignment version to prevent duplicate sends.
5. Persist response state transactionally and reject stale assignment tokens.
6. Keep no response pending until an approved deadline/escalation policy applies.
7. Add observability and Admin audit records for send, failure, response, expiry and reassignment.
8. Confirm actual deployed functions and Firebase project before release.

## 5. Verification boundary

Documentation-only audit. No Functions, Flutter code, Rules, Firebase configuration or deployment was changed. No tests or deployment checks were run. The inspected source does not establish the state of deployed Cloud Functions or external notification services.