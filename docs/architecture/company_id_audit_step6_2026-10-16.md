# DOJO WALK Company ID Audit — Step 6
Date: 2026-10-16
Status: PARTIAL CODE AUDIT COMPLETE; CROSS-APP ID STANDARD NOT YET IMPLEMENTED

## Scope inspected
- dojo-admin: Service Location service on branch `audit/zone-service-area-mapping-2026-10-16`; search results for booking/walker workflows.
- dojo-partner: main branch.
- dojo-walk-customer: main branch.

## Findings
1. Admin Service Location code creates Firestore auto-IDs when a new model has an empty ID (for example `collection.doc().id`) and then saves to `collection.doc(documentId)`. Name-index documents record that document ID. This makes the Firestore document ID the operational key, not a company-readable code.
2. Customer booking confirmation creates a booking reference using `firestore.collection('bookings').doc()`, i.e. Firestore auto-ID.
3. Partner walker profile uses `walkers/{FirebaseAuth uid}`. This is identity-linked, not a newly generated company-wide ID.
4. Partner onboarding still reads active legacy `zones` and stores selected zone document IDs in the walker's `zones` array, alongside human-readable city/state/area/zone names. It is not yet migrated to `service_cities` / `service_areas`.
5. Partner booking flows read/update `bookings/{bookingId}`; cross-app consistency currently depends on all apps referencing the same Firestore booking document.
6. The inspected patterns are mixed by entity: Firestore auto-ID for bookings and service locations, Firebase UID for walkers, and legacy zone IDs for partner work areas. In this limited audit, no consistent companyId field was evidenced across these flows.

## Risks / constraints
- Do not replace booking IDs, walker UIDs, service-location IDs, or legacy zone IDs in place.
- Do not infer a legacy zone-to-area mapping from matching names alone.
- Do not make companyId mandatory until Firestore Rules, existing documents, Admin services, and Customer/Partner reads/writes have been audited.
- Government LGD codes must remain separate source identifiers.
- This is a partial code audit, not a full-repository or production database audit.

## Next steps
1. Audit remaining Service Location save methods, boundary/import documents, users/pets/addresses, and admin walker workflows.
2. Draft a reviewed legacy-zone -> canonical-area mapping plan preserving both IDs.
3. Create a cross-app migration/testing matrix.
4. Implement only on the working branch after review, then run tests.

## Change status
No production Firestore data changed. No merge to main. This file records findings and does not implement the ID standard.
