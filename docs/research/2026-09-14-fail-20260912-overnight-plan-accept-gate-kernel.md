# Was the 2026-09-12 kernel make test rc=2 that blocked routed-plan acceptance a real kernel defect or a load transient, and what disposition (fix or park) closes alert identity overnight:plan-accept-gate:kernel?

Status: crystallized 2026-09-14 from research line `fail-20260912-overnight-plan-accept-gate-kernel`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-fail-20260912-overnight-plan-accept-gate-kernel.md.

# Research Line — Final Structured Summary (Contracting)

**Line:** Was the 2026-09-12 kernel `make test` rc=2 that blocked routed-plan acceptance a real kernel defect or a load transient, and what disposition (fix or park) closes alert identity `overnight:plan-accept-gate:kernel`?
**Lifecycle state:** contracting — this record is the line's lasting form.
**Repo under study:** `/home/bricker/Projects/etc/hngh` (hngh kernel repository; location as stated in the line, internal paths not verified from this position — see References).

---

## Verdict (one line)

The 2026-09-12 rc=2 is **not yet classifiable** as defect-vs-transient because the decisive artifact (the specific failing make target plus its stderr) was never captured into the line record; the **gate mechanism is the primary failure locus**, and the alert identity `overnight:plan-accept-gate:kernel` closes only on a **reproduced artifact** — never on elapsed time.

---

## Findings

**F1 — The triggering event is established; its cause is not.**
The 2026-09-12 kernel `make test` returned rc=2 and blocked routed-plan acceptance; that much is fixed in the line state. What is *not* fixed is *why*: no record in this line names the failing target or carries the stderr of that run, so defect-vs-transient remains an open classification, not a settled one. I am stating this as a gap in the line record, not asserting a cause.

**F2 — rc=2 is information-poor by construction.**
rc=2 is GNU make's generic "fatal error" exit bucket; it does not encode *which* target failed or *why*. (This is standard GNU make semantics — external tooling knowledge, consistent with the prior beat on this line; I am flagging it as general rather than repo-verified.) A gate that consumes only the bare rc therefore cannot distinguish a kernel compile error, a test assertion failure, or an OOM/timeout kill. The alert identity is being held open by a signal that was never designed to carry the needed detail.

**F3 — The gate is information-starved, and that is the amplification mechanism.**
The acceptance gate consumes bare rc=2 without parsing make output. [[sources/hngh-2026-09-09-stall-lessons]] independently identifies "acceptance parsing" as a root cause of prior stalls on this program. The two agree: a single rc=2 — whether real or transient — is amplified by the gate into a *durable* blocked alert identity, which is exactly the observed symptom (one 2026-09-12 failure still holding `overnight:plan-accept-gate:kernel` open days of line-time later).

**F4 — The overnight window is a known load-contention environment.**
[[sources/SRC-2026-08-24-030]] establishes that overnight windows run concurrent multi-agent load on these hosts. A `make test` executed inside such a window is exposed to CPU/IO contention; parallel `make -j` under agent pressure is a classic flake generator (general engineering judgment, not repo-verified). This makes "load transient" a *live* hypothesis for the 2026-09-12 failure, not a dismissed one — which is precisely why the missing stderr matters: it is the only artifact that would separate the two.

**F5 — The program already runs an evidence-gated disposition discipline; this alert is outside it.**
[[sources/backlog-disposition-sweep-reduces-accepted-plans-by-half]] documents a disposition sweep that closed plans only on reproduced evidence and halved accepted plans. [[sources/mid-line-verification-block-triggers-long-acceptance-pending]] shows how a mid-line verification block propagates into long acceptance-pending states. The 2026-09-12 alert is the same failure mode observed from the gate side: a verification result that was never re-evidenced, left pending. Parking it now would be the reflexive move the sweep discipline exists to prevent.

---

## Recommendations (disposition)

**R1 — Do not fix or park on elapsed time.**
The line holds here until an artifact is produced; neither "fix" nor "park" is a valid closing action against the current record. Parking without reproduction would convert a possibly-transient rc=2 into an accepted durable blocker, contradicting the evidence-gated disposition discipline in F5.

**R2 — Precondition: upgrade the gate to parse make output.**
Before any disposition can be evidence-gated, the acceptance harness must capture and log, at failure time: (a) the specific failing target (e.g., `make[1]: *** [tests/... ] Error 2`), (b) the trailing stderr of the failing recipe, and (c) host load metrics from standard procfs — `/proc/loadavg`, `/proc/meminfo`, `/proc/stat` (these paths exist by construction on any Linux host running this kernel). Only then does a closing artifact become structured rather than a bare rc. *Note: I cannot verify the concrete source path of the acceptance harness inside `/home/bricker/Projects/etc/hngh` from this position; that is an open gap, not a claim.*

**R3 — Run a controlled retest to force the classification.**
As soon as an idle host presents, quiesce non-essential agent load, re-run `make test` at the same parallelism (`-j`) as the original failure, and capture full make output plus `/proc/loadavg`/`/proc/meminfo`. The result splits the line decisively:
- **Passes under controlled load** → classify *load transient*; close the alert with a **reproduced-pass artifact** (identical `-j`, captured metrics showing the original window was elevated).
- **Fails under controlled load** → classify *kernel defect*; carry the specific failing target + stderr as a **reproduced-failure artifact** and enter the fix workflow.

**R4 — Closing condition for `overnight:plan-accept-gate:kernel`.**
The alert identity closes on exactly one of:
- **Path A (defect):** reproduced-failure artifact → fix → post-fix `make test` passes *and* the upgraded gate records a parsed pass.
- **Path B (transient):** reproduced-pass artifact under identical parallelism with load metrics attached.

Either path requires R2 first, so the closing artifact is parseable by the gate rather than a bare rc. Until one of these artifacts exists, the alert stays open — correctly so.

---

## Open Threads

1. **The decisive artifact is missing.** No failing-target name or stderr for the 2026-09-12 run is in the line record. This is the single blocking fact; everything downstream (defect-vs-transient, fix-vs-park) is gated on producing it.
2. **

[truncated at model call: completion hit the max_tokens cap (finish_reason=length) - re-run the beat]
