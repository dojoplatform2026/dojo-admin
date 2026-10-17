# Proposed Service Location Hierarchy — District vs City

Date: 2026-10-17  
Status: **Design proposal only — not implemented and not approved for production**

## Why this design decision is required

The import CSV has separate `State`, `District`, `City`, and `Area` columns. The current Admin/Firebase hierarchy is Country → State → City/District → Area/Sub-district. The current Firestore Rules use strict field allowlists and do not allow the proposed LGD metadata fields or a separate district parent. A client-only change would therefore be incomplete and could be rejected by Rules or leave trusted callable validation inconsistent.

LGD supplies official administrative State, District and Sub-District reference records. It does **not** automatically provide the service-city list or service-area polygons that DOJO WALK needs. Service-area boundaries must not be guessed from an administrative name or a radius.

## Recommended logical hierarchy

`Country → State → District → Service City → Service Area`

Optional customer-entered address/locality text remains separate. The existing `service_localities` collection can remain available where needed, but it should not be required for a booking when the customer provides their own address.

### Collections and fields

- `service_states`: retain existing fields; add optional `lgdCode` only after the Firestore Rules allowlist and tests are updated.
- New `service_districts`: `countryId`, `stateId`, `name`, `lgdCode`, `isActive`, `createdAt`, `updatedAt`, and source/snapshot metadata for traceability. District codes are stored in a representation that preserves the source code exactly.
- `service_cities`: retain existing fields and add optional `districtId` for the new hierarchy. Retain `stateId`/ `countryId` as denormalized compatibility fields. New records should identify their level explicitly; legacy records without `districtId` must not be silently reclassified.
- `service_areas`: child of a service City; the verified polygon is the service coverage boundary. Do not assign an LGD Sub-District code unless the source explicitly proves that the service area is that exact administrative unit.
- `service_location_boundaries`: retain the current verified boundary lifecycle. Trusted Functions must verify City/Area ancestry and geometry before activation.

## Import rules

1. State and District names/codes come from a reconciled official LGD snapshot.
2. City is a DOJO WALK service-city record supplied by an approved city dataset or an explicit admin entry. Do not infer it from a District or Sub-District name.
3. Area is a service coverage polygon, not automatically an LGD Sub-District. Require an authoritative polygon source or a reviewed map-drawn polygon before activation.
4. A CSV preview may validate names and parent links but must not write service records until the schema and mapping are approved.
5. Imports should be staged with source filename, snapshot date, file hash, row counts, validation report and actor; committing records should be transactional/idempotent and reject ambiguous parent mappings.
6. Never activate imported Cities/Areas merely because their names or LGD codes exist. A verified boundary and trusted activation checks are still required.

## Backward compatibility

- Do not delete or rewrite existing `service_cities`, `service_areas`, legacy `zones`, or customer free-text addresses.
- Legacy City/District records without `districtId` remain readable during migration.
- Do not migrate Partner from legacy `zones` in this Admin PR. Plan that as a separate compatibility/migration task.
- No production writes, data migration, activation or deployment are part of this proposal.

## Required implementation sequence

1. Approve the hierarchy and meaning of City/Area.
2. Update Admin models/services/UI and migration/import tests.
3. Update Firebase Rules allowlists and trusted Functions/callables, with Emulator tests for new and legacy records.
4. Verify Customer and Partner compatibility; preserve legacy Zone behavior until a separate migration is tested.
5. Reconcile current official LGD State/District data and keep Sub-District data reference-only unless its role is explicitly approved.
6. Run full Admin analysis/tests/build and Firebase Rules/Functions tests.
7. Only then consider PR review/merge. Production deployment and import require separate explicit release approval.
