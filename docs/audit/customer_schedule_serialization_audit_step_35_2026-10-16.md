# DOJO WALK Customer Schedule Serialization Audit — Step 35

**Date:** 2026-10-16  
**Repository:** `dojoplatform2026/dojo-walk-customer`  
**Source ref:** `main` (checked-in file fetched through GitHub API)  
**Report repository/branch:** `dojoplatform2026/dojo-admin` / `audit/zone-service-area-mapping-2026-10-16`

## Files inspected

- `lib/features/booking/screens/booking_confirmation_screen.dart`
- `lib/features/booking/screens/choose_walk_screen.dart`

## Confirmed customer-side booking shape

`ChooseWalkScreen` serializes each selected walk with:
- `time` (display text, e.g. AM/PM)
- `startHour`
- `startMinute`
- `duration`
- `period`
- `price`

The confirmation screen's `_cleanWalk()` persists:
- `walkNumber` (1-based index)
- `time`
- `duration`
- optional `startHour`
- optional `startMinute`
- optional `price`

**Important gap:** `_cleanWalk()` does not persist `period`, and it does not create a stable `occurrenceId`. `walkNumber` is a display/index value, not a safe permanent ID if the schedule is reordered or edited.

For a standard/regular booking, the parent `bookings/{bookingId}` document includes `bookingId`, `customerId`, `bookingPlan`, `serviceType`, `scheduledAt`, `preferredTime`, `walkCount`, `walkSchedules`, `status: pending`, and `walkerId: null`. Regular plans also include `dailyWalkTemplate`, `walksPerDay`, `frequency: daily`, and `planStatus: pending_confirmation`.

For customize/selected-date bookings, it persists `selectedDates` as date strings and `dateSchedules` as a list of objects with `date` timestamp and `walks` list. Each walk inside those lists uses the same `_cleanWalk()` shape. No stable per-date/per-walk occurrence ID is added.

## Validation and implications

- `_validWalk()` only accepts duration values in `[20, 30, 45, 60]`, although the schedule screen's custom duration dialog allows 1–240 minutes. This is a current code inconsistency to resolve before implementation; do not silently alter product duration rules as part of popup work.
- Selected dates are persisted as a date string list plus a parallel `dateSchedules` list. Do not use list index as a permanent occurrence identity.
- Regular daily walks use a reusable template; individual future occurrences are not materialized in this customer file.
- One-time immediate booking uses `ASAP` as display time and `scheduledAt = DateTime.now()`, so popup logic must distinguish immediate requests from scheduled walks.
- The customer code directly calls `bookingRef.set(bookingData)`. Whether this succeeds depends on the actually deployed Firestore Rules/backend; deployed configuration was not verified in this step.
- No source change, Rules change, Cloud Function change, or tests were performed.

## Required contract before popup implementation

Recommend backend-assigned stable occurrence identity, for example an opaque immutable `occurrenceId` per scheduled walk instance. It must be generated and validated by trusted backend logic, not guessed from `walkNumber`, list position, formatted time, or client-generated schedule labels.

Canonical occurrence record should reference:
- `bookingId`
- `occurrenceId`
- `walkerId` (authoritative current assignment)
- `serviceDate` and scheduled start/end in the agreed timezone
- occurrence lifecycle state
- confirmation phase (`pre_start` or `post_completion`)
- response status, reason code, text, timestamps
- reassignment/leave exception state where applicable

For regular plans, define how each daily occurrence is created (for example by trusted backend scheduling) and how edits/cancellations affect not-yet-started occurrences. The popup should query only the occurrence currently assigned to the signed-in, eligible walker and must not show during a live walk.

## Next actions

1. Audit Partner booking parser and live-walk lifecycle against these exact customer fields.
2. Audit Admin assignment/reassignment and Leave/suspension source fields.
3. Agree a canonical occurrence model shared by all three apps and backend.
4. Verify deployed Firebase Rules and trusted backend functions.
5. Only then implement and test popup gating and idempotent confirmation persistence.

## Status

- Customer schedule serialization audit: completed for the two files above.
- Cross-app contract: still incomplete.
- Code/Rules/Functions changes: none.
- Tests: not run.
- Deployed Firebase behavior: not verified.
- Ready to deploy: no.
