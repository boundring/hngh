# System awareness map

Status: DESIGN — P2 contract, 2026-08-27. Ceremony-ready.

Source: [`../project/master-plan.md`](../project/master-plan.md) (spine
facet R2/R4, system-harness plane), the
[`../project/interface-plan.md`](../project/interface-plan.md) S2/M7
(system awareness panel), the affinity directive 2026-08-26 (`System
awareness rung`), and the live probe surface already served
(`system.json`, `fleet-manager --discover`, `probe-model-route`,
oversight alert rows in the report ledger).

Cross-links: [`command-center.md`](command-center.md),
[`../core/clean-architecture-charter.md`](../core/clean-architecture-charter.md),
[`../project/system-harness-roadmap.md`](../project/system-harness-roadmap.md),
[`../project/decisions.md`](../project/decisions.md).

## Purpose

The system plane tells the operator (and the agentic plane) how much
headroom Hngh and its host have, honestly and read-only. Awareness
feeds **attention**, not action: a resource change yields a
steer/alert, never a hidden mutation.

## Probe architecture

One bounded read-only probe produces a single `system.json` document.
Each probe is a separate local reader; no probe spawns a daemon, opens a
socket for listening, or writes outside the dashboard root.

| Probe | Reads | Emits |
|---|---|---|
| CPU | `/proc/stat` samples over a short window | `cpu.percent`, `load1/5/15` |
| Memory | `/proc/meminfo` | `mem.percent`, `mem.available` |
| Disk | `statvfs` on the repo + store roots | `disk.percent`, `disk.free_bytes` |
| Network | `/proc/net/dev` deltas | `net.rx_kbps`, `net.tx_kbps` |
| Model endpoint | `probe-model-route` + one bounded HTTP HEAD/GET to the resolved local route | `model.endpoint`, `model.ok`, `model.latency_ms` |
| Fleet | `fleet-manager --discover --json` (tailscale peers) | `fleet.peers` (count + per-peer ping/health) |
| Clock/freshness | wall clock at probe start | `generated_at` (ISO UTC) |

Every field carries its source stamp; missing or failing probes emit
`null` + a `stale`/`error` marker — never a fabricated number.

## Integration flow

```
jobs/system-awareness.sh (timer; single tick)
        │  one probe pass, read-only
        ▼
dashboard/system.json   (atomic write: tmp + rename)
        │
        ├──► webapp S2 panel      (freshness-stamped, read-only)
        ├──► CLI status verb      (system section of `hngh status`)
        ├──► oversight-tick.sh    (flap-suppressed alert rules)
        │          │
        │          └──► alert row in the report ledger (kind=alert)
        │                      │
        │                      └──► agentic steer attention trigger
        └──► buddy/OSD snapshot  (headroom line in the overlay)
```

- **`jobs/system-awareness.sh`** — one no-daemon tick run by the
  cadence timer; exits 0 even when nothing changed.
- **`oversight-tick.sh`** — consumes `system.json`, applies the
  threshold rules below with **flap suppression** (a threshold must
  hold for N consecutive ticks before an alert; a recovering alert is
  reported once), and appends an `alert` row when a rule trips. The
  alert row names the probe, the value, the threshold, and the
  freshness stamp.
- **Agentic steer attention** — the alert row is visible to the
  agentic plane as a report; a working agent may read it, but no
  probe output and no alert ever flows into a gate input, a
  certificate, or a selection computation.

## Resource headroom thresholds

Default thresholds; each is configurable only through the queue/card
ceremony path, never by the probe itself.

| Probe | Warn at | Alert at | Notes |
|---|---|---|---|
| CPU percent (1m avg) | 70% | 90% sustained 3 ticks | sustained = flap-suppressed |
| Memory percent | 75% | 90% sustained 3 ticks | available, not total-less-cache |
| Disk percent (root + store) | 80% | 92% | fail-closed: probe error treated as alert `probe-unavailable` |
| Network | — | no alert | informational; fed to the dashboard only |
| Model endpoint | unreachable | unreachable 2 ticks | recovery alerts once |
| Fleet | peer down | same peer down 3 ticks | per-peer, flap-suppressed |

## Fail-closed degradation rules

- A probe that errors emits `"ok": false` + a plain message and that
  pane reads `stale (Nm)`; the dashboard never re-derives the number.
- `system.json` missing or unparseable → every resource pane shows
  `unavailable`, and an alert `system-probe-unavailable` may fire once
  per flap window — consumption never crashes on bad input.
- Alerts are advisory reports; they cannot set loadout limits, change
  a schedule, or pause a run.
- No probe output enters a certificate, a course-selection candidate,
  or a gate input. The awareness plane is a reader, period.

## Non-goals

- Any actuator: no process kill, no service restart, no auto-evacuation
  from headroom alone.
- Multi-node pooling or fleet resource aggregation — local + tailscale
  discovery only; pooling waits for the system-harness fleet rungs.
- Predictive trend lines — current values + freshness only.
- A probe daemon or watcher process.

## Open questions

- Which cadence owns the probe tick (1m read-only tier vs. 5m tier);
  the flow above keeps it a single job either way.
- Whether the operator wants per-peer wake suggestions from a down
  peer alert (advisory only, wired to the existing wake transport).