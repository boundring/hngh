#!/usr/bin/env python3
"""window-tile — spawn transcript-tailing terminals and place them in a
named tiling profile (golden-ratio slots) on the operator desktop.

Geometry source: `xdotool getdisplaygeometry` on the operator display
(ui-config tiling.screen, default "0.0", names the intended display; the
actual box is whatever xdotool reports at call time). Slots are PERCENTAGES
of that box so the same profile tracks resolution changes.

Everything is data-driven from the "tiling" block of
~/.config/hngh/ui-config.json:
    terminal  — command template, {transcript} placeholder (shlex-quoted)
    tiler     — command template, {window} {x} {y} {w} {h} placeholders
                (all values are integers we compute; executed WITHOUT a shell)
    profiles  — name -> {"slots": [{"x%","y%","w%","h%"}, ...]}

Fail-closed: tiling.enabled must be true; no shell interpolation anywhere;
window lookup is a pre/post diff of the terminal's window class (never a
guessed pid). Unresolvable transcript -> that slot is skipped, never
fabricated. Display layer only — never feeds hngh governance.

CLI: python3 jobs/window-tile.py <profile> <session-id>... (debug/manual use)
"""
import json
import os
import shlex
import subprocess
import sys
import time

UI_CONFIG = os.path.join(os.path.expanduser("~"), ".config", "hngh", "ui-config.json")

DEFAULT_TERMINAL = "konsole -e tail -n 80 -f {transcript}"
DEFAULT_TILER = "xdotool windowmove {window} {x} {y} windowsize {window} {w} {h}"

# Phi-flavored splits (62/38). First sessions fill the first slots.
DEFAULT_PROFILES = {
    "duo": {"slots": [
        {"x%": 62, "y%": 0, "w%": 38, "h%": 100},   # detail, right
        {"x%": 0, "y%": 0, "w%": 62, "h%": 100},    # sidebar, left
    ]},
    "focus": {"slots": [
        {"x%": 38, "y%": 0, "w%": 62, "h%": 100},   # focus pane
        {"x%": 0, "y%": 0, "w%": 38, "h%": 100},    # sidebar
    ]},
    "triple": {"slots": [
        {"x%": 38, "y%": 0, "w%": 62, "h%": 100},   # wide primary
        {"x%": 0, "y%": 0, "w%": 38, "h%": 62},     # upper sidebar
        {"x%": 0, "y%": 62, "w%": 38, "h%": 38},    # lower sidebar
    ]},
}


def load_tiling():
    """(enabled, terminal, tiler, profiles) — operator config over defaults.
    Absent/broken config fails closed: enabled=False."""
    try:
        with open(UI_CONFIG, encoding="utf-8") as f:
            cfg = (json.load(f) or {}).get("tiling") or {}
    except Exception:
        cfg = {}
    profiles = cfg.get("profiles") or DEFAULT_PROFILES
    return (bool(cfg.get("enabled")),
            cfg.get("terminal") or DEFAULT_TERMINAL,
            cfg.get("tiler") or DEFAULT_TILER,
            profiles)


def display_geometry():
    """(width, height) of the operator display, via xdotool."""
    out = subprocess.run(["xdotool", "getdisplaygeometry"],
                         capture_output=True, text=True, timeout=10, check=True)
    w, h = out.stdout.split()[:2]
    return int(w), int(h)


def _windows_of(wm_class):
    out = subprocess.run(["xdotool", "search", "--onlyvisible", "--class", wm_class],
                         capture_output=True, text=True, timeout=10)
    return set(out.stdout.split())


def _place(window, slot, screen_w, screen_h, tiler):
    cmd = (tiler.replace("{window}", str(window))
                .replace("{x}", str(int(slot["x%"] * screen_w / 100)))
                .replace("{y}", str(int(slot["y%"] * screen_h / 100)))
                .replace("{w}", str(int(slot["w%"] * screen_w / 100)))
                .replace("{h}", str(int(slot["h%"] * screen_h / 100))))
    subprocess.run(shlex.split(cmd), capture_output=True, timeout=10)
    return _geometry(window)


def _geometry(window):
    """[x, y, w, h] as reported by xdotool, or []."""
    out = subprocess.run(["xdotool", "getwindowgeometry", "--shell", str(window)],
                         capture_output=True, text=True, timeout=10)
    vals = {}
    for line in out.stdout.splitlines():
        k, _, v = line.partition("=")
        if k in ("X", "Y", "WIDTH", "HEIGHT"):
            vals[k] = int(v)
    return [vals.get("X"), vals.get("Y"), vals.get("WIDTH"), vals.get("HEIGHT")]


def tile(transcripts, profile, terminal=None, tiler=None, profiles=None):
    """Spawn one terminal per transcript and place it in the profile's slots.

    transcripts: ordered list of (session_id, transcript_path) — paths must
    be pre-resolved (caller skips unresolvable ones, never fabricated here).
    Returns list of {"session", "window", "geometry"} for placed windows.
    Raises RuntimeError when the tiler binary is missing.
    """
    if terminal is None or tiler is None or profiles is None:
        _, terminal, tiler, profiles = load_tiling()
    if profile not in profiles:
        raise KeyError(profile)
    tiler_bin = shlex.split(tiler)[0]
    if not os.path.isfile(tiler_bin) and not _which(tiler_bin):
        raise RuntimeError(f"{tiler_bin} required")
    slots = profiles[profile].get("slots") or []
    screen_w, screen_h = display_geometry()
    wm_class = os.path.basename(shlex.split(terminal)[0])
    placed = []
    for (sid, transcript), slot in zip(transcripts, slots):
        pre = _windows_of(wm_class)
        cmd = shlex.split(terminal.replace(
            "{transcript}", shlex.quote(os.path.abspath(transcript))))
        subprocess.Popen(cmd, start_new_session=True,
                         stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL,
                         stderr=subprocess.DEVNULL)
        window = None
        for _ in range(30):  # poll up to ~15s for the new window to map
            time.sleep(0.5)
            new = _windows_of(wm_class) - pre
            if new:
                window = sorted(new)[-1]
                break
        if window is None:
            continue  # spawned but unmapped: report nothing for this slot
        geometry = _place(window, slot, screen_w, screen_h, tiler)
        placed.append({"session": sid, "window": window, "geometry": geometry})
    return placed


def _which(binary):
    for d in os.environ.get("PATH", "").split(os.pathsep):
        p = os.path.join(d, binary)
        if os.path.isfile(p) and os.access(p, os.X_OK):
            return p
    return None


if __name__ == "__main__":
    # manual/debug: jobs/window-tile.py <profile> <session-id>...
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    import sessions_feed  # sibling module, same dir
    if len(sys.argv) < 3:
        sys.exit(__doc__)
    profile, sids = sys.argv[1], sys.argv[2:]
    _, terminal, tiler, profiles = load_tiling()
    pairs = []
    for sid in sids:
        for source, _roots in sessions_feed.SOURCES:
            path = sessions_feed.find_transcript(source, sid)
            if path:
                pairs.append((sid, path))
                break
    print(json.dumps(tile(pairs, profile, terminal, tiler, profiles), indent=2))
