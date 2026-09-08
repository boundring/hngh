#!/usr/bin/env python3
"""sessions-feed — build dashboard/sessions.json for the live session
observatory: the roster rows from readout.json enriched with parsed
conversation ENTRIES from the session's omp transcript when one resolves
(~/.omp/agent/sessions/<project>/…, matched to the roster run's start time;
per-agent jsonl files included), falling back to the store's record.lisp
receipt tail (last TAIL_LINES lines, located by roster source, same scan
rules as hngh scripts/dashboard-readout). Recent omp transcripts with no
roster row are appended so the observatory shows live sessions growing —
acp-omp-folds carry context folds, not transcripts; the jsonl itself is
the live record. Credential-shaped content is redacted (same regex spirit
as hngh scripts/verify-candidate.py CREDENTIAL_PATTERN).

Fail-closed: per-session enrichment failure degrades that row (entries:[]
+ reason, or detail:null for the receipt tail); a missing readout.json
leaves any prior sessions.json untouched. Display layer only — this feed
never feeds governance input.
"""
import glob
import hashlib
import json
import os
import re
import time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
READOUT = os.path.join(ROOT, "dashboard", "readout.json")
OUT = os.path.join(ROOT, "dashboard", "sessions.json")
STORE_ROOT = os.path.join(os.path.expanduser("~"), ".hngh-automation", "store")
BRIDGE_STORE = os.environ.get(
    "OMP_BRIDGE_STORE",
    os.path.join(os.path.dirname(os.path.abspath(__file__)),
                 "..", "bridge"))
TAIL_LINES = 80

# omp transcript discovery — tail-read only: entries come from the end, and
# 24h of jsonl across all projects can be tens of MB.
OMP_SESSIONS = os.path.join(os.path.expanduser("~"), ".omp", "agent", "sessions")
OMP_WINDOW_S = 24 * 3600
OMP_MAX_SESSIONS = 24
OMP_TAIL_BYTES = 512 * 1024
OMP_HEAD_BYTES = 64 * 1024  # head must clear the session_init system prompt
ROSTER_MATCH_WINDOW_S = 1200  # run start vs transcript session-start skew
LIVE_S = 300                  # mtime younger than this => state "live"

ENTRY_CAP = 400               # last N entries per session
ENTRY_BUDGET = 196608         # ~192KB of entry text per session
TEXT_CAP = {"message": 8000, "thinking": 4000, "tool_call": 4000,
            "tool_result": 4000, "system": 500}

# same spirit as hngh scripts/verify-candidate.py CREDENTIAL_PATTERN
CREDENTIAL_RE = re.compile(
    r"(?i)(api[_-]?key|secret|token|password)\s*[:=]\s*['\"]?[A-Za-z0-9_\-]{8,}"
)

# (source, roots) — mirrors _roster_sources() in dashboard-readout
SOURCES = (
    ("automation", [STORE_ROOT]),
    ("bridge", [BRIDGE_STORE]),
    ("heartbeat", sorted(glob.glob("/tmp/hngh-heartbeat-*"))),
    ("auto", sorted(glob.glob("/tmp/hngh-auto-*"))),
)


def find_transcript(source, sid):
    """Path to the session's record.lisp, or None. A source root may itself
    be a store (its basename == the row id) or hold <sid>/record.lisp."""
    for src, roots in SOURCES:
        if src != source:
            continue
        for root in roots:
            rec = os.path.join(root, "record.lisp")
            if os.path.basename(root) == sid and os.path.isfile(rec):
                return rec
            rec = os.path.join(root, sid, "record.lisp")
            if os.path.isfile(rec):
                return rec
    return None


def transcript_tail(path):
    """(tail_text, truncated) — last TAIL_LINES lines, redacted."""
    with open(path, encoding="utf-8", errors="replace") as f:
        lines = f.read().splitlines()
    tail = [CREDENTIAL_RE.sub(lambda m: m.group(1) + "=<redacted>", ln)
            for ln in lines[-TAIL_LINES:]]
    return "\n".join(tail), len(lines) > TAIL_LINES


# ---------------------------------------------------------------- omp side

def _clip(text, kind):
    """(redacted text, truncated) capped per entry kind."""
    text = text or ""
    truncated = len(text) > TEXT_CAP.get(kind, 8000)
    if truncated:
        text = text[:TEXT_CAP[kind]]
    text = CREDENTIAL_RE.sub(lambda m: m.group(1) + "=<redacted>", text)
    return text, truncated


