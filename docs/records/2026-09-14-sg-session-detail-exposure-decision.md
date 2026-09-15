# 2026-09-14 — sg-detail: jcode-session graph-node exposure decision

Task: deep-graph node `retry-sg-detail` (retry of `sg-detail`).
Decide + document how much session detail (transcript snippets?
objectives?) the dashboard exposes per jcode-session graph node,
against the display register and shared-sense legibility rules.

## Decision: metadata only

A `jcode-session` node's `detail` carries **routing metadata only**
— the current `_session_detail` k=v pairs: `status`, `model`,
`provider`, `cwd`, `age`, `pid`, `effort` (when present). The viewer
(`graph-view.js` `parseDetail`) already caps at 12 pairs; 7 are used.

**Not exposed on graph nodes, by kind:**

- No transcript snippets (no user/assistant/thinking/tool text).
- No objectives: no first-user-turn, no title/objective string, no
  `short_name` beyond the node `label` (label = `short_name` with a
  12-char truncated-id fallback; the label is an identifier, not a
  payload).
- No system prompts (`<system-reminder>` wrapper text is skipped even
  by the observatory feed).
- No journal text (journals are skipped files, read by nothing).
- No token/cost numbers (`tokens=N` stays reserved until a real
  journal/budget-ledger source exists — phase 2).

## Against the registers

- **Display register** (`docs/design/display-register-spec.md`):
  dosage ladder rung 1 — kernel plain terms. The pairs are literal
  facts (status, model, provider, cwd, age, pid, effort) with no
  perceptual alias, no narration, no invented copy. Adding snippets
  would climb to event narration without earning it: free text on a
  graph node has no co-present canonical term and no renderer that
  keeps the fact first. Name completeness (§7) is met structurally:
  the full session id rides the node `id` (`jcode:<sid>`), so nothing
  readable depends on a truncated label.
- **Presentation boundary** (`docs/design/presentation-boundary.md`):
  renderers consume application output; the graph builder is such a
  renderer. Snippet-carrying would push raw application *content*
  (conversation text) into a topology surface whose contract is
  `nodes[].{id,kind,label,state,detail}` with small k=v detail —
  the wrong layer. The Sessions observatory tab is the content
  surface; the graph is the routing surface.
- **Shared sense** (`docs/records/2026-09-14-jcode-shared-sense.md`):
  legibility = observatory rows, transcripts, git commits. The graph
  contributes the third channel (observation trail) at the *roster*
  granularity: which sessions exist, who spawned whom, what they work
  on (`works-on` edges from `working_dir`). Content-level sense
  (what a session is trying to do) already has two homes — the
  observatory's mission/title row and the ledger spine
  (agent-handoffs.md, budget.md) — and needs no third copy on the
  node.
- **Fail-closed / credential posture**: `sessions-feed.py` redacts
  credential-shaped text because it carries message content;
  `graph-data.py` carries no message content at all, so there is no
  redaction burden to get wrong. `cwd` is a working directory, not a
  secret; session files live under `~/.jcode/sessions` (userspace,
  never committed).

## Practical grounds (measured 2026-09-14)

- **Scale**: 218 live session files, largest ~1MB; the default view
  already emits ~123 jcode-session nodes. Snippets would multiply
  `graph.json` payload and duplicate `sessions.json` (2.7MB, capped
  400 entries / ~192KB per session there).
- **Single-purpose surfaces**: sidebar rail = row metadata,
  `/session/<id>?tail=20` slice = selected transcript kilobytes,
  graph node = routing metadata. Each already has its discipline
  (B5 slice discipline in `sessions-view.js`); the graph must not
  re-create a second transcript pipe.
- **State vocabulary**: the 4-state mapping (healthy/stale/neutral/
  alerting) carries liveness; detail pairs carry routing. Nothing in
  the attention path needs message text.

## What changes

- None in behavior: `_session_detail` already emits exactly this set.
  This record pins the decision; the docstring points here.
- Code ref: `automation/jobs/graph-data.py` `_session_detail`,
  `_read_sessions`, `_emit_sessions`; viewer cap
  `automation/dashboard/graph-view.js` `parseDetail` (12 pairs).
- Content surface ref: `automation/jobs/sessions-feed.py`
  `jcode_rows` (mission/title + redacted log tail) and
  `automation/dashboard/sessions-view.js` (full transcript viewer).

## Revisit triggers (not now)

- A `tokens=N` / spend pair when the journal/budget ledger lands
  (phase 2) — a number, not text.
- An operator-explicit "show objective on node" request with a
  stated attention use-case and a length/redaction rule; that would
  be a new decision record, not an interpretation of this one.
