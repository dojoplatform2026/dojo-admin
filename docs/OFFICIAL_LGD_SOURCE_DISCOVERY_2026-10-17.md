# Official LGD Source Discovery — 2026-10-17

## Finding

The current committed Sub-District reference snapshot in this repository is dated **2024-10-07**. A newer official-source discovery point is available, so the old snapshot must not be described as current.

### Official Ministry of Panchayati Raj / OGD references

- [OGD Platform — Local Government Directory (LGD) catalog](https://data.gov.in/catalog/local-government-directory-lgd) reports the catalog updated on **09 October 2026**.
- [OGD Platform — LGD Districts resource](https://data.gov.in/resource/local-government-directory-lgd-districts) reports the district resource updated on **08 October 2026** and describes it as a monthly-updated dataset.
- [Official LGD download directory](https://lgdirectory.gov.in/demo/downloadDirectory.do) exposes State, District and Sub-District export options but requires a CAPTCHA for report generation in the observed page.

The official OGD pages were discoverable, but their CSV download payloads were **not retrieved and verified during this audit**. Therefore this note does not claim that any current official CSV has been downloaded, parsed, or reconciled.

### Secondary discovery lead — not an authoritative replacement

A secondary Dataful page advertises a dataset titled “List of States, Districts, Sub-Districts, and Villages along with their LGD Codes (as of 12 Oct 2026)” and attributes its source to LGD:
https://dataful.in/datasets/21838/

The displayed dataset is a village-level denormalized table (677,673 rows, eight columns). Its metadata reports distinct-code counts that are not a substitute for independently extracted unique State/District/Sub-District master tables. Treat it as a cross-check lead only; do not use it as the canonical import master without validating the actual downloadable bytes and source lineage.

## Required next reconciliation

1. Obtain the official State, District and Sub-District exports (preferably direct official CSV/XLS files; retain original files unchanged).
2. Record exact download timestamp, source page, file name, byte size and SHA-256 for each file.
3. Validate headers, row counts, unique LGD codes, parent State/District references, duplicates, blanks and source-version fields.
4. Compare the new official exports against the current repository/Library snapshots and produce a field-level added/removed/changed report.
5. Regenerate Dart reference files only after the reconciliation report is reviewed. Preserve leading zeroes for Census codes and do not infer missing local-language names.
6. Run the reference-data integrity tests and full Admin CI.
7. Keep all data out of production Firebase until the model and District/City hierarchy design is resolved.

## Safety status

- Official current CSV bytes retrieved: **No**
- Official record reconciliation completed: **No**
- Production Firebase import authorized: **No**