def _parts_text(content):
    """Concatenate text parts; images noted, other part types skipped."""
    out = []
    for part in content or []:
        if not isinstance(part, dict):
            continue
        if part.get("type") == "text":
            out.append(part.get("text") or "")
        elif part.get("type") == "image":
            out.append("[image omitted]")
    return "\n".join(t for t in out if t)


def _read_window(path):
    """Full text of small jsonl files, else head+tail edges only (entries
    come from the end; the head carries the session/mission line)."""
    size = os.path.getsize(path)
    with open(path, "rb") as f:
        head = f.read(OMP_HEAD_BYTES)
        if size > OMP_TAIL_BYTES:
            f.seek(-OMP_TAIL_BYTES, os.SEEK_END)
            tail = f.read()
            tail = tail[tail.find(b"\n") + 1:]  # drop the partial line
        else:
            f.seek(len(head))
            tail = f.read()
    return head + tail


def parse_omp_entries(path):
    """Parse an omp session transcript into feed entries. Fail-closed:
    returns (None, reason) instead of raising."""
    counts = {"total": 0, "user": 0, "assistant": 0, "thinking": 0,
              "tool_call": 0, "tool_result": 0}
    try:
        blob = _read_window(path).decode("utf-8", errors="replace")
    except OSError as e:
        return None, "unreadable: %s" % e.strerror

    def entry(role, kind, text, ts, tool=None, call_id=None):
        text, truncated = _clip(text, kind)
        e = {"ts": ts, "role": role, "kind": kind, "text": text,
             "truncated": truncated}
        if tool:
            e["tool"] = tool
        if call_id:
            e["call_id"] = call_id
        return e

    entries, dropped = [], 0
    deferred = {}          # toolCallId -> assistant toolCall part (args)
    call_entry = {}        # toolCallId -> emitted tool_call entry (merge tgt)
    for ln in blob.splitlines():
        ln = ln.strip()
        if not ln:
            continue
        try:
            ev = json.loads(ln)
        except ValueError:
            dropped += 1
            continue
        if not isinstance(ev, dict):
            continue
        ts = ev.get("timestamp") or ""
        typ = ev.get("type")

        def fenced(text):
            return "code" if re.match(r"```\w*\n", text) and \
                text.count("```") == 2 else None

        if typ == "message":
            msg = ev.get("message") or {}
            role, content = msg.get("role"), msg.get("content")
            if role == "user":
                text = _parts_text(content)
                if text:
                    counts["total"] += 1
                    counts["user"] += 1
                    entries.append(entry("user", fenced(text) or "message",
                                         text, ts))
            elif role in ("assistant", "developer"):
                for part in content or []:
                    if not isinstance(part, dict):
                        continue
                    pt = part.get("type")
                    if pt == "thinking":
                        counts["total"] += 1
                        counts["thinking"] += 1
                        entries.append(entry("thinking", "thinking",
                                             part.get("thinking") or "", ts))
                    elif pt == "toolCall":
                        call_id = part.get("id") or ""
                        deferred[call_id] = part
                        try:
                            args = json.dumps(part.get("arguments") or {},
                                              ensure_ascii=False)
                        except (TypeError, ValueError):
                            args = str(part.get("arguments"))
                        if call_id and call_id in call_entry:
                            continue  # runtime event already emitted it
                        counts["total"] += 1
                        counts["tool_call"] += 1
                        call_entry[call_id] = entry(
                            "tool", "tool_call", args, ts,
                            tool=part.get("name") or "?", call_id=call_id)
                        entries.append(call_entry[call_id])
                    elif pt == "text":
                        text = part.get("text") or ""
                        if text:
                            counts["total"] += 1
                            counts["assistant"] += 1
                            entries.append(entry(
                                "assistant", fenced(text) or "message",
                                text, ts))
            elif role == "toolResult":
                counts["total"] += 1
                counts["tool_result"] += 1
                entries.append(entry("tool", "tool_result",
                                     _parts_text(content), ts,
                                     tool=msg.get("toolName") or "?",
                                     call_id=msg.get("toolCallId") or ""))
        elif typ == "custom" and ev.get("customType") == "tool_execution_start":
            data = ev.get("data") or {}
            call_id = data.get("toolCallId") or ""
            args = data.get("args")
            if args is None:
                args = (deferred.get(call_id) or {}).get("arguments")
            if args is None:
                args = {"intent": data.get("intent")}
            try:
                args = json.dumps(args, ensure_ascii=False)
            except (TypeError, ValueError):
                args = str(args)
            if call_id and call_id in call_entry:
                tgt = call_entry[call_id]  # enrich the part-emitted entry
                if data.get("args") is not None:
                    tgt["text"], tgt["truncated"] = _clip(args, "tool_call")
                continue
            counts["total"] += 1
            counts["tool_call"] += 1
            new = entry("tool", "tool_call", args, ts,
                        tool=data.get("toolName") or "?", call_id=call_id)
            call_entry[call_id] = new
            entries.append(new)
    if dropped > 5 and not entries:
        return None, "%d unparseable lines" % dropped
    shown = entries[-ENTRY_CAP:]
    budget = ENTRY_BUDGET  # keep the newest entries, shed from the front
    for e in reversed(shown):
        budget -= len(e.get("text", ""))
        if budget < 0:
            shown = shown[shown.index(e) + 1:]
            break
    meta = dict(counts)
    meta["shown"] = len(shown)
    return {"entries": shown, "counts": meta}, None


