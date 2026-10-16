# DOJO WALK Post-Acceptance Customer Profile and Full Walk Access — Step 18
Date: 2026-10-16
Status: Product requirement documented; implementation not yet performed.

## Confirmed requirement
After a walker accepts a booking and the system verifies that the walker is the currently authorized assignee, the walker should be able to see the customer/profile and the full operational information required to complete the accepted walk routine safely.

## Before acceptance
The walker may see the society/apartment complex name, locality/sector, service-area boundary and approximate circle, dog/booking preview details, schedule and approved compensation. Do not expose the customer's full name/profile photo unless explicitly approved by the product privacy policy. Do not expose flat/house number, exact pickup address, exact pin/coordinates or home navigation.

## After authorized acceptance
The authorized assigned walker may see:
- Customer's name.
- Customer's profile photo, if one is available and the customer has provided it.
- Full pickup address, including society/building and flat/house number.
- Pickup instructions, access notes and navigation/directions needed for the accepted walk.
- Dog profile: name/photo (if provided), breed, size, age, gender, behavior/temperament, special care and safety notes.
- Accepted booking details: type, date/range, routine/recurrence, all individual walk slots and their independent times/durations.
- Walk execution tools for the specific occurrence: start/active status, GPS route while the walk is active, timer/distance, pee/poop counts with correction support, notes/photos where supported, and complete-walk action.
- The separate chat for the relevant walk occurrence; any in-app call feature only if supported and approved.
- Relevant company rules and safety/emergency guidance.

Show only information needed for the authorized service. Do not expose unrelated customer account data, private contact details, or other bookings. If the walker rejects, is unassigned, or the booking is reassigned, revoke access to customer identity, exact address, chat and future occurrence details according to policy. Admin access remains role-controlled and auditable.

## Security requirements
- Enforce authorization in Firestore Security Rules and/or trusted backend; UI hiding alone is insufficient.
- If booking documents are readable before acceptance, do not store unprotected customer name/photo and exact pickup details in the same broadly readable document. Split sensitive profile/pickup details into a separately protected document or use a backend endpoint with assignment/acceptance checks.
- Check that the accepted state is current and walkerId matches the requesting walker before returning details.
- Test pre-accept, accepted, rejected, reassigned, cancelled and ended-access cases.
- Keep GPS tracking limited to an active walk, according to the approved privacy policy.

## Acceptance criteria
- [ ] After acceptance, authorized walker can view customer name and profile photo when available.
- [ ] Full pickup address and directions are available after authorization.
- [ ] All dog-care, safety, routine, slot, and walk-execution details needed to complete the booking are accessible.
- [ ] Only the currently assigned, authorized walker can access those details.
- [ ] Rejection/reassignment removes access to sensitive details and relevant chat.
- [ ] No unrelated customer account information is exposed.
- [ ] No app code, Security Rules, live data, or deployment changed in this documentation step.
