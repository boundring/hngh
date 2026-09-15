#!/usr/bin/env python3
"""hygiene — self-maintenance hygiene scan (evidence-first, report-only v1).

Finds recurring debris and files report-queue progress rows ONLY when
something is found (clean runs are silent). Fail-soft: exits 0 on every
expected path, per hngh norms.

Checks (evidence: .agent-scratch/swarm-resume/hist-windows-queue.md and
its workq-*.md siblings, observed 2026-09-15):
  1. jcode zombie session metadata: ~/.jcode/sessions/session_*.json with
     status Active and mtime older than 24h. REPORT-ONLY in v1.
  2. jcode dead pidfiles: ~/.jcode/active_pids/* whose PID is dead.
     Report-only by default; --fix removes ONLY dead-pid pidfiles
     (never session files).
  3. Repo hygiene (cwd repo): stray root-level files not matching known
     patterns (e.g. a file literally named '--model'); empty
     .agent-scratch/* subdirs and .scratch/* work dirs older than 7 days.
     Report-only; never deletes anything in v1.
  4. Ambient memory: appends one line to automation/agent-handoffs.md
     summarizing the run (the cross-session notes convention).

usage: jobs/hygiene.py [--fix] [--json]
env:   HNGH_REPORT_ROOT (report-queue repo root, existing contract),
       HYGIENE_REPO_ROOT (repo scan root, default cwd),
       HYGIENE_JCODE_HOME (fake ~/.jcode root, default ~/.jcode),
       HYGIENE_HANDOFF_FILE (default <repo>/automation/agent-handoffs.md),
       HYGIENE_NO_HANDOFF=1 skips the handoff append (tests).
"""
import argparse
import json
import os
import subprocess
import sys
import time

JOB_DIR = os.path.dirname(os.path.abspath(__file__))
AUTOMATION = os.path.dirname(JOB_DIR)
REPO = os.path.dirname(AUTOMATION)
REPORT_QUEUE = os.path.join(REPO, "scripts", "report-queue")

SESSION_AGE_S = 24 * 3600
SCRATCH_AGE_S = 7 * 86400
# Known/good root-level names: tracked by git or established runtime dirs.
KNOWN_ROOT_PREFIXES_FALLBACK = ("docs", "automation", "src", "tests",
                                "scripts", "dashboard", "prompts", "", ".git",
                                ".github")


def jcode_home():
    return os.environ.get("HYGIENE_JCODE_HOME") \
        or os.path.join(os.path.expanduser("~"), ".jcode")


def repo_root():
    return os.environ.get("HYGIENE_REPO_ROOT") or os.getcwd()


def report_root():
    return os.environ.get("HNGH_REPORT_ROOT") or repo_root()


def pid_alive(pid):
    try:
        pid = int(pid)
    except (TypeError, ValueError):
        return False
    if pid <= 0:
        return False
    try:
        os.kill(pid, 0)
        return True
    except PermissionError:
        return True
    except ProcessLookupError:
        return False
    except OSError:
        return False


def queue_progress(text, identity):
    """Best-effort report-queue row; never raises."""
    try:
        subprocess.run(
            [sys.executable, REPORT_QUEUE, "--add", "progress", text,
             "--identity", identity, "--window", "86400"],
            env=dict(os.environ, HNGH_REPORT_ROOT=report_root()),
            capture_output=True, timeout=30)
    except Exception:
        pass


def find_zombie_sessions(root):
    out = []
    d = os.path.join(root, "sessions")
    try:
        names = sorted(os.listdir(d))
    except OSError:
        return out
    now = time.time()
    for n in names:
        if not (n.startswith("session_") and n.endswith(".json")):
            continue
        p = os.path.join(d, n)
        try:
            if now - os.path.getmtime(p) <= SESSION_AGE_S:
                continue
            with open(p) as f:
                status = str(json.load(f).get("status", "")).lower()
        except Exception:
            continue
        if status == "active":
            out.append(p)
    return out


def find_dead_pidfiles(root):
    out = []
    d = os.path.join(root, "active_pids")
    try:
        names = sorted(os.listdir(d))
    except OSError:
        return out
    for n in names:
        p = os.path.join(d, n)
        try:
            with open(p) as f:
                pid = f.read().strip()
        except Exception:
            continue
        if not pid_alive(pid):
            out.append(p)
    return out


def tracked_top_names(root):
    """Best-effort set of tracked top-level entries via git; None on fault."""
    try:
        r = subprocess.run(
            ["git", "ls-files"], cwd=root, capture_output=True,
            text=True, timeout=30)
        if r.returncode != 0:
            return None
        return {p.split("/")[0] for p in r.stdout.splitlines() if p}
    except Exception:
        return None