def _iso_ts(s):
    """Local epoch seconds from an omp ISO timestamp, or None."""
    try:
        return time.mktime(time.strptime(s[:19], "%Y-%m-%dT%H:%M:%S"))
    except (ValueError, TypeError):
        return None


def omp_candidates(now):
    """Recent omp transcripts (main sessions + per-agent jsonl), newest
    activity first, capped. Each: {path, start, mtime, stem, first_user}."""
    out = []
    for path in glob.glob(os.path.join(OMP_SESSIONS, "*", "*.jsonl")) + \
            glob.glob(os.path.join(OMP_SESSIONS, "*", "*", "*.jsonl")):
        try:
            mtime = os.path.getmtime(path)
        except OSError:
            continue
        if now - mtime > OMP_WINDOW_S:
            continue
        start, first_user = None, ""
        try:
            with open(path, "rb") as f:
                head = f.read(OMP_HEAD_BYTES).decode("utf-8", errors="replace")
            for ln in head.splitlines():
                if start is None and ln.startswith('{"type":"session"'):
                    try:
                        start = _iso_ts(json.loads(ln).get("timestamp"))
                    except ValueError:
                        pass
                elif not first_user and '"role":"user"' in ln:
                    try:
                        msg = json.loads(ln).get("message") or {}
                        first_user = _parts_text(msg.get("content"))[:160]
                    except ValueError:
                        pass
        except OSError:
            continue
        project = os.path.relpath(path, OMP_SESSIONS).split(os.sep)[0]
        out.append({"path": path, "start": start, "mtime": mtime,
                    "stem": os.path.splitext(os.path.basename(path))[0],
                    "project": project.lstrip("-")[:40],
                    "first_user": first_user})
    out.sort(key=lambda c: c["mtime"], reverse=True)
    return out[:OMP_MAX_SESSIONS]


def omp_row_id(cand):
    digest = hashlib.md5(cand["path"].encode()).hexdigest()[:6]
    base = re.sub(r"[^A-Za-z0-9_-]", "", cand["stem"])[:28] or digest
    return "omp-%s-%s" % (base, digest)


def omp_mission(cand):
    """Human label: per-agent files carry the agent name as the stem; main
    transcripts use their first user message."""
    label = re.sub(r"\s+", " ", cand["first_user"] or cand["stem"]).strip()
    return label[:110]


def clip_title(text, n=48):
    """Sidebar display title: one line, cut at a word boundary + ellipsis
    (never mid-word). Full text rides alongside as title_full."""
    s = re.sub(r"\s+", " ", str(text or "")).strip()
    if len(s) <= n:
        return s
    cut = s[:n - 1]
    sp = cut.rfind(" ")
    if sp >= n // 2:
        cut = cut[:sp]
    return cut.rstrip(" ,.;:-") + "…"


def title_for(row, cand_by_path):
    """(title, title_full) for a row: mission text first, else the matched
    omp transcript's first-user snippet, else '' (view falls back to the
    short id)."""
    full = re.sub(r"\s+", " ", str(row.get("mission") or "")).strip()
    if not full:
        cand = cand_by_path.get((row.get("detail") or {}).get("transcript"))
        full = omp_mission(cand) if cand else ""
    return clip_title(full), full


