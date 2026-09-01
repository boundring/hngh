# self-hosting prior art: what systems that build themselves teach the harness-harness

Status: crystallized 2026-09-01 from master-plan §4 research-backlog
candidate "self-hosting prior art" (the fourth of the six backlog
candidates; buddy summoned-not-nagging, handoff-brief schema, and
steer-vs-die threshold are already crystallized — not redone here).
The question this doc answers: Hngh intends to be a harness that
schedules and completes its own development (master-plan §2); prior
art for "a system whose development runs through the system itself"
is old and well-trodden in compilers and build systems — what do
those systems actually do, and which of their patterns are already
load-bearing here, priced as a grow-beat decision?

## Conclusion (kept, framed to this repo)

Self-hosting prior art converges on four load-bearing patterns, and
Hngh already implements analogs of all four — which is evidence the
design is sound, not that the work is done:

1. **Bootstrap from a host, then converge.** A compiler is first
   cross-built by an existing toolchain, then builds itself; the
   bootstrap chain is shortened until the host seed is minimal
   (stage0's ~500-byte hex0 assembler to GNU Mes to GCC —
   https://www.gnu.org/software/mes/,
   https://ekaitz.elenq.tech/hex0.html). Hngh's analog: the operator
   is stage 0 — operator-authored plans and operator-run ceremonies
   seeded the loop; stage 1 is the machine-authored-plan + auto-accept
   + overnight-wake cycle now running (plans authored by delegated
   sessions, accepted by `scripts/accept-plans.py` when both gates are
   green, executed by `scripts/overnight-cycle.sh` wakes). The 24/7
   cycle IS the convergence-in-progress: each wave the machine authors
   a larger share of the next plan.
2. **The trust test is a repeatable fixed point.** Classic
   self-hosting proof: the compiler compiles its own source into a
   binary that again compiles its own source identically (the
   diverse-double-compiling refinement of trusting-trust —
   https://dwheeler.com/trusting-trust/). Hngh's analog is the gate,
   not the binary: `make test` (kernel, 2855 checks) and the
   automation suite gate every change, and the automation tests test
   the tooling that runs the gates (`tests/test-router-tick.py` tests
   the router that drafts the plans; `tests/test-plan-acceptance.py`
   tests the accepter) — the tooling tests the tooling. A true
   compile-twice fixed point (a named artifact reproducible from
   itself) is NOT established here and is not claimed.
3. **Never brick the builder.** Bootstrappable systems keep the
   running build tool functional at every stage (Guix full-source
   bootstrap keeps every intermediate derivable —
   https://www.gnu.org/software/mes/manual/html_node/The-Mes-Bootstrap-Process.html).
   Hngh's analogs are structural: the ledgers are append-only
   (`docs/project/reports.md` rows are only ever appended;
   `scripts/report-queue` dedups rather than rewrites), plans are
   never deleted mid-lifecycle (parked, not removed), and the
   rc=124/foldback lessons (2026-08-30) made ceremonies tick their own
   steps inside the ceremony so a killed beat never leaves the
   builder's state un-derivable. The plan lifecycle
   (proposed|accepted|executing|executed|parked,
   `docs/project/plans/README.md`) is the builder's boot protocol.
4. **Self-description from own state.** A self-hosted system's docs
   are generated from its own build state, not maintained beside it.
   Hngh's analog: dashboards and plan feeds render only from ledger
   front-matter and row files (`jobs/plan-feed.py` reads the plan
   files the selector reads); the honesty leash (master-plan §4,
   gamified runs render only real run fields) is the same law on the
   narrative plane.

## Findings

- **F1 — the loop-closing edge was the missing stage, and it just
  landed.** The 486→514→526 unread-alert growth was a self-hosting
  failure mode visible in prior art terms: the system observed
  defects but its development loop had no edge from observation to
  work. The router tick (`hngh-automation/scripts/router-tick.py`,
  landed this wave, 2026-09-01) is that edge: alert → routed
  candidate → plan lifecycle → tick, re-derived from plan state with
  no router-internal store. Prior art's equivalent is the moment a
  bootstrap chain first reaches its own source.
- **F2 — plan-supply law is the "keep the host alive" law.** A
  cross-compiler that runs out of inputs stops; the continuous cycle
  that runs out of accepted plans produces nothing (foldback lesson
  1, `docs/records/2026-08-30-lessons-and-foldback.md`). Both prior
  art and this repo price the law the same way: the last step of
  every plan authors the next plan.
- **F3 — the seed never fully disappears, it shrinks and changes
  hands.** No bootstrappable system eliminates the host; it reduces
  it (hex0) or moves it to audit (Guix's binary seeds are declared,
  not denied). Hngh's seed is the operator-owned surface: kernel src
  ceremony review, credentials, systemd state, critical-class
  parking. The honest statement is the one the Parked lists already
  make: the machine's share grows, the operator's share does not
  reach zero, and what remains is declared per-plan.
- **F4 — lockstep discipline beats speed.** Bootstrap chains pay in
  staged, verifiable increments (stage0 → mes → tinycc → gcc), never
  a big-bang rebuild. The repo's paced-cadence contract (steps ≤~60m,
  beats killed at 30m, grow↔research alternation) is the same
  discipline: each wake lands one increment the next wake can verify
  from the ledger.

## Recommendation (the priced, parseable decision)

For the next grow rungs, take from prior art only what the loop
lacks:

1. Keep staging convergence as an observable: each follow-on plan
   should record which steps were machine-authored (the
   `routed-from=` front-matter tag now makes that parseable) — the
   bootstrap-share becomes a measurable, not a claim.
2. Do NOT build a compile-twice "fixed point" artifact now — the
   gates already play the trust-test role at current scale; a
   reproducible-artifact fixed point is unpriced here (see Not
   established).
3. When a bootstrap stage must change hands (operator-only work),
   file the handoff as an alert row, never as silence — an unstated
   seed is the trusting-trust failure in harness form.

## Open threads

- What artifact, if any, would count as Hngh's "compile-twice"
  proof? Candidate: a fresh clone reaching green gates using only
  materials the repo itself authors (scripts + plans + ceremony
  records). Not established; parked until a grow run needs it.
- Whether the operator seed has a floor (ceremonies with human
  review only) or shrinks to pure audit (model review + certificate)
  is a policy question, not a research one — it belongs to the
  ceremony-cost doc already crystallized (2026-08-30), not redone.

## Grounding

Repo paths verified present while writing (`test -f` each, 2026-09-01):

- `docs/project/master-plan.md` — §2 intended state (machine
  scheduling+completing its own development), §4 backlog line naming
  this candidate
- `docs/project/plans/README.md` — the plan lifecycle contract
  (proposed|accepted|executing|executed|parked)
- `docs/project/plans/2026-08-30-evening-selfdev.plan.md` — an
  executed machine-self-development wave (stage-1 evidence)
- `docs/project/plans/2026-08-30-overnight-continuity.plan.md` — the
  plan-supply law in running form (final step authors the next plan)
- `docs/project/reports.md` — the append-only ledger (F1's alert
  growth, F3's seed-in-audit)
- `docs/records/2026-08-30-lessons-and-foldback.md` — foldback
  lessons 1-2, the rc=124 tick-inside-ceremony lesson
- `docs/research/2026-08-30-ceremony-cost-reduction-batching-kernel-doc-landings-safely.md`
  — the ceremony-batching companion pattern (not redone)
- `Makefile`, `tests/run.lisp` — the kernel gate (the trust-test leg)
- `scripts/run-autonomous`, `scripts/report-queue`, `scripts/hngh`,
  `scripts/verify-candidate.py` — the machine's own build loop
  (wakes, ledger dedup, governance CLI, ceremony evidence)
- `hngh-automation/scripts/accept-plans.py`,
  `hngh-automation/scripts/overnight-cycle.sh`,
  `hngh-automation/scripts/router-tick.py`,
  `hngh-automation/tests/test-router-tick.py`,
  `hngh-automation/tests/test-plan-acceptance.py`,
  `hngh-automation/Makefile` — stage-1 machinery: machine acceptance,
  the wake cycle, the just-landed routing edge, and the tests that
  test the tooling

External anchors (web-verified 2026-09-01, per the search-grounded
research-beat method —
`docs/research/2026-08-30-search-grounded-research-beats-web-search-reference-capture-source-quality.md`):

- GNU Mes — https://www.gnu.org/software/mes/ (hex0/stage0 origin,
  Guix source transparency)
- stage0 hex0 write-up — https://ekaitz.elenq.tech/hex0.html
  (~500-byte self-hosting hex assembler)
- The Mes bootstrap process —
  https://www.gnu.org/software/mes/manual/html_node/The-Mes-Bootstrap-Process.html
  (the chain to GCC, binary seeds declared)
- Fully Countering Trusting Trust — https://dwheeler.com/trusting-trust/
  (diverse double-compiling)

## Not established

- No reproducible "compile-twice" fixed-point artifact exists or is
  defined for this repo; the gate-as-trust-test claim is an analog,
  stated as such.
- The bootstrap-share measure (machine-authored vs operator-authored
  plan steps over time) is now *parseable* via `routed-from=` tags
  but has no dashboard surface and no baseline numbers yet — whether
  one is wanted is an operator decision (same parked row as the
  routed-outcome panels).
- External prior-art claims are cited to the URLs above as general
  history; no line-level verification of those projects' sources was
  performed in this beat — the repo paths above are the verified
  layer, per the hallucinated-source-line anti-pattern.
