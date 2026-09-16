# 2026-09-16 — read-side ledger surfaces: graph alert-node ingestion and
the system-feed root fallback

## The question

Follow-up to the report-ledger exposure work (emitter-side redaction
backstops landed the same day): two READ-side consumers of the public
ledger were named as unguarded. Can raw alert-row text or absolute
paths reach dashboard surfaces, and was the hardcoded machine root in
system-feed reachable?

## Surface 1: graph-data patrol-alert ingestion (jobs/graph-data.py)

The patrol-state block re-derived `alerting` from `dashboard/reports.md`
(the ledger symlink) by testing whether cell 4 `startswith("patrol:")`.
The live ledger row shape is `| ts | kind | id | first line | body |`
(report-queue): cell 4 is a hex id, so the matcher matched ZERO live
rows — patrol alerting states in /graph.json were permanently dead in
production while the suite stayed green (the fixture still seeded the
obsolete `| ts | patrol-fail | patrol:x | ... |` shape).

The dangerous repair — rescanning raw text — would leak: first lines
carry arbitrary prose and absolute paths (real rows:
`research line ...: -> /home/<user>/.hngh/archive/digest/...`), and a
naive `cols[3].split(":", 1)[1]` on any `patrol:` substring would mint
node ids like `patrol:not-a-surface` out of pathy text
(`/home/x/patrol:not-a-surface`), served by /graph.json to any LAN
viewer. session/story views already render ledger text wholesale BY
DESIGN (operator surface); /graph.json is a structured surface where
ids must stay registry-shaped.

Fix (test-first, red-proven): kind-gated extraction. kind=alert rows
are scanned with `PATROL_TOKEN_RE`
(`(?:^|[^\w:-])patrol:([A-Za-z0-9][A-Za-z0-9_-]*)` — token anchored at
string start or after whitespace/punctuation, never mid-path; body cell
not scanned) and the result is intersected with the patrol registry
before any node id exists. kind=patrol-fail keeps the legacy direct
parse. Rows naming unknown patrols are dropped, never minted.

Validation on the live ledger (read-only): 110 alert rows trailing 24h,
9 tokens extracted, all 9 are registry patrol ids, zero registry-foreign,
zero pathy tokens. Detection is revived and safe.

## Surface 2: system-feed root fallback (jobs/system-feed.py)

`REPORTS_MD` resolved HNGH_HOME -> HNGH_REPO -> hardcoded
`/home/bricker/Projects/etc/hngh`. The path never reached the dashboard
feed (probe_backups embeds only ledger row text, and no /home/ rows
exist in the live ledger since the emitter redaction landed), but the
fallback is a named README sweep item and breaks on any other checkout
path. Fix: `report_ledger_path()` — explicit arg, then HNGH_HOME /
HNGH_REPO env, else the repo that ships the script
(dirname(ROOT)). Env still wins; the machine path is gone from source
(README sweep list updated). Note: hngh_home.py was considered but is
the ~/.hngh userspace home seam, not a repo-root resolver — the
script-relative default is the correct generalization here.

## Guard-node / patrol behavior kept intact

The alerting set feeds the same `state = alerting if pid in alerting`
logic as before; guard nodes, surfaces, watches edges, and the 24h
cutoff are untouched. Existing tests pass unchanged except the fixture
which now also seeds live-format rows.

## Tests

- tests/test-graph-data.py: fixture gains live-format alert rows
  (pathy first lines, a patrol-naming dedup row, a pathy decoy token
  mid-path, a kind=progress row naming a surface — must never alert);
  new tests: alert rows never leak paths/prose into node ids;
  live-format alert rows alert matching patrols ONLY.
- tests/test-system-feed.py: new RepoRootResolution class — no
  hardcoded machine path (or del-refs-style user@host literal) in
  source; env unset resolves script-relative; env still wins.
- Both suites registered in `make test` (they had shipped unregistered;
  unregistered tests are dead tests).

## Not done here

- CHANGELOG entry deferred to the consolidating security lane (file
  shared with three in-flight sibling entries; same-day record).
- The remaining README sweep items (agent-supervision, research-feed,
  oversight-tick, system-awareness, lesson-harvest, systemd units) are
  a separate slice.
