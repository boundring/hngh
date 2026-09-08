#!/usr/bin/env bash
# system-awareness — READONLY live system-resource awareness probe.
#
# Writes dashboard/system.json for the command center + oversight tick:
#   cpu% / mem% / disk% / net-reachability (model endpoint ok|fail, tailscale
#   peers count) + resource headroom flags (low-disk / low-mem / network-down),
#   each field carrying a timestamp.
#
# Fail-closed: a failing probe yields that field "unavailable" — never a
# crash, never a fabricated value. Probe only; never mutates anything.
#
# Reuses existing primitives rather than re-inventing them:
#   - scripts/probe-model-route  (model endpoint reachability; token-level
#                                 health stays in credential-health.sh)
#   - scripts/fleet-manager --json (tailscale peers + system facts)
#
# Mounted at cadence/5m via cadence/5m/01-system.sh.
set -u
. "$(cd "$(dirname "$0")/.." && pwd)/lib/common.sh"
. "$AUTOMATION_ROOT/lib/breadcrumbs.sh"

HNGH_REPO="${HNGH_REPO:-/home/bricker/Projects/etc/hngh}"
FLEET="$HNGH_REPO/scripts/fleet-manager"
PROBE_ROUTE="$HNGH_REPO/scripts/probe-model-route"
ROUTE_CONF="${PROBE_ROUTE_CONF:-$HOME/.hngh-automation/reviewer-local.conf}"
OUT="$AUTOMATION_ROOT/dashboard/system.json"

LOW_DISK_PCT="${LOW_DISK_PCT:-90}"
LOW_MEM_PCT="${LOW_MEM_PCT:-90}"

ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

# cpu% — two 1s-apart /proc/stat samples (idle incl. iowait delta).
cpu="$(
 python3 - <<'PY' 2>/dev/null
import time
def snap():
    with open("/proc/stat") as fh:
        for ln in fh:
            if ln.startswith("cpu "):
                p = ln.split()[1:]
                return (int(p[3]) + int(p[4]), sum(int(x) for x in p))
    return (0, 0)
i1, t1 = snap(); time.sleep(1); i2, t2 = snap()
di, dt = i2 - i1, t2 - t1
print(round(100 * (dt - di) / dt) if dt else 100)
PY
)" || cpu=unavailable

# mem% — used = 100 - MemAvailable/MemTotal.
mem="$(awk '/MemTotal/{t=$2}/MemAvailable/{a=$2}END{printf "%g", 100*(1-a/t)}' /proc/meminfo 2>/dev/null)" || mem=unavailable

# disk% — used fraction of the filesystem holding this repo.
disk="$(df -P "$AUTOMATION_ROOT" 2>/dev/null | awk 'NR==2{gsub("%","",$5);print $5}')" || disk=unavailable

# net ----------------------------------------------------------------------
# tailscale peers + mesh state via the fleet-manager discovery primitive.
peers=unavailable
tailscale=unknown
if [ -x "$FLEET" ]; then
 det="$(timeout 8 "$FLEET" --json 2>/dev/null)" || det=""
 peers="$(printf '%s' "$det" | jq -r '.nodes | length' 2>/dev/null)" || peers=unavailable
 tailscale="$(printf '%s' "$det" | jq -r '.facts.tailscale // "unknown"' 2>/dev/null)" || tailscale=unknown
 [ -n "$peers" ] || peers=unavailable
fi

# model endpoint reachability via probe-model-route (reused primitive).
model=unavailable
if [ -x "$PROBE_ROUTE" ] && [ -n "$ROUTE_CONF" ] && [ -f "$ROUTE_CONF" ]; then
 if "$PROBE_ROUTE" "$ROUTE_CONF" >/dev/null 2>&1; then model=ok; else model=fail; fi
fi

# headroom flags ------------------------------------------------------------
low_disk=false
[ "$disk" != "unavailable" ] && [ "${disk%%.*}" -ge "$LOW_DISK_PCT" ] 2>/dev/null && low_disk=true
low_mem=false
[ "$mem" != "unavailable" ] && [ "${mem%%.*}" -ge "$LOW_MEM_PCT" ] 2>/dev/null && low_mem=true
network_down=false
[ "$model" = "fail" ] && [ "$peers" = "0" ] && network_down=true

# write JSON  (python assembles to dodge shell quoting) ----------------------
python3 - "$ts" "$cpu" "$mem" "$disk" "$model" "$peers" "$tailscale" \
 "$low_disk" "$low_mem" "$network_down" "$OUT" <<'PY'
import json, os, sys
ts, cpu, mem, disk, model, peers, tailscale, low_disk, low_mem, ndown, out = sys.argv[1:]
doc = {
    "generated_at": ts,
    "cpu":  {"pct": cpu,  "ts": ts},
    "mem":  {"pct": mem,  "ts": ts},
    "disk": {"pct": disk, "ts": ts},
    "net":  {"model_endpoint": model, "tailscale_peers": peers,
             "tailscale_state": tailscale, "ts": ts},
    "headroom": {"low-disk": low_disk == "true", "low-mem": low_mem == "true",
                 "network-down": ndown == "true"},
}
tmp = out + ".tmp"
with open(tmp, "w") as fh:
    json.dump(doc, fh, indent=1); fh.write("\n")
os.replace(tmp, out)
PY
rc=$?
if [ "$rc" = "0" ]; then
 breadcrumb "$JOB_NAME" "system-awareness" "cpu=$cpu mem=$mem disk=$disk model=$model peers=$peers"
else
 breadcrumb "$JOB_NAME" "system-awareness" "write-fail rc=$rc"
fi
exit 0
