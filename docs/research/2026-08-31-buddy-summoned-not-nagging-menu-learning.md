# buddy summoned-not-nagging menu learning: grounding the top research-backlog line

Status: crystallized 2026-08-31 from master-plan section 4 research backlog (line: buddy summoned-not-nagging menu learning)

Evidence basis: real repo surfaces read in full or in targeted ranges on 2026-08-31 (every cited path passed `test -f`; see Grounding); prior-art references were actually visited via web read or API during this beat (see References). Short quotes are verbatim from the files listed; paraphrase beyond them is marked. Numbers I could not re-verify in the source are not asserted.

---

## 1. What the backlog line actually asks

`docs/project/master-plan.md` §4, "Research backlog (must precede the fun builds)": "buddy
summoned-not-nagging menulearning; handoff-brief schema; the steer-vs-die threshold; …
Each ties to a build rung." It is the first item in backlog order. The question it names:
the pixel-RPG companion surface must **learn what belongs in its summon menu** —
surfacing learned, context-appropriate actions when the operator SUMMONS it — without
ever becoming a nagging assistant that pushes suggestions unbidden.

Two words in the line carry the whole constraint:

- **summoned** — the buddy acts only after the operator initiates.
- **not-nagging** — learning may reorder a menu the operator opens; it may never open
  itself, prompt, animate, or "help" on its own schedule.

## 2. What each repo surface actually establishes

### `docs/design/buddy-menu-spec.md` (P2 DESIGN, ceremony-ready)

- Establishes the interaction model outright: "The buddy is a summoned, non-nagging
  companion… The operative never pops up uninvited, never animates in the operator's
  peripheral focus, and never interrupts a running surface."
- Establishes the current menu contract as a **fixed three-part column**: (1) "Quest ask"
  (prompt box routing to the same command underneath as the CLI/GUI control contract —
  `summon`-style run via create-run → admit-transport (S5), or `ask:` to the advisory
  path (S6)); (2) "Setting toggles" (display-only overlay preferences); (3) "Shortcut
  lenses" ("queue counts, one-line health verdict, next course, latest report tail"),
  where "no lens opens without the operator choosing it."
- Already contains the learning question, unnamed: "Which shortcut lens set is genuinely
  used first (queue counts vs. verdict vs. next course) — build the used one, keep the
  rest in the snapshot." Menu learning is the general form of this open question.
- Constrains data: "menu lenses reuse the same snapshot fields the feeder already
  writes…; no new data path until a lens needs it, and any new field lands in the
  snapshot first, then the QML."
- Constrains animation so nagging is structurally impossible today: "`alert` and
  `victory` are **event-driven single transitions**, never loops: they play once and
  settle, so the buddy cannot nag."
- Non-goals: "Auto-launch, auto-focus, or any unrequested appearance." Honesty rules:
  "No click path bypasses the control contract."

### `docs/design/display-register-spec.md`

- Names the boundary as forbidden shape, verbatim: "Forbidden shapes: nagging loops;
  uninvited interruption of a running surface (the buddy is summoned, never summoning)".
- Acceptance gate already implies one-shot learning behavior: "one-shot transitions:
  `alert` / `victory` advance on the event tick and never replay while the state is
  unchanged — no loop, no nag"; "exactly one caption per state snapshot."
- Alias/speech rows are "`perceptual:true` scope: display data, never canonical, never
  an input to governance or selection" — the exact leash learned menu state must wear.

### `docs/design/gamified-runs.md` (honesty leash)

- "Any narrative field carries `perceptual:true` at the boundary that produces it and is
  **rendered for display only**"; "Narrative is never an input to selection:
  `perceptual` fields are excluded from course-selection candidates, expedite ripples,
  and scheduling computations." Learned menu ordering is exactly the kind of derived
  display state this leash governs.

### `docs/design/command-center.md`

- Names the control verbs the menu routes through: "S5 Summon control | `summon` + web
  ask-box fire a run through `create-run`→`admit-transport`"; S6 consider/expedite.
- Surface-opening rule: "Open / close surfaces … explicit open | no auto-popup; no
  daemon held." And "The OSD/buddy overlay is a display-only skin over the same spine."
- Accountability rule that any learned-action UI inherits: "Every control echoes how the
  ask was decided in a short report row."
- Open question adjacent to learning: "`summon` loadout defaults: which route/tool
  labels a summoned run gets by default (local first, escalate on refusal?)"

### `docs/design/system-awareness-map.md`