def run_start_ts(run_id):
    try:
        m = re.match(r"run-(\d{8}T\d{6})Z", str(run_id))
        if not m:
            return None
        return time.mktime(time.strptime(m.group(1), "%Y%m%dT%H%M%S"))
    except ValueError:
        return None


def enrich(row, cands):
    """Add detail to a roster row: parsed omp entries when a transcript's
    session start matches this run's start AND its first user message
    corroborates the run's mission (time alone false-positives: hourly
    shell jobs collide with any agent that happens to start nearby), else
    the record.lisp tail."""
    sid, source = row.get("id", ""), row.get("source", "")
    fallback_reason = "no omp transcript within match window"
    try:
        start = run_start_ts(sid)
        cand = None
        if start is not None:
            want = re.findall(r"[a-z]{4,}", str(row.get("mission", "")).lower())
            best = None
            for c in cands:
                if c["start"] is None:
                    continue
                hay = (c["first_user"] or "").lower()
                if sum(w in hay for w in want) < min(2, len(want)):
                    continue
                skew = abs(c["start"] - start)
                if skew <= ROSTER_MATCH_WINDOW_S and \
                        (best is None or skew < best[0]):
                    best = (skew, c)
            cand = best[1] if best else None
        if cand:
            parsed, reason = parse_omp_entries(cand["path"])
            if parsed:
                parsed["transcript"] = cand["path"]
                return parsed
            fallback_reason = "omp transcript %s" % (reason or "unparseable")
        path = find_transcript(source, sid)
        if not path:
            return {"transcript": None, "tail": None, "truncated": False,
                    "entries": [], "counts": {"shown": 0},
                    "reason": fallback_reason + "; no store receipt either"}
        tail, truncated = transcript_tail(path)
        return {"transcript": path, "tail": tail, "truncated": truncated,
                "entries": [], "counts": {"shown": 0}, "reason":
                fallback_reason + "; receipt tail only"}
    except Exception as e:
        return {"transcript": None, "tail": None, "truncated": False,
                "entries": [], "counts": {"shown": 0},
                "reason": "enrichment failed: %s" % type(e).__name__}


def bridge_rows(store_root):
    """Bridge-store runs (omp-bridge --run-start/--run-end) become rows:
    one run per bridge store record.lisp, state from its newest line.
    Non-terminal kernel states render as the observatory's working state
    (bridge runs never enter :running); terminal states pass through."""
    rows = []
    rec = os.path.join(store_root, "record.lisp")
    if not os.path.isfile(rec):
        return rows
    identifier, objective, state = None, "", None
    created = None
    for line in open(rec, encoding="utf-8", errors="replace"):
        m = re.search(r':IDENTIFIER "([^"]+)"', line)
        if m:
            identifier = m.group(1)
        m = re.search(r':OBJECTIVE "([^"]*)"', line)
        if m:
            objective = m.group(1)
        m = re.search(r':STATE :(\w+)', line)
        if m:
            state = m.group(1).lower()
        if state in ("created", "admitted", "armed"):
            state = "working"
        m = re.search(r'timestamp: (\S+)', line)
        if m:
            created = created or m.group(1)
    if identifier and state:
        rows.append({
            "id": identifier,
            "state": state,
            "age": None,
            "last_active_age": None,
            "mission": objective,
            "source": "bridge",
            "detail": {
                "transcript": rec,
                "tail": transcript_tail(rec)[0],
                "truncated": False,
                "entries": [],
                "counts": {"shown": 0},
                "reason": "hngh run ledger (receipts)",
            },
        })
    return rows


