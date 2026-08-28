# Hngh intent

## What Hngh is

Hngh turns development into short, bounded cycles — plan, check, record, close — that an
automated agent can run while a human keeps the final say. Each cycle leaves a paper trail
of evidence. Nothing changes the system without passing a check and being recorded. The
kernel itself is side-effect-free: it does nothing on its own, owns no background process,
and refuses anything unknown or unverified (fail-closed).

## Why this exists

Automation grows more capable every year, and that is exactly when trust gets harder. Most
agentic and developer tools act without a record and without clear boundaries. They change
files, run commands, or call models, and afterward there is little to show for how or why.
When something goes wrong, you cannot reconstruct what happened, and you have no clean place
to say "no."

That is the problem Hngh is built for. Trustworthy automation needs two things ordinary tools
skip: a paper trail, and a human who has the final say. Every decision here is designed to
keep those two things true — every action is recorded, and nothing is treated as approved
until a checked, ruled-on decision says so. When the machine suggests, plans, and asks, and
the human confirms, automation stays useful without becoming an uncontrolled actor.

## How work happens

Work in Hngh happens as a run: one bounded attempt at one objective, with a clear start, a
clear end, and checkpoints in between. A run is not a general "session" that people open and
leave running. It is a small, finite loop, and each loop is complete on its own.

A person sees a run pass through a simple life:

- **Created.** A run exists as an idea with a mission, a role, and limits. Nothing has
  happened yet.
- **Armed.** The run asks for permission and gathers evidence. It is only allowed to start
  when its request is confirmed.
- **Running.** The run does its work, under the limits it was given.
- **Checkpointed.** Verified progress is recorded. A person can see what is done and what
  evidence backs it.
- **Closed.** The run ends in one of a few definite ways — cancelled, evacuated, or dead.
  A closed run stays closed. If you want another attempt, you start a new run; nothing
  retries or continues silently on its own.

Each run is a complete loop. The work repeats — that is the point — but every repetition
starts fresh, with its own evidence and its own checks. Nothing carries over by accident,
and nothing is assumed from a previous try.

## The roguelike idea

The design borrows discipline from roguelike games — deliberately, and as a metaphor only.
It is a proven way to keep progress honest, not a game to be won.

In a roguelike, a run is finite: it has a start, checkpoints, and an end, and when it ends it
is over. "Permadeath" there means the run does not quietly continue or auto-retry; you begin
a new run instead. In Hngh, that same discipline is containment, not punishment. When time or
budget runs out, a check fails, a request is unsafe, or a run expires, the run ends. There is
no automatic retry and no silent continuation. The good ending is "evacuation": named
deliverables and verification evidence are handed over, and what was learned is preserved.
Even a dead run keeps its last verified checkpoint and a bounded salvage record.

The other borrowed idea is the "camp": one tiny, behavior-sized change, then a pause where
evidence, cleanup, and the next move are recorded. Small verified steps, each one leaving a
trace — never a long stretch of unrecorded work.

This is a metaphor for discipline, not a game. Hngh uses "run," "checkpoint," and
"evacuation" as plain working words (defined below); the game flavor is only a reminder that
dead ends stay dead and progress has to be earned.

## What the kernel guarantees

The kernel is the quiet center of Hngh, and it promises five things:

- **Side-effect-free.** The kernel reads no clock, no files, no network, and no process. On
  its own it changes nothing on the machine. All the messy real-world activity lives outside
  it, at the edges, where the rules still apply.
- **Fail-closed.** Unknown, malformed, duplicate, or unverified input is refused. The kernel
  never guesses and never skips a check. If it cannot say "yes" for certain, the answer is
  "no."
- **Evidence, not authority.** A record of what happened — a receipt — describes or justifies
  what went on. By itself it grants no power. Recording that something happened never makes
  it approved.
- **One action per certificate.** A certificate is permission for exactly one action
  (prepare, stage, commit, or push), bound to specific files and specific evidence, and
  re-checked immediately before that action runs. There is no blank permission slip.
- **No hidden execution.** Nothing runs in the background, no daemon watches, no work starts
  without a started run. If you are not looking, nothing is doing.

## Clean architecture, briefly

Hngh keeps its rules in a pure core that depends on nothing external. The core decides what
is valid — which states a run may be in, which evidence is admissible, which verdict a
proposal earns. It knows nothing about Git, model providers, terminals, or files.

