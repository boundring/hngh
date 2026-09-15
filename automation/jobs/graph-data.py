#!/usr/bin/env python3
"""graph-data.py — pure builder for the dashboard /graph.json operations graph.

Reads the governed registries (config/*.tsv), live state (telemetry db,
service-state.json, reports.md), and jcode session files (~/.jcode/sessions)
and returns {"generated_at", "nodes", "edges"}. Node kinds: kernel, leg,
service, package, seam, spawn-path, patrol, surface, cap, guard,
research-line, jcode-session, swarm. No governance decisions here:
display layer only, never governance input (same rule as the KB view).
"""

import json
import re
import shutil
import sqlite3
from datetime import datetime, timedelta, timezone
from pathlib import Path

# Node states -> viewer colors (healthy/stale/alerting/neutral).
STATES = ("healthy", "stale", "alerting", "neutral")

SEAM_GUARDS = {
    "op-cli": ("lib/credentials.sh",
               ["test-credentials.py", "test-doc-secrets.py"]),
    "kimi-credential": ("config.env", ["test-credential-kimi.sh"]),
    "notify-email": ("lib/notify-email.sh",
                     ["test-notify-seam.sh", "test-notify-send-path.py",
                      "test-email-qa.py"]),
}

# launch-session.sh matrix (2026-09-06): omp sessions launch via bili MITM
# when present, else direct; ocgo delegates go through opencode-go.
SPAWN_PATHS = {
    "bctx-launch": ("lib/launch-session.sh",
                    ["unsloth", "ollama", "remote", "deck", "kimi", "zai"]),
    "direct-launch": ("lib/launch-session.sh",
                      ["unsloth", "ollama", "remote", "deck", "kimi", "zai"]),
    "ocgo-delegate": ("lib/launch-session.sh", ["ocgo", "opencode-agent"]),
}

SERVICE_UNITS = {  # registry name -> service-state.json unit prefixes
    "llamacpp": ["llama-server"],
    "unsloth-llamaserver": ["unsloth-warm", "unsloth-studio"],
    "ollama": ["ollama"],
    "comfyui": ["comfyui"],
}


def read_tsv(path, has_header=True, columns=None):
    """Rows (dicts) from a # commented, tab-separated registry file."""
    rows, header = [], None
    for line in Path(path).read_text().splitlines():
        line = line.rstrip("\n")
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        cols = line.split("\t")
        if header is None:
            header = ([c.strip() for c in cols] if has_header
                      else columns)
            if not has_header:
                row = dict(zip(header, (c.strip() for c in cols)))
                row["_line"] = line
                rows.append(row)
            continue
        row = dict(zip(header, (c.strip() for c in cols)))
        row["_line"] = line
        rows.append(row)
    return rows


def _parse_ts(text):
    try:
        return datetime.fromisoformat(text.replace("Z", "+00:00"))
    except (ValueError, AttributeError, TypeError):
        return None


def _now():
    return datetime.now(timezone.utc)


def _parse_any_ts(text):
    """ISO parse tolerant of jcode's nanosecond fractions (9 digits);
    returns None on anything unparsable (fail closed)."""
    if not isinstance(text, str):
        return None
    t = text.strip()
    m = re.match(r"^(.*T\d{2}:\d{2}:\d{2})\.(\d+)(.*)$", t)
    if m:  # truncate fraction to microseconds for fromisoformat
        t = "%s.%s%s" % (m.group(1), m.group(2)[:6], m.group(3))
    return _parse_ts(t)


def _session_status(data):
    """Status as a plain word: jcode writes strings ('Active') or
    one-key tagged dicts ({"Crashed": {...}}); anything else fails
    closed to None (non-Active)."""
    status = data.get("status")
    if isinstance(status, dict) and len(status) == 1:
        status = next(iter(status))
    return status if isinstance(status, str) else None


def _session_state(data, active_dt, now):
    """Existing 4-state vocabulary, no new colors: Active + last
    activity <=10min -> healthy; non-Active -> neutral; Active but
    >10min (or activity unparsable) -> stale."""
    if _session_status(data) != "Active":
        return "neutral"
    if active_dt is None:
        return "stale"
    age_s = (now - active_dt).total_seconds()
    return "healthy" if age_s <= 600 else "stale"


