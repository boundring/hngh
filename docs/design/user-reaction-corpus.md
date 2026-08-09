# User-reaction corpus — steering comments as behavior data (card 118)

One page. Design-first. Feeds 116 (dashboard reaction trail) + 117
(auto-tuning evidence) + 115 (escalation format evidence). Per
artifacts/killy/93-user-reaction-corpus.md.

## 1. Problem

The loop's REACTION half (operator steers, corrections, OOB prompts,
timing judgments) is not captured as data. Agent actions are (111B
casebase feed, watcher state); the operator reactions that approve or
correct them are not paired with the action that triggered them.
Today's sessions are a dataset we are discarding.

## 2. Pairing — the core record

```
REACTION: <ts> <source: steer|oob|correction|timing-judgment>
  ACTION: <ts> <seat> <what was done — claim/card/commit/state>
  TEXT:   <the operator's words, verbatim>
  VALENCE: <approve|correct|flag|steer-new-work>
```

- The steers log (/tmp/hngh-steers.log, owned by the dispatcher
  §7.5) gains FROM=operator entries; the reacting seat's last
  ACTION line (its worklog HEAD) is the pairing target.
- A reaction is VALENCE-classified deterministically first (approve
  = no correction following; correct = followed by a correction
  clause; flag = problem-named; steer-new-work = new card direction)
  — same deterministic-first doctrine as the situation classifier
  (cross-agent-normalization.md §3).
- PAIRING IS APPROXIMATE: an operator steer may refer to the action
  minutes earlier (e.g. "hold it, slow down and stop"). The record
  keeps the RAW text + timestamp; the VALENCE and the paired ACTION
  are the classifier's best-effort, never silently rewritten.

## 3. Corpus — where it lives

- `~/.hngh-night/reactions/` — one append-only file per session
  (reactions-2026-08-09.md), same lane-append helper discipline as
  the tandem lanes: append-only, attribution footers, no clobber
  (killy's write_file lesson 15:31 applies here: NEVER write_file a
  reaction log, append only).
- The corpus stream joins the lesson queue (113) as BEHAVIOR
  guidance, distinct from failure lessons: "when the operator said
  X about action Y, Hngh should do Z". A reaction lesson has
  `kind: behavior`, a failure lesson `kind: failure`; the queue
  files them separately, both feed MisakaNet candidates when
  approved.
- Retention: operator-gated (privacy question, see §5) — default
  proposal: keep verbatim text locally, archive after 30 days to
  the dated back-dir (same as Projects/back pattern).

## 4. Learners — who consumes the corpus

1. Watcher auto-tuning (117): nudge outcomes already feed the tuner;
   operator timing judgments ("that can't be quite right", "seems
   like things are going well") become labeled evidence — the tuner
   prefers knob states that produced approvals over corrections.
2. Wake composition (§7.3): reaction patterns tune the composed
   wake's tone/length — e.g. repeated "too many nudges" flags → the
   wake gets shorter/rarer; repeated "didn't check the lane" →
   the wake names the lane explicitly.
3. Escalation format (115): which bounded-brief shapes got the
   fastest clear decisions is measured from the corpus — evidence
   for the SIZE/URGENCY defaults.
4. Dashboard (116): the reaction trail renders as a view — operator
   sees its own steering history as data, not prose.

## 5. Owner-gated (privacy/scope) — bounded brief

The card's owner-gated item: scope/privacy of user-generated text
recorded across sessions; storage location. Per 115 this is a
bounded brief (drafted, awaiting operator return):

```
DECISION: what user-generated text may be recorded in the corpus,
and where it lives.
CHOICES:
  A. Verbatim local-only, 30d archive — text recorded as-is,
     never leaves the machine, archived after 30d. (privacy:
     strongest; evidence: full fidelity)
  B. Redacted local-only — names/secrets/identifiers scrubbed by
     the existing secrets-guard before recording. (privacy:
     strong; evidence: full but scrubbed)
  C. Verbatim + synced (backup-manager tree) — crosses devices
     with the state tree. (privacy: weaker; evidence: available
     everywhere)
SIZE: M   URGENCY: today   BLOCKS: 118 design-final, 117 tuner
REVIEWED: (pending 2-seat)
DEADLINE: none
IF NO DECISION: fail-closed — NO verbatim recording; corpus starts
empty, only VALENCE+ACTION (no TEXT) is captured. Nothing sensitive
is recorded until the operator chooses.
```

## 6. Acceptance

- Design doc (this page) → operator gate on §5.
- Pairing: steers log gains FROM=operator; reaction record pairs
  TEXT + ACTION + VALENCE (deterministic classifier).
- Corpus: append-only per-session reaction log, behavior-kind
  lessons join the 113 queue.
- One behavior rule extracted from corpus evidence (acceptance per
  card) once the operator opens recording.
- Dashboard shows the reaction trail (116 view).

Attribution: tandem seu — deepseek/deepseek-v4-flash-0731, hermes
TUI, 2026-08-09. Informed by artifacts/killy/93-user-reaction-
corpus.md + card 118 + cross-agent-normalization.md §3 + 115.
