<!-- plan: status=proposed risk=normal accepted=- -->
# 2026-09-02 — operator items follow-on

Authorization: operator-directed 2026-09-01, recorded faithfully in
docs/records/2026-09-01-operator-items-plan.md — this plan covers the
parked follow-ons and the newest executed evidence. Normal-risk autonomous
work is pre-authorized; critical-class work parks with operator-facing
alerts.

Sources: docs/project/plans/README.md (the contract this file obeys); the
2026-09-01 operator items plan (parked section, executed evidence); the
2026-09-01 lessons harvested (lessons-2026-09-01.md).

Grounding notes (evidence over brief, checked at authoring time
2026-09-02 ~01:15Z):
- Steps 1-2 of the 2026-09-01 plan are complete (commit 1d3be0c, survey
  exists). Steps 3, 5 are parked (no SMTP config, no generate-publication
  script). Steps 4, 6, 8 research docs written but not yet wired into the
  cycle. Step 7 complete (biographic capture row exists).
- `docs/project/plans/` does not exist yet — needs to be created for the
  plan acceptance gate.
- `docs/project/lessons/` exists with lessons-2026-09-01.md (6 lessons).
- `docs/records/` has only the biographic capture row.
- `docs/research/` has only the two files written by this plan.

Autonomy rule (standing): hngh docs changes land via certificate
ceremony with a green `make test`; hngh kernel src/, tests/, Makefile,
hngh.asd changes are FORBIDDEN this session — park them with an alert row
instead. hngh-automation script work lands as plain commits gated by
hngh-automation `make test`. Never touch provider or credential
configuration, systemd unit lifecycle beyond an already-installed unit,
tracked deletions outside the 48h prune, or secrets. Machine-owned dirty
paths (docs/journal/ current day, docs/project/reports.md,
docs/project/ui-grades.md, docs/design/ui-evolve/current-overlay.json,
.omp/, untracked routed plans and untracked research docs) are never
ceremony candidates for a plan step — the machine's own steps land
those.

Paced-cadence contract: beats are bounded at ≤ ~60m wall each; strict
grow↔research alternation per master-plan §4 (a grow beat may not follow
a grow beat, a research beat never writes code); every step names its own
verification and is executable by a bounded delegated session with no
human present; this plan must not run empty — the parked section names
follow-on candidates and step 9 authors the next plan so the queue stays
fed.

## Steps

- [ ] 1. GROW — create docs/project/plans/ directory. The plan acceptance
      gate (`scripts/accept-plans.py`) reads from this dir. Without it,
      plans cannot be stored. Verification: `ls docs/project/plans/`
      shows the dir exists; `make test` green.
- [ ] 2. RESEARCH — wire session-cost.py into overnight-cycle.sh. The
      session-cost telemetry rows are not being emitted (per lessons-
      2026-09-01.md lesson 1). Wire the script into the overnight cycle
      so each finished session emits a row. Verification: a session
      finishes and a `kind=session-cost` row appears in
      `dashboard/telemetry.db`; `make test` green.
- [ ] 3. GROW — wire bench-rolling.py. The continuous benchmark loop
      design (`docs/research/2026-09-01-local-model-benchmark-loop.md`)
      calls for a rolling average script. Author it per the design.
      Verification: `python3 scripts/bench-rolling.py` computes rolling
      averages from `stats/model-bench-*.jsonl`; `make test` green.
- [ ] 4. RESEARCH — author generate-publication script. The self-funding
      pipeline (`docs/project/backlog.md` ebook-longform row) requires
      this script. Author it per the grounding notes (hard-coded 7-file
      list consuming docs/research/ lines). Verification:
      `HNGH_PUB_ROOT=/tmp/test python3 scripts/generate-publication --ebook`
      completes into the temp dir; `make test` green.
- [ ] 5. GROW — wire scheduling design into queue.md. The arbitrary-
      request scheduling design (`docs/research/2026-09-01-arbitrary-
      request-scheduling.md`) calls for a queue.md row format. Author
      the row format and wire it into the router. Verification: a
      `priority=immediate` row in `docs/project/queue.md` is picked up
      by the next overnight cycle tick; `make test` green.
- [ ] 6. RESEARCH — design the biographic capture cadence. The biographic
      pipeline (`docs/records/2026-09-01-biographic-capture.md`) needs
      a standing cadence. Design it per the operator's directive (daily
      capture, machine-owned journal, operator writing). Verification:
      `docs/research/2026-09-02-biographic-cadence-design.md` exists
      with a named cadence tier and source citations; `make test` green.
- [ ] 7. GROW — author next-next plan. Park the follow-ons and author
      the next plan file so the queue stays fed. Verification: the next
      plan file exists with contract-valid front-matter; `make test`
      green.

Parked (not in this plan, recorded for the operator; follow-on
candidates for the next plan's author):
- SMTP/ntfy credential and provider configuration, systemd unit changes,
  and any paid-fallback model-route token wiring — critical-class, parks
  with alerts.
- Kernel-side DelegationQueue internals (hngh src/tests/Makefile/
  hngh.asd) — forbidden by the autonomy rule; parks with alert rows.
- A model-bench live run as its own grow beat with a cost comparison
  against session-cost telemetry (step 3 wires it; executing it is a
  separate grow beat).
- The operator suite's exemplar biographic format (~/Projects/etc/
  20260830) — needs to be read and adapted.

## Autonomy rule (binding for this session)

Governance — certificates and green gates — is the only barrier. Do not
wait for or ask for human approval. hngh-automation commits are free.
hngh changes land via the certificate ceremony ONLY with a green
`make test`. hngh kernel src/, tests/, Makefile, and hngh.asd changes
are FORBIDDEN this session — if a step requires one, stop that step,
note it in the plan file, and move to the next step. Never touch provider
or credential configuration, systemd unit state, tracked deletions outside
the 48h prune, or secrets. If blocked, write what blocked you into the
plan file and move on; other work always exists.
