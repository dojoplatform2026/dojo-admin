# DOJO WALK Phone Authentication App Verification Audit — Step 52
Date: 2026-10-16
Scope: Static GitHub source audit only. No code changes, Firebase Console changes, builds, device tests, or deployments performed.

## User-reported symptom
Both DOJO WALK Customer and DOJO WALK Partner APKs downloaded from GitHub Actions fail real phone OTP with:
"This request is missing a valid app identifier, meaning that Play Integrity checks, and reCAPTCHA checks were unsuccessful."

## Confirmed repository findings

### Customer app
- Package/applicationId: `com.dojo.dojo_walk`
- File: `android/app/build.gradle.kts`
- Release signing config explicitly uses `signingConfigs.getByName("debug")`.
- GitHub Actions workflow: `.github/workflows/build.yml`; builds release APK on `ubuntu-latest` and uploads it as an artifact.
- `android/app/google-services.json` contains a Firebase client entry for `com.dojo.dojo_walk`, matching the applicationId.
- Phone login uses Firebase `verifyPhoneNumber`; code does not indicate a custom OTP sender.

### Partner app
- Package/applicationId: `com.example.dojo_partner`
- File: `android/app/build.gradle.kts`
- Release signing config explicitly uses `signingConfigs.getByName("debug")`.
- GitHub Actions workflow: `.github/workflows/flutter.yml`; builds release APK on `ubuntu-latest` and uploads it as an artifact.
- `android/app/google-services.json` contains a Firebase client entry for `com.example.dojo_partner`, matching the applicationId.
- Partner `pubspec.yaml` uses Firebase Auth `^6.1.0`; Customer uses `firebase_auth: ^5.6.2`.
- Partner login uses Firebase Phone Authentication and surfaces Firebase errors.

## Main risk / likely cause
Both Release APKs are configured to use the Android debug signing configuration. GitHub-hosted runners are fresh ephemeral machines, so the generated debug keystore may change between workflow runs. The certificate fingerprint of the downloaded APK may therefore not match the SHA-1/SHA-256 fingerprints registered for the corresponding Android app in Firebase. This is a strong, actionable suspect given the reported Play Integrity/reCAPTCHA app-verification error, but the actual Firebase Console fingerprints and APK certificate have not been inspected, so it is not yet proven as the only cause.

The Firebase configuration files' package names match each app's current applicationId. This does not by itself prove that the correct signing fingerprints are registered.

## Recommended next actions (not executed)
1. Prefer configuring a stable release keystore for both apps via GitHub Actions secrets, without committing the keystore or passwords to Git.
2. Generate and record the signing certificate SHA-1 and SHA-256 for each release APK.
3. Add both fingerprints to the matching Android app entries in Firebase Project Settings.
4. Confirm Firebase Authentication Phone provider and SMS region policy allow India (+91); the user says the console is correct, but this was not independently verified.
5. Rebuild both APKs, install those exact artifacts, and test one real number after avoiding repeated requests that could trigger throttling.
6. If the error remains, collect Android Logcat/FirebaseAuth error details and inspect API-key restrictions, especially the reCAPTCHA fallback allowlist for `dojo-platform-b68a3.firebaseapp.com`.

## Official reference
Firebase Android phone authentication documentation explains that Play Integrity requires SHA-256 and reCAPTCHA fallback requires SHA-1 and suitable API-key access:
https://firebase.google.com/docs/auth/android/phone-auth

## Audit status
- Static source inspection: COMPLETE for listed files.
- Firebase Console verification: NOT DONE.
- Actual APK certificate extraction: NOT DONE.
- Runtime real-SMS test: NOT DONE.
- Fix/build/deployment: NOT DONE.
- Overall: LIKELY CAUSE IDENTIFIED; needs fingerprint verification before making changes.
