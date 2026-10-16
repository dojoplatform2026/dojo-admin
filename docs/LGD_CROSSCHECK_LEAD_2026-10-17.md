# LGD Cross-check Lead — 2026-10-17 (Not Authoritative)

## Why this note exists

The official OGD catalog lists a Local Government Directory (LGD) catalog updated on 15 October 2026, and a Districts resource updated on 8 October 2026. The official catalog page was reachable, but the ZIP/API retrieval did not return a usable export during this check. The official LGD portal's download flow includes CAPTCHA.

Official sources:
- Ministry of Panchayati Raj LGD overview: https://panchayat.gov.in/en/lgd/
- OGD LGD catalog: https://www.data.gov.in/catalog/local-government-directory-lgd
- OGD LGD Districts resource: https://www.data.gov.in/resource/local-government-directory-lgd-districts
- LGD download directory: https://lgdirectory.gov.in/demo/downloadDirectory.do

## Third-party cross-check lead

Dataful advertises a dataset titled “List of States, Districts, Sub-Districts, and Villages along with their LGD Codes (as of 12 Oct 2026)”. Its public metadata states:
- Last updated: 12 October 2026
- 677,673 rows and 8 columns
- Distinct state codes: 35
- Distinct district codes: 781
- Distinct sub-district codes: 7,081

Reference page: https://dataful.in/datasets/21838/

**Critical caveat:** Dataful is a third-party redistribution, not the official LGD download endpoint. Its metadata is only a lead for a later comparison; it does not establish the official totals. The row data itself was not downloaded and reconciled in this step. The 35 distinct state codes also should not be interpreted as 35 States/UTs without checking whether every entity is represented and how the dataset encodes the hierarchy.

## Local snapshot under review

The restored Dart snapshot currently has:
- 36 State / UT records
- 785 District records
- 7,151 Sub-district records

Differences between these summary counts and third-party metadata are **flags for investigation**, not evidence of specific missing or extra records. Counts may differ because of dataset scope, code uniqueness, timing, or data quality. Do not edit generated Dart files based on counts alone.

## Reconciliation procedure once a downloadable export is available

1. Preserve the original official export without editing.
2. Record retrieval timestamp, official source URL, filename, and SHA-256.
3. Normalize codes as strings for comparisons where leading zeros may exist; do not discard zeros.
4. Compare distinct codes, duplicate codes, names, state parents, district parents, and additions/removals.
5. Inspect each difference and classify it as a confirmed official change, scope difference, data error, or unresolved.
6. Generate a machine-readable CSV report plus a human-readable summary.
7. Update the Dart references only after reviewed differences are resolved, then run CI.

## Gate

Official record-level reconciliation: **PENDING**.  
Production import / activation: **BLOCKED** until official reconciliation and geographic polygon verification are complete.
