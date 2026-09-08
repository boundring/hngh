#!/usr/bin/env python3
"""system-feed — CachyOS system-integration feed for the dashboard System tab.

Builds dashboard/system-ops.json: pending pacman updates, package/ orphan
counts, systemd user/system unit state, per-mount disk usage, memory, 24h
journal error count, temperatures (lm_sensors, when present), a small
network summary (first global v4 address + listening TCP port count),
the last config-backup ledger rows, and dashboard session counts.

READ-ONLY: every command here is a query. Nothing is installed, upgraded,
reset, removed, or restarted. Governed updates are a future rung.

Fail-closed: a missing tool or a failing/timeout probe omits that key and
appends a note — never a fabricated value, never a crash. Runtime budget
~2-5s: collectors run in a small thread pool, each subprocess timeout-
guarded. Mounted at cadence/30m/10-system-feed.sh; safe at that cadence.
"""
import json
import os
import re
import shutil
import subprocess
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timezone

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "dashboard", "system-ops.json")

TEMP_CAP = 16  # sensors can list dozens of chips; the tab needs the hot few
HNGH_ROOT = (os.environ.get("HNGH_HOME")
             or os.environ.get("HNGH_REPO")
             or "/home/bricker/Projects/etc/hngh")
REPORTS_MD = os.path.join(HNGH_ROOT, "docs", "project", "reports.md")
SESSIONS_JSON = os.path.join(ROOT, "dashboard", "sessions.json")
BACKUP_ROWS = 6  # recent config-backup runs surfaced on the backups card


def run(cmd, timeout=10):
    """(stdout, rc) — ('', 127) on missing tool, error, or timeout."""
    try:
        p = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout)
        return (p.stdout, p.returncode)
    except (OSError, subprocess.TimeoutExpired):
        return ("", 127)


def lines(out):
    return [ln.strip() for ln in out.splitlines() if ln.strip()]


# ------------------------------------------------------------------ probes

def probe_updates():
    """updates: {count, packages} — pacman -Qu --quiet."""
    out, rc = run(["pacman", "-Qu", "--quiet"])
    if rc not in (0, 1):  # rc=1 with empty output means "no updates"
        return None, "pacman -Qu failed — updates omitted"
    pkgs = lines(out)
    return {"count": len(pkgs), "packages": pkgs}, None


def probe_packages():
    """packages: {explicit, foreign_aur, orphans} — plain -Q queries."""
    exp, rc1 = run(["pacman", "-Qqe"])
    foreign, rc2 = run(["pacman", "-Qqm"])
    orphans, rc3 = run(["pacman", "-Qdtq"])
    # each -Q query exits 1 for "no packages matched" — an empty truth
    if rc1 not in (0, 1) and rc2 not in (0, 1) and rc3 not in (0, 1):
        return None, "pacman -Q* failed — package counts omitted"
    val = {}
    if rc1 in (0, 1):
        val["explicit"] = len(lines(exp))
    if rc2 in (0, 1):
        val["foreign_aur"] = len(lines(foreign))
    if rc3 in (0, 1):
        val["orphans"] = len(lines(orphans))
    return val, None


def probe_units():
    """units: {user_running, user_failed, system_failed}."""
    out, rc = run(["systemctl", "--user", "list-units", "--type=service",
                   "--state=running", "--no-legend", "--no-pager"])
    failed_u, rc_u = run(["systemctl", "--user", "--failed",
                          "--no-legend", "--no-pager"])
    failed_s, rc_s = run(["systemctl", "--failed", "--no-legend", "--no-pager"])
    if rc != 0 and rc_u != 0 and rc_s != 0:
        return None, "systemctl unreachable — units omitted"
    val = {}
    if rc == 0:
        val["user_running"] = len(lines(out))
    # --failed rows: "[● ]<unit> loaded failed failed <desc>"; newer
    # systemd prefixes failed rows with a '● ' bullet — skip it
    def names(o):
        val = []
        for ln in lines(o):
            if not any(s in ln for s in (".service", ".timer", ".scope", ".socket")):
                continue
            for tok in ln.split():
                if tok != "●" and "." in tok:
                    val.append(tok)
                    break
        return val
    if rc_u == 0:
        val["user_failed"] = names(failed_u)
    if rc_s == 0:
        val["system_failed"] = names(failed_s)
    return val, None


