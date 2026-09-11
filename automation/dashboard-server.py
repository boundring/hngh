#!/usr/bin/env python3
"""dashboard-server — static file server for hngh-automation/dashboard/
PLUS exactly nine write endpoints (any other POST path -> 404) and one
read-only GET route (see below).

Endpoints — all advisory/display-only. They NEVER feed hngh governance,
policy, certificates, or scoring; spawned processes are display surfaces.
The research endpoints below write to the operator's backlog.md, which is
a PROSE surface: proposals and annotations for the operator to read and
rotate into the queue — never authority, never governance input.

POST /flag  {"session": str, "note": str}
    Appends ONE line to agent-handoffs.md:
      flag | <UTC ts> | automation|<session> | operator flag: <note>
    201 {"ok": true}

POST /operator-item/dismiss  {"id": str}
    Appends ONE line to agent-handoffs.md:
        operator-dismiss | <UTC ts> | automation|<id> | item dismissed as viewed
    and records the id in dashboard/operator-dismissed.json
    ({"dismissed": {"<id>": "<UTC ts>"}}) so the UI survives reloads.
    201 {"ok": true}

POST /spawn  {"session": str, "launcher": str}
    Spawns a launcher COMMAND TEMPLATE on the operator desktop to tail
    the session transcript. The client may only NAME a launcher key —
    never supply a command. Templates come from the "launchers" map of
    ~/.config/hngh/ui-config.json (overrides/adds keys) or the built-in
    DEFAULT_LAUNCHERS below ({"session"} -> validated session id,
    {"transcript"} -> shlex-quoted absolute record.lisp path, resolved
    exactly like jobs/sessions-feed.py find_transcript). Spawned via
    subprocess.Popen, shlex.split, no shell, detached (start_new_session),
    stdio discarded. 201 {"ok": true, "launcher": key}; 400 unknown
    launcher key / no transcript for session; 500 spawn failure.

POST /tile  {"profile": str, "sessions": [str, ...]}
    Spawns the configured terminal (ui-config tiling.terminal, default
    konsole tail -f) per session and places the windows in the named
    profile's slots (golden-ratio percentage geometry; see
    jobs/window-tile.py). Desktop mutation, so it is guarded:
    403 unless ui-config tiling.enabled is true; max 4 sessions per call;
    unresolvable transcripts skip that slot (never fabricated); the tiler
    command template is executed WITHOUT a shell (shlex.split, integer
    arguments only). 201 {"ok": true, "placed": [...], "skipped": [...]};
    400 unknown profile / bad input; 403 tiling disabled; 500 tiler
    binary missing. Ledger: tile | <UTC ts> | <profile> | <session ids>

POST /research-line  {"name": str, "intent": str}
    Appends a proposal-ready lane to the operator's backlog.md
    (docs/project/backlog.md in the hngh repo) — append-only, never
    reorders existing content:
      ## <name> (proposed via dashboard <UTC ts>)
      - **Problem:** / **Smallest useful outcome:** bullets from intent
      - **Status:** proposed via dashboard — awaiting queue rotation
    Advisory/organizational only: backlog.md is a prose surface
    (proposals, not authority). 201 {"ok": true, "lane": name}; 400 on
    bad input or an existing lane with that name.

POST /research-note  {"lane": str, "note": str, "affecting": bool}
    Appends an annotation '- note (<UTC ts>): <text>' at the end of the
    named lane's backlog.md section (lane must exist as a '## ' heading)
    and one agent-handoffs.md line:
      research-note | <UTC ts> | automation|<lane> | <note>
    affecting=true ALSO queues an advisory steer via the hngh
    scripts/report-queue ('research-steer <lane>: <note>' alert row) for
    the operator/agents to read — the note itself never mutates
    anything; corrections still ride the certificate loop. 201
    {"ok": true}; 400 unknown lane / bad input.

POST /system/refresh  {}
    Re-runs jobs/system-feed.py (read-only probes, the same script the
    30m cadence mounts) and returns the fresh system-ops.json payload.
    201 {"ok": true, "feed": {...}}; 500 feed failure.

POST /system/reset-failed  {"unit": str}
    Runs `systemctl --user reset-failed <unit>` — clears failed-unit
    STATE only; it stops nothing, restarts nothing, and never touches
    the system bus. Unit validated [A-Za-z0-9.@_-]{1,80}, passed as a
    single argv element (no shell). 201 {"ok": true, "rc": 0}; 400 bad
    unit; 500 exec failure.

POST /system/backup-now  {}
    Executes `jobs/config-backup.sh agent-configs --mode push` — the
    governed backup lane (all sources validated, secret-scan fails
    closed before any commit or push). Captured rc + wall time returned;
    the lane appends its own report-queue row. 201 {"ok": rc==0, "rc":
    N, "wall": S, "tail": last-stdout-line}; 500 exec failure.
    Every /system/* call appends one agent-handoffs.md line
    (system-op | <UTC ts> | automation|system-view | <action>).

Contract (shared, same style as /flag):
    - session/id: non-empty, <=80 chars, [A-Za-z0-9._-]
    - note:       non-empty, <=200 chars after stripping pipes
    - 400 on bad input; 404 on any other POST
All writes are append-only (ledger) or atomic-replace (JSON).
Exception: /research-note splices one annotation line at the end of the
named lane's backlog.md section (insertion is the point of the feature;
existing content is never reordered).
"""
import importlib.util
import json
import os
import re
import shlex
import subprocess
import time
import urllib.parse
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer

