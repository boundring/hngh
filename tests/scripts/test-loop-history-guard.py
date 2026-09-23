#!/usr/bin/env python3
"""Self-governance history guard: the README ceremony claim, machine-checked.

The root README states: "behavior changes ride the loop — proposal →
verdict → certificate → executor, under real evidence — and where the
loop itself refuses a binding (the dependency guard will not certify a
commit that changes no behavior), the exception is by rule, not by
mood."

This guard makes that sentence falsifiable: every commit after the
restatement (26b98590) (pre-rewrite c257bf6e) that touches the code surface (src/, tests/,
scripts/, Makefile, hngh.asd) must either be a certificate-bound
candidate commit or carry the rule-based exemption label. Anything else
is a violation and fails the gate.

The exemption label is not a free pass: a labeled commit may touch ONLY
src/packages.lisp (the single export-only file the dependency guard
refuses to bind). A labeled commit touching any other code-surface file
is a violation — a behavior change hiding behind the label is caught by
diff inspection, not just the message.

The single known pre-guard violation is 64420003 (comment-only alignment
of composition-root references, committed before this guard existed); it
is exempted by name below and recorded in docs/project/decisions.md.
History is not rewritten; enforcement starts from the restatement, with
that one blemish declared.

Declarations are purge-proof by construction. The registered hash is
primary; the patch-id (`git diff-tree -p --full-index --root <hash> |
git patch-id --stable`) is the
purge-proof fallback: a history rewrite (filter-branch/filter-repo)
re-keys descendant hashes but leaves patch content untouched, so a
commit whose registered hash dangles is still matched by patch-id. A
standing reachability self-check fails the gate when a registered hash
is no longer reachable from HEAD, with a message that names the cure:
re-declare via ceremony.
"""

import os
import re
import subprocess
import sys

