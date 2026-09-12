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

Declarations are purge-proof by construction. The registered hash is
primary; the patch-id (git show <hash> | git patch-id --stable) is the
purge-proof fallback: a history rewrite (filter-branch/filter-repo)
re-keys descendant hashes but leaves patch content untouched, so a
commit whose registered hash dangles is still matched by patch-id. A
standing reachability self-check fails the gate when a registered hash
is no longer reachable from HEAD, with a message that names the cure:
re-declare via ceremony.
"""

import re
import subprocess
import sys

RESTATEMENT = "1915713"
EMPTY_TREE = "4b825dc642cb6eb9a060e54bf8d69288fbee4904"
SUBTREE_SQUASH = re.compile(r"^Squashed '.*' content from commit [0-9a-f]+$")
KNOWN_EXEMPTIONS = {
    # comment-only alignment of composition-root references; predates the guard
    "915e0e3": {
        "reason": "comment-only docs alignment (pre-guard)",
        "patch-id": "09b439c8625b0c12d3bf402a5cf696af0157d6c2",
    },
    # portfolio docs commit that also touched a kernel script (2026-09-06),
    # landed outside the loop and already pushed; declared by name per the
    # 2026-08-25 decision, cured by ceremony record -- not rewritten
    "526cd3f": {
        "reason": "portfolio ebook/journal commit touching a kernel script (declared miss)",
        "patch-id": "4496b3361bc3d606837acfd377b9ead29a636a4d",
    },
    # omp-bridge --propose/--plan-status (integration plan step 3) and its
    # bare-slug fix: landed outside the loop on 2026-09-10 while the bridge
    # itself was being built; declared by name per the 2026-09-06 decision,
    # cured by post-hoc certification (2026-09-11) -- not rewritten.
    # hash post-purge (2026-09-11 secret-scrub filter-branch), same patch-id
    # as the declared original (a2f4d0e / 31768d2); re-keyed by ceremony
    "572d3e2": {
        "reason": "omp-bridge --propose/--plan-status (declared miss)",
        "patch-id": "558c84f7a35794b3368334fe3b1e0f1b15e8ac7e",
    },
    "adb0307": {
        "reason": "omp-bridge --plan-status bare-slug fix (declared miss)",
        "patch-id": "697027ae813c96d0bc7638841aa542fe833972a6",
    },
    # declared post-hoc 2026-09-11: machine worker committed to repo-root
    # scripts/ under the automation free-commit rule without the candidate
    # label; change operator-approved (dispatch frame + blocker auto-unpark),
    # full automation suite green at commit time
    "41f646a": {
        "reason": "auto-unpark blocker cooldown + README daily dispatch frame (declared miss)",
        "patch-id": "d72c1f2c8248d8f23944898278398f5ed0c38c40",
    },
    # declared post-hoc 2026-09-12: narrative daily ledger + public
    # dispatch edition (machine worker, operator-directed beat; automation
    # suite green at commit time). The daily journal writer
    # (scripts/generate-publication) carries the narrative layer and the
    # public dispatch edition; the miss is the same class as 41f646a --
    # declared, not rewritten.
    "226de1d": {
        "reason": "narrative daily ledger + public dispatch edition (declared miss)",
        "patch-id": "38ad9a7cc2679d4dad027bb8fe3f6a4e277e198f",
    },
    # declared post-hoc 2026-09-12: stale-badge CI cure (operator-directed
    # mission) touched tests/scripts/test-dashboard-live.py without a
    # candidate label; TERM=dumb graceful skip, automation suite green at
    # commit time; declared per the 41f646a precedent, not rewritten
    "4fc4a0f": {
        "reason": "CI push-trigger + dashboard-live TERM robustness (declared miss)",
        "patch-id": "ae8b9f0569e6ea0c8a14ca66445d664069e99529",
    },
    # declared post-hoc 2026-09-12: CI-green chase (operator-directed
    # mission) touched tests/scripts/test-dashboard-tui.py; textual-missing
    # skip for the help banner, automation suite green at commit time
    "0e3b2c6": {
        "reason": "tui help textual-missing skip + CI sbcl prereq (declared miss)",
        "patch-id": "92bdff695bb02f8d57d3eb3e3a9f50e5744d9907",
    },
    # same CI-green chase, 2026-09-12: hngh-services machine-path
    # resolution skips foreign hosts; automation suite green at commit
    "20700c9": {
        "reason": "hngh-services foreign-host path skip (declared miss)",
        "patch-id": "a1b23363e5daa52760432e9bae9b52f8c3322794",
    },
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
    out = run(["git", "diff", "--name-only", diff_base(sha), sha]).stdout
    return any(p.startswith(prefix) for p in out.splitlines()
               for prefix in CODE_SURFACE)

def code_files(sha):
    out = run(["git", "diff", "--name-only", diff_base(sha), sha]).stdout
    return [p for p in out.splitlines()
            if any(p.startswith(prefix) for prefix in CODE_SURFACE)]

def diff_base(sha):
    # graft/squash imports (git subtree add --squash) land as parentless
    # root commits; diff them against the empty tree
    parents = run(["git", "rev-list", "--parents", "-n", "1", sha]).stdout.split()
    return parents[1] if len(parents) > 1 else EMPTY_TREE


UNREACHABLE_NOTE = ("exemption unreachable - history was rewritten; "
                    "re-declare via ceremony (docs/project/decisions.md)")


def reachable(sha):
    proc = subprocess.run(["git", "merge-base", "--is-ancestor", sha, "HEAD"],
                          capture_output=True)
    return proc.returncode == 0


def patch_id(sha):
    show = run(["git", "show", sha]).stdout
    out = subprocess.run(["git", "patch-id", "--stable"], input=show,
                         capture_output=True, text=True, check=True).stdout
    parts = out.split()
    return parts[0] if parts else ""


def registered_patch_ids(table=None):
    table = KNOWN_EXEMPTIONS if table is None else table
    return {entry["patch-id"] for entry in table.values()}


def exempted_by(sha, table=None):
    # hash is primary; patch-id is the purge-proof fallback (the hash may
    # dangle after a history rewrite, but the same patch re-keyed under a
    # new hash still matches the registered patch-id)
    table = KNOWN_EXEMPTIONS if table is None else table
    if sha in table:
        return True
    pid = patch_id(sha)
    return bool(pid) and pid in registered_patch_ids(table)


def main():
    violations = []
    checked = 0
    exempted = 0
    # standing self-check: every registered exemption hash must resolve in
    # reachable history; a dangling hash fails with a self-naming message
    for sha in KNOWN_EXEMPTIONS:
        if not reachable(sha):
            violations.append((sha, UNREACHABLE_NOTE))
    for sha, subject in commits_since(RESTATEMENT):
        if SUBTREE_SQUASH.match(subject):
            # git-subtree --squash root: a parentless graft commit carrying the
            # imported tree unprefixed; its content is judged at the merge
            # commit, where the paths land under the subtree prefix
            continue
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
        # last-chance purge-proof fallback: would-be violation whose
        # patch-id matches a registered declaration is still exempted
        if exempted_by(sha):
            exempted += 1
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