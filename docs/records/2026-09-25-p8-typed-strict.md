# 2026-09-25 — P8: typed-everything strict

principle: a decision that gates work needs a typed record — advisory
text can raise a gate but never decide one (GOVERNANCE.md §6 decision
recording; confidence-floor table in automation/lib/typesafe.py).
adversarial: park-on-untyped can starve routing when the typed key is
absent for long stretches — the typed-gap rows (7d window) are the
signal to watch for exactly that failure.

## What this records

Refoundation phase P8: one typed seam, strict sufficiency.

1. **One seam (P8a).** `automation/ng/jev.py` sources
   `automation/lib/typesafe.py` (`ask_choices` fan-out) for the typed
   lane; its own `/v1/systemone` urllib POST retires. The local chat
   lane (`/v1/chat/completions`) and the ledger Event/verdict contract
   are unchanged; typed whole-call failure still fails open to the
   chat lane (jev answers are advisory-grade, not gate-grade).
   `TYPESAFE_MODEL` env retires — the model pin lives inside
   `lib/typesafe.py` (`jev-1.13.0`); `_log` provenance cites it.

2. **Strict sufficiency (P8b), two flipped sites.** A gate-grade
   decision needs a typed record at/above the site floor; otherwise it
   PARKS with one report row `typed-gap:<site>` (window 604800) and
   the legacy/local output rides as advisory context only:
   - `automation/cadence/calendar/daily/06-review-disposition.sh`
     (floor 0.5): a finding with no typed severity parks — never
     routed on the legacy prefix alone. Typed-decided findings keep
     the stricter-of rule (legacy can raise, never lower).
   - `automation/cadence/hour/33-research-beat.sh` (floor 0.60):
     verdict glue prints the typed action or parks; the legacy VERDICT
     line becomes advisory text in the disposition reason and the
     typed-gap row. The old `research-beat:review-unparseable` alert
     is subsumed by park (deleted).
   `arbiter()` stays in `lib/typesafe.py` for the one remaining
   raise-only composition (`automation/scripts/overnight-cycle.sh`
   step-class raise at 0.5) — no flip site uses it as a legacy
   fallback anymore.

3. **Confidence-floor table (P8c).** `lib/typesafe.py` module
   docstring is the one table: jev lane 0.5, review severity 0.5,
   research verdict 0.60, overnight step-raise 0.5, plus the
   park-on-untyped rule. Site comments point at it.

## Verification

- `python3 -B tests/test-typesafe-wrapper.py`: 29/29 (8 new jev
  mapping tests: DONE/UNCERTAIN/ESCALATE mapping, `{}` → None,
  ask_batch single fan-out, ask-level fail-open to a loopback chat
  server).
- `bash tests/test-research-review.sh`: ALL OK, 28 assertions — new
  case e (review-disposition: typed-decided routes with a nit→P1
  raise; no-key parks both findings with exactly ONE
  `typed-gap:review-disposition` row carrying the advisory legacy
  prefixes; conf 0.30 parks) and case f (beat: conf 0.30 < 0.60 then
  no-key both park, disposition parked with the advisory reason,
  exactly ONE deduped `typed-gap:research-beat` row, no follow-ons).
- `cd automation && make test`: green.
