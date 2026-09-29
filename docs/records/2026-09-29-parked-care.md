# Parked-items automated care (2026-09-29)

## Problem

Parked report-queue rows accumulate as scattered singles: the park
note ("filed as backlog debt; revisit at the next disposition sweep")
promises a sweep revisit, but nothing combines debt that plainly
belongs together (8 kernel research questions, 8 router slow-unit
dropins, 8 parked research arcs). The 2026-09-29 shelf held 165 parked
rows.

## Change

- `automation/jobs/parked-care.py`: reads the report queue's parked
  rows (same read as the composer's parked digest; seams
  `HNGH_REPORT_QUEUE`/`HNGH_REPORT_ROOT`), tokenizes why texts
  (`[a-z0-9]{4,}`, park*/stop-words/function words excluded), and
  emits one `needs` TSV row per kin group: the row-set of each rare
  token (corpus df 2..KIN_DF_MAX=8), identical member sets merged,
  top GROUPS_CAP=8 groups by size.
- Relation design, carved by live-smoke failures against the real
  shelf:
  - transitive closure over any-shared-token edges collapsed the
    shelf into one 100+-row blob (first through quoted report ids,
    then ISO/millisecond timestamp fragments, then plain bridge
    words) — replaced by per-token groups: a rare token's row-set IS
    the group, so the blob class is structurally impossible;
  - digits mark a pointer (report ids, hex tails like `2070c5`, ISO
    fragments like `15t17`, millisecond `298z`), never a keyword —
    any digit-bearing token is excluded;
  - the settled park templates are boilerplate: a stop list carries
    their vocabulary ("filed/backlog/debt/revisit/disposition/sweep",
    "expired as stale", "suppressed as duplicate identity",
    "acknowledged: <note>") plus function words.
- `automation/cadence/calendar/daily/12-parked-care.sh`: files each
  emitted row as a crumbs-journal breadcrumb (curator-beat protocol:
  disposed-stamp normalization + grep dedup against the journal
  export). Read-only: the queue is never mutated. Fail-closed: exit 0
  on every expected path.
- Emit-dedupe contract: the crumb detail is derived from the kin
  group itself (hot tokens + sorted unique ids + why previews), so
  the crumbs journal absorbs identical repeats (pinned by test); a
  membership change is new information and legitimately refiles once
  at the daily tier. The job never files report-queue rows and never
  re-parks: the combined item is a breadcrumb (needs), and the parked
  rows' whys — the guidance notes — ride in the detail as the
  payload.
- `automation/tests/test-parked-care.py` (10 tests): kin combine,
  park-word and card-class-only non-relations, per-token rarity-band
  bounding with bridges, mid-frequency vocabulary exclusion,
  pointer-fragment exclusion, fail-closed empty/broken queue,
  determinism, wrapper end-to-end (crumb filed once, rerun deduped).
  Registered in `automation/Makefile` `test:`.

## Verification

- Suite: 10/10 OK.
- Full gate (`cd automation && make test`): GREEN.
- Live shelf (165 parked rows): 8 kin groups, all subject tokens
  (dropin, evidence, kernel, question, unverified, session,
  threshold, newspaper), 7-8 unique ids each (ledger resurrections
  deduped), no blob, no pointer garbage.
