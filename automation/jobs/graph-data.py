#!/usr/bin/env python3
"""graph-data.py — pure builder for the dashboard /graph.json operations graph.

Reads the governed registries (config/*.tsv), live state (telemetry db,
service-state.json, reports.md) and returns {"generated_at", "nodes",
"edges"}. Node kinds: kernel, leg, service, package, seam, spawn-path,
patrol, surface, cap, guard, research-line. No governance decisions here:
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


def build(registries_dir, dashboard_dir, telemetry_db, config_env, now=None):
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
    for row in read_tsv(registries_dir / "patrol-routes.tsv"):
        pid, surface = row["patrol-id"], row["surface"]
        state = "alerting" if pid in alerting else "healthy"
        node("patrol:" + pid, "patrol", pid, state,
             "surface=%s check=%s freq=%s finding=%s%s"
             % (surface, row["check"], row["freq-tier"], row["finding-class"],
                " — FAIL reported trailing 24h" if pid in alerting else ""))
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

    return {"generated_at": now.strftime("%Y-%m-%dT%H:%M:%SZ"),
            "nodes": nodes, "edges": edges}
