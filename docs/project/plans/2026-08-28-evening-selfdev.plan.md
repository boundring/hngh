<!-- plan: status=executed risk=normal accepted=2026-08-28T19:43:12Z -->
# 2026-08-28 — evening selfdev

Autonomous evening wave while the operator is away. Operator
authorization: operator away 2026-08-28 ~19:30Z–late evening UTC,
explicitly pre-authorized autonomous normal-risk development in this
session; critical-class work parks with operator-facing alerts. Sources:
docs/records/2026-08-28-automation-advancement.md Next-necessary list
(items 1–4), docs/project/backlog.md "Cadence watch fixes" row (the
automation gate sat red on HEAD 2026-08-28 with no alert because
cadence/day/03-gate-check.sh sweeps only the kernel), and the
ledger-and-records-spec.md sequencing. Autonomy rule (also in the
overnight-cycle prompt): hngh docs changes land via certificate ceremony
with a green `make test`; hngh kernel src/tests/Makefile/hngh.asd
changes are FORBIDDEN — park them. hngh-automation script work lands as
plain commits, each gated by hngh-automation `make test` green (which
step 1 restores). Never touch provider or credential configuration,
systemd unit state, tracked deletions outside the 48h prune, or
secrets.

Parked (not in this plan, recorded for the operator):
- omp-bridge create-run refusal carries no cause (alert a1fde252,
  lessons-consolidation lesson 5): the sharpening is a kernel
  src/tests change — forbidden to machine sessions by the standing
  autonomy rule. Parks.
- OpenRouter remote GLM leg activation (token file placement):
  operator-critical class. Parks.

## Steps

- [x] 1. Automation gate repair — lint-identifiers heredoc scoping +
      dead TS_SUBNET. `jobs/lint-identifiers.sh` currently skips heredoc
      bodies for DEFINITIONS but still counts references, so
      `scripts/deck-setup.sh` (the hngh-connect dispatcher heredoc,
      `$DESK_LAN_IP`/`$DESK_TS_IP` defined at line 180 inside the
      heredoc, referenced at 183–184) reports referenced-never-defined.
      Teach the scanner heredoc scoping so a definition inside a heredoc
      satisfies references inside the same heredoc body (definitions and
      references tracked per-heredoc-tag, same line-walking pass; or a
      scoped exclusion if the general rule is not clean). Remove the
      dead `TS_SUBNET` line from `scripts/hngh-ufw-manage.sh:16`
      (defined, never referenced). Plain commit in hngh-automation.
      Verification: `cd hngh-automation && make test` exits 0 on HEAD —
      `scripts/lint-identifiers.sh` reports 0 problems (reproduced red
      2026-08-28 with exactly 3 findings: the two DESK_* refs and
      TS_SUBNET); deck-setup.sh and hngh-ufw-manage.sh behavior
      unchanged (`bash -n` both).

- [x] 2. Day-tier drop-in gates BOTH repos. Extend
      `cadence/day/03-gate-check.sh`: after the kernel gate, run
      `make test` in `$AUTOMATION_ROOT` (same timeout, fail-closed
      style) and file the honest signal — a `gate: hngh-automation make
      test green` progress row / `gate-check:automation` identity
      breadcrumb when green, an alert row with the last ~10 error lines
      when red. No new units; same drop-in. Plain commit.
      Verification: run `cadence-tick.sh TIER=day` (or invoke the
      drop-in directly with `JOB_NAME` set) on a green tree → both
      gate-green breadcrumbs and both progress rows appear; induce a
      red in a fixture copy (e.g. a scratch tree with a lint failure)
      → alert row with the 3 lint findings text. Day-tier `make test`
      green on HEAD after landing.

- [x] 3. Tree-skew whitelist for machine-maintained append paths.
      The oversight tree-skew probe fired x64 on files the machine
      itself regenerates every few minutes (reports.md, ui-grades.md,
      docs/design/ui-evolve/current-overlay.json, plan status
      transitions) — alert 96bd99de, backlog row evidence. Add these
      paths to the probe's whitelist (or a
      machine-maintained-paths list next to it) so tree-skew only
      fires on genuinely stalled agent edits. Plain commit.
      Verification: run the oversight tick against the current tree
      (dirty with exactly those paths) → no tree-skew alert filed;
      introduce a scratch modification to a non-whitelisted tracked
      file in a fixture → alert still fires.

