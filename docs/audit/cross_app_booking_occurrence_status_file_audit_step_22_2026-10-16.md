# DOJO WALK — Booking/Occurrence Status Implementation File Audit
## Step 22 — Cross-app files and change plan
Date: 2026-10-16
Repository: dojoplatform2026/dojo-admin
Branch: audit/zone-service-area-mapping-2026-10-16
Type: Source audit and implementation plan only

## Objective
Apply the Step 21 status contract consistently: accepting a whole booking sets the booking to assigned; each dated walk occurrence has its own status; finishing today's occurrence(s) must not complete a recurring parent booking while future occurrences remain.

## Source files inspected and findings

### Customer app — dojoplatform2026/dojo-walk-customer
1. lib/features/booking/screens/booking_confirmation_screen.dart
- Writes parent booking status: pending, walkerId: null, and walkSchedules.
- Regular plan data includes dailyWalkTemplate; selected-date flow includes selectedDates and dateSchedules.
- The inspected write constructs schedule data, but this audit did not confirm every occurrence is persisted as a stable, independently addressable record with its own lifecycle status.
2. lib/features/booking/screens/my_bookings_screen.dart
- Displays booking status and schedule details from walkSchedules.
- Needs a UI review to show parent booking status separately from each occurrence's status once the final schema is implemented.

### Partner app — dojoplatform2026/dojo-partner
3. lib/screens/home/walk_details_screen.dart
- Walker acceptance currently writes parent booking status: accepted.
- This conflicts with the user-confirmed value assigned.
4. lib/screens/home/navigation_screen.dart
- Contains status writes for accepted, picked_up, and walking.
- These should be mapped to the final booking/occurrence lifecycle rather than overwriting the parent booking with occurrence-specific progress.
5. lib/features/live_walk/screens/live_walk_screen.dart
- On walk completion, writes a completed walk record and also updates the parent booking to status: completed.
- This is the key recurring-booking risk: completing one walk can prematurely complete the entire booking. Completion must update the specific occurrence and only complete the parent when the booking period has ended and all required occurrences have been accounted for.
6. firestore.rules
- Contains booking-related update rules and status constraints. Must be reviewed and updated together with the final schema; UI changes alone are not sufficient to protect state transitions or location data.

### Admin app — dojoplatform2026/dojo-admin
7. lib/screens/bookings/bookings_screen.dart
- Lists bookings and their status. Needs to distinguish parent booking status from occurrence statuses/details.
8. lib/screens/dashboard/dashboard_screen.dart
- Dashboard counts use a status value for bookings (search result shows a Completed filter). Verify status casing/values and ensure completed-walk metrics are not calculated as completed parent bookings.
9. lib/features/walkers/services/walker_admin_service.dart
- Provides booking query/service logic and notes that UI should validate booking status and walkerId. Must align with final assignment and occurrence contract.

## Proposed final model (requires schema migration review)
- Parent booking: pending -> assigned -> completed or cancelled.
- Individual dated occurrence: scheduled -> in_progress -> completed, with explicitly defined cancellation/reschedule outcomes.
- Existing UI terms such as accepted, picked_up, and walking must be mapped deliberately. Do not blindly replace strings without checking all reads, filters, rules, tests, and stored documents.
- Each occurrence needs a stable ID and date/time, duration, status, lifecycle timestamps, and link to the parent booking. Candidate storage may be a nested occurrence collection or structured array, but choose only after checking query patterns and Firestore Rules. A structured array is harder to update atomically by occurrence and query individually; a subcollection is a strong candidate but must be validated against existing data and UI.
- For recurring bookings, parent status remains assigned while future required walks remain. Mark parent completed only after the booking period ends and every required occurrence has an explicitly accepted final outcome. Missed, skipped, cancelled, or rescheduled occurrences need business rules before finalization.
- Acceptance must be atomic and server/rules-authorized: booking still pending/available, eligible walker, no prior competing assignment; then set walkerId, status: assigned, and acceptance/update timestamps.

## Recommended implementation order
1. Finalize occurrence schema and lifecycle, including missed/cancelled/rescheduled cases.
2. Review Customer writer and display; persist/show stable occurrence records.
3. Fix Partner acceptance and start/complete flows so they target the correct level.
4. Align Firestore Rules/backend authorization with assignment, occurrence updates, and sensitive pickup data.
5. Update Admin booking detail/list and dashboard metrics.
6. Add tests for one-time booking, multi-slot day, recurring multi-day booking, duplicate acceptance race, one occurrence completed with future occurrences remaining, and final completion.

## Scope / verification
This is a source-level audit and plan. No application code, Firestore Rules, production data, or deployment was changed. Automated tests were not run. Source findings do not establish what is currently deployed in production.
