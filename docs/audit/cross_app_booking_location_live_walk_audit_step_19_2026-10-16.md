# DOJO WALK Cross-App Source Audit — Step 19
Date: 2026-10-16
Branch: audit/zone-service-area-mapping-2026-10-16
Status: Source inspection completed for the files listed below. No code or deployed configuration changed.

## Scope inspected
- Customer: `lib/features/booking/screens/booking_confirmation_screen.dart` on `main`, lines 900–990.
- Partner: `firestore.rules` on `main`, lines 350–460.
- Partner: `lib/screens/home/partner_home_screen.dart`, `lib/screens/home/walk_details_screen.dart`, and `lib/features/live_walk/screens/live_walk_screen.dart` on `main`.
- This is a limited source audit, not a complete repository-wide audit or a check of deployed Firebase Rules.

## Findings

### 1. Customer booking writer stores full pickup address in the booking document
The Customer booking writer builds `bookingData` with `customerId`, `petDetails`, `pickupAddressId`, and `pickupAddress` directly in `bookings/{bookingId}`; it also writes `status: pending` and `walkerId: null`. It writes `walkSchedules`, and for regular bookings `dailyWalkTemplate`; for selected-date bookings it writes `selectedDates` and `dateSchedules`.

Implication: exact pickup details are currently part of the main booking document payload. Hiding them in the UI alone would not protect them if a pre-accept reader can read that document. The privacy requirement likely needs a protected pickup-details document or trusted backend access control, coordinated with deployed Rules.

### 2. Partner Rules source denies direct booking creation
The checked Partner `firestore.rules` has `allow create: if false` for `bookings/{bookingId}`, with a comment saying the complete shared production rules must validate customer booking creation before deployment. This conflicts with the inspected Customer client-side `bookingRef.set(bookingData)` writer if these exact Rules are deployed. This is a source-level mismatch only; deployed Rules/version and actual runtime behavior have not been verified.

### 3. Booking read permission is based on walkerId, not an explicit accepted state
The checked Rules allow a signed-in walker to get/list a booking when `resource.data.walkerId == request.auth.uid`. The rule does not additionally require a specific accepted status for reads. Therefore the source Rules do not themselves express the intended pre-accept vs post-accept visibility boundary. If a booking is assigned before acceptance, this read predicate could expose fields in that document; exact exposure depends on the deployed rules and assignment flow.

### 4. Partner detail screen expects a different data shape
The checked `walk_details_screen.dart` reads `customer` and `dog` maps, direct `customerName`, `dogBreed`, `dogSize`, and `pickupAddress`. The inspected Customer writer uses `customerId`, `petDetails`, and `pickupAddress`; it does not write the same customer/dog map shape in the shown payload. This indicates a schema compatibility risk for customer name/photo and dog details. Inspect remaining code and all writers before changing the schema.

### 5. Live Walk implementation exists
Partner source includes `lib/features/live_walk/screens/live_walk_screen.dart`. It initializes a walk document ID, tracks elapsed seconds, distance, pee/poop counters, GPS route, and customer latitude/longitude. This confirms relevant live-walk UI logic exists in source, but this limited read does not verify the complete write path, security rules for `walks`, occurrence-level isolation, or whether GPS only runs during an authorized active walk.

### 6. Circle / privacy-safe approximate pickup zone not verified
The limited Partner search found circular UI decorations, but no evidence in the inspected snippets proves the requested service-area boundary plus privacy-safe approximate pickup circle is implemented. Do not treat the circle feature as complete. It needs a dedicated design/data contract and map-source audit. The approximate circle must not expose or allow easy inference of the exact pickup point.

## Priority next steps
1. Inspect deployed Firebase Rules/version and all booking creation/assignment code before making changes.
2. Design a protected pickup-details path/backend check that only the currently assigned, accepted walker can access.
3. Align Customer booking payload with Partner booking/detail readers without breaking existing records.
4. Inspect the complete live-walk start/write/end flow and `walks` Rules; enforce occurrence-level isolation and active-walk GPS constraints.
5. Audit Admin Service Location boundaries and map widgets; define a privacy-safe circle based on the service area, not the exact customer coordinate.
6. Add emulator/unit tests for pending, assigned-not-accepted, accepted, rejected, reassigned, cancelled and completed states.

## Status
- Source-level findings recorded.
- No app code, Firestore Rules, live data, secrets, or deployment changed.
- No tests were run as part of this audit.
