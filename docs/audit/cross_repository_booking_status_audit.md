# DOJO WALK — Cross-Repository Booking Status Audit (Step 6)

**Date:** 2026-10-16  
**Status:** Static source audit; no tests run  
**Branch:** `audit/zone-service-area-mapping-2026-10-16`

## Scope
Reviewed status handling in Customer `my_bookings_screen.dart` and booking creation, Admin `bookings_screen.dart` and Walker Management dashboard, Partner navigation/live-walk completion, plus the inspected Partner `functions/index.js`.

## Confirmed source findings

### Customer
- New booking writes `status: 'pending'`.
- Customer UI recognizes legacy and canonical-like values including `pending`, `finding_walker`, `walker_assigned`, `walker_arriving`, `confirmed`, `assigned`, `accepted`, `in_progress`, `in progress`, `completed`, `cancelled`, and `canceled`.
- UI groups `walker_assigned` and `assigned) under the same label; `confirmed` and `accepted` are also displayed together. That is presentation compatibility, not proof these states mean exactly the same thing.

### Admin
- Booking filter options are human-readable labels: `Pending`, `Walker Assigned`, `Walker Accepted`, `Walk In Progress`, `Completed`, `Cancelled`.
- The inspected filter compares stored `status.toLowerCase()` directly to the selected label's lowercase text. It does not normalize spaces to underscores or map labels to canonical values. Therefore machine values such as `walker_assigned`, `accepted`, and `walking` will not match those respective human-readable filters.
- Walker Management dashboard treats `in_progress`, `active_walk`, `walking`, and `walk_started` as running statuses. These values do not form one consistent set across the apps.

### Partner
- Navigation flow writes statuses including `accepted`, `picked_up`, and `walking` as the walker progresses.
- Live walk completion writes `status: 'completed'` to both a `walks` record and the related booking, and adds completion fields to the booking.
- The inspected Partner Functions entry point exports only an authenticated `checkBackend` callable; it does not implement booking assignment or status transitions. This conclusion applies to the inspected `functions/index.js` only, not to any unsearched external backend.
- Earlier rules audit found the inspected Partner `firestore.rules` walker update allowlist does not include `completedAt`, `dogReturned`, or `returnLocationVerified`; whether that causes a live failure depends on which ruleset is active in Production, which is unverified.

## Compatibility table for review

| Current value / label | Candidate canonical value | Decision |
|---|---|---|
| `pending` | `pending` | Keep |
| `walker_assigned` | `assigned` | Candidate; audit historical meaning |
| `assigned` | `assigned` | Keep |
| `accepted` | `accepted` | Keep |
| `confirmed` | Unknown pending confirmation | Do not auto-map yet |
| `walker_arriving` | `walker_arriving` | Keep if agreed |
| `picked_up` | `picked_up` | Keep if agreed |
| `walking`, `in_progress`, `in progress`, `active_walk`, `walk_started` | Candidate `walking` | Map only after semantics/source review |
| `completed` | `completed` | Keep |
| `canceled` | `cancelled` | Candidate spelling normalization |
| Admin labels such as `Walker Assigned` | UI labels only | Never compare raw label to stored status |

## Risks and priority
1. **Admin filters are incompatible with machine status values.** Fixing this should use a central status-to-filter mapping, not a destructive data migration.
2. **Running-walk logic is inconsistent.** Dashboard and Customer screens can classify the same booking differently.
3. **The meaning of `confirmed` is ambiguous.** Decide whether it means booking accepted by the business or walker accepted the job before mapping.
4. **Status writes are distributed across apps.** Each transition must be paired with role authorization, required fields, and Firestore Rules tests.
5. **Deployment is not verified.** Source findings cannot prove which rules or backend are active in Production.

## Next actions
- Search all status read/write sites, including nested schedule status and any server/backend code.
- Agree on a canonical enum and transition table.
- Add Admin filter mapping from UI labels to canonical values.
- Add a Customer status compatibility mapping for legacy records without silently changing stored data.
- Validate all Partner transitions and completion fields against the final rules.
- Test positive/negative cases in Firestore Emulator before proposing deployment.

**Safety boundary:** No source code, Firestore data, rules, indexes, Functions, Hosting, or Production settings were changed. This report is a static audit artifact only.
