# Watcher layer — routines, not scripts (card 117)

One page. Design-first. Feeds 116 (dashboard abstraction). Per
durable-coordination-records §7.4 (embedding) + §7.5 (dispatch).

## 1. What the layer is

A WATCHER ROUTINE is a function/plugin with a contract:

```
inputs:  state feeds (per-seat state, claims, steers log, lanes)
outputs: events (wake/nudge/escalate) + logs (outcomes)
knobs:   config, auto-tuned by the layer (not hand-set)
```

The current hngh-live-watch shell script is ONE such routine — the
reference prototype. It is not the layer; the layer is the thing
that runs routines, owns lifecycle + dashboard feed + steer dispatch
(§7.5), and tracks each seat's thread of activity (per-claim logs)
for the dashboard's abstraction.

## 2. Layering

```
dashboard (116)  ←  consumes feeds (state, steers, claims, owner)
     ↑
watcher layer    ←  lifecycle, nudge outcomes log, auto-tuning,
     ↑             steer dispatch per §7.5, per-seat activity threads
routines         ←  lane-change, idle-backstop, WAIT-GATE judge,
                     escalation (each a registered plugin)
```

- Routines REGISTER with the layer; the layer decides which run and
  when. A routine is a pure function of its feeds — testable in
  isolation, replaceable without touching the layer.
- The layer's outputs are events; the dashboard renders events as
  views (watch state done in 105; steers + owner inbox next per 116).

## 3. Auto-tuning (closed loop)

Timing knobs — IDLE_BOUND, NUDGE_GRACE, WAIT_TTL, RC4_SLOT,
SLEEP_FLOOR — become per-routine CONFIG, and the knobs are SUBJECT
TO SCRUTINY AUTOMATICALLY:

- The layer records each nudge outcome — fields: consumed? acted?
  latency-to-act? stalled? — and that record IS the evidence source
  (named fields, not vibes).
- A tuner adjusts knobs by feedback: too many unconsumed nudges →
  raise grace; waits that needed more than WAIT_TTL → raise TTL;
  seats that always act on first nudge → fewer nudges needed.
- The tuner ITSELF starts as a routine — a pure function of the
  outcome log — dogfooding the layer before the layer exists;
  its fixture reads a sample outcome log and asserts the knob delta.
- Today the owner/seat hand-tunes constants; the layer replaces that
  cycle with recorded evidence. The tuning is conservative — each
  knob drifts by small deltas, never jumps, and logs every change.

## 4. Embedding (per §7.4, both paths)

- Option A: routines + layer as a Lisp plugin under Hngh's own
  lifecycle — started/stopped/statused by hngh or the dashboard.
- Option B: pluggable watcher.impl from config; the shell routine
  remains one implementation, swappable.
- Either way: the shell script is a PROTOTYPE ONLY, explicitly not
  reference-by-inertia.

## 5. Transition rule

- No new shell watcher features. Shell code only LOSES features,
  gains none, as the Lisp/plugin layer absorbs behavior.
- The dashboard consumes the SAME feeds the shell writes today
  (/tmp/hngh-live-watch.state, claims, steers log) — the swap is
  feed-compatible; consumers never notice the routine change.
- Selective watcher deployment per owner: routines are registered
  deliberately, not all-on; a routine earns its keep by outcome
  data, and can be paused without stopping the layer.

## 6. Acceptance

- This doc describes routine contract + layer responsibilities +
  auto-tuning loop + embedding + transition rule (done here).
- First Lisp routine (post-115 design): lane-change, with the
  current shell behavior as its reference — fixture-testable in
  isolation.
- Shell watcher: no new features from this card forward (hard rule).

## Open questions (owner)

- Tuning aggressiveness: per-seat tuning vs global defaults first?
  (Recommendation: global defaults + per-seat deltas, evidence-gated.)
- Where the layer lives first: dashboard plugin (116 dependency) or
  standalone daemon plugin? (Recommendation: dashboard plugin —
  dashboard-first is the owner's priority.)
