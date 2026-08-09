#!/usr/bin/env python3
"""lint-deps.py — Structural dependency guardrails (autonomy-strategy Wave B).

Enforces the deterministic fitness checks that gate self-modification BEFORE
it lands (design: docs/design/autonomy-strategy.md §7 Wave B). These are the
"fitness functions as tests, not advisory docs":

  1. No plugin -> plugin :use clauses        (packages are the registration
     surface; plugins talk via hngh.core, not by :use-ing each other)
  2. Core never CALLS plugin symbols         (src/core/* must not reference
     hngh.plugins.<X>:sym; main.lisp is the composition root and may call
     only :init/:shutdown — the plugin-registration contract)
  3. No circular dependencies                (cycle check over the package
     :use graph + plugin call graph)
  4. Production never depends on tests       (system "hngh" components must
     not reference hngh.tests)

Each rule is deterministic + unit-tested (tests/fixtures/guardrails/), the
same pattern as lint-parens. Runs in the test-suite gate before tests.

Usage:
  python3 scripts/lint-deps.py                # check the repo
  python3 scripts/lint-deps.py <paths...>     # check specific files
Exit 0 = clean, 1 = violations found.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
DEFAULT_SRC = REPO_ROOT / "src"
CORE_DIR = DEFAULT_SRC / "core"
MAIN_ROOT = CORE_DIR / "main.lisp"
COMPOSITION_ONLY_CALLS = {"init", "shutdown"}

# Package-definition and use-clause scraping (works on both the defpackage
# one-liner style and the multi-line :use (:a :b) style used in this repo).
_DEFPACKAGE_RE = re.compile(
    r"\(defpackage\s+:([a-z0-9.-]+)(.*?)\)\)", re.S
)
_USE_RE = re.compile(r":use\s+\(?([^)]*)\)")
_USE_ITEM_RE = re.compile(r":([a-z0-9.-]+)")
_IN_PACKAGE_RE = re.compile(r"\(in-package\s+:([a-z0-9.-]+)\)")
_PLUGIN_SYM_RE = re.compile(r"hngh\.plugins\.([a-z0-9.-]+):([a-z0-9*-]+)")
_PLUGIN_NAME_RE = re.compile(r"hngh\.plugins\.[a-z0-9.-]+")
_TESTS_REF_RE = re.compile(r"hngh\.tests")


def parse_packages(text: str) -> dict[str, set[str]]:
    """Return {package-name: set-of-used-packages} from defpackage forms."""
    packages: dict[str, set[str]] = {}
    for match in _DEFPACKAGE_RE.finditer(text):
        name = match.group(1)
        body = match.group(2)
        uses: set[str] = set()
        use_match = _USE_RE.search(body)
        if use_match:
            uses = set(_USE_ITEM_RE.findall(use_match.group(1)))
        packages[name] = uses
    return packages


def file_package(text: str) -> str | None:
    """Package bound by the file's (in-package ...) form, if any."""
    match = _IN_PACKAGE_RE.search(text)
    return match.group(1) if match else None


def is_plugin_package(pkg: str) -> bool:
    return pkg.startswith("hngh.plugins.")


def is_core_file(path: Path) -> bool:
    """Core-ness is package-based (files in hngh.core.* or the top hngh
    package), not directory-based — this is what the design means by
    'core must not reference plugins'."""
    try:
        text = path.read_text(encoding="utf-8")
    except OSError:
        return False
    pkg = file_package(text)
    return bool(pkg) and (pkg == "hngh" or pkg.startswith("hngh.core"))


def segment_packages(text: str) -> list[tuple[str, str]]:
    """Split TEXT into (package, segment) pairs, one per in-package form.

    Files with multiple (in-package ...) forms (e.g. defpackage + section
    bodies) must attribute each code segment to the package in scope at
    that point — the CL semicolon-scope rule, made explicit."""
    segments: list[tuple[str, str]] = []
    positions = [(m.start(), m.group(1)) for m in _IN_PACKAGE_RE.finditer(text)]
    if not positions:
        return segments
    for i, (pos, pkg) in enumerate(positions):
        end = positions[i + 1][0] if i + 1 < len(positions) else len(text)
        segments.append((pkg, text[pos:end]))
    return segments