ROOT = os.path.dirname(os.path.abspath(__file__))
DASHBOARD = os.path.join(ROOT, "dashboard")
HANDOFFS = os.path.join(ROOT, "agent-handoffs.md")
UI_CONFIG = os.path.join(os.path.expanduser("~"), ".config", "hngh", "ui-config.json")
DISMISSED = os.path.join(DASHBOARD, "operator-dismissed.json")
HNGH = os.environ.get("HNGH_REPO", "/home/bricker/Projects/etc/hngh")
BACKLOG = os.path.join(HNGH, "docs", "project", "backlog.md")
REPORT_QUEUE = os.path.join(HNGH, "scripts", "report-queue")
RESEARCH_DOCS = os.path.join(HNGH, "docs", "research")
DOC_NAME_RE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9 _.-]{0,120}\.md$")
DIGESTS = os.path.join(ROOT, "digest")
DIGEST_NAME_RE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._-]*\.md$")
FEEDBACK = os.path.join(DASHBOARD, "feedback")
FEEDBACK_TYPES = ("css-theme", "data-format", "correction", "idea")

SESSION_RE = re.compile(r"^[A-Za-z0-9._-]{1,80}$")
UNIT_RE = re.compile(r"^[A-Za-z0-9.@_-]{1,80}$")

# Built-in launcher templates (ui-config "launchers" overrides/adds).
# {transcript} is replaced with the shlex-quoted absolute record.lisp
# path; {session} with the validated session id. Display-only: the
# spawned konsole tails the run's store record.
DEFAULT_LAUNCHERS = {
    "konsole-tail": "konsole -e tail -n 80 -f {transcript}",
    "konsole-store": "konsole -e tail -n 80 -f {transcript}",
}

# jobs/sessions-feed.py has a dash in its filename; load it explicitly to
# reuse find_transcript (same scan rules as the dashboard feed itself).
_spec = importlib.util.spec_from_file_location(
    "sessions_feed", os.path.join(ROOT, "jobs", "sessions-feed.py"))
sessions_feed = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(sessions_feed)

# same treatment for jobs/window-tile.py (dash in filename): the tiling
# helper the /tile endpoint drives.
_tspec = importlib.util.spec_from_file_location(
    "window_tile", os.path.join(ROOT, "jobs", "window-tile.py"))
window_tile = importlib.util.module_from_spec(_tspec)
_tspec.loader.exec_module(window_tile)


def _launchers():
    merged = dict(DEFAULT_LAUNCHERS)
    try:
        with open(UI_CONFIG, encoding="utf-8") as f:
            cfg = json.load(f)
        for key, tmpl in (cfg.get("launchers") or {}).items():
            if isinstance(tmpl, str) and SESSION_RE.fullmatch(key):
                merged[key] = tmpl
    except Exception:
        pass  # absent/broken ui-config: built-in defaults apply
    return merged


def _transcript(sid):
    for source in sessions_feed.SOURCES:  # ("automation"|"heartbeat"|"auto", roots)
        path = sessions_feed.find_transcript(source[0], sid)
        if path:
            return path
    return None


