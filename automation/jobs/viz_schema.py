#!/usr/bin/env python3
"""viz_schema.py — shared validation seam for the dashboard viz payloads.

One stdlib-only validator (no jsonschema; no kernel imports, no automation
imports) for the payload families the dashboard viz renders. Each family
has exactly one source of truth and one future gate:

  graph/1   — automation/jobs/graph-data.py build(): the {"generated_at",
              "nodes", "edges"} operations graph served at /graph.json.
              Gate: node viz-history-payload's graph sibling (the builder
              must stamp "schema": "graph/1"; until then the gate fails
              closed on live output — fail closed over fail open).
  patrol/1  — automation/jobs/patrol.py findings contract
              (findings_md / stdout PASS|FAIL machine contract, alert
              identity "patrol:<id>") + docs/design/ui-evolve/
              patrol-payload-schema.md (draft JSON shape this module
              validates). Emitter does not exist yet.
  history/1 — NOT YET IMPLEMENTED by any producer. Gate:
              automation/tests/test-viz-schema-history.py (deep-task node
              viz-history-payload owns the producer).

Fail-closed exit contract: the CLI exits 0 on accept (clean or warn),
exits 2 whenever any ERROR-level finding exists (malformed JSON; missing,
non-string, wrong, or unknown "schema"; unknown envelope/nodes/edges/
entries keys; missing required fields; wrong types; duplicate node ids or
duplicate entry keys; self-loop edges; dangling edge endpoints; nested
payloads hidden behind unknown keys). Exit 2 is the callers' contract
("validate -> rc 2"); exit 1 is reserved for usage errors. Warnings never
change the exit code — they flag additive drift only.

Tolerance policy (fail closed by default, additive-only WARN lane):
  OK    — a payload matching its versioned schema exactly.
  WARN  — unknown extra keys INSIDE nodes/edges/entries WHEN their value
          is a scalar (a nested object/array could hide deeper schema
          violations, so those fail closed); unknown "rel" values; unknown
          "state" values. The payload is accepted and the finding flagged.
  ERROR — everything else. The envelope surface (top-level keys and the
          "schema" value) is the versioned surface: unknown keys there
          fail closed so a future schema bump is never silently rendered
          as today's shape.
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

RC_OK = 0
RC_REJECTED = 2

GRAPH_SCHEMA = "graph/1"
PATROL_SCHEMA = "patrol/1"
HISTORY_SCHEMA = "history/1"
SUPPORTED = (GRAPH_SCHEMA, PATROL_SCHEMA, HISTORY_SCHEMA)
# Source: graph-data.py build() -- every literal the builder can emit
# today (STATES tuple, the node() call, _emit_sessions, and the edge()
# call sites in this file).
NODE_KINDS = (
    "kernel", "leg", "service", "package", "seam", "spawn-path",
    "patrol", "surface", "cap", "guard", "research-line",
    "jcode-session", "swarm",
)
NODE_STATES = ("healthy", "stale", "alerting", "neutral")
REL_VALUES = (
    "chain-admits", "bounded-by", "runs", "watched-by", "ghost-row-guard",
    "credential-seam", "fail-soft-guard", "launches-through", "drives-leg",
    "watches", "research-beat", "spawns", "coordinates", "hosts",
    "works-on",
)

_ENVELOPE_FIELDS = {
    GRAPH_SCHEMA: ("schema", "generated_at", "nodes", "edges"),
    PATROL_SCHEMA: ("schema", "run_ts", "date", "tier", "patrol_count",
                    "pass_count", "fail_count", "quip_present", "results",
                    "rounds", "queued_subjects", "alerts"),
    HISTORY_SCHEMA: ("schema", "entries"),
}
_REQUIRED_FIELDS = {
    GRAPH_SCHEMA: ("schema", "generated_at", "nodes", "edges"),
    PATROL_SCHEMA: ("schema", "run_ts", "date", "tier", "patrol_count",
                    "pass_count", "fail_count", "quip_present", "results",
                    "rounds", "queued_subjects", "alerts"),
    HISTORY_SCHEMA: ("schema", "entries"),
}

TYPES = {
    "generated_at": str,
    "run_ts": str,
    "date": str,
    "quip_present": bool,
    "patrol_count": int,
    "pass_count": int,
    "fail_count": int,
    "nodes": list,
    "edges": list,
    "entries": list,
    "results": list,
    "rounds": list,
    "queued_subjects": list,
    "alerts": list,
}

_SCALAR = (str, int, float, bool)


def _err(code, detail):
    return {"severity": "ERROR", "code": code, "detail": detail}


def _warn(code, detail):
    return {"severity": "WARN", "code": code, "detail": detail}


def _type_name(value):
    return type(value).__name__


def _check_entry_fields(entry, index, kind, required, types, issues):
    """Shared per-entry field/type check. Missing/wrong = fail closed."""
    where = "%s[%d]" % (kind, index)
    if not isinstance(entry, dict):
        issues.append(_err(
            "entry-not-object", "%s must be an object, got %s"
            % (where, _type_name(entry))))
        return None
    for field in required:
        if field not in entry:
            issues.append(_err(
                "missing-required-field",
                "%s missing required field %r" % (where, field)))
    for field, want in types.items():
        if field in entry and not isinstance(entry[field], want):
            issues.append(_err(
                "wrong-type",
                "%s.%s must be %s, got %s"
                % (where, field, want.__name__, _type_name(entry[field]))))
    return where


def _warn_scalar_extra(where, entry, allowed, issues):
    """Additive-only tolerance: unknown keys inside entries carrying
    scalar values warn and are accepted; nested payloads fail closed."""
    nested = []
    for key, value in sorted(entry.items()):
        if key in allowed:
            continue
        if isinstance(value, _SCALAR):
            issues.append(_warn(
                "unknown-extra-key",
                "%s unknown extra key %r accepted (additive)"
                % (where, key)))
        else:
            nested.append((key, value))
    for key, value in nested:
        issues.append(_err(
            "unknown-key-nested-payload",
            "%s unknown key %r carries a nested %s; nested payloads "
            "fail closed" % (where, key, _type_name(value))))


def _validate_graph(payload, issues):
    nodes = payload.get("nodes")
    edges = payload.get("edges")
    seen_ids = set()
    if isinstance(nodes, list):
        for i, node in enumerate(nodes):
            where = _check_entry_fields(
                node, i, "nodes",
                ("id", "kind", "label", "state", "detail"),
                {"id": str, "kind": str, "label": str, "state": str,
                 "detail": str}, issues)
            if where is None:
                continue
            _warn_scalar_extra(where, node,
                               ("id", "kind", "label", "state", "detail"),
                               issues)
            nid = node.get("id")
            if isinstance(nid, str):
                if nid in seen_ids:
                    issues.append(_err(
                        "duplicate-node-id",
                        "%s duplicate node id %r" % (where, nid)))
                seen_ids.add(nid)
            if "kind" in node and node["kind"] not in NODE_KINDS:
                issues.append(_warn(
                    "unknown-kind-value",
                    "%s unknown kind %r accepted (additive)"
                    % (where, node["kind"])))
            if "state" in node and node["state"] not in NODE_STATES:
                issues.append(_warn(
                    "unknown-state-value",
                    "%s unknown state %r accepted (additive)"
                    % (where, node["state"])))
    if isinstance(edges, list):
        for i, edge in enumerate(edges):
            where = _check_entry_fields(
                edge, i, "edges", ("src", "dst", "rel"),
                {"src": str, "dst": str, "rel": str}, issues)
            if where is None:
                continue
            _warn_scalar_extra(where, edge, ("src", "dst", "rel"), issues)
            src, dst = edge.get("src"), edge.get("dst")
            if src is not None and src == dst:
                issues.append(_err(
                    "self-loop-edge", "%s self-loop edge %r" % (where, src)))
            for endpoint in ("src", "dst"):
                val = edge.get(endpoint)
                if isinstance(val, str) and val not in seen_ids:
                    issues.append(_err(
                        "dangling-edge-endpoint",
                        "%s %s %r matches no node id" % (where, endpoint, val)))
            if "rel" in edge and edge["rel"] not in REL_VALUES:
                issues.append(_warn(
                    "unknown-rel-value",
                    "%s unknown rel %r accepted (additive)"
                    % (where, edge["rel"])))


_PATROL_TIERS = ("30m", "day", None)
_CAUSE_EXAMPLES = ("bad-execution", "gate-red", "unclaimed-err")


def _validate_patrol(payload, issues):
    if "tier" in payload and payload["tier"] not in _PATROL_TIERS:
        issues.append(_err(
            "wrong-type", "envelope.tier must be '30m', 'day', or null, "
            "got %r" % (payload["tier"],)))
    # per doc section 1: pass_count + fail_count >= patrol_count
    counts = (payload.get("patrol_count"), payload.get("pass_count"),
              payload.get("fail_count"))
    if all(isinstance(c, int) and not isinstance(c, bool) for c in counts):
        if counts[1] + counts[2] < counts[0]:
            issues.append(_err(
                "count-invariant-violated",
                "pass_count + fail_count (%d) < patrol_count (%d)"
                % (counts[1] + counts[2], counts[0])))
    results = payload.get("results")
    if isinstance(results, list):
        for i, res in enumerate(results):
            where = _check_entry_fields(
                res, i, "results",
                ("id", "surface", "check", "tier", "finding_class",
                 "passes", "fails"),
                {"id": str, "surface": str, "check": str, "tier": str,
                 "finding_class": str, "passes": list, "fails": list},
                issues)
            if where is None:
                continue
            _warn_scalar_extra(
                where, res,
                ("id", "surface", "check", "tier", "finding_class",
                 "passes", "fails"), issues)
            if isinstance(res.get("passes"), list):
                for j, item in enumerate(res["passes"]):
                    sub = _check_entry_fields(
                        item, j, "%s.passes" % where,
                        ("name", "detail"), {"name": str, "detail": str},
                        issues)
                    if sub is not None:
                        _warn_scalar_extra(sub, item, ("name", "detail"),
                                           issues)
            if isinstance(res.get("fails"), list):
                for j, item in enumerate(res["fails"]):
                    sub = _check_entry_fields(
                        item, j, "%s.fails" % where,
                        ("artifact", "cause", "detail"),
                        {"artifact": str, "cause": str, "detail": str},
                        issues)
                    if sub is not None:
                        _warn_scalar_extra(sub, item,
                                           ("artifact", "cause", "detail"),
                                           issues)
    for list_field, item_shape in (("rounds",
                                    ("id", "surface", "artifact", "cause")),
                                   ("alerts",
                                    ("identity", "window", "text",
                                     "evidence"))):
        items = payload.get(list_field)
        if not isinstance(items, list):
            continue
        types = {f: str for f in item_shape}
        if list_field == "alerts":
            types["window"] = int
        for i, item in enumerate(items):
            where = _check_entry_fields(item, i, list_field, item_shape,
                                        types, issues)
            if where is not None:
                _warn_scalar_extra(where, item, item_shape, issues)
    for i, item in enumerate(payload.get("queued_subjects") or []):
        if not isinstance(item, (str, dict)):
            issues.append(_err(
                "wrong-type",
                "queued_subjects[%d] must be a string (rid) or object, "
                "got %s" % (i, _type_name(item))))


def _validate_history(payload, issues):
    entries = payload.get("entries")
    if not isinstance(entries, list):
        return
    seen_keys = set()
    for i, entry in enumerate(entries):
        where = _check_entry_fields(
            entry, i, "entries", ("key", "ts", "summary"),
            {"key": str, "ts": str, "summary": str}, issues)
        if where is None:
            continue
        for key, value in sorted(entry.items()):
            if key in ("key", "ts", "summary"):
                continue
            if isinstance(value, (dict, list)):
                issues.append(_err(
                    "unknown-key-nested-payload",
                    "%s unknown key %r carries a nested %s; nested "
                    "payloads fail closed"
                    % (where, key, _type_name(value))))
            else:
                issues.append(_warn(
                    "unknown-extra-key",
                    "%s unknown extra key %r accepted (additive)"
                    % (where, key)))
        key = entry.get("key")
        if isinstance(key, str):
            if key in seen_keys:
                issues.append(_err(
                    "duplicate-entry-key", "%s duplicate entry key %r"
                    % (where, key)))
            seen_keys.add(key)


_VALIDATORS = {
    GRAPH_SCHEMA: _validate_graph,
    PATROL_SCHEMA: _validate_patrol,
    HISTORY_SCHEMA: _validate_history,
}

# Public schema table: tag -> envelope/required contract (the machine
# form of this module's docstring). Membership answers "is this tag
# supported"; the tuples drive the fail-closed envelope checks.
SCHEMA = {tag: {"fields": _ENVELOPE_FIELDS[tag],
                "required": _REQUIRED_FIELDS[tag]}
          for tag in SUPPORTED}


def validate_payload(payload, tag=None):
    """Validate a decoded payload dict against family tag.

    tag None detects from payload["schema"]. Returns a list of issues;
    [] = clean, WARN-severity items accept the payload, ERROR-severity
    items reject it.
    """
    issues = []
    if not isinstance(payload, dict):
        issues.append(_err(
            "envelope-not-object",
            "payload envelope must be a JSON object, got %s"
            % _type_name(payload)))
        return issues

    if tag is None:
        if "schema" not in payload:
            issues.append(_err(
                "missing-schema-field",
                "missing required envelope key 'schema'"))
            return issues
        tag = payload["schema"]

    if not isinstance(tag, str):
        issues.append(_err(
            "schema-not-string",
            "'schema' must be a string, got %r" % (tag,)))
        return issues
    if tag not in SUPPORTED:
        issues.append(_err(
            "unknown-schema-version",
            "unknown schema version %r (supported: %s)"
            % (tag, ", ".join(SUPPORTED))))
        return issues

    if "schema" not in payload:
        issues.append(_err(
            "missing-schema-field",
            "missing required envelope key 'schema'"))
    elif payload["schema"] != tag:
        issues.append(_err(
            "schema-version-mismatch",
            "schema version mismatch: expected '%s', got %r"
            % (tag, payload["schema"])))

    allowed = _ENVELOPE_FIELDS[tag]
    for key in sorted(payload):
        if key not in allowed:
            issues.append(_err(
                "unknown-envelope-key",
                "unknown envelope key %r (fail closed)" % (key,)))
    for field in _REQUIRED_FIELDS[tag]:
        if field not in payload:
            issues.append(_err(
                "missing-required-field",
                "missing required envelope key %r" % (field,)))
    for field, want in TYPES.items():
        if field not in payload:
            continue
        value = payload[field]
        wrong = not isinstance(value, want) or (
            want is int and isinstance(value, bool))
        if wrong:
            issues.append(_err(
                "wrong-type",
                "envelope.%s must be %s, got %s"
                % (field, want.__name__, _type_name(value))))

    _VALIDATORS[tag](payload, issues)
    return issues


def _detail(ok, issues, tag):
    if ok:
        if issues:
            return "warn: %s payload accepted with %d warning(s)" \
                % (tag, len(issues))
        return "ok: %s payload valid" % tag
    return "fail: %s payload rejected with %d error(s)" \
        % (tag, len(issues))


def validate(payload_text, tag=None):
    """Validate payload TEXT (bytes-level contract).

    Returns (ok, detail, warns): ok False on any ERROR (malformed JSON,
    schema mismatch, structural violation); warns is the WARN-severity
    issue list (additive tolerance is flagged, never fatal).
    """
    try:
        payload = json.loads(payload_text)
    except (json.JSONDecodeError, ValueError, UnicodeDecodeError) as exc:
        return (False, "fail: malformed JSON: %s" % exc, [])
    issues = validate_payload(payload, tag)
    errors = [i for i in issues if i["severity"] == "ERROR"]
    warns = [i for i in issues if i["severity"] == "WARN"]
    ok = not errors
    shown = errors if errors else warns
    detail = _detail(ok, shown, tag or payload.get("schema")
                     if isinstance(payload, dict) else tag)
    if shown:
        detail += ": " + "; ".join(i["detail"] for i in shown)
    return (ok, detail, warns)


def validate_graph(payload_text):
    return validate(payload_text, GRAPH_SCHEMA)


def validate_patrol(payload_text):
    return validate(payload_text, PATROL_SCHEMA)


def validate_history(payload_text):
    return validate(payload_text, HISTORY_SCHEMA)


class _Parser(argparse.ArgumentParser):
    """Usage errors exit 1, keeping rc 2 unambiguous: rc 2 always means
    'this payload failed closed', never 'you called the CLI wrong'."""

    def error(self, message):
        self.print_usage(sys.stderr)
        print("%s: error: %s" % (self.prog, message), file=sys.stderr)
        raise SystemExit(1)


def main(argv=None):
    ap = _Parser(
        description="Validate a dashboard viz payload against its "
                    "versioned schema (exit 0 accept, 2 fail closed).")
    ap.add_argument("--schema", choices=list(SUPPORTED), default=None,
                    help="expected family tag (default: read from the "
                         "payload's own 'schema' field)")
    ap.add_argument("payload", help="path to the payload JSON file")
    args = ap.parse_args(argv)
    try:
        text = Path(args.payload).read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError) as exc:
        print("fail: cannot read payload: %s" % exc, file=sys.stderr)
        return RC_REJECTED
    ok, detail, warns = validate(text, args.schema)
    for issue in warns:
        print("warn: %s" % issue["detail"], file=sys.stderr)
    print(detail, file=sys.stderr if not ok else sys.stdout)
    return RC_OK if ok else RC_REJECTED


if __name__ == "__main__":
    sys.exit(main())
