# DOJO WALK — Regular Walk Company-Controlled Operations

**Date:** 2026-10-16  
**Decision status:** User-confirmed product requirement; design only  
**Applies to:** Customer, Partner, Admin, and shared backend

## Product rule
Regular Walk operations are controlled by the company. The company controls both (1) assignment of walkers to recurring customer plans and (2) when/where walkers are available to receive company assignments. Walkers do not self-assign recurring plans and cannot bypass company assignment.

## Proposed company workflow

1. Customer submits a Regular Walk plan. The booking is created as a request with `status=pending` and a separate plan-review state such as `planStatus=pending_confirmation`.
2. Company/Admin reviews the requested schedule, service area, pet/pickup details, plan capacity and price.
3. Company checks the walker availability roster: active/approved, documents verified, assigned service area, available time slots, workload/capacity, time-off/unavailability and overlapping bookings.
4. Company selects a suitable walker and assigns the plan. The assignment is written to the booking/plan by a trusted company-authorized action.
5. Walker receives the assignment and may acknowledge it according to company policy. Acknowledgement is not self-assignment and does not let the walker change the assigned customer or plan.
6. If the walker declines, becomes unavailable, or misses an acknowledgement deadline, the plan returns to the company assignment queue for reassignment/backup.
7. Company monitors recurring occurrences, absences, complaints, pauses, replacements and cancellation. Every assignment/reassignment is audit logged.

## Availability is company-managed
Recommended availability record (schema proposal, not implemented):
- `walkerId`
- `serviceAreaIds` / approved service location IDs
- `weeklyAvailability` with local-time windows
- `unavailableIntervals` / leave
- `maxConcurrentBookings` or capacity policy
- `activeForAssignment`
- `lastReviewedAt`, `reviewedBy`
- timestamps and audit metadata

Availability must not mean merely `isOnline=true`: online presence is live-operation telemetry, while recurring work availability is a planned, company-managed roster.

## Authority boundaries
- **Customer:** request/modify/cancel plan within published rules; cannot select or force a walker assignment.
- **Walker/Partner:** view assigned work and report availability/leave or accept/decline only if the company enables that policy; cannot write arbitrary `walkerId`, change plan ownership, or assign themselves.
- **Company/Admin:** approve plans, manage availability, assign/reassign, set backup, pause/resume plans, and inspect assignment history.
- **Backend/Security Rules:** enforce authorization and valid state transitions; hiding buttons in the UI is not security.

## Regular plan vs individual occurrence
Keep the recurring plan distinct from its daily walk occurrences. Proposed model:
- Plan: customer, pet, service area, approved schedule template, plan status, assigned primary walker, optional backup, effective dates.
- Occurrence: plan ID, scheduled date/time, assigned walker for that occurrence, status, check-in/walk/return evidence, completion outcome.
This avoids one recurring booking document being overloaded with every daily execution and allows an approved backup for a single missed day. Final schema must be reconciled against current customer/partner Firestore fields before implementation.

## Required safeguards/tests
- Only an authorized company role can assign/reassign a Regular Walk.
- Reject assignment to unapproved/inactive walkers, outside their service area, during unavailable windows, or beyond capacity.
- Detect overlapping assignments, including recurring time slots.
- Prevent duplicate occurrence creation and duplicate completion writes.
- Record who assigned/reassigned, when, previous walker, new walker, reason and plan/occurrence IDs.
- Test unauthorized customer/walker assignment attempts and valid/invalid Admin flows in Firestore Emulator.
- Do not deploy rules, indexes, Functions, or migrate Production data until tests and schema reconciliation pass.

## Implementation status
This file records the requirement and proposed workflow only. No application code, rules, Production data, or deployment configuration was changed.
