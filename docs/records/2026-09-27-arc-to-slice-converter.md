# arc-to-slice converter lane (2026-09-27)

Problem: 2026-09-27 operator observation that the research loop has a
dead edge -- research arcs crystallize into docs
(docs/research/<date>-<arc>.md), get dispositioned parked/killed in
research-dispositions.tsv, and nothing ever converts a crystallized
arc into an implementable dev slice; 4/4 arcs ended parked/killed with
zero code landed from them.

Design: automation/cadence/calendar/daily/29-arc-to-slice.sh scans
research-dispositions.tsv for arcs whose TERMINAL disposition (last
row per line id -- an overturned kill is adopted, not convertible) is
parked or killed dated today (UTC) and whose research-lines.tsv status
says the line crystallized. Schema note: the real tsv never holds
`crystallized` on a dispositioned line -- the review writes back
`reviewed` -- so eligibility accepts status crystallized or reviewed
and excludes planned (never crystallized). Each eligible arc gets ONE
typed Jev call (lib/typesafe.py ask_choices, floor 0.60 per the
confidence-floor table, 33-research-beat.sh call pattern):
landable-slice files an identity-deduped queue row naming the arc doc
path and the doc-derived one-line proposed slice (identity
arc-to-slice:<id>, 7d window, --evidence = the disposition's doc
token), needs-operator files the operator-item variant
(arc-to-slice-op:<id>), no-slice files nothing. Kind deviation from
the ticket: report-queue's KINDS whitelist
(scripts/report-queue:92) has no plan-candidate or operator-item kind
and scripts/report-queue sits outside automation/, so both file
`alert` rows -- the identity-deduped durable channel the router
(router-tick.py) and the lib/operator-item.sh shim both build on;
--evidence means a changed doc bumps the occurrence, an unchanged one
does not. Decisions land in the userspace home
(db/arc-to-slice/state.tsv, arc-id TAB verdict TAB ts, atomic mv
append) so an arc is asked once, ever; arcs older than 7 days (age
from the arc-YYYYMMDD id) are stale residue left to the operator.
Without TYPESAFE_API_KEY the beat fails closed: one deduped alert
(identity arc-to-slice:typed-unavailable, 7d window), no candidates.
API-error detail rides typesafe's crumb channel (26abce6d), never
duplicated here. Fail-closed: every path exits 0; on success only
breadcrumbs escape.

Out of scope by design: no plan-file drafting (the router stays the
alert->candidate bridge), no mutation of the research tsvs, no
auto-commit, and no slice work beyond the filed row -- landing the
slice remains operator/acceptance work.

Escalation shape (SLA + halt, per the 2026-09-23 escalation-sla
tune): every operator-landing row carries its own SLA and halt in the
row text. All three row types -- arc-to-slice:<id>,
arc-to-slice-op:<id>, arc-to-slice:typed-unavailable -- carry a 7d
SLA matching the identity window: stale action is expire (window
lapses; the state.tsv decision stands and the row never re-files, so
an ignored needs-operator call parks the arc rather than re-alerting).
Halt: one filing per arc, ever -- the state one-shot means daily ticks
cannot pile rows on the operator, and the typed-unavailable lane is
rate-capped at one alert per 7d and self-ends once TYPESAFE_API_KEY
returns. A filed or router-routed row is never a landed slice;
landing remains operator work.

Verification: automation/tests/test-arc-to-slice.sh (20 checks,
hermetic sandbox copy of lib/ + scripts/report-queue + the beat, stub
typesafe module): no dispositions file, parked+crystallized converts,
rerun dedupe with atomic state (no .new residue), killed arc still
consults the typed lane, typed-unavailable alert with no candidate,
7-day residue skip, operator-item variant, no-slice records without
filing, planned-line skip, malformed tsv row skips fail-closed while a
well-formed arc in the same file still converts. Registered in the
automation gate after test-omp-changelog-watch.