def _ts():
    return time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())


def jailed_doc_path(base, name_re, name):
    """Resolve one markdown name inside base; None unless it validates,
    exists, and realpath-lands inside base (symlink/traversal fail closed).
    Shared by the /hngh-docs/research/ and /digest/ GET jails."""
    if not name_re.fullmatch(name or ""):
        return None
    doc = os.path.join(base, name)
    real = os.path.realpath(doc)
    if not real.startswith(os.path.realpath(base) + os.sep):
        return None
    return doc if os.path.isfile(real) else None


class Handler(SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=DASHBOARD, **kwargs)

    # GET /hngh-docs/research/<name>.md and GET /digest/<name>.md —
    # read-only serve of ONE markdown document from a jailed directory
    # (research-page-spec §2 result-doc links; Camp's full-dispatch link).
    # Strict name validation + directory jail; anything else 404s. The
    # client probes first and renders the state chip without a link on
    # 404 — fail closed, no dead links. Display-only.
    def do_GET(self):
        if self.path.startswith("/hngh-docs/research/"):
            self._serve_md(RESEARCH_DOCS, DOC_NAME_RE)
            return
        if self.path.startswith("/digest/"):
            self._serve_md(DIGESTS, DIGEST_NAME_RE)
            return
        super().do_GET()

    def _serve_md(self, base, name_re):
        name = urllib.parse.unquote(self.path.rsplit("/", 1)[-1].split("?")[0])
        doc = jailed_doc_path(base, name_re, name)
        if not doc:
            self.send_error(404)
            return
        with open(doc, "rb") as f:
            payload = f.read()
        self.send_response(200)
        self.send_header("Content-Type", "text/markdown; charset=utf-8")
        self.send_header("Content-Length", str(len(payload)))
        self.end_headers()
        self.wfile.write(payload)

    def _body(self):
        length = int(self.headers.get("Content-Length", 0))
        return json.loads(self.rfile.read(length) if length < 65536 else b"")

    def do_POST(self):
        try:
            p = self.path.lstrip("/")
            if p == "api/feedback":
                p = "feedback"  # namespaced client path, root dispatch
            {"flag": self._flag,
             "operator-item/dismiss": self._dismiss,
             "spawn": self._spawn,
             "tile": self._tile,
             "research-line": self._research_line,
             "research-note": self._research_note,
             "system/refresh": self._system_refresh,
             "system/reset-failed": self._system_reset_failed,
             "system/backup-now": self._system_backup_now,
             "feedback": self._feedback}[p]()
        except KeyError:
            self._json(404, {"ok": False, "error": "not found"})

    def _handoff(self, action):
        try:
            with open(HANDOFFS, "a", encoding="utf-8") as f:
                f.write("system-op | %s | automation|system-view | %s\n"
                        % (_ts(), action))
        except OSError:
            pass  # ledger down must not fail a completed system op

    def _system_refresh(self):
        try:
            p = subprocess.run(["python3", os.path.join(ROOT, "jobs", "system-feed.py")],
                               capture_output=True, timeout=60)
        except Exception:
            self._json(500, {"ok": False, "error": "feed refresh failed"})
            return
        self._handoff("feed-refresh rc=%d" % p.returncode)
        try:
            with open(os.path.join(DASHBOARD, "system-ops.json"), encoding="utf-8") as f:
                feed = json.load(f)
        except Exception:
            self._json(500, {"ok": False, "error": "feed output unreadable"})
            return
        self._json(201 if p.returncode == 0 else 500,
                   {"ok": p.returncode == 0, "feed": feed})

    def _system_reset_failed(self):
        try:
            unit = str(self._body().get("unit", "")).strip()
        except Exception:
            self._json(400, {"ok": False, "error": "invalid JSON"})
            return
        if not UNIT_RE.fullmatch(unit):
            self._json(400, {"ok": False, "error": "invalid unit name"})
            return
        try:
            p = subprocess.run(["systemctl", "--user", "reset-failed", unit],
                               capture_output=True, timeout=15)
        except Exception:
            self._json(500, {"ok": False, "error": "systemctl exec failed"})
            return
        self._handoff("reset-failed %s rc=%d" % (unit, p.returncode))
        self._json(201 if p.returncode == 0 else 500,
                   {"ok": p.returncode == 0, "rc": p.returncode})

    def _system_backup_now(self):
        started = time.monotonic()
        try:
            p = subprocess.run(
                ["bash", os.path.join(ROOT, "jobs", "config-backup.sh"),
                 "agent-configs", "--mode", "push"],
                capture_output=True, text=True, timeout=300)
        except Exception:
            self._json(500, {"ok": False, "error": "backup exec failed"})
            return
        wall = round(time.monotonic() - started, 1)
        tail = (p.stdout or p.stderr or "").strip().splitlines()[-1:]  # last lane log line
        self._handoff("backup-now rc=%d wall=%ss" % (p.returncode, wall))
        self._json(201 if p.returncode == 0 else 500,
                   {"ok": p.returncode == 0, "rc": p.returncode, "wall": wall,
                    "tail": tail[0] if tail else ""})

    def _flag(self):
        try:
            body = self._body()
            session = str(body.get("session", "")).strip()
            note = str(body.get("note", "")).strip().replace("|", "")
        except Exception:
            self._json(400, {"ok": False, "error": "invalid JSON"})
            return
        if not SESSION_RE.fullmatch(session) or not 0 < len(note) <= 200:
            self._json(400, {"ok": False, "error": "invalid session or note"})
            return
        ts = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
        with open(HANDOFFS, "a", encoding="utf-8") as f:
            f.write(f"flag | {ts} | automation|{session} | operator flag: {note}\n")
        self._json(201, {"ok": True})

    # POST /api/feedback — write-only feedback capture from the dashboard
    # pips (JSON body) and the notification-email feedback forms
    # (application/x-www-form-urlencoded body; email is JS-free). One
    # validator for both encodings. POST endpoints here carry no shared
    # token (LAN-served static
    # dashboard; every route is display/ledger-only), so the posture is:
    # files only, plain text, 2000-char cap, 64 KB body cap (in _body),
    # and a simple 1-per-second per-type rate guard. Nothing is executed.
    _fb_last = {}  # type -> monotonic ts of last accepted write

    def _feedback(self):
        try:
            ctype = self.headers.get("Content-Type", "")
            if "application/x-www-form-urlencoded" in ctype:
                # HTML email feedback forms post urlencoded (email is
                # JS-free); parse_qsl cannot raise, empty fields drop out
                # to "" and fail validation below like any bad JSON field.
                length = int(self.headers.get("Content-Length", 0))
                raw = self.rfile.read(length if length < 65536 else 0)
                body = dict(urllib.parse.parse_qsl(raw.decode("utf-8", "replace")))
            else:
                body = self._body()
            ftype = str(body.get("type", "")).strip()
            text = str(body.get("text", "")).strip()
            element = str(body.get("element", "")).strip()
        except Exception:
            self._json(400, {"ok": False, "error": "invalid JSON"})
            return

        if ftype not in FEEDBACK_TYPES:
            self._json(400, {"ok": False, "error": "invalid type"})
            return
        if not 0 < len(text) <= 2000:
            self._json(400, {"ok": False, "error": "text must be 1-2000 chars"})
            return
        now = time.monotonic()
        if now - Handler._fb_last.get(ftype, 0.0) < 1.0:
            self._json(429, {"ok": False, "error": "slow down (1/sec per type)"})
            return
        Handler._fb_last[ftype] = now
        rec = {"ts": _ts(), "type": ftype,
               "text": text.replace("\x00", "")[:2000],
               "element": element[:80]}
        try:
            os.makedirs(FEEDBACK, exist_ok=True)
            name = _ts().replace(":", "-") + ".json"
            tmp = os.path.join(FEEDBACK, name + ".tmp")
            with open(tmp, "w", encoding="utf-8") as f:
                json.dump(rec, f, ensure_ascii=True, indent=2)
            os.replace(tmp, os.path.join(FEEDBACK, name))
        except OSError:
            self._json(500, {"ok": False, "error": "feedback write failed"})
            return
        self._json(201, {"ok": True})

    def _dismiss(self):
        try:
            item_id = str(self._body().get("id", "")).strip()
        except Exception:
            self._json(400, {"ok": False, "error": "invalid JSON"})
            return
        if not SESSION_RE.fullmatch(item_id):
            self._json(400, {"ok": False, "error": "invalid id"})
            return
        ts = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
        with open(HANDOFFS, "a", encoding="utf-8") as f:
            f.write(f"operator-dismiss | {ts} | automation|{item_id} | item dismissed as viewed\n")
        try:
            with open(DISMISSED, encoding="utf-8") as f:
                dismissed = json.load(f).get("dismissed") or {}
        except Exception:
            dismissed = {}
        dismissed[item_id] = ts
        tmp = DISMISSED + ".tmp"
        with open(tmp, "w", encoding="utf-8") as f:
            json.dump({"dismissed": dismissed}, f, indent=2)
        os.replace(tmp, DISMISSED)
        self._json(201, {"ok": True})

    def _spawn(self):
        try:
            body = self._body()
            session = str(body.get("session", "")).strip()
            launcher = str(body.get("launcher", "")).strip()
        except Exception:
            self._json(400, {"ok": False, "error": "invalid JSON"})
            return
        if not SESSION_RE.fullmatch(session) or not SESSION_RE.fullmatch(launcher):
            self._json(400, {"ok": False, "error": "invalid session or launcher"})
            return
        templates = _launchers()
        if launcher not in templates:
            self._json(400, {"ok": False, "error": "unknown launcher"})
            return
        transcript = _transcript(session)
        if not transcript:
            self._json(400, {"ok": False, "error": "no transcript for session"})
            return
        cmd = (templates[launcher]
               .replace("{session}", session)
               .replace("{transcript}", shlex.quote(os.path.abspath(transcript))))
        try:
            subprocess.Popen(shlex.split(cmd), start_new_session=True,
                             stdin=subprocess.DEVNULL,
                             stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        except Exception:
            self._json(500, {"ok": False, "error": "spawn failed"})
            return
        self._json(201, {"ok": True, "launcher": launcher})

    def _tile(self):
        try:
            body = self._body()
            profile = str(body.get("profile", "")).strip()
            sessions = body.get("sessions")
            sessions = [str(s).strip() for s in sessions] if isinstance(sessions, list) else []
        except Exception:
            self._json(400, {"ok": False, "error": "invalid JSON"})
            return
        if (not SESSION_RE.fullmatch(profile) or not sessions
                or len(sessions) > 4 or not all(SESSION_RE.fullmatch(s) for s in sessions)):
            self._json(400, {"ok": False, "error": "invalid profile or sessions (max 4)"})
            return
        enabled, terminal, tiler, profiles = window_tile.load_tiling()
        if not enabled:
            self._json(403, {"ok": False, "error": "tiling disabled (ui-config tiling.enabled)"})
            return
        if profile not in profiles:
            self._json(400, {"ok": False, "error": "unknown profile"})
            return
        placed, skipped = [], []
        for sid in sessions:
            transcript = _transcript(sid)
            if transcript:
                placed.append({"session": sid, "transcript": transcript})
            else:
                skipped.append({"session": sid, "reason": "no transcript"})
        pairs = [(p["session"], p.pop("transcript")) for p in placed]
        try:
            tiled = window_tile.tile(pairs, profile, terminal, tiler, profiles)
        except RuntimeError as exc:  # tiler binary missing — install nothing
            self._json(500, {"ok": False, "error": str(exc)})
            return
        except Exception:
            self._json(500, {"ok": False, "error": "tile failed"})
            return
        for t in tiled:  # decorate placed rows with window + geometry
            for p in placed:
                if p["session"] == t["session"]:
                    p.update(window=t["window"], geometry=t["geometry"])
        ts = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
        with open(HANDOFFS, "a", encoding="utf-8") as f:
            f.write(f"tile | {ts} | {profile} | {', '.join(sessions)}\n")
        self._json(201, {"ok": True, "placed": placed, "skipped": skipped})

    LANE_NAME_RE = re.compile(r"[A-Za-z0-9 -]{3,64}")

    def _research_line(self):
        try:
            body = self._body()
            name = str(body.get("name", "")).strip().replace("|", "")
            intent = str(body.get("intent", "")).strip().replace("|", "")
        except Exception:
            self._json(400, {"ok": False, "error": "invalid JSON"})
            return
        if not self.LANE_NAME_RE.fullmatch(name):
            self._json(400, {"ok": False,
                             "error": "invalid lane name (3-64 chars: letters, digits, space, dash)"})
            return
        if not 3 <= len(intent) <= 500:
            self._json(400, {"ok": False, "error": "invalid intent (3-500 chars)"})
            return
        try:
            with open(BACKLOG, encoding="utf-8") as f:
                existing = f.read()
        except Exception:
            self._json(500, {"ok": False, "error": "backlog unreadable"})
            return
        for line in existing.splitlines():
            if line.startswith("## ") and (line[3:].strip() == name
                                           or line[3:].strip().startswith(name + " ")):
                self._json(400, {"ok": False, "error": "lane already exists"})
                return
        ts = _ts()
        # ponytail: split intent on the first ". " into Problem /
        # Smallest useful outcome; single-sentence intents duplicate —
        # the operator refines both at queue rotation.
        head, sep, tail = intent.partition(". ")
        problem, outcome = (intent, intent) if not sep else (head + ".", tail)
        with open(BACKLOG, "a", encoding="utf-8") as f:
            f.write("\n## %s (proposed via dashboard %s)\n\n"
                    "- **Problem:** %s\n"
                    "- **Smallest useful outcome:** %s\n"
                    "- **Status:** proposed via dashboard — awaiting queue rotation\n"
                    % (name, ts, problem, outcome))
        self._json(201, {"ok": True, "lane": name})

    def _research_note(self):
        try:
            body = self._body()
            lane = str(body.get("lane", "")).strip().replace("|", "")
            text = str(body.get("note", "")).strip().replace("|", "")
            affecting = bool(body.get("affecting", False))
        except Exception:
            self._json(400, {"ok": False, "error": "invalid JSON"})
            return
        if not lane or len(lane) > 120 or not 3 <= len(text) <= 300:
            self._json(400, {"ok": False, "error": "invalid lane or note (note 3-300 chars)"})
            return
        try:
            with open(BACKLOG, encoding="utf-8") as f:
                lines = f.read().splitlines()
        except Exception:
            self._json(500, {"ok": False, "error": "backlog unreadable"})
            return
        idx = next((i for i, l in enumerate(lines) if l.startswith("## ")
                    and (l[3:].strip() == lane or l[3:].strip().startswith(lane + " "))), None)
        if idx is None:
            self._json(400, {"ok": False, "error": "unknown lane"})
            return
        ts = _ts()
        end = next((j for j in range(idx + 1, len(lines)) if lines[j].startswith("## ")),
                   len(lines))
        lines.insert(end, "- note (%s): %s" % (ts, text))
        tmp = BACKLOG + ".tmp"
        with open(tmp, "w", encoding="utf-8") as f:
            f.write("\n".join(lines) + "\n")
        os.replace(tmp, BACKLOG)
        with open(HANDOFFS, "a", encoding="utf-8") as f:
            f.write("research-note | %s | automation|%s | %s\n" % (ts, lane, text))
        if affecting:
            # advisory steer row only — never mutates anything itself
            try:
                subprocess.run(["python3", REPORT_QUEUE, "--add", "alert",
                                "research-steer %s: %s" % (lane, text)],
                               capture_output=True, timeout=10)
            except Exception:
                self._json(500, {"ok": False, "error": "report-queue steer failed"})
                return
        self._json(201, {"ok": True, "affecting": affecting})

    def _json(self, code, obj):
        payload = json.dumps(obj).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(payload)))
        self.end_headers()
        self.wfile.write(payload)

    def log_message(self, fmt, *args):  # quiet: journal already has stderr
        pass

    def end_headers(self):
        # Live assets must never be heuristically cached: the operator's
        # browser served stale stylesheets twice on 2026-08-27.
        if self.path.endswith((".css", ".js", ".json")):
            self.send_header("Cache-Control", "no-cache")
        super().end_headers()

    def guess_type(self, path):
        # Explicit charset on everything textual: browsers sniff
        # encodings when none is declared, and a sniff can render the
        # whole page as CJK garbage (observed 2026-08-27 evening).
        ctype = super().guess_type(path)
        if ctype.startswith(("text/", "application/json")):
            ctype += "; charset=utf-8"
        return ctype


if __name__ == "__main__":
    ThreadingHTTPServer(("0.0.0.0", 8890), Handler).serve_forever()
