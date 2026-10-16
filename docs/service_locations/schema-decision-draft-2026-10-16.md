# Service Locations: Schema Decision (Draft)
Date: 2026-10-16
Repository: dojoplatform2026/dojo-admin
Branch: audit/zone-service-area-mapping-2026-10-16

## Finding
The current UI and models combine City/District and Area/Sub-district. This is ambiguous for official administrative data versus operational service coverage.

## Recommended target
- Country
- State/UT (retain official LGD code and source metadata)
- District (separate official administrative reference entity, retain district LGD code and parent state code)
- City (operational city/service-market entity; may be linked to a district, not assumed identical to it)
- Area (operational service coverage entity with its own reviewed polygon and parent city)
- Locality/Society (optional address/locality metadata under an area; polygon not mandatory)
- Sub-district/Tehsil (retain as a separate official administrative reference dataset and parent relationship; do not silently treat as an operational area)

## Migration safety
- Do not rename or delete existing Firestore collections in place.
- Preserve existing service_cities/service_areas IDs and legacy zones IDs.
- Do not map legacy zones to new areas by name alone.
- Before migration, prepare reviewed mapping records and verify deployed Firestore Rules and indexes.
- Activation must require a verified boundary and valid parent relationships. A minimum of three distinct points is only a basic geometry check, not proof of polygon correctness or official provenance.

## Current status
Draft decision only. No application code, production Firestore data, or main branch changed. This proposal needs implementation review and Flutter tests before use.
