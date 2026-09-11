# Agent self-steering: how an opencode session avoids recorded mistakes (research)

Status: research draft (2026-09-11, delegated opencode session 2). Companion to
`docs/research/2026-09-10-opencode-agentic-surface.md` (the session-surface
design); this doc studies the self-steering loop that landed on top of it.

## Question

How can an opencode agent actively steer itself away from the failure classes
recorded in a lessons file — and is hngh's current mechanism (write side
`append_ocgo_lesson` + read side in the executor/scout prompts) sufficient, or
what is the next line of the loop?

Related session-level question (the class this session exercises): session 1
died by ending its turn with a background subagent in flight, losing the
survey. Session 2 avoids that class by delegating synchronously and integrating
the result in-turn.

## Evidence read

hngh's own loop mechanics (all read this session):

- Write side: `automation/lib/launch-session.sh:39-58` — `append_ocgo_lesson
  CAUSE-CLASS` appends one line `UTC date | cause class | lesson sentence` to
  `automation/state/ocgo-agent-lessons.md`; cap at header + newest 200 entries
  (`launch-session.sh:50-55`); runs inside the launch path after
  classification, no daemon (`launch-session.sh:31-38`).
- Classification: `automation/lib/causes.sh:25-46` — `classify_cause` keyword
  bestiary over the log tail, first-match-wins over
  missing-design / missing-knowledge / missing-authority / bad-execution /
  obsolete / unknown; `lesson_for_cause` (`causes.sh:54-75`) maps each class to
  one fixed sentence.
- Happy-path skip: `launch-session.sh:207-210` — a lesson line is appended only
  when rc≠0 or the class is not `unknown`; a clean exit would pollute the file
  with "you failed" noise on every success (first-session finding, recorded in
  the 2026-09-11 reclassification row).
- Read side: `automation/config/opencode/agents/executor.md:9-14` and
  `automation/config/opencode/agents/scout.md:5-8` — first action every
  session/tool is to read the lessons tail and "actively steer away from every
  recorded class"; the executor prompt additionally carries
  "never end the session with work in flight" (`executor.md:59-62`) — the
  lesson actually recorded so far.
- Live file: `automation/state/ocgo-agent-lessons.md:1-6` — header plus one
  line (2026-09-11T03:34:05Z, reclassified rc=0 success: never end the session
  with a background subagent in flight).
- Session-1 transcript (`ses_f7179a85bffeJAPHuoFs3RSO0k`): delegated the survey
  via a background subagent (`bg_5313d536`), ended its turn while waiting
  (03:34:01Z), and the launch path exited with the survey in flight; the task
  record is unrecoverable afterward. Session 2 (this one) delegates
  synchronously (`run_in_background=false`) and integrates the result
  in-turn.
- Registered surface: `automation/config/opencode/opencode.jsonc:89-100` —
  `hngh-scout` is a read-only subagent (edit/bash/task/todowrite denied); the
  executor is the primary (`opencode.jsonc:83-88`).

Prior-art survey (delegated to the scout subagent this session; integrated
below). Local: the operator's llm-wiki has no harvested entries on
self-correction/memory strands — the existing
`hngh-prior-art-landscape-2026-08.md` synthesis covers agent-security models
and harness governance but not this lens; the kernel's operator-curated
lessons table (`llm-wiki/wiki/concepts/hngh-lessons-current.md`) already runs
the post-mortem→config-change pattern with "Change landed" / "Guardrail added"
columns — the ocgo lessons loop is its lightweight session-level twin.

External prior art: Reflexion (Shinn et al., NeurIPS 2023, arXiv:2303.11366);
Self-Refine (Madaan et al., NeurIPS 2023, arXiv:2303.17651); MemGPT/Letta
(Packer et al., arXiv:2310.08560); FORGE (arXiv:2605.16233, evaluated on the
CybORG CAGE-2 benchmark); MAGE (arXiv:2605.10064); Harness-R1
(arXiv:2608.02276); Co-Harness (arXiv:2607.22688); AHE / Agentic Harness
Engineering (arXiv:2604.25850); Claude Code auto memory (MEMORY.md, 200-line
session-start load); AGENTS.md convention; robinbril/claude-harness
(SessionStart-read / SessionEnd-write hooks); azena-ai/self-improving-loop
(self-rewritten genome); Boucle "217 Loops Later" retrospective; OpenAI
self-evolving agents cookbook; a long-run-watchdog skill
(merceralex397-collab/skilllibrary) with classify/recover/record structure.

## Doctrine applied

