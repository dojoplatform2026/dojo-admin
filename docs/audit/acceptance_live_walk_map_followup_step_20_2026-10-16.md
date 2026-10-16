# DOJO WALK Acceptance, Live Walk and Map Follow-up Audit — Step 20
Date: 2026-10-16
Branch: audit/zone-service-area-mapping-2026-10-16
Status: Source inspection recorded; no app code, Rules, live data or deployment changed.

## Files inspected
- Partner `lib/screens/home/walk_details_screen.dart` (booking read, customer/dog fields, pickup address and navigation action).
- Partner `lib/screens/home/partner_home_screen.dart` (today's booking query and active statuses).
- Partner `lib/features/live_walk/screens/live_walk_screen.dart` (customer coordinate lookup and walk completion write).
- Admin `lib/features/service_location/widgets/service_boundary_editor.dart` (service-area polygon editor).
- Partner `firestore.rules` and Customer booking writer findings from Step 19 remain relevant.

## Findings

### 1. The current Walk Details flow updates status when navigating
The inspected `_navigateToPickup()` in `walk_details_screen.dart` updates the booking's status to `accepted` and then navigates to pickup navigation. The update is wrapped in a catch that silently continues if it fails. In this inspected method, there is no visible check that the current user is still the assigned `walkerId`, no explicit server-verified acceptance result, and no confirmation that an acceptance transition succeeded before showing navigation. This is a critical workflow/security risk to verify across all callers and deployed Rules.

### 2. Customer profile photo is not loaded in the inspected detail screen
The inspected details loader reads `customer.name`, `dog.breed`, `dog.size`, `customerName`, `dogBreed`, `dogSize`, and `pickupAddress`. It does not read a customer photo/profile URL in the inspected section. The inspected Customer booking writer's shape from Step 19 uses `customerId`, `petDetails`, and a map-valued `pickupAddress`, whereas this Partner screen expects some legacy/different fields and treats `pickupAddress` as a String. This is a confirmed source-schema mismatch risk; exact UI fallback behavior should be tested.

### 3. Partner Home booking query uses a different date field
The inspected Partner Home loads bookings with `walkerId == uid`, then filters for today's `date` and uses `startTime` for sorting. The Customer booking writer inspected in Step 19 writes `scheduledAt`, `walkSchedules`, and optionally `dateSchedules` / `selectedDates`; it does not show top-level `date` or `startTime` in that payload. This can cause scheduled bookings not to appear correctly unless a trusted assignment/normalization process adds those fields. All booking writers and assignment functions need review.

### 4. Live Walk uses exact customer coordinates from the booking
The inspected Live Walk loader reads top-level `latitude`, `longitude`, or a GeoPoint in `location` from the booking and stores them as the customer coordinate. The walk completion code writes a separate `walks/{walkId}` document with walkerId, bookingId, route, start/end locations, timing, duration, distance, pee/poop counts and completion status, then updates the booking status to completed.

This confirms source code can use exact coordinates during Live Walk, but does not establish that the coordinate is securely hidden before acceptance or that location tracking is restricted to the correct accepted occurrence. The exact coordinate must not be used to draw the pre-accept circle.

### 5. Admin boundary editor draws a polygon only
The inspected `ServiceBoundaryEditor` supports map interaction and drawing a polygon from at least three points; it persists only through parent callbacks. The inspected widget does not create a privacy-safe approximate pickup circle. Circle display/derivation remains a separate feature requiring a safe source, defined radius/area policy and UI label.

## Required implementation plan
1. Replace direct status mutation from the UI with a validated acceptance operation that confirms current walker assignment, pending/assigned state, and an allowed transition. Do not silently continue to navigation if acceptance fails.
2. Define one canonical booking schema and occurrence model; normalize the Customer writer, Partner Home query, Walk Details reader and assignment backend together.
3. Store exact pickup details in a protected document or trusted backend path; permit access only after the currently assigned walker has accepted the booking. Do not rely on UI hiding.
4. Fetch customer name/photo through a protected, minimal profile projection after authorization; map the actual map-valued pickupAddress and petDetails schema correctly.
5. Make each walk occurrence have its own stable occurrence ID and link its live-walk record/chat/counters to that occurrence, not just the booking.
6. For the pre-accept map, display service-area polygon plus a privacy-safe approximate circle that does not expose the actual pickup coordinate. Verify locality/society display and service-area eligibility.
7. Add tests for pending, assigned-not-accepted, accepted, rejected, reassigned, cancelled, active occurrence, completed occurrence, missing/legacy fields and unauthorized direct document reads.

## Step 20 status
- Source findings recorded in this report.
- No code or Rules changed.
- No tests executed.
- Deployed Firebase Rules/version not verified.
