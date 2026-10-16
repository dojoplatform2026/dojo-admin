# DOJO WALK Walker Pre-Accept Location Privacy — Step 16
Date: 2026-10-16
Branch: audit/zone-service-area-mapping-2026-10-16
Status: Product requirement confirmed; documentation/design only.

## Confirmed privacy rule
Before a walker accepts a booking, **do not reveal the customer's exact pickup address, exact pickup pin, or current pickup point on the map**. Instead, show the service locality/area and an approximate service-area map/boundary so the walker can judge whether the booking is in an eligible area.

After the booking is accepted and the walker is authorized for that booking, reveal the exact pickup address and task-specific directions needed to perform the service, subject to the approved company workflow. If a booking is rejected, released, or reassigned away from that walker, remove access to exact pickup details and future task information according to the access policy.

## Before acceptance — what the map may show
- Service locality name (e.g. the relevant locality/sector/neighborhood).
- Parent service area/city labels as needed.
- Verified service-area polygon/boundary and an area-level map view.
- A non-precise area indication only if it cannot be mistaken for the customer's pickup point.
- A clear label such as: "Approximate service area — exact pickup location shown after booking acceptance."

Do not show:
- Exact pickup address or flat/house/building number.
- Exact pickup coordinates, geohash, or precise customer pin.
- Directions/navigation route to the customer's home.
- A map marker that exposes or allows inference of the exact pickup location.

## After acceptance
Show the assigned walker only the exact pickup address, pickup instructions, and navigation details needed for the accepted booking. Enforce this at the data-access layer, not only by hiding fields in the UI. Prefer a separate protected pickup-detail document or server-mediated access if the current booking document contains the exact address; otherwise a client that can read the whole booking may still extract hidden fields.

## Booking preview behavior
The walker still sees the full booking commitment before accepting:
- Booking type, date range, recurrence, all slot times and each slot's duration.
- Number of slots per day and expected workload.
- Dog details and relevant care/safety instructions, with personal data minimized.
- Service locality and boundary map (not exact pickup point).
- Approved walker compensation and applicable policies.

Accept/Reject actions remain at the whole-booking level. The exact pickup point is revealed only after a successful authorized acceptance/assignment state.

## Security requirements
- Do not rely on UI-only redaction. Firestore Rules must prevent pre-accept access to exact pickup fields.
- If booking document read access exposes all fields, move exact pickup details to a separately protected document/path or use a trusted backend endpoint that checks the current assignment and acceptance state.
- Test assigned-but-not-accepted, accepted, rejected, reassigned, cancelled, and ended-access cases.
- Audit exact-location access where practical; do not include exact coordinates in logs or notifications.
- Admin access remains role-controlled and auditable.
- If the system must reveal approximate geography, use the verified service locality polygon; do not derive or publish a false precise pickup pin.

## Acceptance criteria
- [ ] Pre-accept preview contains locality and service-area boundary map only.
- [ ] No exact pickup address, pin, coordinates, or navigation route is available before acceptance.
- [ ] Exact pickup details become available only after authorized acceptance.
- [ ] Reject/reassignment removes access to exact pickup details.
- [ ] Automated Rules/backend tests prove the boundary at the data layer.
- [ ] Map is based on verified service-area boundaries and clearly labelled approximate.
- [ ] No app code, Rules, live data, or deployment changed in this documentation step.
