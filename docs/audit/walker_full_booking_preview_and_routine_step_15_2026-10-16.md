# DOJO WALK Walker Booking Preview — Full Routine & Schedule Requirement
Date: 2026-10-16
Branch: audit/zone-service-area-mapping-2026-10-16
Status: Product requirement confirmed by user; design/documentation only.

## Confirmed rule
When a booking is assigned to a walker, the walker must be able to inspect the complete booking and routine **before accepting or rejecting the whole booking**. A short summary alone is not enough. The walker accepts the booking as a whole, not every walk slot individually.

## Required full booking preview

### A. Booking overview
- Booking ID/reference
- Booking type: One-Time, Regular, or Temporary/Selected Dates
- Overall start date and end date (for ongoing/recurring plans, show the agreed period and renewal/expiry rules if applicable)
- Assignment date and current booking status
- Number of walks per day and the number of planned days/occurrences, where known
- Approved walker compensation/payment details and any relevant work terms

### B. Complete routine and every slot
For every scheduled day or recurring pattern, show each slot independently:
- Slot label/order (e.g. Morning, Afternoon, Evening)
- Exact local date where it is a dated booking, or recurrence pattern for a Regular booking
- Planned start time
- Duration in minutes for that specific slot
- Expected end time, calculated from start + duration
- Any approved break/travel/capacity expectations that affect the assignment
- A clear indication when a schedule is a recurring template rather than a fully generated dated schedule

Do not assume every slot shares the same duration. One day may have one, two, or three slots, and slot durations can differ (examples: 20, 30, 40, 45, or 60 minutes; custom durations only within company-approved limits).

### C. Dog/pet details
- Dog name and profile/photo when available
- Breed, size, age and relevant behavior/special-care notes
- Any safety or handling instructions provided by the owner
- Keep unrelated or unnecessary private customer information out of the walker view

### D. Pickup and service location
- Pickup address and useful directions/landmark/pickup instructions
- Map preview and coordinates if authorized and necessary for the assigned task
- Service area eligibility and any location constraints
- Reveal only information needed for the assigned booking; protect customer address from unassigned walkers

### E. Booking terms and changes
- Customer's relevant notes and special requests
- The approved price/compensation that applies to the walker (do not expose internal margin or other private financial data)
- Clear cancellation, lateness, missed-walk and absence policies that have been approved by the company
- Schedule changes after acceptance must be highlighted and must follow an approved reconfirmation/reassignment policy; do not silently alter an accepted commitment

## Acceptance UX
1. Company/Admin assigns a booking.
2. Walker opens a detailed preview and can review the full date range, routine, every slot, dog, pickup details, instructions, and compensation/terms.
3. Provide two explicit actions: **Accept Booking** and **Reject Booking**.
4. Record acceptance/rejection actor, timestamp and assignment version.
5. Only after booking acceptance, expose the authorized walk execution controls and each occurrence's Chat/GPS/Pee-Poop/Notes features at the appropriate stage.
6. If the booking schedule changes materially, notify the walker and require the approved re-confirmation workflow.

## Privacy and access rules
- Only the assigned walker may view the full operational details.
- Unassigned/rejected/released walkers must not retain access to current customer address, chat or future schedule details beyond the company's approved retention needs.
- Admin access is role-controlled and auditable.
- Do not reveal customer's personal phone number if in-app chat/call relay is used.
- Store only data necessary to fulfil the booking.

## Acceptance criteria
- [ ] One-time booking preview shows all applicable details.
- [ ] Regular booking preview shows full start/end period and recurring routine.
- [ ] Temporary/selected-date booking preview shows each chosen date and each slot.
- [ ] Each slot displays its own time and duration.
- [ ] Preview distinguishes template patterns from concrete dates.
- [ ] Walker can accept/reject the whole booking in one action.
- [ ] Schedule changes are versioned, visible and handled by approved policy.
- [ ] Authorization tests verify only the assigned walker can read full booking details.
- [ ] No code, Rules, live data or deployment changed in this documentation step.
