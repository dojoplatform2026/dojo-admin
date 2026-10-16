# DOJO WALK — Popup Targeting Contract & Cross-App Gap Audit (Step 34)

**Date:** 2026-10-16  
**Repositories searched:** `dojo-walk-customer`, `dojo-partner`, `dojo-admin`  
**Report repository:** `dojoplatform2026/dojo-admin`  
**Branch:** `audit/zone-service-area-mapping-2026-10-16`

## Product rules carried forward

- No global popup time. Timing follows the assigned booking and that booking's schedule.
- Only the currently assigned and eligible walker receives the popup.
- Popup may appear before a walk starts or after it completes; never interrupt a live walk.
- Do not send new-walk prompts to a walker who is on leave, inactive, unapproved, rejected, or suspended.
- Confirmation response must be either Confirm or Reason. Reason requires a reason code and non-empty text; include Other.
- Missing response remains Pending; it is not success.
- If a walker becomes unavailable after accepting a booking, the booking must be explicitly resolved/reassigned by Admin rather than silently discarded.

## Source findings

### Customer booking creation
Search results from `lib/features/booking/screens/booking_confirmation_screen.dart` show booking creation under `bookings/{bookingId}` with fields including `bookingId`, `customerId`, `walkType`, `bookingPlan`, and `serviceType`. The customer booking UI also reads `bookingPlan`, `serviceType`, and `walkCount` in `my_bookings_screen.dart`.
The exact full shape of each schedule/occurrence and its stable ID was not established by this targeted search.

### Partner assignment lookup
`lib/screens/home/partner_home_screen.dart` queries `bookings` where `walkerId == current UID`, filters active booking statuses and orders candidate bookings by `startTime`. This is a useful targeting filter but is not itself a confirmation-popup implementation.
`lib/features/live_walk/screens/live_walk_screen.dart` writes a separate `walks` document with `walkerId`, `startedAt`, and `endedAt`, and updates a booking to `completed` in a completion path. The search did not establish a single stable occurrence identifier connecting every scheduled walk, booking, and walk record.

### Walker eligibility and Leave
Partner `account_check_screen.dart` requires `isApproved == true`, `isActive == true`, and `status == 'approved'` before entering Partner Home.
Admin model/helper results use `status`, `verificationStatus`, `isApproved`, and `isActive`; Admin service supports suspension. The targeted search did not establish a canonical separate Leave field/status or its date range. Leave must not be guessed or inferred from unrelated schedule fields.

### Security and runtime limits
Earlier Step 33 source audit found the checked-in Partner Rules do not include `workingSchedule` in the root walker-document update allowlist, and actual deployed Rules are unknown. A client-side popup is not a trusted authority for assignment, leave, attendance, or penalties. This Step 34 did not inspect deployed Firebase, run tests, or change code.

## Required canonical targeting contract before implementation

Every popup event must be associated with a stable scheduled-walk/occurrence identity, not merely the parent booking:
- `bookingId`
- stable `occurrenceId` (must be agreed across Customer, Partner, Admin, and backend)
- assigned `walkerId`
- scheduled start/end in the agreed service timezone
- current booking/occurrence state
- trusted live-walk state
- current walker eligibility and explicit Leave state
- popup phase: `pre_start` or `post_completion`
- idempotency key so the same occurrence/phase does not repeatedly prompt after response

Do not invent a missing `occurrenceId` from array position or time. First decide how the canonical ID is created and persisted across all apps.

## Implementation order

1. Inspect complete customer schedule serialization and partner booking parser.
2. Agree and document the stable occurrence ID and lifecycle fields.
3. Identify canonical Leave data and effective date range; ensure Admin and Partner use the same fields.
4. Verify deployed Firebase Rules/Functions and authoritative backend before making security claims.
5. Implement popup gating and persistent response records only after the contract is agreed.
6. Test wrong walker, schedule mismatch, leave, inactive, suspended, pre-start, live walk, post-completion, duplicate prompt, missing reason text, reassignment, and stale/offline app state.

## Status

- Targeted cross-app source search: completed; full-field verification remains incomplete.
- Report created; issue #5 comment added separately.
- Application code changes: none.
- Firestore Rules/Cloud Functions changes: none.
- Tests: not run.
- Deployed configuration: not verified.
- Ready to deploy: no.
