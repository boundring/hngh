#!/usr/bin/env bash
# deck-producer -- one-shot deck facts producer (deck phase 1, zero operator).
# Staged by the desktop cadence (cadence/hour/32-deck-facts.sh) into
# ~/hngh-deck/ and run over ssh on every hourly pull; the deck itself stays
# passive: one $HOME directory, no repos, no daemons, no timers.
# Pure stdlib: bash + python3 (both present on SteamOS; no sbcl/gcc/make).
# Writes facts/facts-<UTCts>.json, appends a sha256 manifest line to
# manifest.txt (kept to the last 64 entries), and keeps only the last 24
# facts files. Exits 0 always: per-fact errors land in the JSON "error"
# field, and every probe is timeout-bounded so this never hangs.
set -u
ROOT="${DECK_FACTS_ROOT:-$HOME/hngh-deck}"
mkdir -p "$ROOT/facts" 2>/dev/null || true
python3 - "$ROOT" <<'PY'
import glob, hashlib, json, os, platform, shutil, subprocess, sys, time

root = sys.argv[1]
facts_dir = os.path.join(root, "facts")


def run(argv, timeout=5):
    return subprocess.run(argv, capture_output=True, text=True, timeout=timeout)


def read(path, limit=4096):
    with open(path) as f:
        return f.read(limit).strip()


facts = {"schema": "deck-facts/1", "peer": platform.uname().node or "unknown"}
facts["clock_utc"] = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
facts["epoch_s"] = int(time.time())
errors = []


def fact(key, fn):
    try:
        facts[key] = fn()
    except Exception as e:
        errors.append("%s: %s" % (key, e))


def f_uname():
    return run(["uname", "-a"]).stdout.strip()


def f_meminfo():
    out = {}
    for line in read("/proc/meminfo").splitlines():
        k, _, v = line.partition(":")
        if k in ("MemTotal", "MemAvailable"):
            out[k] = v.strip()
    if len(out) != 2:
        raise ValueError("meminfo keys missing")
    return out


def f_loadavg():
    return read("/proc/loadavg")


def f_uptime_since():
    return run(["uptime", "-s"]).stdout.strip()


def f_df_home():
    return run(["df", "-h", "/home"]).stdout.strip()


def f_gpu():
    gpus = []
    for card in sorted(glob.glob("/sys/class/drm/card[0-9]*")):
        g = {"card": os.path.basename(card)}
        dev = os.path.join(card, "device")
        for key, fname in (("vendor", "vendor"), ("device_id", "device")):
            try:
                g[key] = read(os.path.join(dev, fname), 32)
            except Exception:
                pass
        drv = os.path.join(dev, "driver")
        if os.path.islink(drv):
            g["driver"] = os.path.basename(os.readlink(drv))
        gpus.append(g)
    hwmon = []
    for h in sorted(glob.glob("/sys/class/hwmon/hwmon*")):
        m = {"hwmon": os.path.basename(h)}
        try:
            m["name"] = read(os.path.join(h, "name"), 64)
        except Exception:
            pass
        for t in sorted(glob.glob(os.path.join(h, "temp*_input")))[:8]:
            e = {"input": read(t, 32)}
            try:
                e["label"] = read(t.replace("_input", "_label"), 64)
            except Exception:
                pass
            m.setdefault("temps", []).append(e)
        hwmon.append(m)
    return {"drm": gpus, "hwmon": hwmon}


def f_tailscale():
    cli = shutil.which("tailscale") or os.path.expanduser("~/.local/bin/tailscale")
    sock = os.path.expanduser("~/.local/share/tailscaled/tailscaled.sock")
    tried = []
    for argv in ([cli, "ip", "-4"], [cli, "--socket", sock, "ip", "-4"]):
        if not os.path.exists(argv[0]):
            continue
        r = run(argv)
        tried.append(" ".join(argv))
        if r.returncode == 0 and r.stdout.strip():
            return r.stdout.strip().splitlines()[0].strip()
    raise RuntimeError("tailscale CLI gave no ip (tried: %s)" % "; ".join(tried))


def f_dir_free():
    u = shutil.disk_usage(root)
    return {"total_bytes": u.total, "free_bytes": u.free}


fact("uname", f_uname)
fact("meminfo_kB", f_meminfo)
fact("loadavg", f_loadavg)
fact("uptime_since", f_uptime_since)
fact("df_home", f_df_home)
fact("gpu", f_gpu)
fact("tailscale_ip4", f_tailscale)
fact("hngh_deck_disk", f_dir_free)
if errors:
    facts["error"] = "; ".join(errors)

name = time.strftime("facts-%Y%m%dT%H%M%SZ.json", time.gmtime())
path = os.path.join(facts_dir, name)
with open(path, "w") as f:
    f.write(json.dumps(facts, indent=1, sort_keys=True) + "\n")

digest = hashlib.sha256(open(path, "rb").read()).hexdigest()
mf = os.path.join(root, "manifest.txt")
with open(mf, "a") as f:
    f.write("%s  %s  %s\n" % (digest, name, facts["clock_utc"]))
lines = open(mf).read().splitlines()[-64:]
with open(mf, "w") as f:
    f.write("\n".join(lines) + ("\n" if lines else ""))

for old in sorted(glob.glob(os.path.join(facts_dir, "facts-*.json")))[:-24]:
    try:
        os.remove(old)
    except OSError:
        pass

print(path)
PY
exit 0
