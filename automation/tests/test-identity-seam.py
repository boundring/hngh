#!/usr/bin/env python3
"""Identity-seam contract guard: every auto-committer in the automation
writer surfaces pins the machine identity per invocation.

The 2026-09-13 Fixture leak (docs/records/2026-09-16-identity-seam-
reconciliation.md) showed auto-committers taking author identity from
ambient .git/config: 566 commits in that window carry the anonymous
author, including research-beat, kernel/plan ledger sync, torch refresh,
ceremony candidates, and lesson-harvest ticks. The contract (16dae2eb,
config-backup.sh) is per-invocation pinning (`-c user.name=` /
`-c user.email=`) so attribution never depends on ambient config state.

Scan scope (2026-09-17 non-sh/py writer audit, same record):
- .sh/.py under automation/{cadence,jobs,lib,scripts} (the original
  surface), shell continuation-joined, quotes stripped;
- .js/.mjs under automation/{dashboard,jcode} plus the four surfaces
  above (the audit's admitted blind spot: dashboard code was never
  scanned). JS lines are comment-stripped (// and /* */) with string
  CONTENTS kept, because the ordinary JS invocation forms are quoted:
  execSync(`git commit ...`) / spawn("git", ["commit", ...]). A string
  that spells the invocation shape must carry a pin on the same line or
  the guard fires (fail-closed; reword prose instead);
- git-array forms in .py/.sh raw lines: ["git", "commit"] and
  ["git", "-c", ...] adjacency that the shell-oriented regex misses.

Hermetic: no git, no network -- source inspection only. Shell/JS
comments are exempt; built-in self-tests (fixture probes in a tmp dir,
run on every invocation) keep the scanner itself from rotting; a
positive control pins config-backup.sh's own seam so the contract
cannot rot silently.
"""
import pathlib
import re
import sys
import tempfile

ROOT = pathlib.Path(__file__).resolve().parent.parent
SURFACES = ("cadence", "jobs", "lib", "scripts")
JS_SUFFIXES = (".js", ".mjs")
# Code surfaces scanned for .js/.mjs in addition to SURFACES (2026-09-17
# non-sh/py writer audit: dashboard code + the jcode delegation lane).
JS_SURFACES = ("dashboard", "jcode")

# `git ... commit` as the git subcommand (not prose like `{commit}` revs).
GIT_COMMIT_RE = re.compile(r"\bgit\b[^\n]*?\scommit\b")
PIN_RE = re.compile(r"user\.name=")
# Array/argv forms: spawn("git", ["commit"...]), ["git", "commit"...],
# and "git", "-c", ..., "commit" adjacency in any language.
# (triple-single-quoted: a """-quoted literal would end early on the
# trailing ['"] class and silently narrow it to single quotes only)
GIT_ARGS_ARRAY_RE = re.compile(
    r'''['"]git['"]\s*,\s*(?:\[[^\]]*?|['"]-c['"][^\n]*?|)['"]commit['"]'''
)


def continuation_joined(text):
    """Join shell line continuations so wrapped commands scan as one."""
    return text.replace("\\\n", " ")


def strip_quoted(line):
    """Drop double-quoted substrings so prose like "git commit failed"
    inside breadcrumb messages cannot masquerade as an invocation."""
    return re.sub(r'"[^"]*"', "", line)


def js_comment_free(line, in_block):
    """Strip // and /* */ comments from one JS line, keeping string
    contents (invocations live in strings). Returns (code, in_block)."""
    out = []
    i, n = 0, len(line)
    while i < n:
        ch = line[i]
        nxt = line[i + 1] if i + 1 < n else ""
        if in_block:
            if ch == "*" and nxt == "/":
                in_block = False
                i += 2
            else:
                i += 1
            continue
        if ch == "/" and nxt == "*":
            in_block = True
            i += 2
            continue
        if ch == "/" and nxt == "/":
            break
        out.append(ch)
        i += 1
    return "".join(out), in_block


def scan_file(path):
    """Shell/python scan: continuation-joined, quotes stripped, plus the
    raw-line git-array forms (["git", "commit"] / ["git", "-c", ...])."""
    hits = []
    text = continuation_joined(path.read_text(errors="replace"))
    for no, line in enumerate(text.splitlines(), 1):
        stripped = line.strip()
        if stripped.startswith("#"):
            continue  # shell/python comment, not an invocation
        code = strip_quoted(line)
        shell_hit = GIT_COMMIT_RE.search(code) and not PIN_RE.search(code)
        array_hit = GIT_ARGS_ARRAY_RE.search(stripped) and not PIN_RE.search(stripped)
        if shell_hit or array_hit:
            hits.append((no, stripped))
    return hits


