# Overnight plan execution brief — 2026-09-21/22

Session: omp overnight run in the hngh repo. Plan: local://hngh-overnight-20260921-plan.md
(session-local artifact; phases: tree triage -> bead closes -> certificate
lane -> research/review -> halt discipline).

## Landed (commits, in order)

| Commit | Slice |
|---|---|
| ccfcee99 | burst gate narrowed to pin=remote; feedback/unpinned ride REMOTE_DAILY_CAP_CALLS; config.env shadow pre-sets dropped |
| 3aef3b8e | test-bctx-canary.sh + test-ttsr-fit.sh STATE_FILE isolation |
| 494d479c | manga-draft shell-outs take argv lists (submitter-text injection closed) |
| a86c2629 | research feed rows 2026-09-20 + lesson handoff counter 356->368 |
| 630ecfe2 | burst record correction appended |
| 17ba8d4b | ui-evolve overlay gen 3 + grade ledger rows |
| 383560c4 | book.md cron minimal-environment note |
| 5900ffca | routed dash-selfreview plan dispositions + 3 new candidates |
| 64ed0e80 | secret-scrub round-2 record + 6 briefs |
| 142a1899 | CEREMONY kernel slice: filesystem read-eval hardening (*read-eval* NIL, TRANSPORT-FAULT on unreadable lines, directory-at-record-path fail-closed); gate 2934 |
| 036f8a68 | docs/project/registries/kernel-slice-ledger.md created with d5u row |
| d7ff825f | research: ground-truth dispositions for synth-2026-09-20-1/2/3 |

## Beads

Closed with evidence: hngh-n28 (OpenRouter archaeology), hngh-8ls comment
(corrective: live bead is reader-audit-m census leftovers, plan mislabel;
left open), hngh-bud, hngh-cf2, hngh-d5u (TOCTOU, ceremony bb7f4a5e).
Deferred 2026-10-01 with landscape comments: hngh-0pu/lmi/qnb/ck8 (gemini
burst quartet).

Census at halt: 12 open (292, 2ya, 6ih, 8ls, mqc, qnb, 0pu, lmi, 7ly,
dqq, ays, ck8) — reconciles 15-open after n28 minus bud/cf2/d5u.

## Research dispositions (d7ff825f)

Evidence doc: docs/research/2026-09-21-synth-2026-09-20-123-ground-truth.md

- synth-2026-09-20-1 ADOPTED: kernel writer located (src/main.lisp:63 ->
  src/adapter/filesystem.lisp:118 store-record-run), UTC-Z normalization
  verified TRUE at the writer boundary, s-expr lines not JSON, golden
  coverage held by tests/adapter/test-filesystem.lisp.
- synth-2026-09-20-2 KILLED: premise refuted — unit-not-practiced is a
  deliberate fail-closed allowlist verdict (automation/jobs/patrol.py:1434-1437),
  not lost persistence; journal_counts (:1439/:1462) and restart-guard cap
  (:1441-1444) exist.
- synth-2026-09-20-3 KILLED: both load-bearing facts of synth-2026-09-19-2
  verified already implemented — pathspec-limited staging
  (automation/cadence/day/14-plan-ledger-sync.sh:26) + dirty-lane handoff
  (:21-24).

## Fresh-eyes review

Independent reviewer pass over 64ed0e80^..HEAD: ALL CLEAN, overall PASS,
no P0. Notable correctness confirmations: manga TestShelloutContract is
adversarial and behavior-pinning; burst gate has no gemini bypass; the
filesystem handler-case is type-preserving on inner transport-faults.
One pre-existing observation (not tonight's): 72 older disposition rows
are 6-col historical schema.

## Halt state

- Tree: clean at halt check.
- Gate: 2934 checks green (full make test at halt).
- Strays: none (only gate's own test processes + hngh MCP server + omp).
