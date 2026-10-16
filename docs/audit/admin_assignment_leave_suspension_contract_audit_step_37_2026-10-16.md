# DOJO WALK Admin Assignment / Leave / Suspension Contract Audit — Step 37

**Date:** 2026-10-16  
**Repository:** `dojoplatform2026/dojo-admin`  
**Source ref:** `main` (checked-in files fetched through GitHub API)  
**Report repository/branch:** `dojoplatform2026/dojo-admin` / `audit/zone-service-area-mapping-2026-10-16`

## Files inspected

- `lib/features/walkers/services/walker_admin_service.dart`
- `lib/features/walkers/models/walker_admin_model.dart`
- `lib/features/walkers/utils/walker_admin_helpers.dart`
- `lib/screens/bookings/bookings_screen.dart`

## Confirmed Admin walker-state contract

Admin's `WalkerAdminService` reads `walkers/{walkerId}`, and its administrative action enum currently includes:
- `approve`
- `reject`
- `suspend`
- `reactivate`
- `requestCorrection`

The service writes walker state and an `audit_logs` record in the same Firestore transaction. It requires an active `super_admin` account for these actions. Walker state uses fields including `status`, `verificationStatus`, `isApproved`, `isActive`, `decisionBy`, `decisionAt`, and `decisionReason`.

The eligibility helper returns eligible only when status is `approved`, verificationStatus is `verified`, `isApproved == true`, and `isActive == true`. Unavailable account detection includes rejected, suspended, inactive, left, unverified, unapproved, or inactive accounts.

## Assignment and Leave findings

- The service exposes read streams for all bookings and bookings filtered by `walkerId`; the inspected service has no dedicated transactional booking reassignment action in the reviewed section.
- The checked-in Admin walker model has no canonical Leave dates/range or leave approval fields.
- Searches across the checked-in Admin source for `leave` and `reassign walker booking` did not identify a dedicated Leave workflow or an explicit reassignment implementation. This is limited to the searched source/ref; it does not prove that no such feature exists in another branch or backend.
- Booking management reads the `bookings` collection and displays `walkerId` / `walkerName` as assignment indicators, but the inspected screen is a list/monitoring screen, not an authoritative reassignment workflow.
- Admin booking screen status labels include legacy display values such as `Walker Assigned`, `Walker Accepted`, and `Walk In Progress`; exact canonical enum compatibility with Customer/Partner is not established.

## Required policy / schema decisions

1. Do not treat `status == suspended` or `isActive == false` as a substitute for a Leave schedule. Leave is time-bounded operational availability and needs an explicit, documented source of truth.
2. Define Leave contract before coding: requested/approved state, start/end instants or service dates, timezone (recommend Asia/Kolkata for India service), actor, reason, timestamps, and effect on new vs already accepted assignments.
3. Define a trusted assignment/reassignment transaction: check booking occurrence state, current `walkerId`, target walker eligibility, service-area eligibility, time overlap, Leave/suspension, and write an audit record atomically.
4. For already accepted bookings when a walker becomes unavailable, preserve the booking and create an explicit Admin action/incident requiring reassignment or escalation; do not silently clear `walkerId`.
5. Require the same immutable `occurrenceId` across schedule, assignment, popup response, and completed `walks` record. Parent `bookingId` alone is insufficient for multi-walk or recurring bookings.
6. All client-side eligibility checks are advisory only; Firestore Rules and/or trusted backend must enforce assignment and popup response authorization.

## Popup gating implications

A pre-start popup should only be eligible when the occurrence is assigned to the signed-in walker and the authoritative walker account is approved, verified, active, and not suspended or on approved Leave for the occurrence's service date/time. Never show the prompt during an active walk. Post-completion prompt must be linked to the same occurrence's completed event. No response remains pending; it is not a confirmation.

## Status

- Admin walker status model and booking monitoring screen audit: completed for the files above.
- Canonical Leave schema/workflow: not found in inspected checked-in source.
- Dedicated authoritative reassignment workflow: not found in inspected service/screen.
- Cross-app occurrence contract: still incomplete.
- Code/Rules/Functions changes: none.
- Tests: not run.
- Deployed Firebase configuration: not verified.
- Ready to deploy: no.
