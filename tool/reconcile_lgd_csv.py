#!/usr/bin/env python3
"""Compare an existing LGD CSV snapshot with a freshly downloaded official CSV.

This tool deliberately does not guess column names. Pass the exact header names
from each CSV with --key and --compare, so code/parent fields are compared
explicitly. Files are read as UTF-8 (BOM accepted); values are trimmed but
otherwise preserved. It writes a JSON report and exits non-zero on duplicate
keys or any record differences.
"""
from __future__ import annotations

import argparse
import csv
import json
import sys
from pathlib import Path
from typing import Any


def read_csv(path: str, key_column: str, compare_columns: list[str]) -> dict[str, dict[str, str]]:
    rows: dict[str, dict[str, str]] = {}
    with open(path, "r", encoding="utf-8-sig", newline="") as handle:
        reader = csv.DictReader(handle)
        if not reader.fieldnames:
            raise ValueError(f"{path}: CSV has no header")
        required = [key_column, *compare_columns]
        missing = [column for column in required if column not in reader.fieldnames]
        if missing:
            raise ValueError(f"{path}: missing column(s): {', '.join(missing)}")
        for line_number, raw in enumerate(reader, start=2):
            row = {str(k): (v or "").strip() for k, v in raw.items() if k is not None}
            key = row.get(key_column, "")
            if not key:
                raise ValueError(f"{path}:{line_number}: empty key in {key_column!r}")
            if key in rows:
                raise ValueError(f"{path}:{line_number}: duplicate key {key!r}")
            rows[key] = row
    return rows


def compare_csvs(baseline_path: str, official_path: str, key_column: str,
                 compare_columns: list[str]) -> dict[str, Any]:
    baseline = read_csv(baseline_path, key_column, compare_columns)
    official = read_csv(official_path, key_column, compare_columns)
    old_keys, new_keys = set(baseline), set(official)
    added, removed = sorted(new_keys - old_keys), sorted(old_keys - new_keys)
    changed = []
    for key in sorted(old_keys & new_keys):
        differences = {
            column: {"baseline": baseline[key].get(column, ""),
                     "official": official[key].get(column, "")}
            for column in compare_columns
            if baseline[key].get(column, "") != official[key].get(column, "")
        }
        if differences:
            changed.append({"key": key, "fields": differences})
    return {
        "baseline_file": str(baseline_path),
        "official_file": str(official_path),
        "key_column": key_column,
        "compare_columns": compare_columns,
        "baseline_rows": len(baseline),
        "official_rows": len(official),
        "baseline_unique_keys": len(baseline),
        "official_unique_keys": len(official),
        "added_in_official": added,
        "removed_from_official": removed,
        "changed_records": changed,
        "passed": not (added or removed or changed),
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--baseline", required=True, help="CSV exported from the current restored snapshot")
    parser.add_argument("--official", required=True, help="Original CSV downloaded from the live LGD portal")
    parser.add_argument("--key", required=True, help="Exact LGD code column name in both files")
    parser.add_argument("--compare", required=True,
                        help="Comma-separated exact columns to compare, e.g. State Name,Parent State Code")
    parser.add_argument("--output", help="Optional JSON report path (default: stdout)")
    args = parser.parse_args()
    columns = [part.strip() for part in args.compare.split(",") if part.strip()]
    if not columns:
        parser.error("--compare must contain at least one column")
    try:
        report = compare_csvs(args.baseline, args.official, args.key, columns)
    except (OSError, ValueError, csv.Error) as error:
        print(f"ERROR: {error}", file=sys.stderr)
        return 2
    output = json.dumps(report, ensure_ascii=False, indent=2) + "\n"
    if args.output:
        Path(args.output).write_text(output, encoding="utf-8")
    else:
        print(output, end="")
    return 0 if report["passed"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
