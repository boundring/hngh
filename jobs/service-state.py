#!/usr/bin/env python3
"""service-state — READ-ONLY recognition probe for the allowlisted local
serving units (operator grant 2026-09-03; contract:
hngh docs/design/service-management.md, landing in parallel).

For each allowlisted systemd --user unit, runs
  systemctl --user show -p ActiveState,SubState,UnitFileState,ExecMainStartTimestamp
and TCP-probes the serving ports (127.0.0.1:8888 unsloth — the fleet's
front door served by unsloth-studio.service; :8080 informational, the
llama-server config lane's future port; :11434 ollama) with a
short-timeout connect — no curl dependency. Corrective slice 2026-09-04:
the chain speaks UNSLOTH_URL=http://127.0.0.1:8888 (config.env +
lib/model.sh token refresh /api/auth/refresh); :8080 was never in the
chain's path. Evidence: hngh
docs/research/2026-09-04-unsloth-launch-config-lane.md.

Output: one JSON line per unit, then one line per port (up/down + which
unit, if any, that should serve it and whether it is active). Also writes
dashboard/service-state.json for the command center.

State classification for the serving port (:8888) + serving unit
(unsloth-studio.service):
  - :8888 up, unit installed-but-inactive -> "serving-out-of-unit
    (hand-launched)": the fleet is actually up but the unit's state lies
    about it (observed 2026-09-04, pid outside the unit). NO recovery,
    NO alert — one informational breadcrumb per UTC day max (day-dedup
    stamp, same pattern as the alert stamp). The divergence is
    classified, never collapsed into "healthy".
  - :8888 down, unit installed-but-inactive -> ONE alert row per UTC day
    max (ALERT_TEXT; recoverable via scripts/service-ctl.sh).
  - :8888 down, unit active -> ONE alert row per UTC day max
    (ALERT_TEXT_ACTIVE — check journal; no recovery implication).
  - :8888 down, unit not installed -> no alert (the model chain already
    falls back to Ollama).

Fail-closed: exit 0 in every expected path; a failing probe yields
"unavailable" fields, never a crash, never a fabricated value. This
script NEVER starts anything (recovery is cadence/day/11-service-recovery.sh
via scripts/service-ctl.sh).

Seams (hermetic tests, never real units): HNGH_SERVICE_ALLOWLIST
(colon-separated unit list), HNGH_SERVICE_SYSTEMCTL (systemctl binary /
PATH stub), HNGH_SERVICE_DASHBOARD (output json path),
HNGH_SERVICE_ALERT_STAMP (alert dedup stamp path),
HNGH_SERVICE_DIVERGENCE_STAMP (divergence breadcrumb dedup stamp path),
STATE_FILE (breadcrumb target), HNGH_REPORT_QUEUE /
HNGH_REPORT_ROOT (report writer), HNGH_SERVICE_PORTS (comma-separated
port list; the FIRST port is the serving port — default 8888), DRY_RUN=1
(report what would happen, write nothing).
"""
import json
import os
import socket
import subprocess
from datetime import datetime, timezone
from pathlib import Path

AUTOMATION = Path(os.environ.get(
    "HNGH_AUTOMATION_ROOT",
    Path(__file__).resolve().parent.parent))
SYSTEMCTL = os.environ.get("HNGH_SERVICE_SYSTEMCTL", "systemctl")
ALLOWLIST = [
    u for u in os.environ.get("HNGH_SERVICE_ALLOWLIST", "").split(":") if u
] or ["llama-server.service", "unsloth-warm.service", "unsloth-studio.service"]
PORTS = [int(p) for p in os.environ.get("HNGH_SERVICE_PORTS", "8888,8080,11434").split(",") if p]
SERVING_PORT = PORTS[0] if PORTS else 8888   # unsloth API port (:8888 front door)
SERVING_UNIT = "unsloth-studio.service"      # unit expected to serve :8888
DASHBOARD = os.environ.get(
    "HNGH_SERVICE_DASHBOARD", str(AUTOMATION / "dashboard" / "service-state.json"))
ALERT_STAMP = os.environ.get(
    "HNGH_SERVICE_ALERT_STAMP",
    str(AUTOMATION / "logs" /
        (".service-alert-%s" % datetime.now(timezone.utc).date())))
DIVERGENCE_STAMP = os.environ.get(
    "HNGH_SERVICE_DIVERGENCE_STAMP",
    str(AUTOMATION / "logs" /
        (".service-divergence-%s" % datetime.now(timezone.utc).date())))
STATE_FILE = os.environ.get("STATE_FILE", str(AUTOMATION / "STATE.md"))
REPORT_QUEUE = os.environ.get(
    "HNGH_REPORT_QUEUE",
    str(Path(os.environ.get("HNGH_HOME", "~/Projects/etc/hngh"))
        .expanduser() / "scripts" / "report-queue"))
DRY_RUN = os.environ.get("DRY_RUN", "0") == "1"

ALERT_TEXT = ("unsloth serving down (:8888) while unsloth-studio.service "
              "inactive (recoverable via service-ctl)")
ALERT_TEXT_ACTIVE = ("unsloth serving down (:8888) while unsloth-studio.service "
                     "active — check journal")
