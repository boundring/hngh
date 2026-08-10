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
- Kimi's own **weekly quota** is not tracked at all by our tooling; we
  "just use it sparingly" by hand.

That means: when the weekly Kimi quota resets, we have *no automated way*
to spend it evenly and sparsely across the period — we either overuse it
early and run dry, or underuse and waste the quota. And with price bumps, the
"use each paid model as little as possible, spread evenly" discipline has no
enforcement.

### Kimi Code reset semantics (authoritative, Kimi Code docs — Membership Benefits)

Read the docs, don't probe the API: there is **no public Kimi Code API
endpoint** for quota or reset (balance/token-estimation APIs on
`api.moonshot.ai` are the separate pay-as-you-go Kimi Open Platform, not the
`kimi-sub` subscription). Documented facts:

- Kimi Code quota **refreshes automatically every 7 days from the
  subscription date**; unused quota does not roll over. Reset is deterministic
  by construction — model locally, no API call needed.
- A **rolling 5-hour rate window** also applies (rate limits recover when the
  window rolls over).
- Check remaining quota/rate-limit: **Kimi Code Console** (web),
  **Kimi Code CLI `/usage`**, or Kimi web/app My Quota — not an API.
- All logged-in devices + API keys share the same quota; sharing with the
  Kimi membership month.

**Goal**: a **quota spreader** — schedule awareness per route (daily/weekly/
monthly reset, with per-period token/cent budgets), so spend is drawn down
evenly and sparsely across each reset period, and never spikes early. For
`kimi-sub`, the reset is a 7-day period anchored to the subscription date;
persist that anchor (the reset-anchor table) and treat the period as fixed, not
queried.

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

### Recurring-authority reservation

