# DOJO WALK Location Master — Step 42

Date: 2026-10-17  
Branch: `restore/india-location-reference-data`  
Pull request: [#6 — Restore India location reference data](https://github.com/dojoplatform2026/dojo-admin/pull/6)

## Parent/child polygon containment — CI pending

Added `ServiceLocationBoundary.isContainedBy(parent)` using planar longitude/latitude geometry. It requires both polygons to pass model validation, rejects proper crossings between child and parent edges, and requires each child vertex to be inside or on the parent boundary.

Regression tests cover:
- Area polygon fully inside City polygon.
- Area polygon extending outside City polygon.
- Invalid child polygon rejected.

Validation workflows: [38975696435](https://github.com/dojoplatform2026/dojo-admin/actions/runs/38975696435) and [38975692845](https://github.com/dojoplatform2026/dojo-admin/actions/runs/38975692845).

## Limitations and remaining gates

- This is planar geometry only, not geodesic or antimeridian-safe validation.
- The containment helper is not yet wired into the save/verification lifecycle.
- Locality-inside-Area lifecycle enforcement, authoritative boundary provenance, official LGD row-level reconciliation, and map source integration remain pending.
- Do not import or activate reference records in production Firebase; keep PR #6 open.