def find_repo_debris(root):
    stray, empty_scratch, aged_work = [], [], []
    tracked = tracked_top_names(root)
    known = tracked if tracked is not None \
        else set(KNOWN_ROOT_PREFIXES_FALLBACK)
    try:
        entries = os.listdir(root)
    except OSError:
        return stray, empty_scratch, aged_work
    now = time.time()
    for n in sorted(entries):
        if n == ".git" or n in known or n.startswith("."):
            continue
        p = os.path.join(root, n)
        if os.path.isfile(p):
            stray.append(p)
    for base, key in ((".agent-scratch", "scratch"), (".scratch", "work")):
        b = os.path.join(root, base)
        try:
            subs = os.listdir(b)
        except OSError:
            continue
        for s in subs:
            d = os.path.join(b, s)
            if not os.path.isdir(d):
                continue
            try:
                empty = not os.listdir(d)
                age = now - os.path.getmtime(d)
            except OSError:
                continue
            if age > SCRATCH_AGE_S and (empty if key == "scratch" else True):
                if empty:
                    empty_scratch.append(d)
                else:
                    aged_work.append(d)
    return stray, empty_scratch, aged_work


def append_handoff(summary):
    if os.environ.get("HYGIENE_NO_HANDOFF") == "1":
        return
    path = os.environ.get("HYGIENE_HANDOFF_FILE") \
        or os.path.join(AUTOMATION, "agent-handoffs.md")
    ts = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
    line = "hygiene | %s | automation|hygiene-run | %s\n" % (ts, summary)
    try:
        with open(path, "a") as f:
            f.write(line)
    except OSError:
        pass


def main():
    ap = argparse.ArgumentParser(prog="hygiene")
    ap.add_argument("--fix", action="store_true",
                    help="remove pidfiles with dead PIDs (v1: pidfiles only)")
    ap.add_argument("--json", action="store_true", dest="as_json")
    args = ap.parse_args()

    jh = jcode_home()
    rr = repo_root()
    zombies = find_zombie_sessions(jh)
    dead_pid = find_dead_pidfiles(jh)
    stray, empty_scratch, aged_work = find_repo_debris(rr)

    fixed = []
    if args.fix:
        for p in dead_pid:
            try:
                os.unlink(p)
                fixed.append(p)
            except OSError:
                pass

    if zombies:
        oldest = min(os.path.getmtime(p) for p in zombies)
        age_h = int((time.time() - oldest) / 3600)
        queue_progress(
            "hygiene: %d zombie Active session file(s) >24h old "
            "(oldest %dh); report-only v1; e.g. %s"
            % (len(zombies), age_h, os.path.basename(zombies[0])),
            "hygiene:sessions")
    if dead_pid:
        note = "; %d removed by --fix" % len(fixed) if fixed else \
            "; report-only (run with --fix to remove dead pidfiles)"
        queue_progress(
            "hygiene: %d dead pidfile(s) in active_pids%s; e.g. %s"
            % (len(dead_pid), note, os.path.basename(dead_pid[0])),
            "hygiene:pidfiles")
    if stray or empty_scratch or aged_work:
        parts = []
        if stray:
            parts.append("%d stray root file(s) e.g. %s"
                         % (len(stray), os.path.basename(stray[0])))
        if empty_scratch:
            parts.append("%d empty .agent-scratch dir(s) >7d" % len(empty_scratch))
        if aged_work:
            parts.append("%d aged .scratch work dir(s) >7d" % len(aged_work))
        queue_progress("hygiene: repo debris: " + "; ".join(parts),
                       "hygiene:repo")

    result = {
        "zombie_sessions": len(zombies),
        "zombie_examples": [os.path.basename(p) for p in zombies[:3]],
        "dead_pidfiles": len(dead_pid),
        "pidfile_examples": [os.path.basename(p) for p in dead_pid[:3]],
        "pidfiles_removed": len(fixed),
        "stray_root_files": len(stray),
        "empty_scratch_dirs": len(empty_scratch),
        "aged_work_dirs": len(aged_work),
    }
    found = sum((result["zombie_sessions"], result["dead_pidfiles"],
                 result["stray_root_files"], result["empty_scratch_dirs"],
                 result["aged_work_dirs"]))
    if found:
        summary = "found %d item(s): sessions=%d pidfiles=%d (removed=%d)" \
            " stray_root=%d empty_scratch=%d aged_work=%d" % (
                found, result["zombie_sessions"], result["dead_pidfiles"],
                result["pidfiles_removed"], result["stray_root_files"],
                result["empty_scratch_dirs"], result["aged_work_dirs"])
        append_handoff(summary)
    else:
        summary = "clean run, nothing found"

    if args.as_json:
        result["found"] = found
        result["summary"] = summary
        print(json.dumps(result))
    return 0


if __name__ == "__main__":
    sys.exit(main())
