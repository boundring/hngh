#!/usr/bin/env python3
"""Self-governance history guard: the README ceremony claim, machine-checked.

The root README states: "behavior changes ride the loop — proposal →
verdict → certificate → executor, under real evidence — and where the
loop itself refuses a binding (the dependency guard will not certify a
commit that changes no behavior), the exception is by rule, not by
mood."

This guard makes that sentence falsifiable: every commit after the
restatement (1915713) that touches the code surface (src/, tests/,
scripts/, Makefile, hngh.asd) must either be a certificate-bound
candidate commit or carry the rule-based exemption label. Anything else
is a violation and fails the gate.

The exemption label is not a free pass: a labeled commit may touch ONLY
src/packages.lisp (the single export-only file the dependency guard
refuses to bind). A labeled commit touching any other code-surface file
is a violation — a behavior change hiding behind the label is caught by
diff inspection, not just the message.

The single known pre-guard violation is 915e0e3 (comment-only alignment
of composition-root references, committed before this guard existed); it
is exempted by name below and recorded in docs/project/decisions.md.
History is not rewritten; enforcement starts from the restatement, with
that one blemish declared.
"""

import re
import subprocess
import sys

RESTATEMENT = "1915713"
KNOWN_EXEMPTIONS = {
    # comment-only alignment of composition-root references; predates the guard
    "915e0e3": "comment-only docs alignment (pre-guard)",
}

CODE_SURFACE = ("src/", "tests/", "scripts/", "Makefile", "hngh.asd")
CANDIDATE = re.compile(r"^hngh: candidate [0-9a-f]{64}$")
EXEMPT = "excluded from cert manifest by dependency guard"
EXEMPT_ALLOWED_FILES = {"src/packages.lisp"}


def run(argv):
    return subprocess.run(argv, capture_output=True, text=True, check=True)


def commits_since(rev):
    out = run(["git", "log", "--format=%h%x09%s", f"{rev}..HEAD"]).stdout
    return [line.split("\t", 1) for line in out.splitlines() if line]


def touches_code(sha):
    out = run(["git", "diff", "--name-only", f"{sha}^", sha]).stdout
    return any(p.startswith(prefix) for p in out.splitlines()
               for prefix in CODE_SURFACE)

def code_files(sha):
    out = run(["git", "diff", "--name-only", f"{sha}^", sha]).stdout
    return [p for p in out.splitlines()
            if any(p.startswith(prefix) for prefix in CODE_SURFACE)]


def main():
    violations = []
    checked = 0
    exempted = 0
    for sha, subject in commits_since(RESTATEMENT):
        if not touches_code(sha):
            continue
        checked += 1
        if sha in KNOWN_EXEMPTIONS:
            exempted += 1
            continue
        if CANDIDATE.match(subject):
            continue
        if EXEMPT in subject:
            files = code_files(sha)
            if files and not set(files) <= EXEMPT_ALLOWED_FILES:
                violations.append((sha, subject,
                    f"labeled exemption touches {files}"))
            continue
        violations.append((sha, subject))
    if violations:
        print(f"loop-history guard: {len(violations)} violation(s):")
        for item in violations:
            sha, subject, *extra = item
            print(f"  {sha} {subject}"
                  + (f" [{extra[0]}]" if extra else ""))
        print("every code-surface commit must be 'hngh: candidate <hash>' "
              "or a labeled rule-based exemption")
        return 1
    print(f"loop-history guard: {checked} code-surface commits checked, "
          f"{exempted} named exemption(s), 0 violations")
    return 0


if __name__ == "__main__":
    sys.exit(main())