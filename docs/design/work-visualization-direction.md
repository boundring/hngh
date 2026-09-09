# Work-visualization direction — from gantt to story

Status: DESIGN — operator direction, 2026-09-09. Companion to
docs/design/presentation-direction.md (voice rules apply here in full:
dry, precise, flavor as texture). Scope: the dashboard's gantt becomes
the visual guide to how work is staged and completed; dramatized
narrative forms (comic strips, animations) are later rungs on the same
data spine, not a separate effort.

## The gap, stated honestly

Today's gantt renders the timer schedule: 61 recurring beats, estimate
bars, depends-on cascades. What it does not render is the work itself:
the plan queue (accepted plans, their steps, their ordering
constraints) lives in plans.json and queue.md as text. The operator
asking "what is staged, what's done, what's next" gets a chart of
timers and a JSON blob — two separate truths.

## The fix: one work graph, many renderers

Authoritative model (build once, in the feed layer):

- **Nodes**: plans (accepted/executing/executed/parked), steps within
  active plans, and the queue's rotation rows. Each node carries:
  status, risk, accepted-at, steps_total/done, depends-on (explicit in
  step text or inherited from plan execution-notes), priority key,
  last outcome (committed hash / verified check name).
- **Edges**: "unlocks" (plan→plan, step→step), "feeds" (record/beat →
  plan that cited it), "parked-because" (plan → the evidence that
  dispositioned it).

Renderers consume that graph; none of them is the truth:

1. **Gantt (existing surface, upgraded)**: queue lanes gain plan
   reality — an accepted plan renders as its step list; done steps
   filled, next step pulsing, blocked-by edges drawn to the blocking
   plan. The honesty rule stays: estimates are projections; facts are
   checkmarks.
2. **Story view (new, near-term)**: a narrative ledger page — "what
   happened today" rendered from the same graph as short chapters:
   plan accepted → steps completed (with the commit hashes as
   footnotes) → blockers hit → parks. Dry narration, automatically
   generated from records; the wit budget from
   presentation-direction.md applies (one aside per section, earned).
3. **Comic strip / animation rungs (mid)**: the story view's data
   model (chapters, actors = sessions, panels = events) is exactly a
   comic layout: panels, speech-bubble text (tool calls summarized),
   recurring characters (the operative sprite already exists in the
   TUI — it becomes the story's protagonist). Animation rung: panel
   transitions over the timeline scrubber; the gantt's playhead
   becomes a storyboard head.
4. **The long rung**: whatever WebGL/3D form the environmental surface
   takes (presentation-direction rung 5) consumes this same graph.

## Why this compounds

Dependency staging is already computed (depends-on cascade in
gantt.js); the missing piece is plan-step granularity in the feed. One
feed upgrade (plan graph with steps + edges) upgrades every present and
future surface at once — chart, story, comic, animation, 3D. Build the
graph once; let the renderers compete.
