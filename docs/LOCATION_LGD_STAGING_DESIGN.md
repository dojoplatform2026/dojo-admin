# DOJO WALK — LGD Read-Only Staging Design

Status: design only; no production import or Firestore writes.
Branch: `step-119-boundary-geometry`
Prepared: 2026-10-17

## 1. Goal and non-goals

Convert the three committed LGD administrative CSV snapshots into a deterministic, reviewable staging dataset. This is not a service-location import. The staged records must not create or activate `service_states`, `service_cities`, `service_areas`, `service_localities`, or verified boundary documents.

Non-goals:
- Do not invent City records from Districts.
- Do not treat LGD Sub-Districts as DOJO service Areas.
- Do not generate or infer service polygons from administrative names.
- Do not write to Firestore or change customer/partner production reads.

## 2. Inputs and source field mapping

Input files in `review/lgd_exports/`:
- `states.csv`: source headers include `State Code`, `State Name (In English)`, `State Name (In Local)`, `Census 2001 Code`, `Census 2011 Code`, `State or UT`.
- `districts.csv`: `state_code`, `state_name_english`, `state_census2011_code`, `district_code`, `district_name_english`, `district_census2011_code` and local-name columns.
- `sub_districts.csv`: 13-column LGD export; its committed snapshot reports last_updated `2024-10-07`. Re-check source freshness before any real use.

Keep source codes as strings in staging, even if a column looks numeric. Preserve leading zeros (especially Census codes). Never derive LGD codes from names or row numbers.

## 3. Canonical read-only staging record

Use a versioned JSON Lines file (one JSON object per line) for the first implementation. It is easier to validate mixed optional fields without forcing State, District and Sub-District into a false common service schema.

Required/common fields:
- `schemaVersion`: integer, initially `1`.
- `sourceSystem`: `LGD`.
- `sourceLevel`: one of `state`, `district`, `sub_district`.
- `sourceCode`: original LGD code, serialized as a string.
- `sourceNameEnglish`: trimmed display value; retain raw input separately.
- `sourceNameLocal`: trimmed value or null; missing local-language names are allowed.
- `parentSourceLevel`: `null` for state, `state` for district, `district` for sub-district.
- `parentSourceCode`: `null` for state; otherwise original parent LGD code as string.
- `sourceUpdatedAt`: source-provided date when present; otherwise null, never guessed.
- `sourceFile`: exact relative input path.
- `sourceRowNumber`: original CSV data row number (1-based after header) for audit/debugging.
- `rawSourceFields`: source header-to-value mapping, retaining original values before trimming.

Additional source fields may include Census codes and State/UT classification, all stored as strings when they are codes. Do not collapse LGD code and Census code into a single field.

## 4. Deterministic identity and relationships

- Staging identity: `LGD|<sourceLevel>|<sourceCode>`. Do not use names as identity.
- District parent must match an existing State `sourceCode`.
- Sub-District parent must match an existing District `sourceCode`, and its state code must match that District's state parent.
- Reject ambiguous duplicate source codes within the same source level. Also report duplicate full parent-child combinations separately.
- Names may be normalized for duplicate detection (Unicode normalization, trim, collapse whitespace, case-fold) but must not be used to silently merge records.
- Preserve source row order only for traceability, never for identity.

## 5. Validation report

Every run should emit a machine-readable report and a human-readable summary with:
1. input filename, byte size, SHA-256, header, and snapshot/source date if available;
2. parsed row count and expected column count per file;
3. UTF-8 BOM handling and quoted CSV correctness;
4. blank/duplicate headers, malformed rows, missing required codes/names;
5. duplicate source codes by level;
6. missing parent codes and state/district parent mismatches;
7. local-language missing counts (warning only);
8. source-code collisions across levels (informational, not automatically invalid);
9. output record count by level and deterministic output hash.

Any malformed row, duplicate same-level source code, missing required code/name, or invalid parent relation fails the staging run. Missing local-language names and absent optional Census codes are warnings unless the source specification says otherwise. No partial output should be presented as a successful complete dataset.

## 6. Safe execution boundary

Phase A: parse and validate local/exported files only.
Phase B: generate staging output and report as repository artifacts for review.
Phase C: human review of source freshness, counts, parent integrity, and sample records.
Phase D: separate design approval for mapping administrative records to DOJO service entities.
Phase E: only after explicit approval, implement a separate migration plan with emulator tests, rollback strategy, and boundary verification.

The initial implementation must have no Firebase SDK dependency, no callable functions, no credentials, and no production write path.

## 7. Required tests before staging implementation is called complete

- UTF-8 BOM in headers.
- Quoted commas, escaped quotes, and quoted multiline values.
- Empty/duplicate headers and wrong field count.
- Leading-zero source codes preserved exactly.
- Duplicate state/district/sub-district code detection.
- District whose state parent is missing.
- Sub-District whose district parent is missing.
- Sub-District with a state code inconsistent with its District.
- Missing local-language name accepted as warning.
- Deterministic output across two runs with identical inputs.
- Input hash changes when a source file changes.
- Failure must not leave a success-marked partial output.

## 8. Current guardrails

- Read-only staging only.
- No Firestore import/write, no activation, no PR merge, and no deployment.
- Current source freshness for the 2024-10-07 Sub-District snapshot is not verified by this design.
- Customer addresses remain free-text; Partner still reads legacy `zones`. Cross-app migration is separate work.
