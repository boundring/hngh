# Hngh skills handbook — expanded descriptions, summoning, composition (2026-09-19)

Direct synthesis (plan full at 1024, no graph nodes). Three new skills
plus eight existing, summon mechanism verified, composition chain defined.

## Expanded skill descriptions

### /hngh-overnight-check (new, user-invocable)

Intended for: end-of-day close and any "how did the night go" moment.
Procedure: timer count (0 held / 11 live), beat process scan, bead
open/closed delta vs last known, guard commits + verdict file age,
tree residue check. Output: 5-line state + risks + resume path.
Triggers: operator says goodnight, asks about overnight, any morning
"what happened" question. Failure mode it prevents: resuming beats
into an unknown studio state. Composes after work, before morning.

### /hngh-morning-review (new, user-invocable)

Intended for: day start. Pipeline: orient via AGENTS.md brief (never
re-walk) → beads hottest-lane via Jev triage pattern → connect state +
plans + designs to candidate work → refactor-first filter (collapse
before create) → 3 ordered next actions, await operator pick. Guardrail:
proposes, never drives unprompted. Triggers: "good morning", "what's
next", day-start in any phrasing. Failure mode it prevents: diving
into work without orientation (the re-walk tax).

### /hngh-next-steps (new, user-invocable)

Intended for: staging work once review picks a direction. Stages docs
writes (records/decisions/designs as beads with acceptance), OSS
searches (Jev ecosystem first, steal-lists to docs/research/),
requirements research (evidence/routes/keys before workers), per-part
steering levels (autonomous / check-in / operator-decides). Triggers:
"what's next for X", "stage work on", "research Y". Composes after
morning-review, verifies via overnight-check.

### Existing eight (unchanged, summarized)

- hngh-orientation: MCP-first state, never re-walk. Foundation all
  three new skills assume.
- hngh-ceremony-awareness: kernel vs automation touch rules.
- hngh-plan-proposal: plan file lifecycle.
- hngh-shared-sense: multi-session comms (DM/broadcast/ledger).
- hngh-swarm-lanes: seeding, attribution, swarm vs omp vs pi.
- hngh-userspace-and-secrets: two-home split, token-only seams.
- cua-driver, omc-reference: GUI driving, agent catalog.

## Can Jcode summon them on its own?

Honest mechanism, verified this session:

- Skills load via `skill_manage` (load/list/reload) or slash-command
  (`/hngh-morning-review`). The registry shows 11 effective skills.
- **Auto-summon: partial.** The omc-reference skill notes auto-load
  "when delegating to agents, using OMC tools, orchestrating teams,
  making commits, or invoking skills" — that is a session-start
  instruction convention, not runtime intent detection. There is no
  config key matching `skill` in ~/.jcode/config.toml, and manifests
  carry `user-invocable: true` (invitation) not triggers.
- What actually happens: when the operator mentions Hngh contexts
  (beats, beads, overnight, morning, next steps), the coordinator
  (this session) recognizes the match and loads the skill. That is
  coordinator judgment, not automatic summoning. It works because the
  skill descriptions are written to match operator phrasing ("Check
  Hngh's overnight progress", "Review Hngh state in the morning").
- To make summoning more automatic: keyword triggers in session-start
  guidance (the OMC `Keyword triggers kept compact` pattern:
  "overnight"→overnight-check, "morning"/"what's next"→morning-review,
  "stage"/"next steps"→next-steps). Staged as follow-up, not done here.

## Composition chain (the day loop)

overnight-check (close yesterday) → morning-review (orient + propose 3)
→ next-steps (stage picked direction) → work (beats/workers/beads)
→ overnight-check (verify). Handoffs: check outputs delta counts the
review consumes; review outputs the picked direction next-steps stages;
staged beads carry steering levels work obeys; work outputs closes the
next check verifies. Steering insertion points: review's await-pick,
per-bead guidance levels, check's go/no-go. Each skill is independently
invocable mid-loop (e.g. next-steps alone for "stage work on X").
