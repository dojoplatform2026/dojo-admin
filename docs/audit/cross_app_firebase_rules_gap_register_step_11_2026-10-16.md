# DOJO WALK Cross-App Firebase Rules Gap Register — Step 11
Date: 2026-10-16
Branch: audit/zone-service-area-mapping-2026-10-16
Status: Source-level gap register only. No Emulator tests or production changes.

## 1. Scope
Reviewed the accessible Partner `firestore.rules`, `firebase.json`, and Functions source/config. The Partner Rules file is source code only; deployment status is not established. This report does not claim live-project behavior.

## 2. Confirmed source-level gaps

### G1 — Booking creation is explicitly denied
In `firestore.rules`, `match /bookings/{bookingId}` has `allow create: if false;`. If this Rules file is deployed as-is, a client app cannot create a booking through Firestore. Customer confirmation code previously inspected writes to `/bookings`. **High priority to verify against deployed Rules.**

### G2 — Customer cancellation is status-limited
Customer update is permitted only when the existing status is one of `pending`, `confirmed`, or `assigned`, and changed keys are limited to `cancelRequest` and `updatedAt`. Customer UI handles additional statuses. The intended cancellation policy for each status must be agreed before changing Rules.

### G3 — Assigned walker status transitions are not constrained
The assigned-walker rule permits updates to `status` plus a list of progress fields, but the checked condition does not enforce a current-status → next-status graph or validate every field's type/range. If deployed, an assigned walker may potentially write status values beyond the intended sequence. Confirm actual Rule evaluation and design a strict transition contract before modifying.

### G4 — Walks collection rules are absent from this file
A full text search of the inspected 15,644-character Partner Rules file found no `match /walks` block. Unless a broader matching rule elsewhere grants access, writes/reads to `/walks/{walkId}` are denied by default. Partner live-walk code previously inspected uses a separate `/walks` record. Verify all rules and any collection-group/subcollection patterns before drawing a production conclusion.

### G5 — Walk requests are explicitly denied
`match /walk_requests/{requestId}` has `allow read, write: if false;`. If any current client workflow relies on this collection, it will be blocked under this file. Confirm whether it is legacy/unused before any change.

### G6 — Rules deployment source is not declared in checked config
Partner `firebase.json` declares Functions only; its Functions workflow deploys `--only functions`. Admin `firebase.json` and Hosting workflow deploy Hosting only. These checked configs do not establish a Rules deployment pipeline or identify the authoritative deployed Rules file.

## 3. Priority order
1. **P0 verification:** retrieve deployed Firestore Rules via authorized Firebase Console/CLI and establish their source owner.
2. **P1 compatibility:** reconcile Customer booking creation payload with intended Rules validation.
3. **P1 live walks:** define whether `/walks` records are client-managed, backend-managed, or both; enforce ownership and idempotency.
4. **P1 lifecycle:** approve booking/walk transition matrix and cancellation policy.
5. **P2 legacy check:** establish whether `walk_requests` is used; remove only after repo-wide and data-owner confirmation.
6. **P2 CI:** set up Emulator tests against the confirmed Rules file with synthetic fixtures and a guard preventing production project selection.

## 4. Required Emulator tests
- Valid customer booking create passes; missing/foreign customer identity and protected fields fail.
- Customer can request cancellation only in approved statuses; cannot change assignment/status.
- Assigned walker can advance only one permitted step; invalid jumps, terminal-state reopening, and wrong-walker writes fail.
- `/walks` create/read/update behavior matches the approved backend/client ownership model.
- `/walk_requests` behavior matches confirmed product use.
- Admin scope, Super Admin behavior, and audit/payment protection are tested.
- Duplicate completion retries do not duplicate walk records or payout.

## 5. Checklist
- [x] Inspected the complete accessible Partner Rules source and searched for booking/walk/request match blocks.
- [x] Logged source-level risks with conditions and limitations.
- [x] Ranked verification and compatibility work.
- [ ] Retrieve and compare authoritative deployed Rules.
- [ ] Confirm collection ownership and intended cancellation policy.
- [ ] Implement isolated Emulator tests against confirmed Rules.
- [ ] Run tests and save real output.
- [ ] Review production change separately with explicit authorization.

No application code, Rules, live data, secrets, or deployments were changed.
