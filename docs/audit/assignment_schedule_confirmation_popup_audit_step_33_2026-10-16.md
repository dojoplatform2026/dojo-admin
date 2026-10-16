# DOJO WALK Partner — Assignment/Schedule Confirmation Popup Audit (Step 33)

**Date:** 2026-10-16  
**Repository audited:** `dojoplatform2026/dojo-partner`  
**Source ref inspected:** `main` (search results point to source commit `cf7760bd393c3c0bbac8bfb7ed5689a203815f7d`)  
**Audit branch for this report:** `audit/zone-service-area-mapping-2026-10-16`

## Approved product requirements

1. Confirmation prompt timing is per assigned booking and its schedule; there is no single global time for all walkers.
2. Only the walker actually assigned to that booking (`walkerId`) and eligible for that assignment may receive its prompt.
3. Do not show a confirmation popup during a live walk.
4. If confirmation is needed, show it before the walk starts or after the walk completes, based on the booking/schedule workflow.
5. Do not send new-walk confirmation prompts to walkers on leave, inactive, unapproved, rejected, or suspended.
6. A prompt must let the walker confirm or choose a reason; selecting a reason requires a text explanation, including for “Other”.
7. A leave/suspension after a booking was already accepted must not silently discard that assignment; Admin must resolve/reassign/escalate it.
8. No app code, Firestore Rules, Cloud Functions, or deployment changes are authorized by this audit report alone.

## Findings from checked-in source

### 1. Working Schedule exists, but is not the confirmation workflow
- `lib/screens/home/working_schedule_screen.dart` reads and writes `walkers/{uid}.workingSchedule`, with per-day enabled flags and start/end times.
- The schedule screen saves the schedule using a root walker-document merge write.
- `firestore.rules` root walker update allowlist does **not** include `workingSchedule`. If these checked-in Rules are deployed as-is, this save may be denied. Actual deployed Rules have not been verified.
- This schedule is a recurring availability window; it does not itself implement the requested per-assignment popup.

### 2. Partner Home filters today's assigned bookings
- `lib/screens/home/partner_home_screen.dart` queries `bookings` where `walkerId == current UID`, filters the current date and active statuses (`assigned`, `accepted`, `picked_up`, `walking`), then sorts by `startTime`.
- This provides a candidate source for schedule-aware prompt targeting, but it is not proof that prompts are currently shown.
- Current date filtering uses device-local `DateTime.now()`; service timezone and schedule/occurrence field consistency need a separate cross-app contract check.

### 3. Live walk has its own screen and walk records
- Search found `lib/features/live_walk/screens/live_walk_screen.dart`; it writes a `walks/{walkId}` record with `startedAt` and `endedAt`.
- The popup logic must check the authoritative live-walk state and never interrupt that screen. This audit did not verify every navigation/state transition or run the app.

### 4. Eligibility and Leave/Suspended enforcement is incomplete at popup level
- `lib/screens/auth/account_check_screen.dart` permits entry to Partner Home only when `isApproved == true`, `isActive == true`, and `status == 'approved'`.
- `firestore.rules` allows Admin to set walker status including `suspended` and `inactive`.
- No existing schedule-aware confirmation popup or explicit leave/suspension suppression logic was found in the searches performed. This is a source search finding, not a proof about deployed app behavior.
- If leave is a distinct status/field, its canonical data contract still needs to be identified before coding.

### 5. Firestore security risk to resolve before implementation
- Checked-in `firestore.rules` allows walkers to create/update their own `walkers/{uid}/availability/{documentId}` and `notifications` subcollection records, but no validated schema for a per-booking confirmation popup was found.
- Root walker profile writes are field-allowlisted, and `workingSchedule` is absent from that allowlist.
- The checked-in booking rule denies client booking creation (`allow create: if false`); actual deployed Rules are unknown. Do not treat repository Rules as proof of deployed configuration.
- Client UI alone must not authorize assignment, eligibility, attendance decisions, or performance penalties. Any persistent confirmation record must be scoped to the assigned walker/booking and validated by trusted backend/Rules.

## Recommended implementation design (not implemented)

1. Resolve the canonical booking occurrence and schedule fields across Customer, Partner, Admin, and deployed Firebase.
2. Add a deterministic popup eligibility check: assigned `walkerId` matches current UID; walker is approved/active and not on leave/suspended; booking occurrence matches this walker's schedule; no live walk is in progress.
3. Trigger at a valid pre-start point or after a completed walk only. Do not use a global wall-clock time.
4. Deduplicate by booking occurrence so rebuilds/reopens do not repeatedly prompt after a response.
5. Show two primary paths: **Confirm** or **Reason**. Require a reason code and non-empty explanation for the reason path; include **Other** with text.
6. Preserve pending state if no response; do not interpret absence of a response as confirmation.
7. If the walker becomes unavailable after accepting an assignment, create an Admin-visible exception and explicitly reassign/escalate rather than silently dropping it.
8. Add tests for wrong walker, schedule mismatch, leave, inactive, suspended, pre-start, live walk, post-completion, duplicate prompt, missing reason text, and reassignment.

## Status

- **Source audit:** Partial, based on checked-in GitHub source and targeted searches.
- **Code changes:** None.
- **Firestore Rules/Cloud Functions changes:** None.
- **Tests:** Not run.
- **Deployment verification:** Not performed.
- **Ready to deploy:** No. Resolve canonical status/occurrence fields and deployed Rules first.
