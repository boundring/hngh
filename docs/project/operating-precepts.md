# Operating precepts — how Hngh is meant to grow

The operator's design doctrine (2026-08-26, folded from reorientation):
nine precepts that every future slice, refactor, and architecture
decision must be checked against, alongside the wired-state lens.

## 1. Watchers over gates
Scheduling is about *watching*, not policing. We schedule varying kinds
of watch sessions for any given thing: procedural watches nearly
continuously (event-fire and 1m), agentic watches from the 1m mark
onward for small items, slower for heavy/expensive ones. Oversight is
adaptive, not a fixed 10-minute default.

## 2. Cadence is dictated by cost, not an arbitrary ladder
Procedural actions/evaluations can happen pretty much continuously and
cost almost nothing. Agentic actions are flexible but scale poorly:
they run from the 1m mark for small things, more often than not, and
lots of work can be parallelized — the cadence is whatever the task's
evaluation time requires, chosen by the piece, not by a global timetable.

## 3. Two optimization levels, both scheduled
Level 1: continual and procedurally scheduled optimization routines
(the cadence ticks, the sweep, the grade loop). Level 2: the self-
review modes that improve Level 1's own dispersion and placement
(what fires on-change vs by-poll, which probes fit which window). Both
levels are planned, period — self-optimization is a standing function,
never an afterthought or a fire-fight.

## 4. Security is not rotated keys
Key/token rotation is base hygiene; the security surface keeps
regularizing (per-job least-authority credentials, patch-state
evidence, incident-response evidence chains, audit trails). New trust
boundaries must justify their existence and come with health probes,
rotation, and revocation stories, never afterthoughts.

## 5. Governance is clean-architecture
Governance development sticks to the same clean-architecture rules as
the kernel: pure cores, injected ports, inward dependency, evidence
before claims. We build clean-architecture-created governance for
clean-architecture operations for clean-architecture results.

## 6. Larger architecture resembles smaller, biologically inspired
We are big fans of the large resembling the small (fleet node mirrors
the single node; one governance spine). Where biology is provably
efficient — nervous-system coordination, homeostatic loops, coherent
alignment by orientation and proximity — take the practical abstraction
and apply it. Information sharing happens laterally, at every level,
like nervous systems interlinking — at speeds biological nervous
systems cannot reach.

## 7. Nervous-system-like control planes
More than a dashboard spine: distributed and unified logging and
control, like a nervous system. Sensory input (evidence, breadcrumbs,
reports) flows up to a unified brain (the control plane / dashboard);
motor output (steers, hooks, certificate-bound mutations) flows down
to effectors. Nervous systems interlink and share information so each
node "knows" — in ways biological ones cannot.

## 8. Continuity as a primary value
Across all fronts, things hold by their *nature, orientation, and
proximity*, like DNA/RNA/proteins — structure that keeps coherent
alignment and function through how parts are placed and how they
natural, without central intervention. The wiring must make
continuity the default: simple parts, complex whole, the harness
composing any system by repeating the base principles.

## 9. Simple parts, complex whole; harness anything
Hngh will harness practically any software and system in the long run.
That means methodically applying base principles over and over
(atomicity, evidence-before-claims, least authority, fail-closed,
coherent orientation), letting the project take complicated and simple
forms to suit emerging needs — more interwoven, aligned harnesses as
desired, never accidental complexity.

---

These precepts are aspirational direction, not a spec: each becomes
concrete when a slice proposes a design that realizes one. The wired-
state lens checks that such slices land with an eye toward the
watch/cadence/unified-logging/continuity dimensions.
## 10. Model tiering — cost/context-optimized calls
Primary functions rely on local models and the cheapest remote models.
Occasionally call smarter/more expensive models, but only in the most
context-optimized and cost-optimized manner. Even local/cheap calls are
context- and cost-optimized; advanced (expensive) calls are held to a
higher bar — bounded payloads, right-sized context, one-shot where
possible, gated to the cadence beat that can afford them. The route
ladder (local < cheap-remote < expensive-remote) is decided by the
evaluation's cost window, not by habit (precept 2).

## 11. Hngh improves Hngh (dogfood the whole loop)
We do not want to use other tools to work WITH Hngh forever; the goal is
Hngh governing its own development. While OMP/oh-my-pi bootstraps Hngh,
the direction is: a plugin interfaces oh-my-pi directly with Hngh
(reusing oh-my-pi's structure while Hngh grows), and Hngh advances toward
hosting its own sessions and applying the same clean-architecture and
roguelike-development rules to its own development that it enforces
in-kernel. Agents working ON Hngh run under the same roguelike death rule
and the same wired-state lens as agents working IN Hngh — a stalled
build-session is as dead as a stalled ceremony, and its replacement is as
failure-informed.
