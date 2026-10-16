# DOJO WALK Walker Address Visibility — Step 17
Date: 2026-10-16
Status: Product requirement documented; implementation not yet performed.

## Confirmed rule
Before a walker accepts a booking, show enough neighborhood context to judge service feasibility, but never reveal a customer's exact residential unit or exact pickup point.

### May be shown before acceptance
- Society/apartment complex name, when available.
- Locality, sector, neighborhood, and service-area name.
- Approximate service-area circle and/or verified service-area boundary map.
- City/area context needed to assess eligibility.
- Dog details and the booking schedule as already specified.

### Must not be shown before acceptance
- Flat/apartment/unit number.
- House/plot number.
- Exact pickup address or exact customer pin/coordinates.
- Exact navigation route to the customer's home.
- Any map marker that reveals the exact pickup point.

### After authorized acceptance
The assigned walker may receive the complete pickup address—including flat/house number—and necessary directions/instructions only after the booking is accepted and the system verifies the walker's authorization.

If the walker rejects the booking, is unassigned, or the booking is reassigned, access to exact pickup details must be revoked according to the approved access policy.

## Security implementation requirement
Do not implement this as UI-only hiding. If the full address currently sits in a booking document readable before acceptance, put exact pickup fields behind a separately protected document/path or trusted backend access check. Test the rules for pre-accept, accepted, rejected, reassigned, cancelled, and completed states.

## Acceptance criteria
- [ ] Society name can appear before acceptance where available.
- [ ] Locality/sector and service-area map/circle can appear before acceptance.
- [ ] Flat/unit and house/plot numbers remain hidden before acceptance.
- [ ] Exact pickup coordinates and navigation remain hidden before acceptance.
- [ ] Full pickup details are revealed only to the currently authorized assigned walker after acceptance.
- [ ] Access is revoked when assignment/authorization ends.
- [ ] No app code, Security Rules, live data, or deployment changed in this documentation step.