def _session_detail(data, now):
    """k=v detail string (viewer parseDetail caps at 12 pairs).
    tokens=N is reserved, not emitted, until a real source exists
    (journal/budget ledger is phase 2)."""
    parts = []
    status = _session_status(data)
    if status is not None:
        parts.append("status=%s" % status)
    for key, out in (("model", "model"), ("provider_key", "provider")):
        val = data.get(key)
        if isinstance(val, str) and val:
            parts.append("%s=%s" % (out, val))
    cwd = data.get("working_dir")
    if isinstance(cwd, str) and cwd:
        parts.append("cwd=%s" % cwd)
    updated = _parse_any_ts(data.get("updated_at")
                            or data.get("last_active_at"))
    if updated is not None:
        age_s = max(0, (now - updated).total_seconds())
        if age_s < 86400:
            parts.append("age=%dm" % int(age_s // 60))
        else:
            parts.append("age=%dh" % int(age_s // 3600))
    pid = data.get("last_pid")
    if isinstance(pid, int) or isinstance(pid, str) and pid:
        parts.append("pid=%s" % pid)
    effort = data.get("reasoning_effort")
    if isinstance(effort, str) and effort:
        parts.append("effort=%s" % effort)
    return " ".join(parts)


def _read_sessions(sessions_dir):
    """session_id -> parsed dict for session_*.json (journal logs and
    .bak copies excluded); unparsable files come back as malformed ids.
    Filename stem == session id by jcode layout, so malformed files
    still get a stable node id. Two files can carry the same internal
    id (swarm coordinator + child mapping to one run): the first file
    (sorted order) wins the id, later files come back as shadowed
    (stem, id) pairs so the emitter surfaces them instead of silently
    overwriting one node's detail with the other's."""
    raw, malformed, shadowed = {}, [], []
    for path in sorted(Path(sessions_dir).glob("session_*.json")):
        name = path.name
        if name.endswith(".journal.jsonl") or name.endswith(".bak"):
            continue  # belt-and-braces; the glob already excludes these
        try:
            data = json.loads(path.read_text(encoding="utf-8"))
        except (OSError, ValueError, UnicodeDecodeError):
            malformed.append(path.stem)
            continue
        sid = data.get("id") if isinstance(data, dict) else None
        if not isinstance(sid, str) or not sid:
            malformed.append(path.stem)  # fail closed: no id, no node
            continue
        if sid in raw:
            if path.stem != sid:
                shadowed.append((path.stem, sid))
            else:
                shadowed.append((path.stem + "#dup", sid))
            continue
        raw[sid] = data
    return raw, malformed, shadowed


def _emit_sessions(nodes, edges, raw, malformed, repo_root, now,
                   all_sessions, shadowed=()):
    """jcode-session + swarm nodes/edges. Default scale filter: only
    sessions active within 24h plus the parent chain needed to anchor
    spawns edges; all_sessions=True lifts the filter. Malformed files
    always surface as alerting nodes (never hidden by the filter).
    Shadowed files (same internal id as an earlier file, e.g. swarm
    coordinator + child mapping to one run) surface as alerting nodes
    under their own filename stem; self-loop spawns edges are skipped
    so a session never spawns itself. Node ids are unique by
    construction: malformed stems colliding with a live id get a
    -malformed suffix."""
    active = {}
    cutoff = now - timedelta(hours=24)
    for sid, data in raw.items():
        dt = _parse_any_ts(data.get("last_active_at"))
        if dt is not None and dt >= cutoff:
            active[sid] = data
    emitted = dict(raw) if all_sessions else dict(active)
    if not all_sessions:
        # parent-linked closure, both directions, transitively: an
        # emitted session keeps its coordinator (spawns anchor) and its
        # subagents (hosts edges), so swarm groups never draw half-drawn
        children = {}
        for sid, data in raw.items():
            pid = data.get("parent_id")
            if isinstance(pid, str):
                children.setdefault(pid, []).append(sid)
        queue = list(emitted)
        while queue:
            sid = queue.pop()
            pid = raw[sid].get("parent_id")
            if isinstance(pid, str) and pid in raw and pid not in emitted:
                emitted[pid] = raw[pid]
                queue.append(pid)
            for cid in children.get(sid, ()):
                if cid not in emitted:
                    emitted[cid] = raw[cid]
                    queue.append(cid)

    def label_of(data):
        name = data.get("short_name")
        if isinstance(name, str) and name:
            return name
        return (data.get("id") or "")[:12]  # truncated id fallback

    for sid, data in sorted(emitted.items()):
        active_dt = _parse_any_ts(data.get("last_active_at"))
        state = _session_state(data, active_dt, now)
        nodes.append({"id": "jcode:" + sid, "kind": "jcode-session",
                      "label": label_of(data), "state": state,
                      "detail": _session_detail(data, now)})

    # spawn edges only when both endpoints are emitted (no danglers,
    # no self-loops: a coordinator and child sharing one run id must
    # never draw a spawns edge to itself)
    for sid, data in sorted(emitted.items()):
        pid = data.get("parent_id")
        if isinstance(pid, str) and pid in emitted and pid != sid:
            edges.append({"src": "jcode:" + pid, "dst": "jcode:" + sid,
                          "rel": "spawns"})

    # swarm hubs: one per coordinator holding >=1 emitted subagent
    for pid in sorted({d.get("parent_id") for d in emitted.values()
                       if isinstance(d.get("parent_id"), str)
                       and d.get("parent_id") in emitted}):
        subs = [s for s, d in emitted.items()
                if d.get("parent_id") == pid]
        hub = "swarm:" + pid
        nodes.append({"id": hub, "kind": "swarm",
                      "label": label_of(emitted[pid]), "state": "neutral",
                      "detail": "sessions=%d" % len(subs)})
        edges.append({"src": hub, "dst": "jcode:" + pid,
                      "rel": "coordinates"})
        for sid in sorted(subs):
            edges.append({"src": hub, "dst": "jcode:" + sid, "rel": "hosts"})

    # works-on: emitted session whose working_dir sits inside this repo
    try:
        repo_res = Path(repo_root).resolve()
    except OSError:
        repo_res = None
    for sid, data in sorted(emitted.items()):
        cwd = data.get("working_dir")
        if not isinstance(cwd, str) or not cwd or repo_res is None:
            continue
        try:
            cwd_res = Path(cwd).expanduser().resolve()
        except OSError:
            continue
        if cwd_res == repo_res or repo_res in cwd_res.parents:
            edges.append({"src": "jcode:" + sid, "dst": "kernel",
                          "rel": "works-on"})

    seen = {n["id"] for n in nodes}
    for stem, sid in sorted(shadowed):
        nid = "jcode:" + stem
        if nid in seen:  # same stem twice (or stem == live id twice)
            k = 2
            while "jcode:%s#%d" % (stem, k) in seen:
                k += 1
            nid = "jcode:%s#%d" % (stem, k)
        seen.add(nid)
        nodes.append({"id": nid, "kind": "jcode-session",
                      "label": stem[:12], "state": "alerting",
                      "detail": "duplicate session file shadows id %s" % sid})

    for sid in sorted(malformed):
        nid = "jcode:" + sid
        if nid in seen:  # malformed stem collides with a live node id
            nid += "-malformed"
            k = 2
            while nid in seen:
                nid = "jcode:%s-malformed%d" % (sid, k)
                k += 1
        seen.add(nid)
        nodes.append({"id": nid, "kind": "jcode-session",
                      "label": sid[:12], "state": "alerting",
                      "detail": "malformed session file (json unparsable)"})


def leg_states(telemetry_db, now=None):
    """model -> (state, last_seen_iso, events_24h) from telemetry events."""
    now = now or _now()
    per_model = {}
    try:
        db = sqlite3.connect("file:%s?mode=ro" % telemetry_db, uri=True)
        try:
            rows = db.execute(
                "select ts, model from events"
                " where model != '' and ts >= ?",
                ((now - timedelta(hours=24)).strftime("%Y-%m-%dT%H:%M:%SZ"),),
            ).fetchall()
        finally:
            db.close()
    except sqlite3.Error:
        rows = []
    for ts, model in rows:
        seen = per_model.setdefault(model, {"n": 0, "last": None})
        seen["n"] += 1
        if seen["last"] is None or ts > seen["last"]:
            seen["last"] = ts
    return {model: {"n": v["n"], "last": v["last"]} for model, v in per_model.items()}


def _leg_of_model(model):
    """Map a telemetry model string to a registry leg name, or None."""
    for leg in ("kimi", "deck", "ocgo", "opencode-agent"):
        if model.startswith(leg + ":"):
            return leg
    if model.startswith("opencode-go/"):
        return "ocgo"
    if model.startswith("z-ai/"):
        return "zai"
    head = model.split("/", 1)[0]
    return head if head else None


def _live_by_leg(live):
    """Aggregate telemetry per-model info into per-leg info."""
    per_leg = {}
    for model, info in live.items():
        leg = _leg_of_model(model)
        if not leg:
            continue
        cur = per_leg.setdefault(leg, {"n": 0, "last": None})
        cur["n"] += info["n"]
        if cur["last"] is None or (info["last"] or "") > cur["last"]:
            cur["last"] = info["last"]
    return per_leg


def _leg_state(model, live, now):
    info = live.get(model)
    if not info:
        return "neutral", "", 0
    last_dt = _parse_ts(info["last"])
    age_h = ((now - last_dt).total_seconds() / 3600.0) if last_dt else 999.0
    state = "healthy" if age_h <= 2.0 else "stale"
    return state, "last %s" % info["last"], info["n"]


def build(registries_dir, dashboard_dir, telemetry_db, config_env, now=None,
          sessions_dir=None, all_sessions=False):
    now = now or _now()
    registries_dir, dashboard_dir = Path(registries_dir), Path(dashboard_dir)
    nodes, edges = [], []
    live = _live_by_leg(leg_states(telemetry_db, now))

    def node(nid, kind, label, state, detail):
        nodes.append({"id": nid, "kind": kind, "label": label,
                      "state": state, "detail": detail})

    def edge(src, dst, rel):
        edges.append({"src": src, "dst": dst, "rel": rel})

    node("kernel", "kernel", "hngh kernel", "healthy",
         "docs/design/governed-fleet.md — one pattern: registry, guard, patrol")

    # --- legs + pacing caps (leg-budgets.tsv, cadence-params.tsv) ---
    cadence_path = registries_dir.parent / "cadence-params.tsv"
    cadence_keys = {r["key"] for r in read_tsv(cadence_path, has_header=False,
                                               columns=["key", "value",
                                                        "provenance", "note"])} \
        if cadence_path.exists() else set()
    env_text = ""
    if config_env and Path(config_env).exists():
        env_text = Path(config_env).read_text()
    cap_declared = {}  # cap-name -> declared-in text
    for row in read_tsv(registries_dir / "leg-budgets.tsv", has_header=False,
                        columns=["leg", "max-time-s", "max-output",
                                 "binding-edge", "source-file"]):
        leg = row["leg"]
        detail = ("max-time=%ss max-output=%s binding=%s source=%s"
                  % (row["max-time-s"], row["max-output"],
                     row["binding-edge"], row["source-file"]))
        state, live_note, n24 = _leg_state(leg, live, now)
        if live_note:
            detail += " | %s (%d events/24h)" % (live_note, n24)
        node("leg:" + leg, "leg", leg, state, detail)
        edge("kernel", "leg:" + leg, "chain-admits")
        for m in re.finditer(r"(?i)[a-z0-9_-]*cap[a-z0-9_-]*",
                             row["_line"]):
            name = m.group(0)
            if name.lower() in ("cap", "caps") or name in cap_declared:
                continue
            vm = re.search(re.escape(name) + r"\s*[=: ]\s*([^\s,)]+)",
                           row["_line"])
            decl = vm.group(1) if vm and any(c.isdigit() for c in vm.group(1)) \
                else "see cadence-params"
            cap_declared[name] = decl
    for cap, decl in sorted(cap_declared.items()):
        ok = (cap in cadence_keys
              or (cap == "REMOTE_DAILY_CAP_CALLS" and cap in env_text))
        node("cap:" + cap, "cap", cap,
             "healthy" if ok else "alerting",
             ("cadence-params: %s" % decl) if ok else
             "declared %s but missing from cadence-params.tsv" % decl)
        edges.append({"src": "cap:" + cap, "dst": "kernel", "rel": "bounded-by"})

    # --- services (hngh-services.tsv + service-state.json) ---
    svc_state = {}
    sspath = dashboard_dir / "service-state.json"
    if sspath.exists():
        try:
            svc_state = {u.get("unit", "").removesuffix(".service"): u
                         for u in json.loads(sspath.read_text()).get("units", [])
                         if isinstance(u, dict)}
        except (ValueError, OSError):
            svc_state = {}
    for row in read_tsv(registries_dir / "hngh-services.tsv"):
        name, url = row["service"], row["health-url"]
        state, note = "neutral", "declared, no live unit match"
        for prefix in SERVICE_UNITS.get(name, []):
            unit = svc_state.get(prefix)
            if unit is not None:
                active = bool(unit.get("active"))
                state = "healthy" if active else "alerting"
                note = "%s.service %s" % (prefix, "active" if active else "inactive")
                break
        node("service:" + name, "service", name, state,
             "role=%s health=%s managed-by=%s (%s)"
             % (row["role"], url or "none", row["managed-by"], note))
        edge("kernel", "service:" + name, "runs")
        edge("service:" + name, "patrol:service-children", "watched-by")

    # --- packages (hngh-packages.tsv; ghost-row check mirrors the guard) ---
    for row in read_tsv(registries_dir / "hngh-packages.tsv"):
        name, disp, ipath = row["package"], row["disposition"], row["install-path"]
        state, note = "neutral", "disposition=%s" % disp
        if disp == "in-use" and not ipath.startswith("none-"):
            target = ipath.split()[0] if ipath.strip() else ""
            target = str(Path(target).expanduser()) if target.startswith("~") else target
            found = bool(target) and (Path(target).exists() or shutil.which(target))
            state = "healthy" if found else "alerting"
            note += " install-path=%s %s" % (target or "none",
                                             "resolves" if found else "GHOST")
        node("package:" + name, "package", name, state, note)
        edge("package:" + name, "guard:test-hngh-packages.py", "ghost-row-guard")

    # --- credential seams -> fail-soft guards ---
    guard_nodes = {"test-hngh-packages.py"}
    for seam, (seam_file, guards) in SEAM_GUARDS.items():
        node("seam:" + seam, "seam", seam, "healthy",
             "token-only fail-soft seam at %s" % seam_file)
        edge("kernel", "seam:" + seam, "credential-seam")
        for guard in guards:
            guard_nodes.add(guard)
            edge("seam:" + seam, "guard:" + guard, "fail-soft-guard")

    # --- spawn paths -> legs (launch-session.sh compression matrix) ---
    for spawn, (src_file, legs) in SPAWN_PATHS.items():
        node("spawn:" + spawn, "spawn-path", spawn, "neutral",
             "launch path in %s" % src_file)
        edge("kernel", "spawn:" + spawn, "launches-through")
        for leg in legs:
            edge("spawn:" + spawn, "leg:" + leg, "drives-leg")

    # --- guard nodes (real files under automation/tests/) ---
    tests_dir = registries_dir.parent / "tests"
    for guard in sorted(guard_nodes):
        exists = (tests_dir / guard).exists()
        node("guard:" + guard, "guard", guard,
             "healthy" if exists else "alerting",
             ("automation/tests/%s%s" % (guard, "" if exists else " MISSING")))

    # --- patrols + surfaces (patrol-routes.tsv + reports.md alerts) ---
    alerting = set()
    reports = dashboard_dir / "reports.md"
    if reports.exists():
        cutoff = (now - timedelta(hours=24)).strftime("%Y-%m-%dT%H:%M:%SZ")
        for line in reports.read_text().splitlines():
            if not line.startswith("|"):
                continue
            cols = [c.strip() for c in line.split("|")]
            if len(cols) >= 4 and cols[1] >= cutoff and cols[3].startswith("patrol:"):
                alerting.add(cols[3].split(":", 1)[1])
    seen_surfaces = set()  # surfaces repeat across patrol rows (e.g.
    # kernel-gate and services are each walked by two patrols); the
    # surface node is emitted once while every patrol keeps its own
    # watches edge, so node ids stay unique and edges stay N:1.
    for row in read_tsv(registries_dir / "patrol-routes.tsv"):
        pid, surface = row["patrol-id"], row["surface"]
        state = "alerting" if pid in alerting else "healthy"
        node("patrol:" + pid, "patrol", pid, state,
             "surface=%s check=%s freq=%s finding=%s%s"
             % (surface, row["check"], row["freq-tier"], row["finding-class"],
                " — FAIL reported trailing 24h" if pid in alerting else ""))
        if surface not in seen_surfaces:
            seen_surfaces.add(surface)
            node("surface:" + surface, "surface", surface, "neutral",
                 "patrolled surface %s" % surface)
        edge("patrol:" + pid, "surface:" + surface, "watches")

    # --- research lines (research-lines.tsv) ---
    for row in read_tsv(registries_dir.parent / "research-lines.tsv",
                        has_header=False,
                        columns=["id", "status", "timestamp", "title"]):
        rid = row["id"]
        node("research:" + rid, "research-line", rid, "neutral",
             "status=%s ts=%s title=%s" % (row["status"], row["timestamp"],
                                           row["title"]))
        edge("research:" + rid, "kernel", "research-beat")

    # --- jcode sessions + swarm hubs (~/.jcode/sessions) ---
    if sessions_dir is None:
        sessions_dir = Path.home() / ".jcode" / "sessions"
    if Path(sessions_dir).is_dir():
        raw, malformed, shadowed = _read_sessions(sessions_dir)
        # resolve() first: a relative registries_dir ('config') must not
        # collapse to '.' when walking to the hngh repo root
        _emit_sessions(nodes, edges, raw, malformed,
                       registries_dir.resolve().parent.parent, now,
                       all_sessions, shadowed)

    return {"generated_at": now.strftime("%Y-%m-%dT%H:%M:%SZ"),
            "nodes": nodes, "edges": edges}