- Confirms the buddy's data feed is a stamped, no-daemon snapshot: the awareness tick
  writes the "buddy/OSD snapshot (headroom line in the overlay)"; "Every field carries
  its source stamp; missing or failing probes emit" explicit marks. A learning feature
  must ride this same snapshot-first pattern (per buddy-menu-spec technical delivery).

### `docs/project/master-plan.md` (context)

- Current honest gap: "the buddy/OSD exists but the animations are 'awkward'" (§1).
- The buddy is one of the presiding surfaces ("presided over through CLI + GUI +
  pixel-RPG buddy surfaces", §2) and a driving adapter in the layer map (§3); the main
  dispatch surface exposes "status/summon/schedule/ask/expedite/dashboard/subagent
  verbs" (§3, R6) — the vocabulary a learned menu can only mirror, never invent.

### `docs/project/roadmap.md`

- No buddy mention at all (case-insensitive grep for `buddy` returns nothing). Roadmap
  row 6 ("QoL & graphic evolution … behind the QoL cadence and the display register")
  is the closest cadence a menu-learning change would ride, by analogy only.

## 3. Prior art (what it says, and where it failed or succeeded)

- **Clippy/Office Assistant** — the canonical failure. Introduced in Office 97, it
  "appeared when the program determined the user could be assisted," was "widely
  reviled among users as intrusive and annoying," and was criticized "for interrupting
  users and not providing advice that was fully adapted to the situation." Microsoft
  "turned off the feature by default in Office XP" and removed it entirely in Office
  2007. Alan Cooper's account (via the same article) diagnoses the mechanism: a
  misreading of Nass & Reeves' CASA research — people treat computers as social actors,
  so "the added human-like face emerged as an annoying interloper." The lesson maps
  one-to-one onto the buddy: uninvited initiation is the failure, not the agent, not
  even the personality.
- **Horvitz, "Principles of Mixed-Initiative User Interfaces" (CHI '99)** — the
  primary-source articulation of coupling "automated services with direct manipulation";
  automation earns its initiative only where the user keeps control of when it acts.
  The summon-menu is the buddy's version of direct manipulation: the operator opens,
  the system proposes inside.
- **Horvitz, Jacobs & Hovel, "Attention-Sensitive Alerting" (UAI '99)** — models that
  "balance the context-sensitive costs of deferring alerts with the cost of
  interruption." Even for *legitimate* push (real alerts), initiative must be
  utility-weighted against interruption cost. The buddy's snapshot already carries an
  `alert` state — real alerts keep their one-shot path; learning may never promote
  itself into that channel.
- **Adamczyk & Bailey, "If not now, when?" (CHI '04)** — interruption cost depends on
  *when* in a task it lands; deferring to task boundaries measurably reduces damage.
  Generalizes here: the only moment the buddy may surface learned actions is the
  operator's own boundary — the summon click.
- **Pielot, Church & de Oliveira, "An in-situ study of mobile phone notifications"
  (MobileHCI '14)** — field evidence that notification volume itself produces
  interruption burden (not just badly timed single alerts); dose matters, and the only
  safe dose of proactive assistant chatter is zero unless the recipient asked.

## 4. Design principles (each tied to a repo fact or a reference)

1. **The menu may learn; nothing else may change.** Learning writes only the ordering
   and membership of the summon-opened menu column. It must never alter the event-driven
   animation vocabulary (`alert`/`victory` one-shots stay exactly as specified), the
   speech captions, the snapshot schema semantics, or any gate. (buddy-menu-spec state
   mapping; display-register forbidden shapes.)
2. **Learned state is `perceptual:true`, display-only, and never an input to
   governance.** The learned ordering lives at the presentation boundary like every
   other display alias: "never canonical, never an input to governance or selection."
   A learned lens must route through the same verbs/gates as the CLI ("No click path
   bypasses the control contract"). (display-register-spec; buddy-menu-spec honesty
   rules; gamified-runs leash.)
3. **Learn from the operator's summons, not from ambient signals.** The evidence signal
   is: which lenses/actions the operator actually chooses per summon, and which quest
   asks they type. Menu learning is a direct-manipulation feedback loop (Horvitz CHI
   '99), not a prediction engine watching the operator (Clippy's error). Conveniently,
   the repo's existing open question — "Which shortcut lens set is genuinely used
   first" — already implies the only data path needed: the snapshot fields the feeder
   already writes, plus summon-time choice counts. No new data path until a lens needs
   one.
4. **Rank by a decaying mix of frequency and recency; keep static defaults beneath.**
   Learned actions surface above, not instead of, the fixed contract (quest ask,
   toggles, lenses); stale learned entries sink back. Freshness decay prevents an old
   habit from fossilizing into noise — the same dose-control lesson as the notification
   study, applied inside the menu. [INFERENCE: the exact decay function is this beat's
   estimate, not a repo rule.]
5. **The hard boundary: never auto-offer, never interrupt.** A learned menu entry may
   exist and be ranked only while the menu is open. The buddy may not badge, animate,
   caption, sound, or pop anything because it "learned something"; proactive initiative
   stays zero except the already-specified event-driven one-shots derived from real
   run state. "The buddy is summoned, never summoning." (display-register-spec verbatim
   forbidden shape; buddy-menu-spec non-goals; Clippy/XP-off-by-default outcome.)
6. **Accountability rides the existing report row.** Any learned-action invocation
   "echoes how the ask was decided in a short report row" (command-center rule) —
   including, if introduced, the fact that its placement came from learning.
7. **Fail closed.** With no learning data, the menu is today's fixed menu. Missing or
   malformed learned state must degrade to the static contract, matching the snapshot
   rule "an unreadable/missing snapshot keeps the last good frame and the window never
   crashes." (buddy-menu-spec technical delivery.)

## Not established

- **Implementation state of the menu itself.** `scripts/osd-operative.qml` (176 lines,
  read 2026-08-31) contains no menu, and its feeder (`scripts/osd-operative`) writes
  only state speech, queue counts, backlog summary, and one-line status to
  `/tmp/hngh-osd.json` (override `HNGH_OSD_OUT`). There is no menu code and no learning
  code anywhere in the repo to characterize; everything in §4 is contract design, not
  behavior description.
- The persistence store and schema for learned menu state (where summon-choice counts
  live, retention/decay constants, whether learning lives in the QML, the feeder, or a
  new snapshot field) — no repo doc decides this yet.
- What "context-appropriate" means concretely beyond lens choice — e.g. whether
  learned *quest-ask templates* (summon presets) are in scope. The backlog line says
  "menulearning" without scoping it; this doc assumes menu-entry ranking only.
- Whether the pending open questions (default lens set; quest-ask `ask:` vs run
  default) are closed before or by learning — the alternation is unspecified.
- Exact quantitative results from Pielot et al. 2014 (the widely quoted ~25-minute
  resumption figure) — the paper's metadata was verified via Crossref during this
  beat, but the numbers were not re-read from the primary text, so none are asserted
  here.

## References

All visited 2026-08-31 (via direct read or API during this beat):

- Horvitz, E., "Principles of Mixed-Initiative User Interfaces," CHI '99, pp. 159–166.
  https://www.microsoft.com/en-us/research/publication/principles-mixed-initiative-user-interfaces/
- Horvitz, E., Jacobs, A., Hovel, D., "Attention-Sensitive Alerting," UAI '99,
  pp. 305–313. https://www.microsoft.com/en-us/research/publication/attention-sensitive-alerting/
- Adamczyk, P. D., Bailey, B. P., "If not now, when? The effects of interruption at
  different moments within task execution," CHI '04. https://doi.org/10.1145/985692.985727
- Pielot, M., Church, K., de Oliveira, R., "An in-situ study of mobile phone
  notifications," MobileHCI '14. https://doi.org/10.1145/2628363.2628364
- "Office Assistant," Wikipedia (Clippit/Clippy history, XP default-off, criticism
  sections). https://en.wikipedia.org/wiki/Office_Assistant

## Batched landing

This doc is an uncommitted working-tree research artifact; it rides the next
certificate ceremony and is landed by the orchestrator (no machine git operations in
the kernel repo). No code was written in this beat.

## Grounding

All paths verified with `test -f` on 2026-08-31:

- `docs/design/buddy-menu-spec.md` — PASS; read in full (119 lines).
- `docs/design/gamified-runs.md` — PASS; targeted ranges (honesty leash, buddy rows).
- `docs/design/command-center.md` — PASS; targeted ranges (S5/S6, verb table, OSD note).
- `docs/design/system-awareness-map.md` — PASS; targeted ranges (snapshot feed).
- `docs/design/display-register-spec.md` — PASS; targeted ranges (forbidden shapes,
  acceptance invariants).
- `docs/project/master-plan.md` — PASS; §1–§4 ranges (backlog line at §4).
- `docs/project/roadmap.md` — PASS; buddy-grep negative result confirmed.
- `scripts/osd-operative.qml` — PASS; read for implementation-state check (no menu).
- `scripts/osd-operative` — PASS; read for snapshot-field check.
- `docs/project/interface-plan.md`, `docs/design/presentation-boundary.md`,
  `docs/design/assistant-interface.md`, `docs/design/operative-frames.md` — PASS
  (existence verified; cited only as cross-links the above documents name).