def scan_js_file(path):
    """JS/mjs scan: comment-free lines (strings kept), invocation shape
    via the subcommand regex or the spawn-argv array regex."""
    hits = []
    in_block = False
    for no, line in enumerate(path.read_text(errors="replace").splitlines(), 1):
        cf, in_block = js_comment_free(line, in_block)
        shape = GIT_COMMIT_RE.search(cf) or GIT_ARGS_ARRAY_RE.search(cf)
        if shape and not PIN_RE.search(cf):
            hits.append((no, line.strip()))
    return hits


def self_test_failures():
    """Fixture probes in a tmp dir: the scanner must catch every
    unpinned form and stay quiet on pinned/commented forms."""
    failures = []
    with tempfile.TemporaryDirectory() as td:
        tmp = pathlib.Path(td)

        def expect(name, text, scanner, should_flag):
            f = tmp / name
            f.parent.mkdir(parents=True, exist_ok=True)
            f.write_text(text)
            flagged = bool(scanner(f))
            if flagged != should_flag:
                failures.append(
                    "self-test %s: expected %s, got %s"
                    % (name, "flag" if should_flag else "clean", "flag" if flagged else "clean")
                )

        expect("dash/leak.mjs",
               "import { execSync } from 'node:child_process';\n"
               "execSync(`git commit -m \"probe\"`);\n",
               scan_js_file, True)
        expect("dash/ok.mjs",
               "execSync('git -c user.name=hngh-machine commit -m \"x\"');\n",
               scan_js_file, False)
        expect("dash/spawn.js",
               "spawn(\"git\", [\"commit\", \"-m\", msg]);\n",
               scan_js_file, True)
        expect("dash/spawn-pinned.js",
               "execFile('git', ['-c', 'user.name=hngh-machine', 'commit', '-m', msg]);\n",
               scan_js_file, False)
        expect("dash/comments.js",
               "// a comment may say git commit freely\n"
               "/* so may a block comment: git commit */\n"
               "const msg = 'reworded prose without the invocation shape';\n",
               scan_js_file, False)
        expect("jobs/w.py",
               "subprocess.run([\"git\", \"commit\", \"-m\", m])\n",
               scan_file, True)
        expect("jobs/ok.py",
               "subprocess.run([\"git\", \"-c\", \"user.name=hngh-machine\", \"commit\"])\n",
               scan_file, False)
        expect("jobs/pinned.sh",
               "git -c user.name=hngh-machine commit -q -m \"tick\"\n",
               scan_file, False)
        expect("jobs/leak.sh",
               "git commit -q -m \"tick\"\n",
               scan_file, True)
    return failures


def main():
    failures = self_test_failures()
    if failures:
        print("identity-seam guard: scanner self-test failure(s)")
        for f in failures:
            print("  " + f)
        return 1

    violations = []
    for surface in SURFACES:
        base = ROOT / surface
        if not base.is_dir():
            continue
        for path in sorted(base.rglob("*")):
            if not path.is_file():
                continue
            if path.parent.name == "tests":
                continue  # test fixtures legitimately use throwaway identities
            if path.suffix in (".sh", ".py"):
                scanner, kind = scan_file, "unpinned git commit"
            elif path.suffix in JS_SUFFIXES:
                scanner, kind = scan_js_file, "unpinned js git commit"
            else:
                continue
            for no, line in scanner(path):
                violations.append(
                    "%s/%s:%d: %s: %s" % (surface, path.name, no, kind, line[:120])
                )
    for surface in JS_SURFACES:
        base = ROOT / surface
        if not base.is_dir():
            continue
        for path in sorted(base.rglob("*")):
            if not path.is_file() or path.suffix not in JS_SUFFIXES:
                continue
            if path.parent.name == "tests":
                continue
            for no, line in scan_js_file(path):
                violations.append(
                    "%s/%s:%d: unpinned js git commit: %s" % (surface, path.name, no, line[:120])
                )

    # Positive control: the reference seam must still be pinned.
    reference = ROOT / "jobs" / "config-backup.sh"
    if reference.exists() and not PIN_RE.search(continuation_joined(reference.read_text())):
        violations.append(
            "jobs/config-backup.sh: reference identity seam lost its pin"
        )

    if violations:
        print("identity-seam guard: %d violation(s)" % len(violations))
        for v in violations:
            print("  " + v)
        return 1
    print("identity-seam guard: every automation auto-committer pins "
          "user.name per invocation (sh/py/js/mjs, array forms, self-tested)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
