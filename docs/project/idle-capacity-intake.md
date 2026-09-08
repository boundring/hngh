# Idle-capacity acceleration — Owner-directive intake packet

*Status: INTAKE PACKET — queued for Hngh cadence-tuning and research/design
cycles.*
*Date: 2026-09-08.*
*Source: Owner directive, not an implementation. The tuning lane and
research cycles own the design and landing through the normal gates.*

## 1. Owner's requirements (verbatim-faithful)

1. **Advance the pace** at which Hngh works.
2. **Use idle resources on this desktop** — work as quickly as it can.
3. **Prefer the simplest ways.**
4. **Queue changes into Hngh itself** — Hngh changes Hngh; the
   operator-side move is to queue the directive, not to hand-edit the
   machine's tunables.

## 2. Observed evidence (2026-09-08, measured)

- **The dev spend ceiling bound today.** `sessions-day-max` is 8; the
  overnight beat spent all 8 and fell back to research-only
  (`automation/scripts/overnight-cycle.sh:71-74`, telemetry
  `kind=overnight` count 8 for 2026-09-08). Development stopped at
  ~16:00 while the box sat half-idle.
- **Concurrency ceilings are far below box capacity.** Fail-first dev
  ceilings are 3/2/1 (full/standard/cautious) on a 16-thread desktop at
  loadavg-per-cpu 0.54 with 18 GiB RAM available. Delegated sessions
  are model-wait-bound, not CPU-bound.
- **Remote quota is not the binding constraint.** kimi 19/40,
  lobehub well under 50 today. The quota legs have headroom; the
  ceiling chain stops dev work before quota matters.
- **Plan supply is capped at 1/day.** `failfirst-dev-synth-daily 1`:
  when the accepted-plans queue runs dry, at most one dev plan per day
  is synthesized from adopted research. Raising session ceilings
  without raising plan supply moves the bottleneck downstream.
- **Duty cycle has dead time.** `hngh-overnight.timer` fires hourly;
  a full beat (3 concurrent sessions × ≤30 min timeout) runs ~30 min,
  leaving up to ~29 min idle between beats. The flock makes overlap
  safe; the contract already says "continuous operation (24/7), the
  timer is the only clock".
- **Idle hardware is real.** GPU[0] 5% util / GPU[1] 0% util
  (RX 7900 XTX, 24 GB VRAM), loadavg/cpu 0.54. `llama-server`
  (/usr/bin) and `ollama` (/usr/local/bin) are already installed. The
  deck node (`docs/DECK-NODE.md`, `lib/model.sh deck_chat`) is a
  working precedent for a remote-box local endpoint; the desktop is
  the same pattern one hop closer (localhost).
- **Load ceiling is a routing signal, not a defer.** Since fail-first
  (2026-09-07), `research-load-ceiling 0.7` shifts local-pinned
  research to the deck or a quota leg above 0.7 loadavg/cpu; it never
  defers. 0.7 leaves ~30% of the box unaddressed by policy.

## 3. Levers (requirements, not specifications)

1. **Dev spend ceiling.** The 2026-09-07 operator authorization was
   "8+/day"; today 8 bound and dev stopped. Research question: the
   right ceiling given session-cost telemetry; the cadence-tuning lane
   owns the Inventory row and the number.
2. **Dev concurrency ceilings.** Raise the full-speed ceiling toward
   what the box tolerates (order of 2×). The fail-first
   demote-on-degradation / promote-on-ok machinery stays exactly as it
   is — ceilings are headroom, the tuner is still the governor.
3. **Plan supply.** Raise the daily synthesis cap from adopted
   research so dev beats do not starve behind a 1-plan/day intake.
   Sequence with lever 1; a session ceiling without plan supply is a
   research-only machine.
4. **Beat duty cycle.** Evaluate shortening the overnight timer
   interval (e.g. 60m → 15m) or dispatching from an existing higher-
   frequency tick. flock already serializes. This is a systemd unit
   change: service-lifecycle gate applies.
5. **Desktop-local model leg.** Serve a local endpoint on the idle
   GPU with the already-installed `llama-server`/`ollama`, mirroring
   the deck node: endpoint row in the Inventory, `lib/model.sh` leg,
   availability probe, model-bench picks the best local model.
   Service enablement is gated: requires the standing certificate or
   an explicit operator instruction naming the exact action.
6. **Load ceiling.** Research whether raising 0.7 (e.g. 0.85)
   preserves operator responsiveness on the daily-driver desktop;
   it routes work rather than dropping it, so the cost of being
   wrong is slowness elsewhere, not lost work.

## 4. Quality bars (inherited, non-negotiable)

- Fail-first demotion/promotion stays; nothing bypasses the tuner.
- Spend telemetry (`kind=overnight`, `kind=session-cost`) keeps
  flowing and stays visible on the dashboard.
- Remote quota caps (kimi 40, lobehub 50) are operator-set and are
  **not** changed by this directive.
- No new daemon/service without the standing gate (certificate or
  explicit operator instruction naming the exact action and target).
- Operator desktop responsiveness is a constraint, not an obstacle to
  route around blindly — the load ceiling exists for the operator.
- Config-only changes ride `automation/cadence-params.tsv` with
  provenance recorded; timer/unit changes ride the systemd cutover
  docs; both commit through the normal verified-slice path.

## 5. Suggested sequencing (for Hngh's queue)

```
1. Inventory raises (levers 1-3)      — cadence-tuning lane, one slice,
                                        self-tuning verifies, re-measure
                                        same day (torch numbers + ledger)
2. Overnight timer interval (lever 4) — systemd slice, after 1 shows
                                        the ceiling holding at full speed
3. Desktop-local GPU leg (lever 5)    — research beat -> design -> land
                                        like deck-node phase 1; needs the
                                        service-enablement gate first
4. Load ceiling review (lever 6)      — research question; adopt only
                                        with operator-responsiveness data
5. Re-measure and report              — before/after wall-time and
                                        session counts in the ledger
```

**Rationale for the order:** 1 is config-only and immediately unbinds
the measured bottleneck; 2 removes dead time only once sessions exist
to fill it; 3 is the largest lever but carries a service gate and a
model-selection question; 4 is deliberately last because operator
responsiveness is the one constraint with no automatic feedback loop.

---

*This is an intake packet, not a plan or spec. Hngh's cycles own the
research, adversarial review, design, and build that turns these
requirements into standing machinery.*
