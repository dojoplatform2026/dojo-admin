# DOJO WALK Handover OTP Source Search — Step 51
Date: 2026-10-16
Scope: public/default-branch source inspection of `dojo-walk-customer`, `dojo-partner`, and `dojo-admin`.

## Confirmed findings
1. Partner `lib/screens/home/customer_otp_sheet.dart` reads the booking document directly and accepts the first non-empty value from `customerOtp`, `returnOtp`, or `otp`. It compares the entered four digits client-side.
2. Partner `lib/features/live_walk/screens/live_walk_screen.dart` invokes this sheet when the return location does not match.
3. GitHub code search across the inspected repositories found no Customer-side references to `customerOtp` or `returnOtp`. Customer OTP-related matches are for Firebase Phone Authentication and changing a phone number (six-digit login/phone verification), not handover OTP generation.
4. The Partner repository search found no `functions.httpsCallable` or `createHash` match. Its `functions/index.js` previously inspected contains only the `checkBackend` callable; no handover OTP generator/verifier was found in the inspected default-branch source.
5. Admin search found no `customerOtp` reference. Admin Live Operations reads a `currentBookingId` reference but is not evidence of OTP generation.
6. The Customer and Admin default-branch trees inspected do not contain a root `firestore.rules` file. Partner has `firestore.rules`, but its existence in the repository does not prove it is the active deployed ruleset.
7. The inspected Partner deployment workflow runs `firebase deploy --only functions`; Admin workflow deploys Hosting, and Customer workflow builds an Android APK. These workflows do not establish the currently deployed Firestore Rules or the origin of OTP fields.

## Security / integration risks
- The handover OTP producer remains unidentified in the inspected repository scope.
- The client reads the OTP value from the booking document and verifies it locally. If assigned walkers can read that field, it exposes the secret needed for verification.
- No server-side attempt limit, expiry, one-time consumption, or atomic completion verification was found in the inspected Partner path.
- Do not infer that the system has no OTP generator anywhere: a different branch, repository, Firebase Console configuration, deployed service, or manual/legacy data source may exist.

## Next required evidence
1. Inspect all relevant branches and repository history for OTP field creation.
2. Verify the actual Firebase project and deployed Firestore Rules / Functions using authorized Firebase access.
3. Implement server-side OTP creation and verification only after identifying the active schema and deployment ownership.
4. Test wrong OTP, expired OTP, repeated attempts, concurrent duplicate completion, and authorized-vs-unauthorized booking reads using Emulator or a controlled test project.

## Validation limits
Static repository/code-search audit only. No production Firebase reads/writes, deployed-rules checks, emulator tests, end-to-end tests, code changes, or deployments were performed as part of this audit.
