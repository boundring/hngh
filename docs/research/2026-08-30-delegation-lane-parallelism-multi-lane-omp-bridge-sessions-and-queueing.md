# delegation lane parallelism: multi-lane omp-bridge sessions and queueing

Status: crystallized 2026-08-30 from research line `delegation-lane-parallelism-multi-lane-omp-bridge-sessions-and-queueing`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-delegation-lane-parallelism-multi-lane-omp-bridge-sessions-and-queueing.md.

# Final Structured Summary — Delegation Lane Parallelism: Multi-Lane `omp-bridge` Sessions and Queueing

**Line:** delegation lane parallelism: multi-lane omp-bridge sessions and queueing
**Lifecycle state:** contracting → **contracted / recommended record**
**Disposition:** Do not pursue a “multi-lane manager” as the primary design. Contract the line to a prerequisite architectural change: introduce a minimal asynchronous delegation queue in the `omp-bridge` layer, then revisit explicit lanes only if telemetry justifies them.

---

## 1. Executive Finding

The original research premise treated “lane parallelism” as an optimization of existing delegation, scheduling, or lane-management code. The available line record does not support that framing.

According to the supplied prior beat, verification against the `hngh` repository found no dedicated delegation/scheduler module, and this grounded pass confirms the kernel has no scheduler surface at all (the kernel is a pure Common Lisp core — `src/domain/`, `src/application/` — whose only concurrency story is the certificate loop; there is no `delegation` or `scheduler` module). Verification found no evidence for the assumed artifacts:
- a dedicated lane manager
- an exposed kernel scheduler API usable by the bridge

I cannot independently re-enumerate the repository from this session, so this final record does not assert those paths exist. It treats them as **not established** based on the prior beat’s verification note.

The practical conclusion is:

> The `omp-bridge` delegation path should be treated as a greenfield queueing problem, not as a tuning problem for existing lanes.

---

## 2. Findings

### F1 — “Multi-lane” was initially based on assumed code structure

The prior expansion referenced lane-management abstractions that were assumed to exist. Verification against the repository found none: delegation lives entirely in the `omp-bridge` outer adapter (a Python script), not in kernel source. The C-style filenames the expansion guessed at do not exist in this repo.

**Status:** Not supported by available evidence.
**Grounding:** Verified 2026-08-30 against the repository: `scripts/omp-bridge` (the delegation surface, single outer-adapter script) and the kernel docs read-order (`docs/README.md`, `docs/architecture.md`) show no lane/scheduler component. Assumed artifact names from the expansion beat are treated as fabrications, not as files that were merely hard to find.

---

### F2 — The current `omp-bridge` delegation path appears synchronous and single-threaded

The prior beat describes the existing `omp-bridge` behavior as a single-threaded, synchronous event loop within the automation layer.

**Status:** Reported in the line record; not independently re-verified in this session.
**Grounding:** Supplied prior research beat 2026-08-30.

This matters because if delegation is executed synchronously on the bridge’s event path, then adding “lanes” without changing submission/execution semantics would not remove head-of-line blocking.

---

### F3 — No existing delegation queueing infrastructure was identified

The available line record does not identify an existing queue, task store, backpressure mechanism, or lane scheduler for `omp-bridge` delegation.

**Status:** Reported in the line record; not independently re-verified in this session.
**Grounding:** Supplied prior research beat 2026-08-30.

Therefore, “parallelism” requires a new submission/execution boundary rather than merely distributing work across existing lanes.

---

### F4 — Head-of-line blocking is best explained by synchronous execution, not lane scarcity

If delegation requests are handled synchronously, one slow request can block subsequent bridge activity regardless of whether the conceptual model calls them “lanes.”

**Status:** Architectural inference grounded in the prior beat’s description of synchronous behavior.
**Grounding:** Supplied prior research beat 2026-08-30.

The minimal fix is to decouple request submission from execution.

---

### F5 — Kernel scheduler exposure to the bridge is not established

The prior beat states that no scheduler abstraction was found exposed to the bridge. The grounded pass agrees at the level that matters: the bridge's run governance is per-session (one `hngh` run per delegated session, created by `--run-start`), with no shared scheduler object the kernel exposes for lane arbitration. The bridge comment records the actual serial constraint: one shared bridge store and a single-flight assumption ("at check-in scale a single bridge run is in flight at a time"), plus a global ceremony lock.

**Status:** Not independently verified in this session; treated as unestablished.
**Grounding:** Supplied prior research beat 2026-08-30. No specific kernel scheduler file is cited because I am not confident it exists.

---

## 3. Recommendations

### R1 — Implement a minimal `DelegationQueue` first

Grounded against `scripts/omp-bridge` as it exists today (2026-08-30): delegation entry is one synchronous command, `--run-start SESSION OBJECTIVE`, which (a) creates a bounded `hngh` run with a fixed worker loadout and admits the worker transport, and (b) writes the session into one shared bridge store under `AUTOMATION_ROOT/bridge` — the script itself carries a `ponytail:` note that this is a single global store, widened only "if two delegated sessions ever need to be open concurrently", and a single global ceremony lock serializes landings. So today's "lane model" is: one explicit command per session, one store, one lock — no queue object exists, and nothing is asynchronous.

That matches this line's contracted conclusion exactly: the first architectural change is a **minimal DelegationQueue at the omp-bridge layer** — accept a delegation record, persist it, and let a later tick or session pick it up — before any multi-lane manager is designed. The queue's first consumer is already visible in the repo: the overnight cycle executes the next unchecked step of the oldest accepted plan one at a time (`hngh-automation/scripts/overnight-cycle.sh` per docs/project/plans/README.md), which is precisely the single-lane consumer a DelegationQueue would feed. Explicit multi-lane scheduling remains not established as a need until telemetry (per-lane medians, gantt actuals — roadmap stage 3's own exit criteria) shows head-of-line blocking at more than one concurrent delegation.

**Status of this recommendation:** design direction only; no code written in this beat. Kernel src/ changes are forbidden to machine sessions (standing autonomy rule), so any implementation lands in the bridge/automation layer or parks.

## Grounding

Verified paths read in this repo (2026-08-30):

- `scripts/omp-bridge` — the delegation surface: `--run-start SESSION OBJECTIVE`, `--run-end RUN DISPOSITION`, `--orient/--register/--note/--task/--ceremony`; single shared bridge store (`BRIDGE_STORE`, one run in flight at a time), global ceremony lock, `:created`-only legal close (`cancelled`)
- `docs/project/roadmap.md` — stage 3 "roguelike delegation live" (the wrap criteria this line feeds)
- `docs/project/backlog.md` — "Pi read-only delegation spike" and "Bridge-backed continual worker" rows (the bounded-worker surface a queue would feed)
- `docs/records/2026-08-30-lessons-and-foldback.md` — the failure classes observed in the 33h window (agent-stall, slow-unit) that motivate bounded, queued delegation

Not established: whether any second concurrent delegation consumer exists in hngh-automation (single-flight was assumed from the bridge store note, not enumerated); multi-lane demand remains unproven by telemetry.
