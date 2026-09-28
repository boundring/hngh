# Is there an existing pattern in the repository for lexical guards or text sanitization (e.g., in `lib/logs.py` or `lib/display.py`) that could be reused for quips?

Status: recheck record 2026-09-28 for research line `fail-20260913-Is-there-an-existing-pattern-in-the-repo`.
Prior artifacts: crystallized record 2026-09-13 (same name, this directory) and the
parked disposition row `automation/research-dispositions.tsv` line 85 (2026-09-13,
model:deck:deck-7b). This slice answers the parked verdict's stated gap — its
findings ruled out nothing about which files exist because no filesystem
inspection happened in any beat of the line.

# Question

Does a reusable lexical-guard / text-sanitization pattern exist in the repo, and
did the 2026-09-13 parked disposition survive contact with the tree it referenced?

# Evidence read

- `automation/research-dispositions.tsv:85` — the parked row itself. Evidence
  column points at the crystallized 2026-09-13 doc; verdict says evidence was
  insufficient to drive immediate action.
- `docs/research/2026-09-13-fail-20260913-Is-there-an-existing-pattern-in-the-repo.md`
  (lines 1–25) — crystallized verdict: the design answer is file-independent —
  "quips are untrusted display text and must pass through exactly one lexical
  guard choke point before rendering or logging"; open gap was purely empirical
  (do `lib/logs.py` / `lib/display.py` exist, is there a hireable guard).
- `automation/lib/docfilter.py:1–12` — module docstring names itself "the single
  source of truth for the junk signature", born from the 2026-09-11 corpus loss
  (commit 2880b09); it carries `injection_lines()` (line 59) — an injection
  signature scanner — and `finalize()` (line 72), the capture-side strip/cap
  choke point.
- Callers: `automation/cadence/hour/33-research-beat.sh` consumes `finalize()`
  before captures become docs; `automation/tests/test-doc-hygiene.py` scans the
  repo with the same signature. This is the habitual single-choke-point shape
  the 2026-09-13 record prescribed, already in production for two weeks.
- Alert surface: `automation/STATE.md` rows 56989–57891 — the routed identity
  `research-beat:injection:fail-20260913-Is-there-an-existing-pattern-in-the-repo`
  fired only on 2026-09-13 (routed 11:00Z, two plan-dedup suppressions at 12:00Z
  and 13:00Z); no breadcrumb row for this identity appears after 2026-09-13, and
  the dedup store `automation/state/report-identities.json` no longer carries
  it (pruned). The alert is fixed-or-parked as parked, not live.

# Doctrine applied

Plan-file stale-recheck doctrine (lesson class "obsolete"): a 15-day-old
routed plan must be rechecked against current state before any action — the
recheck replaces re-execution when the verification surface already holds.
The alert identities are the barrier, not the plan checkbox: no STATE.md row
recurs and the dedup entry decayed, so nothing routes this identity again.
Evidence-over-inference: the disposition recheck cites file:line anchors, not
model recollection.

# Findings

1. The parked disposition survives. The 15-day recheck confirms both
   verification clauses from the parked row's evidence path: the crystallized
   record exists and the disposition is recorded against the subject. The
   subject is present in `automation/research-subjects.txt` line 65.
2. The empirical gap is closed in automation's favor: `lib/docfilter.py`
   (origin commit 2880b09, 2026-09-11 corpus loss) is the repository's existing
   shared lexical guard — `injection_lines()` scans for injection signatures,
   `finalize()` is the single strip/cap choke point before captures land. The
   kernel question the line originally asked (`lib/logs.py` / `lib/display.py`
   in the KERNEL tree) remains uninvestigated, but the automation side already
   consumes a working guard instead of building a parallel one — which is
   exactly the recommendation the parked verdict asked future work to verify.
3. The alert is dead, not actionable: routed once on 2026-09-13, dedup
   suppressed twice same-day, zero recurrences in 15 days, identity pruned
   from the dedup store. No code, kernel or automation, needs touching — the
   kernel src forbidden lane stays untouched.

# Recommended next line

Keep the line parked; do not reopen. If a quip-specific guard is ever needed
in kernel work, the doctrine is already crystallized and exemplified: reuse the
docfilter shape (one choke point, signature scan inside) rather than a new
sanitizer module. No follow-on subject required.