def probe_disk():
    """disk: [{mount, use_pct, size, avail}] — real block devices, deduped."""
    out, rc = run(["df", "-Ph", "-x", "tmpfs", "-x", "devtmpfs",
                   "-x", "efivarfs", "-x", "squashfs"])
    if rc != 0:
        return None, "df failed — disk omitted"
    seen, val = set(), []
    for ln in lines(out)[1:]:  # skip header
        cols = ln.split()
        if len(cols) < 6 or not cols[0].startswith("/dev"):
            continue
        if cols[0] in seen:  # one device bind-mounted at several paths
            continue
        seen.add(cols[0])
        try:
            val.append({"mount": cols[5], "use_pct": int(cols[4].rstrip("%")),
                        "size": cols[1], "avail": cols[3]})
        except ValueError:
            continue
    return val or None, (None if val else "df parsed empty — disk omitted")


def probe_memory():
    """memory: {used_pct, available_gb} — /proc/meminfo."""
    try:
        info = {}
        with open("/proc/meminfo") as fh:
            for ln in fh:
                k, _, v = ln.partition(":")
                info[k] = int(v.strip().split()[0])  # kB
        total, avail = info["MemTotal"], info["MemAvailable"]
        return {"used_pct": round(100 * (total - avail) / total, 1),
                "available_gb": round(avail / 1048576, 2)}, None
    except (OSError, KeyError, ValueError, IndexError):
        return None, "/proc/meminfo unreadable — memory omitted"


def probe_journal():
    """journal_err_24h — err+ priority lines, last 24h (user+system vantage)."""
    out, rc = run(["sh", "-c",
                   "journalctl -p err --since -24h --no-pager -q 2>/dev/null | wc -l"],
                  timeout=20)
    if rc != 0 or not out.strip().isdigit():
        return None, "journalctl failed — journal_err_24h omitted"
    return int(out.strip()), None


TEMP_RE = re.compile(r"^\s*([A-Za-z][\w .-]*?):\s+\+([0-9]+(?:\.[0-9]+)?)°C")
CHIP_RE = re.compile(r"^([a-z0-9]+[a-z0-9_-]*)-[\w-]+-\S*$")


def probe_temps():
    """temps: [{label, C}] — lm_sensors parse; None (omit) when absent."""
    if not shutil.which("sensors"):
        return None, "lm_sensors not installed — temps omitted"
    out, rc = run(["sensors"])
    if rc != 0:
        return None, "sensors failed — temps omitted"
    val = []
    chip = None
    for ln in out.splitlines():
        cm = CHIP_RE.match(ln)
        if cm:
            chip = cm.group(1)
            continue
        m = TEMP_RE.match(ln)
        if m:
            label = m.group(1).strip()
            # 'temp1' alone is ambiguous across chips; qualify duplicates
            if any(t["label"] == label for t in val):
                label = (chip or "sensor") + " " + label
            val.append({"label": label, "C": float(m.group(2))})
    return (sorted(val, key=lambda t: -t["C"])[:TEMP_CAP] or None), \
           (None if val else "sensors reported no temperatures — temps omitted")


def probe_network():
    """network: {ip, listening} — first global v4 addr + ss -tln count."""
    out, rc = run(["ip", "-4", "-o", "addr", "show", "scope", "global"])
    ip = None
    if rc == 0 and lines(out):
        cols = lines(out)[0].split()
        if len(cols) >= 4 and "/" in cols[3]:
            ip = cols[3].split("/")[0]
    ss_out, rc2 = run(["ss", "-tln"])
    if not ip and rc2 != 0:
        return None, "ip/ss unavailable — network omitted"
    val = {}
    if ip:
        val["ip"] = ip
    if rc2 == 0:
        val["listening"] = max(0, len(lines(ss_out)) - 1)  # minus header
    return val or None, (None if val else "network probes parsed empty")


