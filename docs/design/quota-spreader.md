# Quota Spreader & Cost Control — Design

**Status**: Design (2026-08-07). Drives the C6 Wave-2 planner budget gate and
extends the model-routing / model-pareto cost handling.
**Cross-links**: `docs/design/model-routing.md` (routes + budget), `docs/design/
model-pareto.md` (cost frontier), `~/.local/bin/llm-budget` (rolling OpenRouter
hour gate), `docs/design/planner-design-roadmap.md` §3 (cost gating).

---

## 0. Problem

We're expecting price increases on several models, and K3 (Kimi, annual sub)
has a **weekly quota that resets periodically** (daily/hourly + weekly buckets).
Current cost control is a *semicolon-shaped* mechanism:

- `llm-budget` gates **OpenRouter** spend on a **rolling 60-minute window** —
  it only tracks "how much in the last hour," nothing about reset periods.
- Kimi's own **weekly/daily quota** is not tracked at all by our tooling; we
  "just use it sparingly" by hand.

That means: when the weekly Kimi quota resets tomorrow, we have *no automated
way* to spend it evenly and sparsely across the period — we either overuse it
early and run dry, or underuse and waste the quota. And with price bumps, the
"use each paid model as little as possible, spread evenly" discipline has no
enforcement.

**Goal**: a **quota spreader** — schedule awareness per route (daily/weekly/
monthly reset, with per-period token/cent budgets), so spend is drawn down
evenly and sparsely across each reset period, and never spikes early.

---

## 1. The primitive: a quota envelope per route

For each paid / quota-limited route in the routing table, define a **quota
envelope** in `~/.hngh/quotas.lisp` (state-store key `quotas`):

```
route          kimi-sub
provider       kimi (annual)
buckets        ({period :hour cap 40000 units tokens}
                {period :day  cap 300000 units tokens}
                {period :week cap 2000000 units tokens})
reset-anchor   2026-07-31T00:00:00Z   ; when the weekly bucket resets
```

Each bucket: `period` (hour/day/week/month), `cap` (max units per period),
`units` (tokens or cents — per-route), `reset-anchor` or effective reset.

### Even-sparse drawdown (the "spreader")

Spend within a period is **paced**, not bursty. Two rules:

1. **Rate-limited drawdown.** At any moment the route must not exceed
   `(remaining-in-period) / (time-left-in-period)` projected rate beyond a
   safety margin. If today is day 2 of a weekly bucket, you may spend about
   1/7 of the weekly cap per day, projected — not 50% in one go.
2. **Sparse over-allocation.** Prefer the cheapest qualifying route within a
   capability band (model-pareto), and only escalate to a paid quota route
   when cheaper/local/free routes genuinely can't do the job. K3 is for the
   "certain situations" that need it — nothing else.

### Period projection

A route is "destined to run dry" if `spent/projected-use` exceeds the even
rate. Before a route is chosen, the router asks the envelope: *"given what's
used and what's left and how long until reset, is drawing from me now
sustainable?"* If not, route to a cheaper/local/fallback route.

---

## 2. Where it plugs in

- **Model-routing selection**: the router checks the envelope *before*
  choosing `kimi-sub` (or any quota route). Selection becomes:
  1. cheapest capable route that's *within its envelope's even rate*,
  2. else local $0,
  3. else fallback paid route,
  4. else refuse / degrade (never author a spike).
- **C6 Wave-2 planner budget gate**: per-cycle and per-task budget checks
  consult the envelope, not just the rolling OpenRouter hour. The planner's
  "fail closed on budget" becomes "fail closed on any route being over its
  even-drawdown rate." This is the concrete place the quota spreader meets
  the loop.
- **`llm-budget`**: extend (or add a sibling) to read quota envelopes and
  report per-route period health, not just OpenRouter lifetime rate.

### Tracking

Consumption is recorded per route per period (tokens + cents), keyed by the
effective reset period. A small state file (like `llm-budget`'s) is enough —
append timestamps + amounts, roll up per bucket at read time. No DB. Fail
closed: if the envelope is unreachable or unknown, treat the quota route as
"over" for the current tick (don't spend blind on a quota'd paid route).

---

## 3. Quota reset awareness (the specific case: K3 weekly reset tomorrow)

Kimi's weekly bucket resets on a schedule (tomorrow, per the report). The
spreader's job at reset:

- **Detect reset**: `now >= reset_anchor + period` → zero the period's used
  counter, advance the anchor. (Composite buckets: a daily reset is a
  24h-aligned sub-window of the weekly; the weekly anchor governs.)
- **Re-plan even drawdown**: with the new fresh budget, recompute the even
  rate for the next period. Don't let a "fresh quota!" feeling authorize a
  spike — the even rate is the same discipline as before, just more headroom.
- **Sparse distribution intent**: the point of spreading evenly across
  daily/weekly/monthly is to guarantee K3 is *available* for the situations
  that need it throughout the whole period, not exhausted mid-week. The
  envelope enforces "leave room for next week" as a first-class constraint,
  not a hope.

---

## 4. Config & defaults

- Per-route envelope defaults live in code (`model-routing` / a `quotas`
  data file); overridable by `~/.hngh/quotas.lisp` or env.
- Caps are **rubrics, not authority** — the PM/user can override per period
  (same stance as milestone priorities in the planner).
- Price bumps: when a model's price rises, its envelope `cap` in cents stays
  but its token-equivalent `cap` implicitly falls; the "spend least, spread
  evenly" rule becomes stricter automatically. Track cents, not just tokens,
  per route.

---

## 5. What this is NOT (scope guard)

- Not a new scheduler — it reuses `core/scheduler.lisp` and the existing
  routing table.
- Not a full cost-model / optimizer — just per-route period envelopes + even
  drawdown, matching the "hard caps in code, not prompts" principle.
- Not per-task token metering beyond the planner's existing step/token caps —
  this is *route-level* pacing, complementary to per-task caps.
- Cloud/vLLM/multi-device cost comes later (autonomy-strategy Wave E); the
  envelope abstraction is designed to extend to node-level cost later.

---

## 6. Concrete near-term steps (C6 Wave-2 adjacent, cheap)

1. **`quotas.lisp` data + envelope reader** — a small Lisp module (or extend
   model-routing) with `quota-envelope (route)`, `quota-ok-p (route amount)`,
   `quota-consumed (route amount)`.
2. **Envelope → route selection**: gate `kimi-sub` (and any quota route) on
   `quota-ok-p` + even-rate before selection.
3. **Reset handling**: `maybe-advance-reset (route)` zeros period usage when
   the anchor passes.
4. **Planner Wave-2 gate**: per-cycle budget check calls the envelope; fail
   closed when any route is over its even-drawdown.
5. **Tests**: envelope math (even rate, reset advance, sparse distribution,
   fail-closed on unknown), pure and fixture-based — no live API.

## Attribution
Cost-control design for Hngh (owner concern: K3 weekly quota + expected price
bumps), orchestrated by deepseek-v4-flash-0731 via openrouter (Hermes TUI).
