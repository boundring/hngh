# What do the deployed hngh-model-bench.timer unit and its drop-ins actually contain for `Persistent=` and `OnCalendar=`, and does a stamp file exist on disk indicating a stored last-trigger timestamp?

Status: crystallized 2026-10-03 from research line `fail-20261002-What-do-the-deployed-hngh-model-bench-ti`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-fail-20261002-What-do-the-deployed-hngh-model-bench-ti.md.

# Research line — final crystallization

**Line:** What do the deployed `hngh-model-bench.timer` unit and its drop-ins actually contain for `Persistent=` and `OnCalendar=`, and does a stamp file exist on disk indicating a stored last-trigger timestamp?

**Lifecycle state: contracting → crystallized (closed as a line; question transferred to open threads as an audit task).**

---

## 1. Findings

### 1.1 The core finding is negative, and it is itself the result

Across this line's history, **no transition ever observed the deployed unit, its drop-ins, or the filesystem state of the stamp file.** The 2026-10-03 beat looped degenerate filler; the subsequent contraction explicitly declined to assert contents it could not read. This crystallization inherits that constraint: I cannot read the deployed host from here, and I will not fabricate `Persistent=` / `OnCalendar=` values.

So the durable finding of this line is:

> **F1 — The line's question is a host-state question, and the line's tooling never reached the host.** No repository file can answer "what does the *deployed* unit contain," because drop-ins and effective configuration live in `/etc/systemd/system/`, `/run/systemd/system/`, and `/var/lib/systemd/timers/` on the target machine — none of which are necessarily tracked in either repository. The correct instrument is `systemctl cat` / `systemctl show` on the host, not further beats of this line.

### 1.2 What is verified in-scope

- The hngh kernel repository exists at `[redacted path] (given as ground truth for this line). No specific path within it for the unit file has been verified by any beat, and I decline to assert one.
- The unit is named `hngh-model-bench.timer`; its associated service is presumably `hngh-model-bench.service` (name pairing is systemd convention; the service's existence is unverified).
- A prior beat established the audit commands and the failure mode (line moving without evidence). That methodological lesson is the line's second real output.

### 1.3 External documentation claims (flagged, not verified against host)

These are from systemd documentation knowledge and must be confirmed against `systemd.timer(5)` on the target host, since stamp behavior has version-dependent nuances:

- `Persistent=true` causes systemd to write the last trigger time to `/var/lib/systemd/timers/stamp-<unit>` — here plausibly `stamp-hngh-model-bench.timer` — and to fire missed `OnCalendar=` events on boot. `Persistent=false` is the documented default; no stamp is written and missed runs are silently skipped.
- Effective configuration = base unit + all `<unit>.d/*.conf` drop-ins, viewable only via `systemctl cat hngh-model-bench.timer`.
- **Asymmetry that survives crystallization:** stamp-file *existence* is positive evidence `Persistent=true` fired at least once; stamp-file *absence* is ambiguous (`Persistent=false`, or `Persistent=true` with zero triggers). Any future audit must use `systemctl show -p Persistent` alongside `ls`, not the stamp file alone.

## 2. Recommendations (lasting record for hngh / hngh-automation)

1. **Close the evidence gap with one host-side audit, then archive its output.** The three commands from the prior beat remain the definitive answer mechanism:
   - `systemctl cat hngh-model-bench.timer`
   - `systemctl show hngh-model-bench.timer -p Persistent -p OnCalendar -p LastTriggerUSec -p NextElapseUSecRealtime`
   - `ls -l /var/lib/systemd/timers/stamp-hngh-model-bench.timer`
   This line is spent; the question now lives as an operational task, not a research thread.
2. **Pin `Persistent=` explicitly in the repo-tracked unit, whichever decision lands.** For a model benchmark, backfilling missed runs after downtime usually pollutes the result series (stale data points attributed to a wrong wall-clock window), arguing for explicit `Persistent=false` with a comment. If the intent is "never silently skip," use `Persistent=true` and treat the stamp file's mtime as a liveness signal. The failure mode to avoid is the unset default — behavior nobody chose.
3. **Eliminate drop-in drift.** Anything `systemctl cat` reveals that isn't in the repo should be absorbed into the tracked unit or committed as a tracked drop-in; undeclared drop-ins are exactly how a line like this becomes necessary.
4. **Line-quality guardrail (the 2026-10-03 lesson, generalized):** a line whose question requires host access must either acquire host access in its first transition or be converted to an audit task immediately. Degenerate beats cost the same wall time as real ones. This aligns with the stall-lessons and consecutive-failure-demotion notes already in the vault (see Prior art).

## 3. Open threads

- **OT-1 (operational, blocking):** Run the §2.1 audit on the deployed host and record output in the vault. Until then, the line's literal question remains *open but correctly re-homed* — it is not a research question anymore.
- **OT-2:** Whether the repo-tracked unit (wherever it lives under `[redacted path] matches the deployed unit. A `diff` of `systemctl cat` output against the repo copy resolves it; unverified here.
- **OT-3:** Whether missed-run backfill is *desirable* for hngh-model-bench's downstream consumers — a design decision for the hngh maintainers, not resolvable by filesystem inspection.

## 4. References

- `[redacted path] — hngh kernel repository (existence given as ground truth; no sub-path asserted as verified).
- Vault prior art (read-only pointers supplied with this line): `[[sources/hngh-2026-09-09-stall-lessons]]`, `[[sources/outcome-demotion-at-two-consecutive-failures]]`, `[[concepts/governance-models]]`, `[[sources/LES-fail-20260915-Does-the-obs-2026-08-25-hngh-automation-]]`.
- **External, unverified from this workspace:** `systemd.timer(5)` man page (semantics of `Persistent=`, `OnCalendar=`, and `/var/lib/systemd/timers/stamp-*`) — confirm on the target host before acting on §1.3.

**Line status: crystallized.** Its lasting contribution is not the answer to its question but (a) the precise audit procedure that *is* the answer mechanism, (b) the stamp-file asymmetry caveat, and (c) the methodological guardrail against evidence-free beats. The literal question is transferred to OT-1 as a host-side task.