def probe_backups():
    """backups: [{ts, ok, text}] — last config-backup rows from reports.md."""
    try:
        with open(REPORTS_MD, encoding="utf-8") as fh:
            rows = []
            for ln in fh:
                cells = ln.split("|")
                if len(cells) < 5:
                    continue
                text = cells[4].strip()
                if text.startswith("config-backup "):
                    rows.append({"ts": cells[1].strip(), "kind": cells[2].strip(),
                                 "ok": ": ok " in text, "text": text})
    except OSError:
        return None, "reports.md unreadable — backups omitted"
    return rows[-BACKUP_ROWS:][::-1] or None, \
           (None if rows else "no config-backup runs in the ledger yet")


def probe_remote():
    """remote: {tailscale, sshd, dashboard} — the remote-access posture
    (vacation readiness): tailnet state, sshd unit, dashboard LAN bind."""
    val = {}
    ts_out, ts_rc = run(["tailscale", "status", "--json"], timeout=8)
    if ts_rc == 0 and ts_out:
        try:
            st = json.loads(ts_out)
            val["tailscale"] = {
                "state": st.get("BackendState", "?"),
                "ip": ((st.get("TailscaleIPs") or [""])[0] or None),
                "self": ((st.get("Self") or {}).get("HostName")),
            }
        except ValueError:
            val["tailscale"] = {"state": "parse-error"}
    else:
        val["tailscale"] = {"state": "unavailable"}
    ssh_out, ssh_rc = run(["systemctl", "is-active", "sshd"])
    val["sshd"] = ssh_out.strip() if ssh_rc == 0 and ssh_out else "unknown"
    ss_out, ss_rc = run(["ss", "-tln"])
    val["dashboard"] = ("lan" if ss_rc == 0 and ":8890" in ss_out
                        else "down")
    return val or None, (None if val else "remote probes unavailable")


def probe_sessions():
    """sessions: {live, total} — omp/bridge rows in dashboard/sessions.json."""
    try:
        with open(SESSIONS_JSON, encoding="utf-8") as fh:
            rows = json.load(fh).get("sessions") or []
    except (OSError, ValueError):
        return None, "sessions.json unreadable — sessions omitted"
    live = sum(1 for r in rows if r.get("state") == "live")
    return {"live": live, "total": len(rows)}, None


# ------------------------------------------------------------------- main

def build():
    data = {"generated": datetime.now(timezone.utc)
            .strftime("%Y-%m-%dT%H:%M:%SZ")}
    notes = []
    probes = {"updates": probe_updates, "packages": probe_packages,
              "units": probe_units, "disk": probe_disk,
              "memory": probe_memory, "journal_err_24h": probe_journal,
              "temps": probe_temps, "network": probe_network,
              "backups": probe_backups, "remote": probe_remote,
              "sessions": probe_sessions}
    # thread pool: the slow probes (journalctl, pacman) overlap; wall ~2s
    with ThreadPoolExecutor(max_workers=4) as pool:
        for key, fn, (val, note) in (
                (k, fn, f.result()) for k, fn, f in
                ((k, fn, pool.submit(fn)) for k, fn in probes.items())):
            if val is not None:
                data[key] = val
            if note:
                notes.append(note)
    if notes:
        data["notes"] = sorted(notes)
    return data


def main():
    data = build()
    tmp = OUT + ".tmp"
    with open(tmp, "w") as fh:
        json.dump(data, fh, indent=1, sort_keys=True)
        fh.write("\n")
    os.replace(tmp, OUT)


if __name__ == "__main__":
    main()
