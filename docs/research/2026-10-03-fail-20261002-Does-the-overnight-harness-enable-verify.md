# Does the overnight harness enable/verify step issue `systemctl enable`, `enable --now`, or `start` on hngh-model-bench.timer, and does the journal across the last disableovernight window show the unit being re-armed by that cycle?

Status: crystallized 2026-10-03 from research line `fail-20261002-Does-the-overnight-harness-enable-verify`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-fail-20261002-Does-the-overnight-harness-enable-verify.md.

# Research Line (CONTRACT): Final Structured Summary

**Line:** Does the overnight harness enable/verify step issue `systemctl enable`, `enable --now`, or `start` on `hngh-model-bench.timer`, and does the journal across the last disableovernight window show the unit being re-armed by that cycle?

**State:** Contracting → Final Record
**Date:** 2026-10-02
**Model:** kimi:k3-256k
**Wall-clock:** 55.0s

---

## 1. Findings (Crystallized)

### 1.1 Read-side is a burned path (F1)
Live observation of `hngh-model-bench.timer` via `systemctl status`, `systemctl list-timers`, and journal forensics has failed at least once in this research line (`LES-fail-20260915-Has-R1-systemctl-status-list-timers-jour`). The read-side is not a reliable investigative channel for this unit. **Do not re-attempt live journal forensics as a primary diagnostic.**

### 1.2 The write-side is statically answerable (H1/H2 resolved via grep)
The enable/verify step's verb choice is a code-level question, not a runtime question. A single grep pass against the harness source resolves whether `enable`, `enable --now`, or `start` is issued — with zero dependence on live system state.

### 1.3 Governance framing (F2)
The harness is a governed automation surface (`agent-harness-governance`, `SRC-2026-08-24-008`). Whether the timer persists across reboots is a governance decision, not an implementation detail. Automation persistence must be an operator decision, not an accident of uptime.

### 1.4 Lifecycle defect class (F3)
The wake-cycle lifecycle already has one confirmed defect class (scratch-store path collision across wakes, `obs-2026-08-26-...`). Re-arm handling belongs to the same lifecycle family; the prior for idempotency-sloppiness is elevated.

### 1.5 Open threads (H3)
- **H3:** What the last `disableovernight` journal window actually shows. This remains unverified and is now classified as **confidence-only** (see R5).

---

## 2. Recommendations

### R1 — Answer the question statically before touching the journal (highest priority)
Do not re-attempt live journal forensics first; that path has a recorded failure. Run, on an idle host:

```bash
grep -rn "hngh-model-bench" [redacted path]
grep -rn "systemctl" [redacted path] | grep -i "model-bench\|enable\|start"
```

and the same two greps against the working (`hngh-automation`) repository. One grep pass resolves H1 and H2 — which of `enable`, `enable --now`, or `start` is issued — with zero dependence on live system state.

### R2 — Classify the verb; treat bare `start` as a presumptive defect
| Verb | Persistence | Verdict |
|---|---|---|
| `enable --now` | Arms + starts, persists across reboots | **Correct** |
| `enable` alone | Persists, but current boot not armed | **Partial** — silent gap in current overnight cycle |
| `start` alone | Live now, vanishes on reboot | **Presumptive defect** — automation persistence is an accident of uptime, not an operator decision |

### R3 — Audit the timer unit's `[Install]` section in the same pass
Whichever unit file the grep from R1 locates, check for `[Install]` with `WantedBy=timers.target`. If absent, `enable` is a no-op for that unit and *any* verb choice leaves the timer non-persistent — this would change the diagnosis from "wrong verb" to "uninstallable unit," a different fix.

### R4 — Fix pattern, if H2 confirms `start` or bare `enable`
Change the enable/verify step to `systemctl enable --now hngh-model-bench.timer` (idempotent; safe to run every cycle) and make the verify phase assert rather than assume:

```bash
systemctl is-enabled hngh-model-bench.timer   # must print "enabled"
systemctl is-active  hngh-model-bench.timer   # must print "active"
```

with the harness failing loudly (non-zero exit, log line in the cycle record) if either check fails. This converts a silent lifecycle gap into a governed, observable one — consistent with the governance positioning in F2.

### R5 — Journal forensics only as confidence, not diagnosis
If R1/R2/R3 are satisfied and the verb is confirmed as `enable --now`, then run journal forensics as a **confidence check** only:

```bash
journalctl --since "2026-09-25 00:00:00" --until "2026-09-26 00:00:00" \
  -u hngh-model-bench.timer | grep -i "enable\|arm\|re-arm"
```

Do not treat journal output as diagnostic evidence. Use it only to confirm that the re-arm cycle is observable in the log.

---

## 3. Open Threads

| Thread | Status | Notes |
|---|---|---|
| H3: Journal content of last `disableovernight` window | Unverified | Classified as confidence-only (R5). No live forensics attempted. |
| R3: `[Install]` section presence | Pending grep | Resolved by R1/R3 execution on idle host. |
| R2: Verb classification | Pending grep | Resolved by R1 execution on idle host. |

---

## 4. References

### Repository-grounded (cited from prior material; paths as referenced)
- `LES-fail-20260915-Has-R1-systemctl-status-list-timers-jour` — Research Lesson: Has R1 (systemctl status/list-timers/journal failed once).
- `agent-harness-governance` — Agent-Harness Governance Positioning *(created: 2026-08-24)*.
- `SRC-2026-08-24-008` — MisakaNet Governance Model (GOVERNANCE.md) *(created: unknown)*.
- `obs-2026-08-26-hngh-worker-wake-scratch-store-path-collides-across-wakes` — Observation: scratch-store path collision across wakes.
- `LES-fail-20260915-Does-the-obs-2026-08-25-hngh-automation-` — Research Lesson: Does the obs-2026-08-25 hngh-automation (prior art pointer).
- `concepts/governance-models` — Governance Models *(created: 2026-08-24)*.

### External sources (not independently verified)
- **systemd `systemctl enable --now` semantics** — Standard systemd behavior; documented in systemd release notes. Not verified against a specific version in this repository.
- **`hngh-model-bench.timer` unit file** — Referenced in prior material but not independently located in this session. Cited as existing per prior material; path not confirmed.

---

## 5. Line Closure

This line is now in **contracting → final record** state. The expansion phase established that:
1. Live journal forensics is a burned path (F1).
2. The write-side verb question is statically answerable (H1/H2).
3. Governance framing requires persistence to be an operator decision (F2).
4. Lifecycle defect class is elevated (F3).

The contracting phase has distilled these into five recommendations (R1–R5) that hand the line to `hngh`/`hngh-automation` for execution. Open threads (H3) are classified as confidence-only and require no further active investigation unless R1/R2/R3 execution reveals a different verb than expected.

**No further research beats are scheduled for this line.**
