# DOJO WALK Location Master — Official LGD Source Discovery (Step 24A)

Date checked: 2026-10-17  
Branch: `restore/india-location-reference-data`

## Findings

1. The Ministry of Panchayati Raj's LGD page describes LGD as the official directory assigning unique location codes to existing and newly created local-government entities. Source: https://panchayat.gov.in/en/lgd/
2. The official OGD Platform India catalog for Local Government Directory was shown as updated **15 October 2026** during this check. Its page exposes a Catalog API and a Zip Download link, but the page's download endpoint returned HTTP 503 when followed in this session. Source: https://www.data.gov.in/catalog/local-government-directory-lgd
3. The official OGD Districts resource was shown as updated **8 October 2026**. Source: https://www.data.gov.in/resource/local-government-directory-lgd-districts
4. The LGD portal's Download Directory page offers entity-wise or state-wise exports and includes a CAPTCHA. Source: https://lgdirectory.gov.in/demo/downloadDirectory.do
5. A third-party dataset page advertises a dataset dated 12 October 2026, but it is not itself the official download source. It can be used only as a lead for cross-checking and must not be treated as the authoritative baseline. Source: https://dataful.in/datasets/21838/

## Decision

**Official record-by-record reconciliation remains BLOCKED / not complete.** The official catalog metadata confirms newer data resources exist, but a metadata date alone does not provide the export contents needed for a trustworthy code-by-code comparison. The catalog ZIP could not be retrieved in this check (HTTP 503), and the LGD portal's export flow requires normal user interaction with CAPTCHA.

## Next actions

1. Retry the official OGD Catalog API / ZIP download through an accessible official route, or obtain the export using the normal LGD portal flow.
2. If the portal requires CAPTCHA, a human must complete it; do not bypass or automate around it.
3. Once the export file is available, preserve the original file and record source URL, retrieval date, and SHA-256 checksum.
4. Run deterministic comparisons against the restored reference files: unique codes, names, state/district parents, added/removed records, and renamed/changed parent chains.
5. Save a machine-readable difference report before updating any generated Dart data.
6. Keep PR #6 open; do not import into production Firebase or activate service areas until official data reconciliation and polygon boundary checks pass.

## Current local snapshot (for comparison only)

- States / UTs: 36
- Districts: 785
- Sub-districts: 7,151

These are local snapshot counts and are not an assertion of current official counts or completeness.
