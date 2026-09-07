# TTSR alignment — the Splice

Status: DESIGN — Task ttsr-alignment, 2026-09-07.
Canonical term: **ttsr alignment**. Display alias: **"the Splice"** —
the stream cut-and-rejoin (the record is severed mid-generation and
resewn around an injected rule).

## (a) The two-layer doctrine

oh-my-pi's TTSR (Time Traveling Stream Rules) prevents session-discipline
violations **at the stream layer**: markdown rules with regex/ast-grep
`condition` frontmatter are matched against the live output stream while
the assistant generates; a match aborts mid-flight and retries with the
rule body injected as `<system-interrupt reason="rule_violation" rule=...>`.
Non-interrupting scopes prepend `<system-reminder reason="rule_violation">`
to tool results or queue a hidden followUp message. Facts, with sources:

- Rule files: `~/.omp/agent/rules/*.md` (user scope); frontmatter keys
  `name`/`description`/`globs`/`alwaysApply`/`condition`/`scope`/`agents`/
  `interruptMode` (omp TTSR docs; the two live files carry `condition` + `scope`).
- Settings group `ttsr`: `enabled` (default true), `contextMode`,
  `interruptMode`, `repeatMode` (`once|after-gap`), `repeatGap` — live in
  `~/.omp/agent/config.yml` under `ttsr:` (verified 2026-09-07: `enabled: true`).
- Detect surface: `stopReason 'aborted'` + `customType "ttsr-injection"`
  entries + `<system-reminder reason="rule_violation" ...>` blocks;
  `SessionManager.appendTtsrInjection` persists injected rule names
  (`getInjectedTtsrRules()`) (omp session-manager docs).
- The operator's two live rules: `no-ungrounded-time-of-day.md`
  (check the actual clock; schedule-neutral terms — "the next workbeat",
  "the 09:00 digest") and `research-continuous-not-batch.md` (research is
  CONTINUOUS on idle hosts; multi-day numbers are interim measurements
  to eliminate; state the continuous target).

Hngh **catches at the record layer**: deterministic, model-free screens
over session transcripts (`cadence/day/22-ttsr-fit.sh`) — prevention
where prevention is possible, detection where it is not. Missteps that
slip both layers are dispositioned by the existing machinery: the
Bestiary classifies the failure, the respawn ladder (`scripts/agent-respawn.sh`,
`jobs/agent-supervision.py`) corrects or parks it. Neither layer writes
the other's files: the stream layer belongs to the operator, the record
layer belongs to Hngh.

## (b) The three Hngh mechanics

- **VERIFY** — rule presence + a `ttsr.enabled` probe. Drift (a rule file
  missing, a condition emptied, the group switched off) means the
  operator's safety net silently vanished — alert `ttsr-rule-drift:<name>`
  even though nothing "happened". The absence of enforcement is itself
  the finding.
- **SUPPLY** — make the violations unnecessary. The machine clock is
  authoritative: context packs carry `current UTC (machine clock — verify
  against it, never assume)` (`lib/context-pack.sh`), so a model never
  guesses time of day and the no-ungrounded-time-of-day rule has nothing
  to catch. Continuity framing in briefs: the research beat prompt opens
  "one transition of a CONTINUOUS research process (line state:
  research-lines.tsv; prior material below)" — pace is never framed as
  batched, so the continuous-not-batch rule has nothing to catch.
- **DETECT** — the record-level screen: per-session counts of ttsr
  injection markers and post-hoc regex matches over assistant text,
  one identity-deduped alert per session past `ttsr-fit-threshold`
  (Inventory; env `TTSR_FIT_THRESHOLD` overrides).

## (c) The thinking-scope gap and the backstop

Stream rules monitor `scope: text` (and `tool`): the emitted stream.
**Thinking is not monitored.** A violation formulated in thinking and
then worded innocently in the visible text — or the same drift repeated
across subagents whose sub-transcripts no stream rule sees — passes the
stream layer clean. The record screen is the backstop: it runs the
mirrored condition regexes post-hoc over assistant text in the
transcripts (`~/.omp/agent/sessions/**.jsonl`, same specimen paths as
`jobs/agent-supervision.py`, read-only). Post-hoc screening cannot stop
the sentence — but it files the pattern, and filed patterns feed the
Bestiary and respawn disposition. Prevention at the stream, correction
at the record.

## (d) Integration horizon: Hngh-proposed rules as a governed artifact class

Lessons and Bestiary findings that keep recurring at the stream layer
should become **stream-rule candidates**: an artifact class with the
house cycle — proposal (a rule file drafted into a Hngh record),
check (the record screen proves the pattern actually recurs and the
regex does not over-fire), record (ledger entry citing the evidence).
The operator admits candidates into `~/.omp/agent/rules` by hand.
Hngh never writes there unadmitted. The first backlog row
(`docs/BACKLOG.md`, "TTSR proposal artifact class") opens when a second
recurring class survives the record screen long enough to deserve
prevention rather than detection.

## (e) Boundaries

- Hngh NEVER edits `~/.omp/agent/rules/*` — operator-owned, read-only
  always. VERIFY and DETECT only read.
- The screen's mirrored regexes live in ONE commented place at the top
  of `cadence/day/22-ttsr-fit.sh`, with the pointer: *source of truth:
  `~/.omp/agent/rules/{no-ungrounded-time-of-day,research-continuous-not-batch}.md`;
  re-sync on operator edits*. A copy that drifts from its source is a
  liability, not a mirror — hence the pointer, not a claim of ownership.
- `~/.hngh` is never written by this lane. No daemons: the screen is a
  day-tier drop-in, fail-closed (every path exit 0).

## (f) Lexicon row

| term | alias | one line |
|---|---|---|
| ttsr alignment | the Splice | stream rules prevent mid-generation; the record screen catches what the stream cannot see (thinking, subagents) — verify, supply, detect. |
