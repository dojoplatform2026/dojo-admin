# Official LGD Export Reconciliation — Runbook

Status date: 2026-10-17  
Repository branch: `restore/india-location-reference-data`

## Goal

Compare the restored India reference records against a verifiable export from the live Government of India Local Government Directory (LGD). This is a source-validation step; it does not authorize a production import.

## Source hierarchy

1. Prefer a file downloaded directly from the live LGD portal: https://lgdirectory.gov.in/
2. Ministry overview: https://panchayat.gov.in/en/lgd/
3. OGD catalog/resource pages may help discover resources, but the pages reviewed on 2026-10-17 explicitly identified the site as a sandbox/testing environment and warned that data may be incomplete or inaccurate. Do not treat its displayed update dates alone as proof of a current authoritative export.

## Export requirements

Obtain three exports where available:
- State / Union Territory directory
- District directory
- Sub-district directory

For each downloaded file, preserve the original unedited file and record:
- Exact download date/time (IST)
- Page or download URL
- Entity/report name and any selected filters
- Original filename and format
- SHA-256 checksum
- Any date/version printed inside the export

If the portal asks for CAPTCHA, complete it manually in the browser. Do not attempt to bypass the CAPTCHA or substitute a sandbox file without clearly marking it.

## Comparison checklist

For each entity type, compare using LGD codes as identifiers—not names alone.

- Count rows and distinct LGD codes.
- Detect duplicate codes.
- Detect additions and removals relative to the restored snapshot.
- Detect name changes for matching codes.
- For districts, verify each state parent code and parent name.
- For sub-districts, verify each state and district parent code/name.
- Preserve codes as strings where source formats may contain leading zeroes; normalize types deliberately only where the reference model requires it.
- Report unmatched rows separately instead of silently dropping them.
- Review all differences before changing generated Dart files.

## Existing snapshot baseline (not a freshness claim)

| Entity | Existing count | Unique-code check |
|---|---:|---|
| States / UTs | 36 | 36 unique LGD codes |
| Districts | 785 | 785 unique district codes |
| Sub-districts | 7,151 | 7,151 unique sub-district codes |

Internal parent-code/name checks passed for the restored snapshot. That only establishes internal consistency; it does not establish current official completeness. A Ministry annual-report dashboard found during research showed different district/sub-district totals for its reporting point. Those totals are a comparison lead, not enough by themselves to prove the restored data is wrong because the snapshot dates and definitions may differ.

## Acceptance criteria

Do not mark reconciliation complete until:
- All three original exports are available and their source/date/checksums are recorded.
- Counts, duplicate checks, additions/removals, renames, and parent mappings have a reviewed result.
- Every discrepancy is either resolved or explicitly documented as an accepted, explained difference.
- A repeatable validation artifact and report are committed to the branch.
- The reference-data integration tests are added and CI passes.

## Current blocker / next action

The public LGD download page exposes a CAPTCHA-protected report flow. An automated current export has not been obtained in this pass. Next, obtain the three files through the live portal (manual CAPTCHA if prompted), then place the original exports in a review-only location or attach them to the working conversation so they can be reconciled. Until then, current-source reconciliation remains **PENDING**.

## Safety boundary

Do not overwrite the restored Dart data, merge PR #6, import the snapshot into production Firebase, or activate service boundaries based solely on internal consistency or OGD metadata.


## Additional comparison lead discovered (2026-10-17)

A public GitHub Gist describes a sub-district CSV as exported from the live LGD download flow. The gist shows last activity on 2026-06-21. It may be useful as an **interim cross-check only**, not as the final official snapshot, because it is third-party hosted, covers sub-districts only in the surfaced file, and predates this status date.

- Gist page: https://gist.github.com/planemad/b2195c7feb506f8436659f36da1e58af
- The page links a raw CSV and states that it was exported from `https://lgdirectory.gov.in/downloadDirectory.do`.
- Do not replace the direct live LGD export requirement with this file. If used for investigation, record its capture date, checksum, and provenance separately, and label results “secondary comparison” until checked against a fresh export from the live portal.


## Newer secondary cross-check lead (2026-10-17)

A third-party data platform, Dataful, lists a dataset titled “List of States, Districts, Sub-Districts, and Villages along with their LGD Codes (as of 12 Oct 2026)” and attributes the source to the Ministry of Panchayati Raj / Local Government Directory. Page: https://dataful.in/datasets/21838/

The page reports 677,673 village rows and these distinct-code counts within its village-based table: 35 state codes, 781 district codes, and 7,081 sub-district codes. These are **not directly comparable entity-table totals**: the table is village-granular and only shows entities represented in village rows. It is also hosted by a third party, so treat it as a strong lead for cross-checking—not as a substitute for original files downloaded from the live LGD portal.

Compared with the restored standalone reference files (36 states/UTs, 785 districts, 7,151 sub-districts), these counts signal that a careful code-level reconciliation is important. Do not assume every difference is an error; check the dataset's coverage, extraction date, entity definitions, and parent mappings. No production or Dart data was changed based on this secondary listing.

## Repeatable CSV comparison tool (added 2026-10-17)

A dependency-free Python tool and unit tests are now in the branch:
- `tool/reconcile_lgd_csv.py`
- `tool_tests/test_reconcile_lgd_csv.py`

Run the tests with:

```bash
python -m unittest discover -s tool_tests -v
```

For each entity, export the existing snapshot to CSV without modifying the original Dart files, download the matching fresh export from the live LGD portal, and compare using the exact header names shown in those two CSVs. Example (replace sample header names with the actual export headers):

```bash
python tool/reconcile_lgd_csv.py \
  --baseline review/baseline_states.csv \
  --official review/official_states.csv \
  --key "State LGD Code" \
  --compare "State Name,State Name (In Local language)" \
  --output review/states_reconciliation.json
```

Repeat for districts and sub-districts, including the parent-code/name fields in `--compare`. The script trims surrounding whitespace but does not silently normalize code values, case, punctuation, or names. It reports added/removed keys and changed fields. Exit code 0 means no differences; 1 means differences exist; 2 means the input/header is invalid. Duplicate keys and empty keys are errors. Review differences manually before any Dart data update.

The Flutter validation workflow now runs these Python unit tests before Flutter analysis/tests/build. This tooling prepares the reconciliation but does **not** mean the official export comparison has been completed; the live LGD files are still required.

