# Cost Conservation — Strategic Reserve & Economic Routing (C-cost)

**Status**: Policy capture (2026-08-07), from the first live ACP squad run.
**Cross-links**: `model-pareto.md`, `model-strategy.md`, `quota-spreader.md`,
`autonomy-strategy.md`, `squad-autonomy.md`, and the `multi-agent-coordination`
skill (cost-governance references).

---

## 1. The directive

> Defend against costs scaling *in advance* of costs increasing — proactively
> minimize expense. Models, quota windows, and billing balances are conserved
> resources; all are scarce and all must be budgeted up front.

The first live squad run surfaced a concrete violation: **GLM-5.2 ($0.40/M)
kicked in as a default driver**, because PM and Designer seats are pinned to it
as primary. $0.40/M is well past the conservation line. This doc sets the
policy so it does not recur.

## 2. The conservation tier (which models are scarce)

Any model costing **more than $0.20/M input**, or with UNKNOWN input pricing,
is a **strategic reserve** — to be used `as infrequently as Kimi K3`, i.e. only
for guidance on specific design problems or code that must be extremely well
designed.

| Model | $/M (in) | Tier | Use |
|---|---|---|---|
| gemma-4-12b (local) | 0 | primary driver | queued / non-time-sensitive work |
| deepseek-v4-flash-0731 | 0.09 | primary driver | default for most roles |
| gpt-5.6-luna | 0.10 | primary boundary | cheap capable, high familiarity |
| glm-5.2 | 0.40 | **reserve** | specific design problems, high-stakes code only |
| kimi-k3 | 3.00 | **reserve** | authority-only strategic reserve |

Rule of thumb: **if remote input costs >$0.20/M or is UNKNOWN, treat it like
K3.** Sparse, gated, named-reason, never the default driver.

## 3. Quota windows are budget lines, not just the weekly number

We plan for granular windows, not a single $50/week figure:

- weekly (~$50), daily (<$10), half-day, quarter-day, per-hour windows;
- service quota ceilings and **reset windows** on every remote service;
- API **billing balances** carried by each remote provider.

These are all tracked the way we track the quota-spreader — a live budget that
fails closed, not a post-hoc reconciliation.

## 4. Squads are a tool, not the default

- Squads may not always be affordable. Keep them small on average; use them
  for particular task types / development waves, and possibly **off-peak** when
  pricing is lower.
- Roles, multiple agents, and coordinating agents are **viable options among a
  suite of tools** — not an always-on pattern.

## 5. Summon-on-need (agent cost ladder)

Agents summon other agents *according to need*, up and down the cost ladder:

- **Cheap agents** may summon *very cost-limited* use of smarter agents.
- **Intelligent agents** are used sparingly, and themselves summon cheap agents
  for: on-the-fly summarization, condensation, reference tagging.
- **Procedural tools** (not LLM calls) absorb routine requests first.

This inverts the assumption that every coordination turn needs a smart model.

## 6. User-led vs agentic session tracking (open item)

We have not yet distinguished *Hngh's* use of Hermes/Opencode from *our own*.
Wanted: Hngh tracks, per session, whether it is:

- **user-initiated / user-led**, or
- **fully agentic** (initiated and prompted by another agent).

This distinction feeds cost attribution and the ledger, and is a design item
for the live-orchestration/ledger work.

## 7. This work is exploratory

We evaluate, weigh, and re-strategize as we go. Every lesson learned is fuel
for design — recorded here and in work-sessions, not silently absorbed.

## 8. Squad-seat state is Hngh's to manage (design direction)

The squad seat definitions (`~/.hngh-night/squad-seats.conf`) are **not a
permanent Hermes-owned boundary**. The user is comfortable with Hngh managing
squad seats natively. Treat this file as a **bridge artifact** on the path to
Hngh owning seat/model/routing state itself (the squad-manager plugin in
`squad-startup-automation.md` / `autonomy-strategy.md §3`). When Hngh manages
seats, the conservation policy in this doc is the live rule Hngh enforces — not
a static file to hand-edit. Same for any per-tool config that should live under
Hngh's control rather than an external file wall.

---
## Attribution
Policy capture: Hermes / deepseek-v4-flash-0731 / hermes TUI / $0.
