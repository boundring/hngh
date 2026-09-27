#!/usr/bin/env python3
"""system-ingest: snapshot host resources (memory, load, uptime, disks, GPU).

Writes db_dir()/system-resources.json (HNGH_SYSTEM_STATE seam, --out flag)
for newspaper-compose's system desk. Stdlib-only, reads /proc + statvfs,
optional nvidia-smi GPU probe. Fail-open: exits 0 even when nothing works.
"""

import json
import os
import subprocess
import sys
import time

sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "lib"))

from hngh_home import db_dir  # noqa: E402


def _mb(kb):
    return round(kb / 1024.0, 1)


def parse_meminfo(text):
    """{"total_mb","avail_mb","used_pct"} or None; content in /proc/meminfo shape."""
    fields = {}
    for line in text.splitlines():
        parts = line.split(":", 1)
        if len(parts) == 2:
            val = parts[1].split()
            if val:
                try:
                    fields[parts[0].strip()] = float(val[0])
                except ValueError:
                    pass
    if "MemTotal" not in fields or "MemAvailable" not in fields:
        return None
    total, avail = fields["MemTotal"], fields["MemAvailable"]
    if total <= 0:
        return None
    used = total - avail
    return {
        "total_mb": _mb(total),
        "avail_mb": _mb(avail),
        "used_pct": round(used / total * 100.0, 1),
    }


def parse_loadavg(text):
    parts = text.split()
    if len(parts) < 3:
        return None
    try:
        return {"load1": float(parts[0]), "load5": float(parts[1]), "load15": float(parts[2])}
    except ValueError:
        return None


def parse_uptime(text):
    try:
        return round(float(text.split()[0]), 1)
    except (ValueError, IndexError):
        return None


def parse_nvidia_smi(text):
    """nvidia-smi --query-gpu=memory.used,memory.total,utilization.gpu --format=csv,noheader,nounits"""
    parts = [p.strip() for p in text.strip().split(",")]
    if len(parts) < 3:
        return None
    try:
        return {"used_mb": float(parts[0]), "total_mb": float(parts[1]), "util_pct": float(parts[2])}
    except ValueError:
        return None


def disk_usage(path):
    try:
        st = os.statvfs(path)
    except OSError:
        return None
    total = st.f_blocks * st.f_frsize
    free = st.f_bavail * st.f_frsize
    if total <= 0:
        return None
    return {
        "path": path,
        "used_pct": round((total - free) / total * 100.0, 1),
        "total_gb": round(total / 1024 ** 3, 1),
        "free_gb": round(free / 1024 ** 3, 1),
    }


def gpu_info():
    try:
        r = subprocess.run(
            ["nvidia-smi", "--query-gpu=memory.used,memory.total,utilization.gpu",
             "--format=csv,noheader,nounits"],
            capture_output=True, text=True, timeout=10,
        )
        if r.returncode == 0:
            return parse_nvidia_smi(r.stdout)
    except (OSError, subprocess.SubprocessError):
        pass
    return None


def main():
    try:
        doc = {
            "generated": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
            "memory": parse_meminfo(_slurp("/proc/meminfo")) or {},
            "load": parse_loadavg(_slurp("/proc/loadavg")) or {},
            "uptime_s": parse_uptime(_slurp("/proc/uptime")) or 0.0,
            "cpu_threads": os.cpu_count() or 0,
            "disks": [d for d in (disk_usage(p) for p in _disk_paths()) if d],
        }
        gpu = gpu_info()
        if gpu:
            doc["gpu"] = gpu
        out = _out_path()
        os.makedirs(os.path.dirname(out), exist_ok=True)
        tmp = out + ".tmp"
        with open(tmp, "w", encoding="utf-8") as f:
            json.dump(doc, f, indent=1, sort_keys=True)
        os.replace(tmp, out)
    except Exception as exc:  # fail-open: a resource snapshot never blocks a beat
        print("system-ingest: %s" % exc, file=sys.stderr)
    return 0


def _slurp(path):
    try:
        with open(path, encoding="utf-8", errors="replace") as f:
            return f.read()
    except OSError:
        return ""


def _disk_paths():
    paths = []
    try:
        paths.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    except Exception:
        pass
    home = db_dir()
    if home:
        paths.append(home)
    return list(dict.fromkeys(paths))


def _out_path():
    args = sys.argv[1:]
    if "--out" in args:
        i = args.index("--out")
        if i + 1 < len(args):
            return args[i + 1]
    env = os.environ.get("HNGH_SYSTEM_STATE")
    if env:
        return env
    return os.path.join(db_dir(), "system-resources.json")


if __name__ == "__main__":
    sys.exit(main())
