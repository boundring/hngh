# Bounded K3 completions

Status: DESIGN — initial conservative policy, 2026-08-10.
Cross-links: `quota-spreader.md`, `model-routing.md`, `squad-autonomy.md`,
K3 review artifact `95-k3-sanity-review.md`.

## Problem

K3 is a strategic reserve with three coupled quota horizons. The 2026-08-10
sanity review was useful, but the quota page showed that one context-heavy run
consumed **72.97% of the 5-hour window** and **14.71% of the 7-day window**;
the page showed **23.88% total usage**. The 5-hour window later reset, but the
7-day and 30-day reserves did not.

Both previous modes are wrong:

- unconstrained agentic sessions exhaust quota before the window ends;
- zero use wastes the model's authority throughout the reset cycle.

The practical unit is a bounded completion: a workhorse prepares one compact
question; K3 answers once without tools; workhorses consume the durable result.

## Authority classes

K3 is eligible only for:

- `plan-veto` — challenge a decision-complete plan before an expensive wave;
- `design-authority` — resolve a named architectural conflict;
- `code-final-review` — review a narrow, high-impact diff or security seam;
- `sanity-review` — diagnose a compressed incident set and prescribe method.

K3 is ineligible for repo discovery, coordination chatter, routine coding,
formatting, polling, test execution, general web research, or open-ended
"continue working" sessions.

## Completion packet

A workhorse creates one artifact with this fixed shape:

```text
DECISION: one question K3 must answer
AUTHORITY CLASS: plan-veto | design-authority | code-final-review | sanity-review
CURRENT DECISION: what the workhorses presently believe
CONFLICT: the exact doubt or failure
VERIFIED FACTS: compact bullets; no claims without artifacts
REFERENCES: local paths plus narrow line/commit ranges
CONSTRAINTS: budget, security, scope, forbidden changes
OUTPUT SCHEMA: verdict, causes, ordered actions, guardrails, unknowns
```

No transcript dump. No full repository. No repeated background. The packet
should normally fit in 8–32K input tokens. Larger packets require an explicit
operator override and a pre-call estimate showing why compression would lose
the decision.

Default completion limits:

- tools: none;
- turns: one;
- output: 2–8K tokens;
- context attachment: only the packet and its named excerpts;
- retries: zero unless the provider returned no usable completion;
- coordination: result is written to an artifact; K3 does not message seats.

These are conservative starting limits, not provider facts. Outcome and quota
telemetry tune them; agents may not silently raise them.

## Implementation status: automatic routing is still blocked

The shipped predicate is a useful seam, not yet an authoritative gate. Review
against the current source found these gaps:

- no effective 5-hour bucket in the default route envelope;
- marginal `amount` is ignored by admission;
- production usage is caller-supplied rather than rolled up from the ledger;
- two callers can admit concurrently against the same headroom;
- reservation pacing and configured safety margin are not enforced as designed;
- reset advancement depends on bucket order.

Card 128 hardens quota truth. Card 127 (planner consumption) is blocked on it.
Until 128 passes, `should-route-to-k3-p` is advisory and automatic K3 routing
remains disabled.

## Three-window admission gate

A call is admitted only when all active envelopes allow it:

1. `:five-hour` — enough headroom for this completion and one emergency review;
2. `:week` — projected weekly use remains below the even-drawdown line;
3. `:month` / 30-day — projected use preserves reserve through month end;
4. the authority-class reservation is open;
5. no equivalent K3 result already exists for the same decision fingerprint.

Unknown quota state fails closed for automatic calls. The operator may approve
a named one-off with unknown telemetry. A fresh 5-hour reset never overrides a
low weekly or monthly reserve.

Initial cadence:

- normal maximum: one K3 completion per 5-hour window;
- additional completion in the same window: only for a distinct authority
  class, with a much smaller packet/output, and only when weekly/monthly
  projections remain healthy;
- agentic K3 session: disabled by default.

The quota-spreader owns admission. The planner/router must consume
`should-route-to-k3-p`; otherwise the policy is documentation only.

## Quota observation

Kimi subscription quota has no assumed public API. Observation adapters may
consume:

- operator-provided quota screenshots, locally OCR'd;
- Kimi CLI `/usage`, if its documented output is available;
- manually entered normalized percentages and reset anchors.

Record before/after when possible:

```text
observed_at, five_hour_used_pct, week_used_pct, month_used_pct,
reset_at[5h,7d,30d], call_fingerprint, input_tokens, output_tokens
```

Unavailable values are `UNKNOWN`, never zero. Screenshot content is evidence,
not a scraper contract.

## Thin K3 harness / Pi feasibility

A dedicated low-context harness is desirable because a normal Hermes session
carries broad context and tool affordances that K3 should not need. A Pi-like
agent is a **spike**, not a selected dependency.

The spike must establish from official docs/source:

- Kimi Coding provider support and exact model selection;
- hard input/output limits;
- tool-disable and one-turn completion mode;
- transcript/context isolation;
- local artifact capture and attribution;
- ability to reject retries and agentic continuation.

If Pi cannot prove these, build the completion adapter on the existing provider
client instead. The stable product interface is `run-authority-completion`, not
the harness brand.

## Consumption protocol

1. Save the K3 result under the current canonical artifacts root.
2. Mark it `AUTHORITY INPUT`, with model/provider, observed quota delta, packet
   fingerprint, and any unknowns.
3. Workhorse seats translate every ordered action into a card, design change,
   guard, or explicit rejection with reason.
4. Do not re-research verified findings merely because they came from K3.
5. A verifier audits that every finding was consumed or rejected; the K3 call
   is not complete when the prose artifact lands.
6. Feed measured cost and usefulness back into quota and routing policy.

## Roadmap slices

1. Wire planner routing to the existing K3 driver.
2. Add a completion-packet schema and fingerprint.
3. Add manual/screenshot quota observations to the quota ledger.
4. Build a no-tools, one-turn adapter with strict caps.
5. Spike Pi against the stable adapter requirements.
6. Add a dashboard view showing admission state across 5h/7d/30d.
7. Shadow-run on workhorse-generated packets; promote only after measured quota
   use matches the envelope.

Attribution: operator direction, K3 artifact 95, Killy design authority.
