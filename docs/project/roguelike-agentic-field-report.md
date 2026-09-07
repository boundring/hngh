# Field report — Cistern applies the roguelike rule at orchestration scale

The roguelike agent lifecycle ([roguelike-agentic.md](roguelike-agentic.md)) was
written from Hngh-internal ceremony deaths. Cistern (an external elisp project,
2026-09-03..2026-09-07) just ran two full delegated-subagent orchestration
cycles *applying* it — a 4-phase domain rewrite plus a 2-round adversarial UX
cycle — with its own steering lessons on top. This report is the field's
feedback into the method: what held, what the field added, and what could be
promoted into the rule itself.

## What ran

- 4-phase domain rewrite + 2-round adversarial UX cycle, orchestrated through
  delegated subagents on a good/fast split (good model for the director's
  rulings and handoff briefs; fast model for mechanical and probe work).
- 45 UX directives + 23 v4 directives, batched and ruled per directive.
- Test suite grew 79→80, green at close on both rounds.
- Failure ledger L-001..L-077, harvested continuously across every run.

## What held from the rule

**Death-and-replacement, three times, zero context re-discovery.** Three
upstream deaths in the field: 2 idle-timeouts on long generations, 1 request
abort mid-draft (L-077). All three were cancelled at non-recovery and
replaced with failure-informed handoff briefs; the replacements started
working without re-discovering anything. This is the core claim of
roguelike-agentic.md confirmed at orchestration scale — the brief *is* the
session's context budget, spent once, deliberately.

**Ledger harvest per run.** 77 entries across the whole engagement, written
continuously — every run that died or deviated contributed its entry before
the replacement launched, exactly the "harvest the lesson into the failure
ledger" step of the session-boundary rotation.

**Fail-first red/green discipline.** Held under pressure throughout; no
manufactured reds, unexpected red-passes strengthened the probe instead
(L-006 class).

## What the field ADDED — promotion candidates

These are new; the rule as written does not carry them. In suite style,
each names the mechanism and its evidence:

1. **Incremental appends for long generations.** Failure class: 3 consecutive
   idle-timeout deaths, all on generation-length single writes. Fix: split
   long writes into incremental appends (write the head, append sections).
   Immediate success after splitting — the timeout was never a capacity
   problem, only a single-call-duration problem. *Rule: any write expected to
   take a generation-length turn is written incrementally; a whole-file
   single write is a death invitation.*
2. **Commit-per-green as a RECOVERY mechanism, not just hygiene.** Evidence:
   a session death cost zero directives because every green test was a commit
   boundary — the replacement resumed at the boundary, not at the batch's
   start. This generalizes roguelike-agentic.md's "capture the state" step:
   the cheapest capture is a commit that already exists. *Rule: green
   boundaries are commit boundaries; a death then costs at most the current
   red/green pair, never the batch.*
3. **Procedural state reconciliation for replacements.** The replacement's
   first actions are fixed and procedural: `git log` (what landed), full
   suite run (what actually holds), ledger continuity check (what was
   harvested). No agentic re-discovery of session state. *Rule: the handoff
   brief ends with the three reconciliation probes; the replacement runs
   them before its first mutation.* (L-077: git log confirmed V4-01 fully
   landed — red commit + green commit — before the replacement touched
   V4-02.)
4. **Mid-turn owner-observation steering.** The fastest corrective observed
   in the field: an owner observation steered into a *running* turn narrowed
   a full-glyph sweep to two double-width glyphs within minutes. *Rule:
   owner observations go into the running turn as steering, never into a
   post-mortem.* This is the live sibling of the rule's "steer, don't kill"
   branch: steering is not only for mid-flight progress, it is the cheapest
   place to inject ground truth.
5. **Measurement-before-layout-ruling for the director.** A layout/geometry
   ruling made on reasoning was overturned by a later measurement probe
   (a badge rendered 126 cols, not the assumed 95, and shifted the map).
   *Rule: the director rules on probe numbers, not reasoning, wherever
   width/geometry/layout is the question.*

## When NOT to respawn — field corroboration

The rule's exemption branch held: mid-flight progressing turns were steered,
not killed, and every death in the field matched the non-recovery triggers
(timeout, abort, loop). No premature kills, no nursed corpses.

## Promotion

Items 1–3 are mechanical and evidence-backed; they read as direct amendments
to roguelike-agentic.md's session-boundary rotation (state capture, harvest,
brief, launch) and the procedural-over-agentic hook. Items 4–5 are director/
steerer-side and belong alongside the live-corrective guidance. Promotion is
left to the rule's owner; this report is the field evidence.

## Provenance

2026-09-03..2026-09-07: Cistern orchestration, two full cycles. Evidence:
cistern `docs/PROCESS-RETRO.md` (steering lessons — UX cycle) and
`docs/FAILURE-LEDGER.md` L-001..L-077 (esp. L-001 upstream idle-timeout,
L-076 owner-observation fix, L-077 replacement reconciliation after request
abort). Three upstream deaths, three replacements, zero context re-discovery.