- [x] 4. Review digest hygiene — findings, not prompt echo.
      `cadence/day/04-review-prep.sh` ships `digest/REVIEW-<date>.md`
      with the echoed prompt plus raw diffs (~1100 lines) around the
      findings. Keep the findings sections (the `## hngh` /
      `## hngh-automation` verdict blocks, model + wall_s header, and
      the commit range reviewed); drop the prompt echo and raw diff
      bodies (the commits are in git; cite the range hash instead).
      Plain commit.
      Verification: next REVIEW digest contains the findings blocks and
      the reviewed-range hash, and no longer contains the verbatim
      prompt preamble ("You are doing a fresh-eyes review...") nor raw
      `diff --git` hunks; file size drops by an order of magnitude;
      `make test` green.

- [x] 5. Telemetry readers — first consumers over
      `dashboard/telemetry.db` (capture-first store has data since
      `232c5fe`; zero readers today by design). Add
      `jobs/telemetry-report.py`: read-only stdlib-sqlite queries
      producing (a) per-day event counts by source/kind, (b) a
      research-cost summary (research-beat rows per subject), (c) a
      session-cost stub table fed by step 6 once it lands. Fail-closed:
      missing store → exit 0 with a notice, never a crash. Read-only
      against the db (no schema changes needed — SELECT only). Plain
      commit.
      Verification: `python3 jobs/telemetry-report.py --day 2026-08-28`
      prints counts that match direct sqlite3 queries on the same db
      (spot-check two numbers); run against a missing db path → notice
      + exit 0.

- [x] 6. Session-cost capture per ledger-and-records-spec.md §3.
      One row per omp session: parse token usage from session
      transcripts (the same `~/.omp/agent/sessions/<project>/` jsonl
      files `jobs/sessions-feed.py` already tail-reads — reuse its
      discovery helpers, do not duplicate) plus model/duration; emit
      through `jobs/telemetry.py emit --kind session-cost`. Producer
      before views, per the spec's sequencing; capture only, no
      dashboard changes. Plain commit.
      Verification: emit for a known finished session → one telemetry
      row with model + token fields populated (spot-check against the
      transcript's own usage fields); transcript with no usage data →
      row with nulls, never a failure; re-run is idempotent (dedup by
      session id).

- [x] 7. Watchdog/oversight consuming day-tier gate-red rows. The
      gate-red alert rows (identity `gate-check:hngh`, and
      `gate-check:automation` after step 2) already land in the ledger;
      arming the 5m oversight on them is wiring, not new machinery.
      Extend `jobs/oversight-tick.sh`: on an unexpired gate-red alert
      row, surface an operator-facing alert (dedup identity per repo,
      escalation-cap semantics per the report-queue escalation lesson)
      so a red gate cannot sit unnoticed overnight as this one did.
      Plain commit.
      Verification: file a synthetic gate-red alert via report-queue in
      a fixture report root → oversight tick emits the operator-facing
      alert once (dedup holds on second run); green state → no alert.

- [x] 8. ui-audit findings feeding oversight. The ui-audit alert
      identities are already per-rule (36 ui-audit events in the
      telemetry store today); the 5m consumer needs only a read.
      Extend the oversight tick (same pass as step 7) to count open
      ui-audit alert rows and file a single summary breadcrumb when a
      rule's violation count crosses its previous value (regression
      signal), staying inside the existing dedup windows. Plain commit.
      Verification: with the 15:40 ui-grades/ui-audit churn present,
      the tick runs clean (no false regression); bumping a fixture
      rule's violation count → one summary breadcrumb, deduped on
      repeat.

## Verification summary

- Kernel gate: `make test` green (2855 checks as of 09:01Z today) before
  every hngh ceremony landing; plan file lands via ceremony-drive.
- Automation gate: `make test` green after step 1, required before every
  subsequent automation commit in this plan.
- No systemd changes, no credential work, no deletions outside the 48h
  prune; any step that cannot meet its verification parks with an
  alert row rather than forcing through.