def main():
    try:
        with open(READOUT, encoding="utf-8") as f:
            roster = json.load(f).get("roster") or []
        if not isinstance(roster, list):
            roster = []
    except Exception:
        return  # missing/broken readout: keep the prior sessions.json
    now = time.time()
    cands = omp_candidates(now)
    cand_by_path = {c["path"]: c for c in cands}
    rows = [dict(r) for r in roster if isinstance(r, dict)]
    for row in rows:
        row["detail"] = enrich(row, cands)
    rows.extend(bridge_rows(BRIDGE_STORE))
    # unmatched omp transcripts become rows too — live sessions grow here
    matched = {r["detail"].get("transcript") for r in rows
               if isinstance(r.get("detail"), dict)}
    for cand in cands:
        if cand["path"] in matched:
            continue
        parsed, reason = parse_omp_entries(cand["path"])
        detail = parsed or {"entries": [], "counts": {"shown": 0},
                            "reason": reason or "unparseable"}
        detail["transcript"] = cand["path"]
        rows.append({
            "id": omp_row_id(cand),
            "state": "live" if now - cand["mtime"] < LIVE_S else "complete",
            "age": max(0, int(now - cand["start"])) if cand["start"] else None,
            "last_active_age": max(0, int(now - cand["mtime"])),
            "mission": omp_mission(cand),
            "source": "omp/" + cand["project"],
            "detail": detail,
        })
    feed = {
        "generated": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        "sessions": rows,
    }
    for row in rows:
        row["title"], row["title_full"] = title_for(row, cand_by_path)
    # per-PID tmp: the 1m drop-in and refresh-dashboard.sh run this
    # concurrently (daily 11:30Z overlap); a shared tmp interleaves two
    # multi-MB dumps into one corrupt sessions.json
    tmp = "%s.%d.tmp" % (OUT, os.getpid())
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(feed, f, indent=2)
    os.replace(tmp, OUT)


if __name__ == "__main__":
    if len(os.sys.argv) > 1 and os.sys.argv[1] == "--selfcheck":
        import tempfile
        ev = [
            '{"type":"session","version":3,"id":"s1","timestamp":"2026-08-27T12:00:00.000Z","cwd":"/x"}',
            '{"type":"message","id":"a","timestamp":"2026-08-27T12:00:01.000Z","message":{"role":"user","content":[{"type":"text","text":"fix the thing"}]}}',
            '{"type":"message","id":"b","timestamp":"2026-08-27T12:00:02.000Z","message":{"role":"assistant","content":[{"type":"thinking","thinking":"plan it"},{"type":"toolCall","id":"c1","name":"edit","arguments":{"path":"/x"}}]}}',
            '{"type":"custom","customType":"tool_execution_start","data":{"toolCallId":"c1","toolName":"edit","startedAt":"2026-08-27T12:00:03.000Z","args":{"path":"/x"}},"timestamp":"2026-08-27T12:00:03.000Z"}',
            '{"type":"message","id":"c","timestamp":"2026-08-27T12:00:04.000Z","message":{"role":"toolResult","toolCallId":"c1","toolName":"edit","content":[{"type":"text","text":"done"}]}}',
            '{"type":"message","id":"d","timestamp":"2026-08-27T12:00:05.000Z","message":{"role":"user","content":[{"type":"text","text":"api_key=supersecret12345 ok?"}]}}',
            'not json at all',
        ]
        with tempfile.NamedTemporaryFile("w", suffix=".jsonl", delete=False) as f:
            f.write("\n".join(ev) + "\n")
            tmp = f.name
        parsed, reason = parse_omp_entries(tmp)
        os.unlink(tmp)
        assert reason is None, reason
        c = parsed["counts"]
        assert (c["user"], c["assistant"], c["thinking"], c["tool_call"],
                c["tool_result"]) == (2, 0, 1, 1, 1), c
        assert parsed["entries"][-1]["text"] == "api_key=<redacted> ok?"
        assert any(e["kind"] == "tool_call" and e["tool"] == "edit"
                   for e in parsed["entries"])
        assert clip_title("short enough") == "short enough"
        t = clip_title("fix the gantt bar rendering that overflows the "
                       "viewport edge tonight")
        assert t.endswith("…") and not t.endswith(" …") and len(t) <= 48, t
        with tempfile.TemporaryDirectory() as bd:
            rec = os.path.join(bd, "record.lisp")
            with open(rec, "w") as f:
                f.write('(:IDENTIFIER "run-1" :KIND :CREATION :STATE :CREATED '
                        ':RUN (:IDENTIFIER "run-1" :MISSION (:OBJECTIVE '
                        '"witness wrap") :STATE :CREATED))\n')
            brows = bridge_rows(bd)
            assert len(brows) == 1 and brows[0]["state"] == "working", brows
            assert brows[0]["mission"] == "witness wrap"
            with open(rec, "a") as f:
                f.write('(:IDENTIFIER "run-1" :KIND :CLOSING :STATE :DEAD '
                        ':RECEIPT (:KIND :CLOSING))\n')
            brows = bridge_rows(bd)
            assert len(brows) == 1 and brows[0]["state"] == "dead", brows
        print("selfcheck ok:", c)
    else:
        main()