- Reads stay read-only; research sessions mutate exactly one file (this
  assignment's autonomy rule). No TSV edit is made — the scout's proposed
  next TSV line is carried as draft text in this doc, for a writer session.
- Fail-closed on history: the loop's own first recorded lesson was hand-
  reclassified (`automation/state/ocgo-agent-lessons.md:6`); a loop that
  cannot verify its lessons is treated as evidence-producing, not
  behavior-guaranteeing — reviewers advise, records decide.
- Every claim outside hngh is labeled prior art; every claim inside hngh
  carries a file:line anchor.

## Findings

1. **The loop's four parts each have a mainstream analogue.** Write side =
   Claude Code auto memory's machine-appended lesson log (one entry per run,
   read at session start — same shape as `launch-session.sh:39-58`);
   read side = the SessionStart instruction pattern confirmed across
   AGENTS.md/CLAUDE.md harnesses and by `executor.md:9-14`;
   classification = the structured cause bestiary
   (`causes.sh:25-46`, deterministic keywords) which the watchdog-skill
   prior art implements as `{condition, action_taken, outcome}` records;
   cap-and-replace = both Claude's 200-line MEMORY.md load and
   `launch-session.sh:50-55`. The loop is not bespoke; it is a
   recognizable pattern implemented at the cheapest possible scale.

2. **The one live lesson was produced in the loop's weakest mode — and the
   demo occasionally validates it.** `classify_cause` matched
   `bad-execution` on session 1's log (`launch-session.sh:201`), the
   reclassification row shows that assignment was a false positive
   (`ocgo-agent-lessons.md:6`), and the correct sentence exists only because
   a writer tightened `causes.sh` the same day. This session demonstrates the
   steering working (synchronous delegation vs session 1's background
   in-flight death; `executor.md:59-62` vs `executor.md` research rule), but
   the steering happened twice hand-authored into the prompts, not derived
   from the recorded line by the mechanism. Prior art agrees the mechanism
   needs the agent to apply the lesson, not just read it — Reflexion's
   actor conditions on its stored reflections
   (arXiv:2303.11366); Claude's auto memory works because the notes land in
   context. The step between "read the tail at session start" (executor.md
   first-action rule) and "steer away from the recorded class" is current
   model discipline the loop trusts but does not measure.

3. **The happy-path skip is a hngh-native selection pressure that prior art
   independently arrived at.** `launch-session.sh:207-210` keeps clean exits
   out of the failure file — the same instinct as MAGE's separation of
   failure memories from success traces (arXiv:2605.10064). But selection
   pressure cuts both ways: FORGE found isolated reflection accumulates
   counterproductive artifacts without a filtering mechanism
   (arXiv:2605.16233), and the Claude auto-memory retrospective warns of
   "trauma replay" — after ~50 machine-appended corrections the agent
   steers for all of them at once and performance degrades. hngh's 200-entry
   cap (`launch-session.sh:50-55`) bounds the file, not its behavioral load;
   nothing in the current mechanism marks a lesson as done/verified once its
   class stops recurring.

4. **Harness-written writes are a real divergence from the field's drift
   toward agent-written memory and are worth keeping.** The field's pattern
   is the agent editing its own memory or genome
   (azena-ai/self-improving-loop rewrites its genome in-flight; Claude's auto
   memory is model-judged). The Boucle "217 Loops Later" retrospective is the
   cautionary case: self-written summaries drifted into systematic optimism
   and only an external reviewer caught it. hngh's write side is
   harness-owned (`launch-session.sh`), classification is deterministic
   keyword matching, and the recorded sentence is fixed vocabulary
   (`lesson_for_cause`, `causes.sh:54-75`): the agent never authors its own
   lesson. That is structurally immune to the Boucle drift and matches
   hngh's fail-closed doctrine. The cost, per Harness-R1's measurement that
   fixed reflection strategies can lower reward
   (arXiv:2608.02276), is that one fixed sentence per class may be less
   useful than a session-specific one — an untested trade here, not a settled
   win.

5. **A mature form of the loop exists and marks the next line: lesson =
   falsifiable claim, verified by the next session's outcome.** AHE pairs
   every harness edit with a self-declared prediction verified at the next
   round, reverted at file granularity when falsified (arXiv:2604.25850);
   Co-Harness's HarnessCritic checks a proposed fix against the targeted
   failure class before accepting it (arXiv:2607.22688). hngh's loop
   currently has neither property: nothing records which lesson a session
   was steering against, nothing verifies the class stopped recurring
   because of the lesson, and nothing marks a lesson done. The session-1
   failure class (background subagent in flight) is the working example:
   the loop records it once, but no mechanism adjudicates whether the
   class is closed when the next session avoids it.

## Recommended next line

Two concrete moves, in order:

1. **Close the verification gap first.** Add a falsifiable-lesson column to
   the lessons line — what to check, and what the next session's outcome
   means for the class. Shape (draft only, for a writer session's
   `append_ocgo_lesson` slice): `date | class | lesson | verify-sentence`,
   where `verify-sentence` names one checkable behavior and one condition
   that marks the class closed (class stops recurring across N sessions).
   The happy-path skip and 200-entry cap stay untouched.
2. **Then evaluate a session-owned confidence probe.** One line in the
   executor prompt contract — after reading the tail, the session reports in
   its final output which recorded classes it steered against (or "none") —
   so the loop can measure steering instead of trusting it, without handing
   the agent write access to the file (the harness-owned write side stays
   as-is per Finding 4).

Not researched here and deliberately out of scope: automated
sentence-generation for lessons (the Harness-R1 direction), any provider or
model leg, and duplicate lessons table systems at the kernel level
(covered in `llm-wiki/wiki/concepts/hngh-lessons-current.md`).
