# 2026-08-26 — System awareness (read-only resource headroom feed + alert)

## Scope

First live slice of the SYSTEM-AWARENESS rung: give the command center
(dashboard) and the oversight tick read-only visibility into the machine's
resource headroom (cpu/mem/disk/network) so the agentic leg can steer on
resource changes. Probe-only — never implicit mutation.

## What landed (hngh-automation)

1. **`jobs/system-awareness.sh`** — a read-only probe writing
   `dashboard/system.json`: `cpu%` / `mem%` / `disk%` /
   `net` (`model_endpoint` ok|fail + `tailscale_peers` count) and
   `headroom` flags (`low-disk` / `low-mem` / `network-down`), each carrying
   a timestamp. Fail-closed: a failing probe yields its field
   `"unavailable"` — never a crash, never a fabricated value. Reuses
   existing primitives (does not re-invent them): `scripts/probe-model-route`
   for model-endpoint reachability, `scripts/fleet-manager --json` for
   tailscale peers + system facts. Token-level credential health stays in
   `jobs/credential-health.sh`.
2. **`cadence/5m/01-system.sh`** — cadence drop-in executing the probe
   (mounted on the existing 5m cadence; no new systemd unit).
3. **`jobs/oversight-tick.sh` → `probe_system_awareness`** — thin reader of
   `system.json` that alerts once per **new** critical headroom flag
   (`system-low-disk` / `system-low-mem` / `system-network-down`) with the
   same-key flapping suppression inside `alert()` (persistent condition
   alerts once, not every 5m), and arms the attention flag so the agentic
   leg can steer (e.g. "network down — pause network-labeled jobs").
4. **Two `alert()` bug fixes found while wiring this** (root cause, one
   guarded call each): `ALERT_LAST` was unbound under `set -u` (crashed
   every alert when the var wasn't exported), and the flapping-suppression
   timestamp parse used `cut -d' ' -f2` which breaks whenever the alert
   detail contains spaces (stale-store/system details do) — now
   `awk '{print $NF}'` (last field is the timestamp).

Headroom thresholds are env-tunable (`LOW_DISK_PCT`/`LOW_MEM_PCT`, defaults
90); `network-down` = model endpoint unreachable **and** zero tailscale
peers (no usable network path — otherwise the reachable model server keeps
network judged up).

## Verification

- **Live probe**: `jobs/system-awareness.sh` exits 0 and writes real values
  (`cpu=19 mem=71.3 disk=83 model=ok peers=0`); the real 5m cadence
  (`TIER=5m`) invokes the drop-in and appends
  `system-awareness.sh | system-awareness | cpu=… mem=… disk=… model=ok peers=0`.
- **No false alert on healthy machine**: `oversight-tick.sh` on the live
  all-false `system.json` emits no `system-*` alert and no attention.
- **Fixture (critical flag)**: `system.json` seeded with `"low-disk": true`
  → first tick appends exactly **one** `system-low-disk: critical resource
  flag set` alert row + arms attention; a second and third tick (same key,
  within the 60-min window) are suppressed — count stays 1. No arithmetic
  errors after the timestamp-parse fix.

## Commits

- hngh-automation: `dc877b4` — system-awareness probe + 5m drop-in +
  oversight probe_system_awareness + the two alert() fixes (not pushed).
- hngh: this record, ceremony-bound (commit hash in the commit itself).

## Remaining

- Next roadmap candidate: gantt-ports / dancing-ui backlog items (tiled
  subagent streaming) — out of scope for this slice; flagged for the next
  decision after this lands.