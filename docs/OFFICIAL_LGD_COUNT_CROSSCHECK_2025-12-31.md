# Official Ministry Baseline — LGD Count Cross-check (Step 24C)

Checked: 2026-10-17  
Branch: `restore/india-location-reference-data`

## Official Ministry publication found

The Ministry of Panchayati Raj Annual Report 2025–2026 includes an LGD dashboard figure labelled “Fig. 10.9. LGD Application Dashboard” and states the following counts **as of 31 December 2025**:
- States / Union Territories: 36 (28 States + 8 UTs)
- Districts: 778
- Sub-districts: 7,071

Source: Ministry of Panchayati Raj, Annual Report 2025–2026, section 10.9, page 78: https://cdnbbsr.s3waas.gov.in/s316026d60ff9b54410b3435b403afd226/uploads/2026/02/20260224563334790.pdf

## Comparison against restored reference snapshot

| Entity | Restored local snapshot | Ministry annual-report dashboard (31 Dec 2025) | Difference: local minus report |
|---|---:|---:|---:|
| States / UTs | 36 | 36 | 0 |
| Districts | 785 | 778 | +7 |
| Sub-districts | 7,151 | 7,071 | +80 |

## Interpretation — do not infer errors from totals alone

- The State/UT total matches the Ministry dashboard.
- District and sub-district totals differ. This is a material reconciliation flag, but the annual-report figure is a historical reporting point, not a current row-level export.
- This comparison does not identify which codes are extra/missing, nor prove that all differences are invalid. Administrative changes, snapshot dates, coverage, or reporting definitions may explain some differences.
- No generated Dart data has been changed on the basis of these totals.

## Next verification action

Obtain the live LGD State/UT, District, and Sub-district exports through the normal portal flow. Preserve each original file and checksum, then compare row-by-row by LGD code and parent code. If CAPTCHA is shown, complete it manually; do not bypass it.

## Gate

Official current record-level reconciliation: **PENDING**.  
Production import, PR merge, and service activation remain blocked until differences are explained and geographic boundaries are verified.