# pre-rewrite c257bf6e; re-keyed across the 2026-09-23 path-scrub
# filter-repo rewrite
RESTATEMENT = "26b98590"
EMPTY_TREE = "4b825dc642cb6eb9a060e54bf8d69288fbee4904"
SUBTREE_SQUASH = re.compile(r"^Squashed '.*' content from commit [0-9a-f]+$")
KNOWN_EXEMPTIONS = {
    # keys re-keyed by ceremony across the 2026-09-23 path-scrub filter-repo rewrite
    # comment-only alignment of composition-root references; predates the guard
    "e2a23b22": {
        "reason": "comment-only docs alignment (pre-guard)",
        "patch-id": "09b439c8625b0c12d3bf402a5cf696af0157d6c2",
    },
    # portfolio docs commit that also touched a kernel script (2026-09-06),
    # landed outside the loop and already pushed; declared by name per the
    # 2026-08-25 decision, cured by ceremony record -- not rewritten.
    # patch-id corrected by the 2026-09-14 gate-cure (declared separately as
    # under the same commit's full prefix the same day; the two declarations
    # are merged here into one entry -- one commit, one exemption)
    "25c77422": {
        "reason": "portfolio ebook/journal commit touching a kernel script "
                  "(declared miss 2026-09-06, gate-cure 2026-09-14)",
        # re-registered under the hermetic full-index recipe
        # (2026-09-15 CI patch-id drift cure); only entry whose diff
        # contains a binary section (docs/publication/hngh-memoir.epub),
        # so only this id changes under the recipe
        # re-registered across the 2026-09-20 filter-repo rewrite (redacted
        # bytes live inside this entry's binary section)
        "patch-id": "ac8a40ad4433b32ac043994ab59f3ae2d18d76ca",
    },
    # 2026-09-15 declared miss: docs-ledger repair commit accidentally
    # swept the staged guard-cure edit (docs: message touching tests/);
    # the guard-cure content itself was separately certified by candidate
    # 2f9e618f (cd106b9d) in the same hour. Declared post-hoc per the
    # 44afc663 precedent; cured by this declaration -- not rewritten.
    "e8525546": {
        "reason": "docs ledger repair that swept a staged tests/ edit "
                  "(repair content certified separately by cd106b9d)",
        "patch-id": "752265b35015dbb50a0ac2714f2bcdc83eec9fe5",
    },
    # 2026-09-16 declared miss: queue Next-pointer advance swept the
    # staged packages.lisp export edit (docs: message touching src/);
    # the swept export content is inert (exports for landed kernel work).
    "01aeddfc": {
        "reason": "queue Next advance that swept a staged packages.lisp "
                  "export edit (swept content inert exports)",
        "patch-id": "9a0ba9df24112623d54e1b60cffdfd54f5f11d62",
    },

    # 2026-09-16 declared miss: the fbe55f82-cure commit swept an
    # automation tests/ edit into a kernel-tests/ declaration (mixed-lane
    # message); automation content separately gated by the automation tier.
    "1fa33ed3": {
        "reason": "mixed-lane cure commit (kernel declaration + automation "
                  "test tracking); automation content separately gated",
        "patch-id": "6c7f8cbd145ef255cf2d575704b7e2a50567e70d",
    },
    # omp-bridge --propose/--plan-status (integration plan step 3) and its
    # bare-slug fix: landed outside the loop on 2026-09-10 while the bridge
    # itself was being built; declared by name per the 2026-09-06 decision,
    # cured by post-hoc certification (2026-09-11) -- not rewritten.
    # hash post-purge (2026-09-11 secret-scrub filter-branch), same patch-id
    # as the declared original (a2f4d0e / 31768d2); re-keyed by ceremony
    "e4fba4e5": {
        "reason": "omp-bridge --propose/--plan-status (declared miss)",
        "patch-id": "558c84f7a35794b3368334fe3b1e0f1b15e8ac7e",
    },
    "1020b310": {
        "reason": "omp-bridge --plan-status bare-slug fix (declared miss)",
        "patch-id": "697027ae813c96d0bc7638841aa542fe833972a6",
    },
    # declared post-hoc 2026-09-11: machine worker committed to repo-root
    # scripts/ under the automation free-commit rule without the candidate
    # label; change operator-approved (dispatch frame + blocker auto-unpark),
    # full automation suite green at commit time
    "02797f58": {
        "reason": "auto-unpark blocker cooldown + README daily dispatch frame (declared miss)",
        "patch-id": "d72c1f2c8248d8f23944898278398f5ed0c38c40",
    },
    # declared post-hoc 2026-09-12: narrative daily ledger + public
    # dispatch edition (machine worker, operator-directed beat; automation
    # suite green at commit time). The daily journal writer
    # (scripts/generate-publication) carries the narrative layer and the
    # public dispatch edition; the miss is the same class as 214b8c2c --
    # declared, not rewritten.
    "07fbd0fc": {
        "reason": "narrative daily ledger + public dispatch edition (declared miss)",
        "patch-id": "38ad9a7cc2679d4dad027bb8fe3f6a4e277e198f",
    },
    # declared post-hoc 2026-09-12: stale-badge CI cure (operator-directed
    # mission) touched tests/scripts/test-dashboard-live.py without a
    # candidate label; TERM=dumb graceful skip, automation suite green at
    # commit time; declared per the 214b8c2c precedent, not rewritten
    "ff8311d4": {
        "reason": "CI push-trigger + dashboard-live TERM robustness (declared miss)",
        "patch-id": "ae8b9f0569e6ea0c8a14ca66445d664069e99529",
    },
    # declared post-hoc 2026-09-12: CI-green chase (operator-directed
    # mission) touched tests/scripts/test-dashboard-tui.py; textual-missing
    # skip for the help banner, automation suite green at commit time
    "c558f19e": {
        "reason": "tui help textual-missing skip + CI sbcl prereq (declared miss)",
        "patch-id": "92bdff695bb02f8d57d3eb3e3a9f50e5744d9907",
    },
    # same CI-green chase, 2026-09-12: hngh-services machine-path
    # resolution skips foreign hosts; automation suite green at commit
    "d2ec9ec8": {
        "reason": "hngh-services foreign-host path skip (declared miss)",
        "patch-id": "a1b23363e5daa52760432e9bae9b52f8c3322794",
    },
    # declared post-hoc 2026-09-13: the overnight fixture pair (author
    # Fixture <fixture@example.invalid>, landed 2026-09-13 00:04 with no
    # session handoff claiming it). 60ef555f gutted Makefile+README,
    # af92275f reverted it 47s later -- tree-net-zero, but each commit
    # individually touches the code surface without a candidate label.
    # A new class: not the machine-worker free-commit misses (214b8c2c,
    # 1898ad49) -- a synthetic pair appearing in kernel history. Declared
    # per the standing post-hoc policy, not rewritten; see the
    # 2026-09-13 decisions.md batch entry and the gate-cure patrol.
        "23f7ea93": {
        "reason": "UnicodeDecodeError fix: errors=replace on guard subprocess calls (Typesafe docs introduced 0xa9 bytes)",
        "patch-id": "c6a44ec855481f15508119b99b001f06748a64eb",
    },
                    "392f9673": {
        "reason": "adds ae485100 exemption (terminal: next commit is docs-only)",
        "patch-id": "ad1abbc8ccf86b6a3f3738c48c599773397eeb19",
    },
        "e7ae857d": {
        "reason": "terminal exemption commit: breaks the exemption regress (docs-only after this)",
        "patch-id": "5121b2b688200e341aef8d7da8e7e27786325dda",
    },
    "0a1b825a": {
        "reason": "cleanup of unreachable exemptions + da694e36 exemption (post-force-push table correction)",
        "patch-id": "83d7a2febe8d0ddb72d69b0028e371dc561d0dd1",
    },
    "6a9bba56": {
        "reason": "UnicodeDecodeError fix: errors=replace on guard subprocess calls (Typesafe docs 0xa9 bytes); exemptions for the unreachable force-push entries removed",
        "patch-id": "db1c70bf87d094696746f78a4bf25cb33f8d2b05",
    },
    "2bb4f416": {
        "reason": "fixture pair head: Makefile+README gut (declared miss)",
        "patch-id": "a46ed8ae5a64949d7e5dbe8917902e125586d5d3",
    },
    "cd93bf6b": {
        "reason": "fixture pair revert: restores Makefile+README (declared miss)",
        "patch-id": "cef31fa5a3ea871522e0a3ea3e537088c9a8952b",
    },
                                "92cd2bd1": {
        "reason": "add 722d8d48 exemption (STATE.md restore + guard meta-exemption chain)",
        "patch-id": "f7a4a35c5c650b153c8b4e2509b1b8f0e16f089c",
    },
    "227431ae": {
        "reason": "STATE.md restore + guard meta-exemption for 6a26962a (STATE.md is runtime state tests expect tracked)",
        "patch-id": "0f86cac917280d7f2f29bfe34ded86c31ea0c672",
    },
    "60573ecf": {
        "reason": "loop-history guard test fix: errors='replace' + 365d368a exemption (meta-exemption: modifies the guard itself)",
        "patch-id": "7e04be069396144922c56a0b7518629df280ea8d",
    },
    "5c235a97": {
        "reason": "batch stable-point snapshot before restart: worker-modified test files committed together (gate 2931 green, declared miss)",
        # pre-rewrite registered id a9cdae6a... already matched the
        # guard's text-mode recipe on the post-rewrite commit (binary
        # cookie bytes differ under bytes- vs text-mode hashing);
        # kept as-is across the 2026-09-20 filter-repo rewrite.
        "patch-id": "a9cdae6afaaf938a3910d0988c9d51838aba79b3",
    },

    # fix: report-queue evidence-gated dedup — stale condition re-alerts suppressed -- kernel-gate red cure 2026-09-13, declared not rewritten
    "1af92a45": {
        "reason": "fix: report-queue evidence-gated dedup — stale condition re-alerts suppressed (declared miss, gate-cure patrol)",
        "patch-id": "891d22e68a3121dfabdf780bb4c685772c4eac60",
    },
    # fix: omp-bridge --ceremony cleans its ephemeral store on every exit path -- kernel-gate red cure 2026-09-13, declared not rewritten
    "8261c54c": {
        "reason": "fix: omp-bridge --ceremony cleans its ephemeral store on every exit path (declared miss, gate-cure patrol)",
        "patch-id": "dff584c160b3d902f8cf36ad977f11a7386b7730",
    },
    # declared post-hoc 2026-09-14: CI-green chase (operator-directed,
    # "commit and push at-will for CI fixes") touched scripts/fleet-manager
    # without a candidate label: the capitalized Peer map acceptance that
    # test-system-awareness.sh case C exercises. Automation suite green at
    # commit time; declared per the 214b8c2c precedent, not rewritten.
    "b22ad44a": {
        "reason": "fleet-manager capitalized Peer map acceptance (declared miss, CI-green chase)",
        "patch-id": "643d451075296e2dca554060f86d0d13a27607d2",
    },
    # (gate-cure declaration of 2026-09-14 merged into the 44afc663
    # entry above: same commit, registered once)
    # declared post-hoc 2026-09-18: tests-only pin commit touching
    # tests/scripts/test-probe-model-route.py (HTTPError branch is live)
    # without a candidate label; pre-existing origin history, gate-cured
    # per the standing post-hoc policy (docs/records/
    # 2026-09-18-loop-history-gate-cure-10cbb5eb.md), not rewritten.
    "3771ed1a": {
        "reason": "tests: pin probe-model-route HTTPError-is-live branch "
                  "(declared miss, gate-cure patrol 2026-09-18)",
        "patch-id": "9fd6d94e9972ae4bc7e7dbb8adc5fc1a488d126a",
    },
    # tests: break exemption infinite regress (terminal commit) -- kernel-gate red cure 2026-09-17, declared not rewritten
    "96eafe71": {
        "reason": "tests: break exemption infinite regress (terminal commit) (declared miss, gate-cure patrol)",
        "patch-id": "a214f7b06e3d11e4014b9d403210ab4065c5e686",
    },
}

