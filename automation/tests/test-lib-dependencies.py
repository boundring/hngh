#!/usr/bin/env python3
"""lib dependency direction (jev-review check-dependencies style).

Contract: automation/lib sourcing flows INWARD only --
orchestrators (launch-session, delegates) source foundation/leaf
modules, never the reverse. A leaf (common, breadcrumbs, params,
scrub, redact, causes, prereqs) sourcing an orchestrator is an
upward import and fails. Cycles fail. Python lib modules stay
stdlib-only (typesafe.py's optional typesafe_sdk import exempt:
fail-closed optional dependency, no repo-state import).

Hermetic: parses the tree only, no sourcing, no model calls.
"""

import re
import sys
import unittest
from pathlib import Path

LIB = Path(__file__).resolve().parent.parent / "lib"

# Layer rank: lower = deeper foundation (may only source same-or-lower).
LAYERS = {
    # layer 0: pure foundation, sources nothing in lib
    "common.sh": 0, "breadcrumbs.sh": 0, "params.sh": 0,
    "scrub.sh": 0, "scrub.py": 0, "prereqs.sh": 0,
    # layer 1: shims / single-purpose leaves over foundation
    "redact.sh": 1, "causes.sh": 1, "platform.sh": 1,
    "launch-jcode.sh": 1, "model-demote.sh": 1,
    "memory-gate.sh": 1,
    "bailiff.sh": 1,
    # layer 2: feature modules over foundation + leaves
    "model.sh": 2, "credentials.sh": 2, "notify.sh": 2,
    "notify-email.sh": 2, "context-pack.sh": 2,
    "digest-block.sh": 2, "news-screen.sh": 2, "news-importance.sh": 2,
    "sources.sh": 2, "hngh-record.sh": 2, "operator-item.sh": 2,
    "git-push.sh": 2, "vip-gate.sh": 2, "beat-blockers.sh": 2,
    "failfirst.sh": 2, "service-mgmt.sh": 2, "permissions.sh": 2,
    "comfyui.sh": 2,
    # layer 3: orchestrators, source anything below them
    "launch-session.sh": 3,
    "jcode-delegate.sh": 3, "ocgo-delegate.sh": 3,
    # python lib: stdlib-only leaves (+ exempt optional SDK below)
    "correction-linkage.py": 1, "credential-evidence.py": 1,
    "crumbs-db.py": 1,
    "docfilter.py": 1, "hngh_home.py": 1, "quips.py": 1,
    "research-harvest.py": 1, "typesafe.py": 1,
    "secrets.py": 1, "vault-freshness.py": 1,
}

# Optional third-party imports that are fail-closed, not repo coupling.
PY_EXEMPT = {"typesafe_sdk"}

SOURCE_RE = re.compile(r'(?:^|[;|&])\s*(?:\.|source)\s+"?([^"\s;|&]+)"?')


def sh_edges(path):
    edges = set()
    for raw in path.read_text(encoding="utf-8", errors="replace").splitlines():
        stripped = raw.strip()
        if not stripped or stripped.startswith("#"):
            continue
        line = raw.split("#", 1)[0] if " . " in raw or raw.lstrip().startswith(".") else raw
        m = SOURCE_RE.search(line)
        if not m:
            continue
        raw_target = m.group(1)
        if raw_target.startswith("$("):
            # . "$(cd ...)/name.sh" form: basename lives at line end
            end = re.search(r"/([A-Za-z0-9_.-]+\.(?:sh|py))[\"']?\s*(?:\|\||;|&&|\s*(?:#|$))", line)
            if not end:
                continue
            target = end.group(1)
        else:
            target = Path(raw_target).name
            if not target.endswith((".sh", ".py")):
                continue  # config.env etc: not a lib edge
        if target == path.name:
            continue
        edges.add(target)
    return edges


def py_edges(path):
    edges = set()
    try:
        tree = __import__("ast").parse(
            path.read_text(encoding="utf-8", errors="replace"))
    except SyntaxError as e:
        return None, "syntax: %s" % e
    stdlibish = set(sys.stdlib_module_names) if hasattr(
        sys, "stdlib_module_names") else set()
    for node in __import__("ast").walk(tree):
        if isinstance(node, __import__("ast").Import):
            for a in node.names:
                top = a.name.split(".")[0]
                if top not in stdlibish and top not in PY_EXEMPT:
                    edges.add(top)
        elif isinstance(node, __import__("ast").ImportFrom):
            if node.module:
                top = node.module.split(".")[0]
                if top not in stdlibish and top not in PY_EXEMPT:
                    edges.add(top)
    return edges, None


class TestLibDependencyDirection(unittest.TestCase):
    def test_every_lib_file_layered(self):
        unlayered = sorted(
            p.name for p in LIB.iterdir()
            if p.suffix in (".sh", ".py")
            and p.name not in LAYERS
            and p.name != "__init__.py")
        self.assertEqual(
            unlayered, [],
            "unlayered lib files (add to LAYERS): %s" % unlayered)

    def test_no_upward_sh_imports(self):
        bad = []
        for name, rank in sorted(LAYERS.items()):
            if not name.endswith(".sh"):
                continue
            p = LIB / name
            if not p.exists():
                continue
            for target in sorted(sh_edges(p)):
                trank = LAYERS.get(target)
                if trank is None:
                    bad.append("%s -> %s (unlayered target)" % (name, target))
                elif trank > rank:
                    bad.append("%s (L%d) -> %s (L%d): upward import"
                               % (name, rank, target, trank))
        self.assertEqual(bad, [], "upward imports:\n%s" % "\n".join(bad))

    def test_no_sh_cycles(self):
        adj = {}
        for name, rank in LAYERS.items():
            if not name.endswith(".sh"):
                continue
            p = LIB / name
            adj[name] = [t for t in sh_edges(p)] if p.exists() else []
        visited, stack, cycles = {}, [], []

        def dfs(node, path):
            visited[node] = 1
            path.append(node)
            for nxt in adj.get(node, []):
                if nxt not in adj:
                    continue
                if nxt in path:
                    cycles.append(" -> ".join(path + [nxt]))
                elif nxt not in visited:
                    dfs(nxt, path)
            path.pop()

        for node in adj:
            if node not in visited:
                dfs(node, [])
        self.assertEqual(cycles, [], "cycles:\n%s" % "\n".join(cycles))

    def test_py_local_imports(self):
        bad = []
        for name in sorted(LAYERS):
            if not name.endswith(".py"):
                continue
            p = LIB / name
            if not p.exists():
                continue
            edges, err = py_edges(p)
            if err:
                bad.append("%s: %s" % (name, err))
                continue
            for target in sorted(edges):
                # a bare top-level name that matches a sibling lib
                # module (with or without .py) is repo coupling
                if (target + ".py") in LAYERS or target in LAYERS:
                    bad.append("%s imports sibling lib %s" % (name, target))
                elif (LIB / (target + ".py")).exists():
                    bad.append("%s imports lib-adjacent %s" % (name, target))
        self.assertEqual(bad, [], "py repo coupling:\n%s" % "\n".join(bad))


if __name__ == "__main__":
    unittest.main()