K3 (and other strong quota'd models) is not a general-purpose faucet — it's
an **authority**: the right answer for a *recurring class* of situation
(code-completion final vetting, context-specific plans/designs, decisions
where a cheaper model's answer wouldn't be trusted). Those recurring needs
are real and may exceed what a casual even-spread would leave available. So
the envelope supports **reserved allocations per situation-class**:

```
budget kimi-authority        ; reserved slice of the weekly cap
  cap          333k tokens/week (example)
  situations   code-final-review, plan-veto, design-authority
  even-over    7 days
  spillover    no          ; never eats into the general nightly pool
```

- Each recurring situation-class gets a **reserved cap** carved out of the
  route's period cap. The even-drawdown applies *within* the reservation, so
  the authority stays available all week, not just Monday.
- **Reservations do not spill** — a class that underuses its reservation
  does not silently balloon into the general pool (that would recreate the
  mid-week dry run it's meant to prevent). Unused reservation is forfeited at
  reset (optionally reallocated by the PM on override).
- **One-off requests** (a single high-value call, not a recurring class) are
  drawn from the *general* envelope pool, gated by the same even rate and the
  cheapest-capable rule — a one-off is allowed when it's within today's fair
  share, never if it would breach tomorrow's reservation.

Net effect: the recurring authority need is **budgeted first**, the general
pool spreads what's left, and no single spike can eat the reservation. This
is the concrete mechanism for "carefully distributing K3 and other
more-expensive remote options across their quota reset / budget windows."

### Period projection

A route is "destined to run dry" if `spent/projected-use` exceeds the even
rate. Before a route is chosen, the router asks the envelope: *"given what's
used and what's left and how long until reset, is drawing from me now
sustainable?"* If not, route to a cheaper/local/fallback route. Reservation
checks happen first (authority class vs general pool).

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

**Config-first, defaults second**: every knob is configurable via
`~/.hngh/quotas.lisp` (state-store key `quotas`) with conservative code
defaults that are overridden, never forked. No behavior lives only in code;
no override is required for sane operation.

- **Route envelopes** (buckets, caps, reset anchors) — code defaults, overridable.
- **Reservations** (situation-class → reserved cap, even-over, spillover) —
  code defaults, PM-overridable. Situation-class *names* are config so the
  user can name the recurring cases (e.g. `code-final-review`) without code.
- **Sparse rules** (even-drawdown safety margin, cheapest-capable threshold) —
  config, with conservative defaults (keep paid quota'd routes scarce).

Resolved envelope = merge(code-defaults, user-overrides). Precedence:
user > defaults. A missing override falls back to defaults; a malformed
override fails closed (deny the route's spend that tick) rather than guessing.

### Expensive models are a strategic reserve (limited use by default)

The expensive/authority routes (K3, frontier, anthropic-tier) carry an
explicit **strategic-use policy**, not a soft preference:

- **Default posture: refuse expensive routes.** A costly model is chosen only
  when a defensible trigger selects it — an authority situation-class, a
  one-off that passed the cheapest-capable + reservation checks, or an
  explicit PM override. Generic work never lands on an expensive route.
- **Hard restricted cap.** Each expensive route has a small period cap by
  default (e.g. frontier: a few dollars/week). The cap is the same trigger a
  house budget would be: once spent, the route refuses until reset.
- **Onto cheaper first.** Selection walks the cost ladder (local $0 → free →
  cheap remote → authority quota), and only the strategic triggers escalate
  past the cheap tiers. This makes accidental over-spend structurally
  impossible: even a bug can't route bulk work to `frontier`, because the
  default posture is *refuse* and only a narrow trigger opens it.

Net: expensive models exist for specific, strategic, limited use — reached by
explicit selection, capped, and configurable — never by default or accident.

---

## 4. K3 quota-distribution driver

The driver is opt-in routing, not a new scheduler. It exists
because a GATE alone distributes nothing: zero K3 today means no
call ever routes to K3, so the even-rate envelope never draws down
(verified killy 20:30). The driver's job: FLAG K3-appropriate
work, ROUTE it when the envelope has room, and GUARANTEE
availability across all three reset windows (5h / 7d / 30d).

### 4.1 Flagging — what counts as K3-appropriate work

A situation class is K3-appropriate iff it is an authority
situation AND the judgment is high-stakes enough to justify the
reserve. Deterministic situation classes (matches the L2/L3
situation vocabulary, cross-agent-normalization §3):

| Situation class | Route to K3? | Why |
|---|---|---|
| `code-final-review` | YES (reserved) | highest-stakes code gate; the reservation exists for it |
| `plan-veto` | YES (reserved) | stopping/redirecting work; cost justified |
| `design-authority` | YES (reserved) | the design call the group cannot make on workhorses |
| everything else | NO | workhorses are the default; K3 is strategic reserve (doctrine) |

Flagging is a pure function of the situation class — the planner
tags a task with its class at creation (existing mechanism), the
driver reads the tag. No heuristic "is this important enough"
scan; the class IS the flag. Unknown classes refuse (fail-closed).

### 4.2 Routing decision — even-rate iff within envelope

```
should-route-to-k3-p (situation-class):
  1. class in {code-final-review, plan-veto, design-authority}? else NO
  2. reservation not exhausted? else NO (strategic reserve refusal)
  3. every bucket (hour/day/week/30d) within even-rate envelope
     (%even-rate-ok-p: used <= f*cap with safety margin)? else NO
  4. else YES
```

- The spreader math stays untouched — the driver only calls
  `quota-ok-p` + `%even-rate-ok-p` through `should-route-to-k3-p`.
- REFUSED does not mean cancelled: the caller falls back to the
  workhorse route (gpt-5.6-luna etc.) with a ledger note
  "k3-refused-over-envelope". The task still completes; only the
  route changes. This is opt-in, not a hard dependency.
- Consumption is ledgered (`quota-consumed`) exactly as today.

### 4.3 The 30-day window

The kimi-sub envelope gains a MONTH/30d bucket (config gap,
killy 20:30). Semantics:

- Three horizons, three purposes:
  - hour/day/week buckets = rate-limit discipline + near-term
    evenness (existing).
  - 30d bucket = the OPERATOR's reset horizon: K3's monthly quota
    must spread across the month, not burst early.
- Month bucket math is the same even-rate formula with window =
  30d: by time-fraction f of the month, used <= f*month_cap
  (safety margin applies). Reset-anchor tracking extends to the
  month anchor (maybe-advance-reset already handles anchors; the
  month anchor is one more).
- The 30d bucket is a LONG-HORIZON GUARD — it rarely fires alone,
  but it is the backstop against "exhausted the month by the 10th".

### 4.4 Availability guarantee — floor + spend-if-idle

The operator's both-wrongs: zero use all day AND exhausted-early.
Two complementary policies:

1. FLOOR-TO-AVOID-EARLY-EXHAUST: the reservation (kimi-authority
   cap 333000, even over 7) is a hard ceiling per period. The
   driver never exceeds it; when the floor is hit, routing refuses
   until the next period anchor. This is the "never exhaust early"
   half — enforced by refusing over-envelope routes (4.2.3).
2. SPEND-IF-IDLE: the other half — K3 must not sit unused while
   the envelope has room. Two mechanisms:
   a. AVAILABILITY SIGNAL: `quota-status` exposes
      `available-now` + `projected-until` (projection from
      current usage + even-rate: when will the envelope run out
      at fair share). The planner/watcher READS this signal; if
      `projected-until` > some horizon and the envelope is under-
      consumed, the planner is encouraged to schedule an
      authority-class task now ("the budget is available — use
      it or lose the fair share").
   b. IDLE-SWEEP: when a period's even-rate share is materially
      under-consumed near the window end (e.g. day-6 of 7 at
      40% of even share), the driver suggests (never forces) an
      authority-class review of the current design/plan backlog —
      a "K3 has budget; candidate tasks: <list>" nudge to the
      planner. This is the "weird delays / awkward thoughts"
      judgment surface (tie to 120): the driver notices the
      budget idling and redirects, same family as the watcher's
      self-adjustment.
   c. DEFAULT IS OPT-IN (operator-gated): spend-if-idle SUGGESTS,
      never silently routes; the planner decides. Matches
      strategic-reserve doctrine — K3 is used deliberately, not
      burned because it's there.

### 4.5 Signal surface (readable by planner + watcher)

`quota-status (route)` returns:

```
(:route kimi-sub
 :available-now <tokens>
 :projected-until <iso or nil>
 :envelope-percent <0..100>
 :reservation-left <tokens>
 :windows ((:hour <pct>) (:day <pct>) (:week <pct>) (:30d <pct>)))
```

Consumers: the planner (before scheduling an authority task), the
watcher layer (117 — the idle-sweep suggestion feeds a wake cycle
of kind "realign" per 120 §G), and the dashboard (116 — a K3
budget view, one number the operator can glance at).

### 4.6 Tie to 120 (self-adjustment, judgment layer)

The driver is a judgment layer of the same family as the watcher's
self-adjustment: it notices (budget idling), decides (an
authority-class task is due), and redirects (suggests to the
planner) — without being asked. The outcome log (117 §3) records
the suggestion + whether it was acted on, feeding the tuner: if
spend-if-idle suggestions are consistently ignored, the driver
raises the bar (suggests only when the idleness is material); if
acted on and useful, it keeps the cadence. Same closed loop as
watcher knob tuning.

### 4.7 Scope guard (what the driver is NOT)

- Not a scheduler — routes via the existing routing table.
- Not a silent spender — suggestions and opt-in only.
- Not a cost model — envelope math unchanged.
- Not per-task metering — route-level pacing, complementary.

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
2. **Reservation layer** — `quota-reserved-p (route situation-class amount)`
   and `quota-general-ok-p (route amount)`: authority classes draw from their
   reservation first (no spillover), one-offs from the general pool, both
   gated by even-rate.
3. **Envelope → route selection**: gate `kimi-sub` (and any quota route) on
   `quota-ok-p` + even-rate before selection.
4. **Reset handling**: `maybe-advance-reset (route)` zeros period usage when
   the anchor passes; forfeits unused reservations (reallocation is a PM
   override).
5. **Planner Wave-2 gate**: per-cycle budget check calls the envelope; fail
   closed when any route is over its even-drawdown or its authority
   reservation is at risk.
6. **Tests**: envelope math (even rate, reset advance, sparse distribution,
   reservation no-spillover, one-off-vs-reserved routing, fail-closed on
   unknown), pure and fixture-based — no live API.

## Attribution
Cost-control design for Hngh (owner concern: K3 weekly quota + expected price
bumps), orchestrated by deepseek-v4-flash-0731 via openrouter (Hermes TUI).
