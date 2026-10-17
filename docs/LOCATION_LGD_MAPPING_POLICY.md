# DOJO WALK — LGD to Service Location Mapping Policy

Status: **Proposed safe mapping; import remains disabled**  
Reviewed: 2026-10-17  
Source branch: `step-119-boundary-geometry`

## 1. Source inventory and validation

Source files are in `review/lgd_exports/`:

- `states.csv`: 36 State/UT data rows, 8 columns; UTF-8 BOM present.
- `districts.csv`: 785 district data rows, 8 columns.
- `sub_districts.csv`: 7,151 data rows, 13 columns; source date `2024-10-07`.

The Sub-District CSV was fetched from the repository Contents API and parsed with CSV quote handling. Observed checks:
- 36 distinct state codes.
- 783 distinct district codes.
- 7,151 distinct sub-district codes and 7,151 distinct State/District/Sub-District code triples.
- Required English names and administrative codes are populated in all 7,151 rows.
- All rows have `last_updated=2024-10-07`.
- Local-language names are not complete; blank local-language values must remain optional and must not be filled with guesses.

These are checks of the committed file, not proof that the snapshot is the latest official LGD release. Refresh against an authoritative current source before production import.

## 2. Safe conceptual mapping to current Firestore hierarchy

Current Service Location hierarchy is Country → State → City/District → Area/Sub-District → optional Locality/Village. There is no separate District collection/entity today.

| LGD source | Current model concept | Rule |
|---|---|---|
| State | State | Match by official code first; names are display/secondary checks. |
| District | City/District-level record | A district can occupy the existing City-level slot only when the record is explicitly tagged with its source level and LGD district code. Do not silently call it a real city. |
| Sub-District | Area/Sub-District-level record | Must retain the parent district code and official sub-district code. This is an administrative area, not a verified DOJO service polygon. |
| Village/locality | Optional Locality/Village | Not present as a full village dataset in these three CSVs; do not fabricate locality records. |

The model may retain its existing collection names for compatibility, but every imported reference record must preserve `sourceSystem=LGD`, `sourceLevel`, `sourceCode`, `sourceUpdatedAt`, and parent source codes. Check the actual model/schema and implement explicit fields before any import. Never identify records by names alone.

## 3. Four-column customer/service CSV is not the same dataset

The Admin CSV preview currently expects `State, District, City, Area`. That is a different shape from the LGD files:
- `states.csv` contains State records.
- `districts.csv` contains District records.
- `sub_districts.csv` contains Sub-District records.
- There is no separate City or DOJO service Area polygon dataset in this LGD export folder.

Therefore, do not feed the three administrative CSVs directly into the four-column service-area import. Do not duplicate District into City, and do not map a Sub-District to a service Area polygon without an explicit, reviewable transformation. An actual DOJO service area must have its own approved geometry/boundary and activation checks.

## 4. Required gates before implementation/import

1. Decide whether the current City-level model will explicitly support a `recordLevel=district` variant, or whether the schema should gain a separate District entity. This requires a compatibility review across Admin, Customer, Partner, and Firebase rules/functions.
2. Define stable source-code fields and parent-code validation; preserve leading zeros in census codes as strings.
3. Add a deterministic transformer from the three LGD files into a staging/preview format, with row counts, invalid-parent counts, duplicate source-code checks, and a downloadable audit report.
4. Keep staging read-only until transformation tests pass.
5. Create/activate a DOJO service Area only from a separately reviewed polygon that satisfies existing geometry validation. LGD sub-district names alone are not a polygon.
6. Refresh the 2024-10-07 snapshot from the authoritative source and record the source URL, retrieval date, and SHA-256 before production use.

## 5. Safety status

- No Firestore writes or imports were performed.
- No service location was activated.
- No PR was merged and no deployment was performed.


## 6. Step 162 — Existing Admin schema audit (2026-10-17)

Reviewed `lib/features/service_location/models/service_location_models.dart` and `lib/features/service_location/services/service_location_service.dart` on this branch.

Observed current Admin schema:
- `ServiceState` is stored in `service_states` and carries a `countryId`.
- `ServiceCity` is stored in `service_cities` and carries `countryId` and `stateId`; the model does not currently expose an explicit `recordLevel`, `districtCode`, or LGD source-code field.
- `ServiceArea` is stored in `service_areas` and carries `countryId`, `stateId`, and `cityId`; the model does not currently expose an explicit `subDistrictCode` or source-level field.
- `ServiceLocality` references `countryId`, `stateId`, `cityId`, and `areaId`.
- Service City and Area activation uses verified boundary records; LGD CSV records provide administrative names/codes, not verified DOJO service polygons.

Decision from this audit: **do not import LGD Districts into `service_cities` yet.** Although the parent IDs could structurally fit, the current model cannot distinguish a district record from an actual city. Do not import LGD Sub-Districts into `service_areas` as active service areas; that would confuse administrative boundaries with DOJO service coverage.

Before implementation, inspect and test Customer/Partner reads, Admin UI filters, callable functions, and Firestore rules against any proposed source metadata. The safe next design is a non-destructive, read-only staging format with explicit `sourceSystem`, `sourceLevel`, `sourceCode`, `parentSourceCode`, and `sourceUpdatedAt`; no production writes until compatibility and boundary approval are complete.
