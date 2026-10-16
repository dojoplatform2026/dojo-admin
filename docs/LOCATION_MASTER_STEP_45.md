# DOJO WALK Location Master — Step 45 Report

Date: 2026-10-17  
Branch: `restore/india-location-reference-data`

## Result: SECURITY AUDIT — BLOCKER FOUND

Audited the repository tree and admin authorization path after Step 44.

### Findings

1. **Firestore rules file is absent from this branch tree.** The repository has `firebase.json` with a Firestore Emulator port, but no checked-in `firestore.rules` file was found. This means the repository does not currently provide a reviewable, version-controlled ruleset for the service-location collections.
2. `AuthGate` checks `admin_users/{uid}.isActive == true` on the client before rendering the AdminShell.
3. `AuthService.signInAdmin()` performs the same client-side active-admin check during sign-in.
4. These client checks are useful for UI access control but **are not a substitute for Firestore Security Rules**. Direct client/API requests must be restricted server-side.
5. The boundary service writes to `service_location_boundaries` and reads/writes service-location collections. Without reviewing the deployed ruleset and its source, this audit cannot confirm that only authorized admins can create drafts, verify boundaries, activate locations, or modify admin records.

## Decision

- Do not create or deploy a guessed ruleset in this step: the current project schema, all existing app access patterns, and any deployed rules are not fully established from this repository snapshot.
- Before production activation, obtain the current deployed Firestore rules (without changing them), add the reviewed canonical rules file to version control, then test authorization cases against the Emulator.
- Minimum tests needed: unauthenticated read/write denied; non-admin write denied; inactive admin write denied; active admin allowed only permitted operations; verified boundary edits/deletes denied; boundary verification fields protected; service activation requires verified boundaries; admin user records cannot be self-promoted by clients.

No production Firebase rules were read or changed. No production writes, imports, activations, or deployments were performed. Keep PR #6 open.
