# DOJO WALK Booking Acceptance and Flexible Walk Slots — Step 14
Date: 2026-10-16
Branch: audit/zone-service-area-mapping-2026-10-16
Status: Product requirement confirmed by user; design/documentation only.

## Confirmed product rule
The walker accepts or rejects the **whole booking**, not each individual walk slot. Before accepting, the walker must see the booking period and the full details of every scheduled slot. Each slot is configured separately, and one booking can include multiple slots per day.

## Per-slot configuration
Each scheduled walk slot must have its own:
- Slot identity/order within the booking schedule
- Time of day
- Duration in minutes
- Relevant date or recurring-day pattern
- Status/progress information after the whole booking is accepted

The owner/customer can configure different durations for different slots. Examples include 20, 30, 40, 45, or 60 minutes. These are examples, not a restrictive list. The owner may enter a custom duration or increase it, subject to product validation and the company's approved pricing/service limits.

## Example
A Regular booking may have three slots per day:
1. Morning — 20 minutes
2. Afternoon — 40 minutes
3. Evening — 60 minutes

Another booking may have one slot per day for 45 minutes, or two slots with different durations. Do not assume all slots in one booking share the same duration.

## Booking acceptance flow
1. Customer submits one booking with its period and full slot schedule.
2. Company/admin assigns the booking to a walker.
3. Walker reviews the whole booking: start/end dates, all daily slots, each slot's time and duration, dog/pickup details, service location, instructions, and applicable compensation/price information.
4. Walker accepts or rejects the **booking as a whole**.
5. If accepted, the individual slots occur on their planned dates/times and are tracked separately for execution. There is no separate acceptance action for each slot.
6. If the schedule changes materially after acceptance, the system must show the change and use an approved re-confirmation/reassignment policy; never silently change the accepted commitment.

## Data-model implications
- Parent booking stores booking type, period, customer/pet/address references, overall status and a full schedule/template.
- Every slot in the schedule stores its own time and duration; do not use one parent-level duration as the only source for every slot.
- Concrete dated walk occurrences may be generated from the recurring template. Each occurrence links back to the parent booking and the corresponding slot/template identifier.
- Whole-booking acceptance is recorded at the booking/assignment level, with actor and timestamp. Slot lifecycle status is tracked separately after acceptance.
- Validate maximum slots per day, custom duration bounds, schedule conflicts, total booking capacity and price calculation through explicit company-approved rules. The examples above do not define maximum duration or final price policy.

## Required UI
Walker booking preview must show:
- Booking type and date range
- Every day/recurrence pattern
- All slots in order, each with its own time and duration
- Dog, pickup location, instructions, and any approved pay/compensation details
- One primary action to Accept Booking and one to Reject Booking

Customer scheduling UI must allow each slot to be configured independently and must not force all slots to share the same duration.

## Implementation guardrails
- This document records product requirements only; it does not change app code, database Rules, existing records, or deployment.
- Before implementation, inventory all schedule readers/writers in Customer, Partner and Admin.
- Confirm duration validation limits, pricing calculation, maximum slots/day and change-after-acceptance policy with the product owner.
- Add automated tests for one, two and three slots/day, mixed durations, custom duration, whole-booking acceptance, rejection/reassignment and schedule changes.

## Checklist
- [x] Whole-booking acceptance confirmed.
- [x] Per-slot time and duration confirmed.
- [x] Multiple slots per day (including three) supported in the target design.
- [x] Example durations 20, 30, 40, 45 and 60 minutes documented.
- [ ] Company-approved duration bounds, slot limit and pricing rules.
- [ ] Cross-app implementation and automated tests.
