# OSS learning program — first steps (2026-09-19)

Operator directive: Hngh goes looking for interesting-enough OSS to learn
from. One foot in front of the other. This record banks the first two
deep reads (direct fetches; plan full at 1024, no graph nodes).

## 1. browser-use/jev-ultrafast (5.5k★, 349 forks)

Dynamic indexed action space: every observation produces a numbered
element table; one Jev call picks operation (CLICK/TYPE_TEXT/SELECT/
SCROLL/WAIT/DONE/BLOCKED) plus speculative targets for each op; only
the matching target executes. Small LLM writes text only on TYPE_TEXT.
No screenshots in the loop; atomic DOM snapshot; executor rechecks
freshness and occlusion — model output never becomes selectors,
coordinates, or JS. 7.1s real flight search, 25% faster than baseline,
101 vs 1,092 browser calls.

Steals for hngh (ordered by effort):

1. **Speculative action fan-out in triage**: our morning digest asks
   hottest + heat + collapse; extend to all lane variants in ONE call,
   execute only the matching branch. Same round-trip shape.
2. **Indexed option tables**: our lane Choice should carry numbered,
   described options (element-table style) instead of bare labels —
   better calibration on close probabilities.
3. **Executor validation**: Jev verdicts never become shell commands
   directly; recheck freshness (state file age) before acting. Our
   30s beatskip cache is the start; add verdict-age checks.
4. **Outcome verification**: a DONE choice requires independent check.
   Our bead closes need the same: evidence Noul before close.
5. **Offline tests**: their suite runs without model calls
   (`check_guards.py`); our wrapper tests should mock the same way.

## 2. devagrawal09/jev-review (269★, MIT)

Staged pipeline: Noul risk matrix → Choice+Score file profiles →
Choice evidence → Choice mechanism → Score severity → conditional
Choice routing. Orchestration in code, Jev for bounded judgments.
**Layered architecture enforced by script**: cli/dashboard →
review → adapters → domain; `check-dependencies.ts` fails on upward
imports or cycles. Local-only dashboard on 127.0.0.1, never serves
env files. Findings are prompts, not proofs.

Steals for hngh:

1. **Staged reviewer pipeline**: our G2-G5 gates already follow this
   shape (ledger → census → fanout → sidecars → verdict). Formalize
   as `review/` stage modules with the same Noul→Choice→Score order.
2. **Dependency-direction check as code**: their import-direction
   script is exactly our "keep dependency direction inward" principle
   made executable. Add an equivalent for automation/lib.
3. **Local-only dashboard discipline**: our :8890 dashboard should
   never serve env or key files — verify.
4. **Explicit mode entry points**: change-review vs codebase-scan maps
   to our beat-vs-deep distinction. Name the modes.

## What NOT to copy

- No screenshots-as-state (Jev is text-only; their discipline).
- No model-output-as-code (always validate through the executor).
- No rescanning everything (ad-blocker lesson stands: cache + units).

## Next feet (one at a time)

1. `hngh-1de` follow-up: speculative lane fan-out in triage call.
2. Dependency-direction lint for automation/lib (jev-review style).
3. Evidence Noul at bead close-out (browser-use DONE rule).
4. jev-drone read (advisory-only safety layering) when 1-3 land.
5. LangChain AutoMode read (guardrail-before-tool) when 1-3 land.