def check_use_clauses(packages: dict[str, set[str]]) -> list[str]:
    """Rule 1: no plugin -> plugin :use clauses."""
    violations = []
    for name, uses in sorted(packages.items()):
        if not is_plugin_package(name):
            continue
        for used in sorted(uses):
            if is_plugin_package(used):
                violations.append(
                    f"rule1: plugin :use plugin — {name} :use {used} "
                    "(plugins talk via hngh.core, not by :use-ing each other)"
                )
    return violations


def check_core_calls_plugins(files: list[Path]) -> list[str]:
    """Rule 2: core packages must not call plugin symbols.

    main.lisp (package hngh) is the composition root: it MAY call
    :init/:shutdown of plugin packages (the registration contract).
    Everything else in a core package must not reference plugin symbols.
    """
    violations = []
    for path in files:
        if not is_core_file(path):
            continue
        is_root = path.resolve() == MAIN_ROOT.resolve()
        text = path.read_text(encoding="utf-8")
        for pkg, segment in segment_packages(text):
            if not (pkg == "hngh" or pkg.startswith("hngh.core")):
                continue
            for match in _PLUGIN_SYM_RE.finditer(segment):
                plugin = match.group(1)
                sym = match.group(2).rstrip("*")
                if is_root and sym in COMPOSITION_ONLY_CALLS:
                    continue
                line_no = text[: match.start()].count("\n") + 1
                allowed = " (main.lisp composition root may call :init/:shutdown only)" if is_root else ""
                violations.append(
                    f"rule2: core calls plugin symbol — {path.name}:{line_no} "
                    f"hngh.plugins.{plugin}:{sym}{allowed}"
                )
    return violations


def check_circular_deps(files: list[Path], packages: dict[str, set[str]]) -> list[str]:
    """Rule 3: cycle check over the package :use graph + plugin call graph."""
    graph: dict[str, set[str]] = {p: set(u) for p, u in packages.items()}
    # plugin call graph: a segment in plugin package X calling plugin package Y.
    # Edges must use the SAME namespace as graph keys (full package names) or
    # cycles never close — the classic name-mismatch cycle-finder bug.
    for path in files:
        text = path.read_text(encoding="utf-8")
        for pkg, segment in segment_packages(text):
            if not is_plugin_package(pkg):
                continue
            called = {f"hngh.plugins.{m.group(1)}"
                      for m in _PLUGIN_SYM_RE.finditer(segment)}
            graph.setdefault(pkg, set()).update(called)
    return _find_cycles(graph)


def _find_cycles(graph: dict[str, set[str]]) -> list[str]:
    """Return human-readable cycles (nodes only) in a directed graph."""
    cycles = []
    seen: set[str] = set()
    for start in sorted(graph):
        if start in seen:
            continue
        path: list[str] = []
        visiting: set[str] = set()

        def visit(node: str) -> None:
            if node in visiting:
                idx = path.index(node)
                cycle = path[idx:] + [node]
                cycles.append(" -> ".join(cycle))
                return
            if node in seen:
                return
            seen.add(node)
            visiting.add(node)
            path.append(node)
            for nxt in sorted(graph.get(node, ())):
                visit(nxt)
            path.pop()
            visiting.discard(node)

        visit(start)
    return cycles


def check_no_tests_dependency(files: list[Path], packages: dict[str, set[str]]) -> list[str]:
    """Rule 4: system "hngh" components must not reference hngh.tests."""
    violations = []
    for name, uses in sorted(packages.items()):
        if name == "hngh.tests":
            continue
        if "hngh.tests" in uses:
            violations.append(f"rule4: {name} :use hngh.tests — production "
                              "must never depend on tests")
    return violations


def check_paths(paths: list[Path]) -> list[str]:
    """Run all rules over given source paths. Returns violation strings."""
    files = [p for p in paths if p.suffix == ".lisp" and p.exists()]
    all_text = "\n".join(p.read_text(encoding="utf-8") for p in files)
    packages = parse_packages(all_text)

    violations: list[str] = []
    violations += check_use_clauses(packages)
    violations += check_core_calls_plugins(files)
    violations += check_circular_deps(files, packages)
    violations += check_no_tests_dependency(files, packages)
    return violations


def main(argv: list[str]) -> int:
    if not argv:
        paths = sorted((DEFAULT_SRC / "**").glob("*.lisp"))
    else:
        paths = [Path(a) for a in argv]
    violations = check_paths(paths)
    if violations:
        print("Dependency guardrail violations found:")
        for v in sorted(set(violations)):
            print(f"  {v}")
        return 1
    print("OK: dependency guardrails clean")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))