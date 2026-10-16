# DOJO WALK Company-Scoped ID Standard (Draft)
Date: 2026-10-16
Repository: dojoplatform2026/dojo-admin
Branch: audit/zone-service-area-mapping-2026-10-16

## Goal
All DOJO WALK applications (Admin, Customer, Partner and future services) must refer to the same entity using the same immutable canonical ID and company scope. IDs must follow the relationship flow, not be generated independently in each app.

## Proposed common fields
Every company-owned operational document should carry:
- `companyId`: canonical company identifier (proposed initial tenant: `dojo_walk`; confirm before production)
- `id`: immutable canonical document ID, equal to the Firestore document ID where practical
- `parentId` or explicit parent references (for example `stateId`, `districtId`, `cityId`, `areaId`)
- `entityType`
- `createdAt`, `updatedAt`
- `sourceSystem` and `sourceCode` where external reference data applies

## ID rules
1. Generate a canonical ID once at record creation (Firestore auto-ID or UUID), store it as the document ID, and never regenerate it from a display name.
2. A readable code such as `DOJ-IN-UP-GBN` may be stored separately as `code`; it is not the primary key unless uniqueness and rename rules are enforced.
3. Every company-owned operational record is scoped by `companyId`. If DOJO WALK becomes multi-company/multi-tenant, scope uniqueness and authorization by company.
4. Use parent IDs to define flow and relationships; do not embed a mutable parent name in the canonical ID.
5. Official LGD codes remain external source identifiers in fields such as `sourceSystem: LGD` and `sourceCode`. Never substitute a company ID for an official code.
6. Preserve existing Firestore document IDs and legacy zone IDs during migration. Use explicit reviewed mapping documents to connect old and new records.
7. Boundary, booking, walker, address and other records must reference canonical IDs; do not duplicate location records per app.
8. Security Rules must enforce the company scope and allowed parent relationships. Client-side checks alone are insufficient.

## Proposed location flow
Company scope -> Country -> State/UT -> District reference -> City/service market -> Area/service polygon -> optional Locality/Society.
Sub-district/Tehsil remains a separate official reference entity linked to its official district parent.

## Migration / release gates
- Audit all existing models and Firestore documents for current ID conventions before implementation.
- Confirm whether companyId should be a constant for the initial single-company deployment or a true tenant collection reference.
- Check deployed Firestore Rules and indexes; the repo tree did not show a `firestore.rules` file at the inspected path, which does not prove no deployed rules exist.
- Add tests for ID immutability, parent references, company isolation and legacy mappings.
- No production import or main-branch merge until reviewed and tested.

## Status
Draft standard saved for review. Not implemented in app code. No production Firestore data changed. Do not treat the sample company ID as production-approved until existing company/tenant records and app conventions are audited.
