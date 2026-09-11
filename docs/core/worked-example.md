# Worked example

One full Hngh cycle and one automation beat, quoted from captured
records. Nothing here is staged: every quoted fact links the record it
came from. If a step has no captured transcript, the record's own
words are quoted instead of a reconstructed terminal session.

---

`[ PART I. THE KERNEL CYCLE ]`

## create-run to close-run, in five verbs

A run is one bounded work cycle. The operator drives it through
`scripts/hngh`; the kernel (`hngh.domain` + `hngh.application`) does
the deciding; nothing is written down except through a receipt.

### 1. create-run

The operator creates a run: one objective, a mission, a role, a
loadout. The run starts in `created` and nothing has happened yet -
the domain validates the closed vocabularies and records the birth
receipt.

    what just happened: a pure value was born; nothing outside the
    kernel was touched.

### 2. admit-transport

The operator admits a transport for the run - a `:model` route for
bounded review, a `:terminal` evidence capture, or a `:worker` task
label. Admission is policy-gated: the run must hold the receipt the
policy names, and an unadmitted transport refuses.

    what just happened: the run gained one explicit capability,
    recorded as evidence - not a configuration flag.

### 3. arm-run and start-run

`arm-run` gives the run one job and the evidence for it; `start-run`
moves it to `running` with one atomic transition record. There is no
way to skip the intermediate states: the lifecycle in
[architecture.md](../architecture.md) refuses every other transition.

    what just happened: the run became live, with a paper trail
    already two receipts deep.

### 4. checkpoint

`checkpoint` admits only closed verification and manifest evidence
through a run-only request value. A checkpoint is the run's
checkpointed state: verified progress, bound to evidence, or a
refusal.

    what just happened: progress was claimed and made checkable, or
    the claim was refused - there is no third outcome.

### 5. close-run

A run reaches a terminal state only under an `:admitted` policy
verdict (policy-gated `close-run`). Cancelled, evacuated, or dead -
then `afterlife -> scored -> archived`. Evacuation is the good
ending: named deliverables and verification evidence handed over.

    what just happened: the cycle closed. Every repetition starts
    fresh - nothing carries over by accident.
---

`[ PART II. THE GOVERNANCE LOOP ]`

## propose, issue-cert, mutation-check

The same verbs the kernel runs with also govern this repository's own
changes. The loop was first exercised end to end on 2026-08-24
([first self-governed commit](../records/2026-08-24-first-self-governed-commit.md));
the command surface's contract is in the
[dogfood record](../records/2026-08-24-command-surface-dogfood.md).

1. `propose` - forms a closed policy proposal and renders the
   deterministic verdict. Evidence requirements arrive as
   `PRINCIPLE:KIND:FINGERPRINTS` (strict format, from the dogfood
   record's contract).

       what just happened: the machine was asked whether a change may
       happen, and answered from a closed principle matrix - not a
       vibe check.

2. `issue-cert` - mints a candidate certificate bound to a stored
   admitted run. The certificate recomputes its bindings from the
   store: repository identity, base revision, candidate paths, the
   admitted verdict.

       what just happened: permission for exactly one action was
       minted, bound to specific files and evidence.

3. `mutation-check` - replays the certificate against fresh evidence
   and executes only the certificate-bound fixed Git action. Stale
   facts, expiry, or a mismatched hash refuse without a mutation.

       what just happened: the commit happened because the evidence
       still agreed - not because someone remembered to check.

The scale of that loop, machine-checked on its first full day
([journal, 2026-08-25](../journal/2026-08-25.md)):

- `make test`: 2,774 checks + 8 reader guards, green.
- 60 commits moved that day; 45 of them candidate-bound.
- The loop-history guard watched every code-surface commit: 24
  code-surface commits / 1 named exemption / 0 violations.

Exit codes across the whole surface: `0` accepted/admitted/executed,
`1` refused/mismatch, `2` malformed, `3` transport fault (dogfood
record, decision 1).

---

`[ PART III. ONE AUTOMATION BEAT ]`

## What the machine hall fired today

The cadence tier runs single-tick timers (no daemon) and files a
digest of every beat. Below is the 0000Z beat of
[2026-09-11](../../automation/digest/2026-09-11.md), quoted verbatim
from the committed digest - the model leg is named on every beat:

> ## 0000 2026-09-11
> _sources: breaking,hn-topstories,gh-trending,service-status,
> claude-status,fear-greed,launches,hnrss,phoronix,arxiv-csai,
> cisakev,ghblog | model: unsloth:unsloth/Qwen3.8-27B-GGUF_
> CRITICAL: CVE-2026-86060 allows privilege escalation in MikroTik
> RouterOS via improper neutralization of argument delimiters.
> NOTABLE: Anthropic status is "Partially Degraded Service" while
> Claude Cowork is in "degraded_performance".
> CONTEXT: Fear and Greed Index value is 56 labeled "Greed".

    what just happened: a local model (bench-gated unsloth leg) read
    thirteen feeds in one tick, classified what it found, and filed
    it - the whole beat is one timer tick, recorded. The same digest
    shows the 0200Z beat returning "none - quiet window": the machine
    is allowed to be quiet.

That is the texture of the machine hall: many small ledgered beats,
each one a fact. The digest that beat belongs to,
[the day's journal](../journal/2026-09-11.md), and
[the Descent loop](../design/descent.md) that audits it are the next
reads.

---

Back to the [documentation index](../README.md).