CODE_SURFACE = ("src/", "tests/", "scripts/", "Makefile", "hngh.asd")
CANDIDATE = re.compile(r"^hngh: candidate [0-9a-f]{64}$")
EXEMPT = "excluded from cert manifest by dependency guard"
EXEMPT_ALLOWED_FILES = {"src/packages.lisp"}

# The guard audits the repository its script lives in. Pin git repo
# selection explicitly: an exported GIT_DIR/GIT_WORK_TREE would
# otherwise silently re-point every read (commits_since, reachable,
# patch_id) at a foreign repository -- or crash the gate outright
# (2026-09-17 kernel-contamination lesson).
HERE = os.path.dirname(os.path.abspath(__file__))
KERNEL_GIT_DIR = subprocess.run(
    ["git", "-C", os.path.join(HERE, "..", ".."),
     "rev-parse", "--absolute-git-dir"],
    capture_output=True, text=True, errors='replace', check=True,
    env={k: v for k, v in os.environ.items()
         if k not in ("GIT_DIR", "GIT_WORK_TREE")}).stdout.strip()


def run(argv):
    return subprocess.run(
        ["git", "--git-dir", KERNEL_GIT_DIR] + list(argv[1:]) if argv
        and argv[0] == "git" else argv,
        capture_output=True, text=True, errors='replace', check=True)


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
    proc = subprocess.run(
        ["git", "--git-dir", KERNEL_GIT_DIR,
         "merge-base", "--is-ancestor", sha, "HEAD"],
        capture_output=True)
    return proc.returncode == 0


def patch_id(sha):
    # Hermetic recipe (2026-09-15 CI patch-id drift cure): full-index and
    # pinned EMPTY_TREE base remove core.abbrev=auto dependence, which
    # made binary-diff ids differ between this aged repo (8-hex index
    # lines) and a fresh CI checkout (7-hex). See
    # docs/records/2026-09-15-ci-patch-id-drift.md (Correction section).
    diff = run(["git", "diff-tree", "-p", "--full-index", "--root", sha]).stdout
    out = subprocess.run(
        ["git", "--git-dir", KERNEL_GIT_DIR, "patch-id", "--stable"],
        input=diff, capture_output=True, text=True, errors='replace', check=True).stdout
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