The messy outside world plugs in later, at the edges, through explicit ports (formal entry
points) and adapters (the plug-in pieces that talk to real things such as Git or a model).
The important rule is one-way: the core never knows about the outside, and the "is this
valid?" decision never lives in an adapter. That means the rules stay small, testable, and
safe to reason about, no matter what real-world machinery gets attached later.

## Agents: Pi and beyond

Long-term, Hngh is meant to orchestrate an automated worker — likely one called Pi — that
actually carries out runs. Today the bounded read-only worker task (`run-worker`, rung 18)
and the one-shot `scripts/worker-driver` cycle are installed behind a port; the durable
Pi RPC compiler agent remains a survey and a plan.

When a worker arrives, it will sit behind a port: a replaceable outer layer that Hngh can
swap out. The worker is read-only by default. Hngh keeps authority, holds the evidence,
and holds the power to end any run. The worker may only act on the one action its current
certificate names, verified at the moment of action. The agent harness that sits on
top is "oh-my-pi," installed and live: its omp-bridge gates
delegated runs through create-run and admit-transport
(`2026-08-26-omp-bridge`), and the watchdog watches it work.

The standing rule: a worker is a tool, never the source of truth. The truth lives in the
evidence and the checked decisions, and the final say stays with the human.

## Cost discipline

Automation can spend real money — tokens, compute, time. Hngh plans to make that spending
deliberate with a simple ladder:

- Try the cheapest adequate route first.
- Use an expensive route only when it is named and evidenced — you say why it is needed, and
  there is a record of the reasoning.
- When the cost is unknown, refuse. No unbounded or unestimated spending.

The rule of thumb for a person: cheaper is the default, expensive is a decision, and unknown
is a "no" until known.

## Words we use

| Term | Plain meaning |
|---|---|
| Kernel (`hngh.domain` + `hngh.application`) | The pure core that decides what is valid; it reads no clock, files, network, or process. |
| Run | One bounded work cycle with a definite start, checkpoints, and end. |
| Evidence | A record of what happened; it can describe or justify but never grants power by itself. |
| Receipt | A specific evidence record written when something happens. |
| Policy verdict | A deterministic pass-or-refuse decision computed from evidence; it admits only when every principle passes, and refuses anything missing, unknown, stale, or conflicting. |
| Certificate | Permission for exactly one action, bound to specific files and evidence, re-checked right before the action. |
| Fail-closed | Refusing unknown, malformed, duplicate, or unverified input — never guessing, never skipping. |
| Port | A formal entry point where the outside world plugs into the core. |
| Adapter | A plug-in piece at the edge that talks to real things (Git, models, terminals). |
| Checkpoint | A verified point in a run where progress is recorded. |
| Evacuation | The good end of a run: named deliverables and verification evidence handed over. |
| Permadeath (analogy) | Ending a run for good when a check fails or limits run out; no auto-retry — containment, not punishment. |
| Ledger | The running record of proposals and their evidence that policy rules over. |

## Today and next

Today Hngh is a self-watching control system: a pure kernel with closed run lifecycles,
governance policy, nineteen operator verbs, a cadence of single-tick timers that drive and
correct the machine on every tier from one minute to daily, a nerve-center webapp
(Schedule, Sessions, System, Research, Logs) with a session observatory that reads live
agent transcripts, and a time ledger that measures every operation so delays are noticed
procedurally. There is no daemon; every timer is an operator-installed single tick. The
direction ahead — seven named stages with exit criteria — is set out in the
[consolidated route](project/roadmap.md); read it for what gets built next and in what
order.

The long horizon is a mesh, not a bigger machine. Each Hngh node guards its own small
boundary — a machine on a shelf, a hand-held that mostly sleeps, a laptop whose network card
is older than the person using it — and each runs the same narrow rulebook: evidence first,
then a place. What one node learns (this bridge drops at three in the morning, this tunnel
has held for a year, this load draws this power, this device woke when asked and stayed quiet
otherwise) is written down as a fact a neighbor can cite, not buried in a ledger only one
wall will ever read. A node wakes a neighbor before it is needed, keeps the corridors open
without a watching process, and admits a new low-powered peer the only way anything is ever
admitted here: through a proposal, a check, and a record. One machine learns only what its
own wall taught it; a lattice of small ledgered machines is how a city crosses a lawn, then
the next lawn, then the planet — and no wall stands that does not say who raised it. None of
that exists yet. It is the direction, and the direction is admitted one verified stretch at a
time, the same as everything else.

---

Back to the [documentation index](README.md).