DIVERGENCE_STATE = "serving-out-of-unit (hand-launched)"


def now_utc():
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def unit_state(unit):
    """Read-only systemctl --user show; unavailable on any failure."""
    props = ("ActiveState", "SubState", "UnitFileState", "ExecMainStartTimestamp")
    try:
        out = subprocess.run(
            [SYSTEMCTL, "--user", "show", "-p", ",".join(props), unit],
            capture_output=True, text=True, timeout=10).stdout
    except Exception:
        return {"unit": unit, "available": False}
    fields = {}
    for line in out.splitlines():
        k, _, v = line.partition("=")
        if k in props:
            fields[k] = v
    if not fields:
        return {"unit": unit, "available": False}
    return {
        "unit": unit,
        "available": True,
        "active_state": fields.get("ActiveState", "unavailable"),
        "sub_state": fields.get("SubState", "unavailable"),
        "unit_file_state": fields.get("UnitFileState", "unavailable"),
        "start_timestamp": fields.get("ExecMainStartTimestamp", "") or None,
        "installed": fields.get("UnitFileState", "") not in ("", "not-found"),
        "active": fields.get("ActiveState", "") == "active",
    }


def port_up(port):
    s = socket.socket()
    s.settimeout(1.5)
    try:
        s.connect(("127.0.0.1", port))
        return True
    except OSError:
        return False
    finally:
        s.close()


def classify(up, serving):
    """Serving-port state classification (the divergence lesson)."""
    if up:
        if serving.get("installed") and not serving.get("active"):
            return DIVERGENCE_STATE
        return None
    if serving.get("active"):
        return "down-while-unit-active"
    if serving.get("installed"):
        return "down-while-unit-inactive"
    return "down-while-unit-missing"


def breadcrumb(event, detail):
    """Append a STATE.md breadcrumb line (best-effort, same format as
    lib/breadcrumbs.sh)."""
    try:
        ts = now_utc()
        with open(STATE_FILE, "a", encoding="utf-8") as fh:
            fh.write("%s | service-state | %s | %s\n" % (ts, event,
                                                         detail.replace("|", "¦")))
    except OSError:
        pass


def file_report(kind, text, identity, stamp):
    """One report-queue row per UTC day max (state-file dedup); a lost
    row must never crash the probe."""
    try:
        Path(stamp).touch(exist_ok=True)
    except OSError:
        return  # cannot even stamp — do not spam the queue
    if DRY_RUN:
        print("dry-run: would file %s row: %s" % (kind, text))
        return
    try:
        subprocess.run(
            [REPORT_QUEUE, "--add", kind, text,
             "--identity", identity, "--window", "86400"],
            env={**os.environ, "HNGH_REPORT_ROOT": os.environ.get(
                "HNGH_REPORT_ROOT",
                str(Path(os.environ.get("HNGH_HOME", "~/Projects/etc/hngh"))
                    .expanduser()))},
            capture_output=True, timeout=30)
    except Exception:
        pass


def main():
    ts = now_utc()
    units = [unit_state(u) for u in ALLOWLIST]
    by_unit = {u["unit"]: u for u in units}
    serving = by_unit.get(SERVING_UNIT, {})
    up = port_up(SERVING_PORT)
    ports = [{
        "port": p,
        "up": port_up(p),
        "serving_unit": SERVING_UNIT if p == SERVING_PORT else None,
        "serving_unit_active": serving.get("active") if p == SERVING_PORT else None,
    } for p in PORTS]
    divergence = classify(up, serving)
    for line in units:
        print(json.dumps(line))
    for p in ports:
        print(json.dumps(p))
    print(json.dumps({"classification": divergence}))

    snapshot = {"generated": ts, "units": units, "ports": ports,
                "divergence": divergence}
    if DRY_RUN:
        return
    try:
        tmp = DASHBOARD + ".tmp"
        with open(tmp, "w", encoding="utf-8") as fh:
            json.dump(snapshot, fh, indent=1)
        os.replace(tmp, DASHBOARD)
    except OSError:
        pass  # the dashboard artifact is best-effort; stdout is the record

    if divergence == DIVERGENCE_STATE and not Path(DIVERGENCE_STAMP).exists():
        # no recovery, no alert: classify only, one breadcrumb per UTC day
        try:
            Path(DIVERGENCE_STAMP).touch(exist_ok=True)
        except OSError:
            return
        breadcrumb("service-divergence",
                   ":8888 up while %s inactive — serving-out-of-unit "
                   "(hand-launched); classified, no recovery, no alert"
                   % SERVING_UNIT)
    elif divergence == "down-while-unit-inactive" \
            and not Path(ALERT_STAMP).exists():
        file_report("alert", ALERT_TEXT, "service-state:unsloth-down",
                    ALERT_STAMP)
    elif divergence == "down-while-unit-active" \
            and not Path(ALERT_STAMP).exists():
        file_report("alert", ALERT_TEXT_ACTIVE, "service-state:unsloth-down-active",
                    ALERT_STAMP)


if __name__ == "__main__":
    main()
    raise SystemExit(0)  # fail-closed: exit 0 in every expected path
