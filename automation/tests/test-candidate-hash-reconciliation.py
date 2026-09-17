#!/usr/bin/env python3
"""candidate-hash reconciliation patrol check, hermetic (2026-09-17,
a4e3 reconciliation closure): the loop-history guard accepts any subject
matching `^hngh: candidate [0-9a-f]{64}$` with no artifact to consult
(tests/scripts/test-loop-history-guard.py:193) and no minted-certificate
ledger exists anywhere (a4e2 verdict: store records carry no hashes, the
certificate struct is in-memory, the render goes to stdout only). The
feasible rung is the weaker cryptographic recompute: the 64-hex label
digests sha256(path+NUL+file-bytes+NUL) over the certificate's candidate
paths (scripts/verify-candidate.py:129), which for every recent commit
equal the commit's own changed paths + blob bytes -- so git alone can
verify label-to-content binding. Calibration on this repo: the 9 newest
candidate commits recompute exactly, 38/40 across the newest 40 (the two
misses are known 2026-09-15-era stragglers outside the check window).

The check walks the newest PATROL_RECON_LOOKBACK labeled commits
(default 24, day-tier heavy surface) in a REAL temp git repo (the
input is git history; synthetic fixtures would verify nothing), fails
closed on any divergence, and stays quiet when no labeled commits
exist (the label regex is the kernel gate's surface, not this check's).

The strict label-to-LEDGER reconciliation stays infeasible until the
kernel persists a mint-time artifact; the closure proposal lives in
docs/records/2026-09-17-candidate-reconciliation-closure.md."""

import importlib.util
import hashlib
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SPEC = ROOT / "jobs" / "patrol.py"
REPO = ROOT.parent  # the hngh repo (real routes table is pinned from here)


def load_mod():
    spec = importlib.util.spec_from_file_location("patrol_mod_recon", SPEC)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def candidate_hash(path_blobs):
    """The mint algorithm, verbatim semantics of
    scripts/verify-candidate.py:129: sha256 over
    path + NUL + bytes + NUL per path."""
    digest = hashlib.sha256()
    for path, blob in path_blobs:
        digest.update(path.encode("utf-8"))
        digest.update(b"\0")
        digest.update(blob)
        digest.update(b"\0")
    return digest.hexdigest()


class CandidateReconciliation(unittest.TestCase):
    """check_candidate_reconciliation against a REAL temp git repo."""

    def setUp(self):
        self._td = tempfile.TemporaryDirectory()
        self.repo = Path(self._td.name)
        env = dict(os.environ)
        # containment: strip repo-selection vars the caller may have
        # exported (2026-09-17 kernel-contamination lesson)
        for hostile in ("GIT_DIR", "GIT_WORK_TREE"):
            env.pop(hostile, None)
        for k in ("GIT_AUTHOR_NAME", "GIT_AUTHOR_EMAIL",
                  "GIT_COMMITTER_NAME", "GIT_COMMITTER_EMAIL"):
            env.setdefault(k, "t")
        env.setdefault("GIT_AUTHOR_DATE", "2026-09-17T00:00:00Z")
        env.setdefault("GIT_COMMITTER_DATE", "2026-09-17T00:00:00Z")
        self._env = env
        self._git("init", "-q")
        self._git("checkout", "-q", "-b", "main")
        (self.repo / "docs").mkdir()
        (self.repo / "docs" / "a.md").write_text("base\n")
        self._git("add", "-A")
        self._git("commit", "-q", "-m", "base")
        self.mod = load_mod()
        self._saved = os.environ.get("PATROL_RECON_LOOKBACK")
        os.environ.pop("PATROL_RECON_LOOKBACK", None)

    def tearDown(self):
        if self._saved is None:
            os.environ.pop("PATROL_RECON_LOOKBACK", None)
        else:
            os.environ["PATROL_RECON_LOOKBACK"] = self._saved
        self._td.cleanup()

    def _git(self, *argv):
        return subprocess.run(["git"] + list(argv), cwd=self.repo,
                              env=self._env, check=True,
                              capture_output=True, text=True)

    def _commit_labeled(self, subject_hash, rel_path, blob):
        """One candidate-labeled commit carrying <blob> at <rel_path>."""
        target = self.repo / rel_path
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(blob)
        self._git("add", "-A")
        self._git("commit", "-q", "-m",
                  "side work\n\nbody line mentions the ceremony\n")
        # amend the subject to the candidate label (git commit --amend -m
        # keeps the tree; the body proves the check reads subjects only)
        self._git("commit", "--amend", "-q",
                  "-m", "hngh: candidate %s\n\ncertified body line\n"
                  % subject_hash)
        return self._git("rev-parse", "HEAD").stdout.strip()

    def _run_check(self):
        return self.mod.check_candidate_reconciliation(
            {"kernel": str(self.repo)})

    # -- the failing-first core ---------------------------------------

    def test_check_is_registered_as_a_patrol_route(self):
        """Wiring: a CHECKS entry and a patrol-routes.tsv row (the
        kernel-gate pattern: day tier, bad-execution finding class)."""
        self.assertIn("candidate-reconciliation", self.mod.CHECKS)
        routes = (REPO / "automation" / "config"
                  / "patrol-routes.tsv").read_text().splitlines()
        rows = [r for r in routes
                if r and not r.startswith("#") and not
                r.startswith("patrol-id")]
        match = [r for r in rows
                 if r.split("\t")[2:3] == ["candidate-reconciliation"]]
        self.assertEqual(len(match), 1,
                         "exactly one routes row expected: %r" % match)
        cols = match[0].split("\t")
        self.assertEqual(cols[3], "day", cols)
        self.assertEqual(cols[4], "bad-execution", cols)

    def test_genuine_candidate_commit_passes(self):
        """A commit whose subject hash really digests its own changed
        paths + blob bytes reconciles: one PASS, no FAILs, detail
        carries the reconciled short sha."""
        blob = b"certificate-bearing content\n"
        self._commit_labeled(candidate_hash([("docs/cand.md", blob)]),
                             "docs/cand.md", blob)
        out = self._run_check()
        self.assertEqual(out["fails"], [], out)
        self.assertEqual(len(out["passes"]), 1, out)
        name, detail = out["passes"][0]
        self.assertEqual(name, "candidate-reconciliation", out)
        self.assertIn("1/1", detail, out)

    def test_forged_label_fails_closed(self):
        """The label binds different bytes than the tree carries: FAIL
        label-content-divergence naming the commit -- this is the check
        being landed for, the guard today accepts it silently."""
        genuine = candidate_hash([("docs/cand.md", b"genuine\n")])
        self._commit_labeled(genuine, "docs/cand.md", b"forged\n")
        out = self._run_check()
        self.assertEqual(out["passes"], [], out)
        self.assertEqual(len(out["fails"]), 1, out)
        artifact, cause, detail = out["fails"][0]
        self.assertEqual(artifact, "kernel", out)
        self.assertEqual(cause, "label-content-divergence", out)
        self.assertIn(genuine[:12], detail, out)

    def test_lookback_window_excludes_aged_divergence(self):
        """The window slides: a divergent commit older than
        PATROL_RECON_LOOKBACK labeled commits is outside the check
        (the two known pre-closure stragglers must not fire it
        forever), while the newest genuine one reconciles."""
        divergent = candidate_hash([("docs/old.md", b"right bytes\n")])
        self._commit_labeled(divergent, "docs/old.md", b"wrong bytes\n")
        for i in range(3):
            blob = ("fresh %d\n" % i).encode()
            self._commit_labeled(
                candidate_hash([("docs/new%d.md" % i, blob)]),
                "docs/new%d.md" % i, blob)
        os.environ["PATROL_RECON_LOOKBACK"] = "2"
        out = self._run_check()
        self.assertEqual(out["fails"], [], out)
        self.assertIn("2/2", out["passes"][0][1], out)

    def test_declared_exemptions_do_not_fire(self):
        """A divergent commit declared in the exemption table (sha
        prefix + reason, the guard's declared-miss convention) is
        counted in the pass detail, never a FAIL -- the two known
        pre-closure stragglers must not re-alert daily until they age
        out of the window."""
        divergent = candidate_hash([("docs/old.md", b"right bytes\n")])
        sha = self._commit_labeled(divergent, "docs/old.md",
                                   b"wrong bytes\n")
        exempts = self.repo.parent / "exempts.tsv"
        exempts.write_text(
            "# declared unreconcilable, pre-closure\n"
            "%s\tknown pre-closure straggler\n" % sha[:12])
        os.environ["PATROL_RECON_EXEMPTS"] = str(exempts)
        out = self._run_check()
        self.assertEqual(out["fails"], [], out)
        self.assertIn("declared 1", out["passes"][0][1], out)

    def test_no_labeled_commits_is_quiet(self):
        """No candidate labels = nothing to reconcile: PASS, not a
        fail-open gap and not a crash (a plain-history repo must not
        turn the patrol red)."""
        (self.repo / "docs" / "plain.md").write_text("x\n")
        self._git("add", "-A")
        self._git("commit", "-q", "-m", "automation: plain commit")
        out = self._run_check()
        self.assertEqual(out["fails"], [], out)
        self.assertEqual(len(out["passes"]), 1, out)

    def test_only_subject_line_is_read(self):
        """A body line shaped like a label is not evidence either way:
        the check reads the subject only (the guard's own rule)."""
        blob = b"content\n"
        self._commit_labeled(candidate_hash([("docs/b.md", blob)]),
                             "docs/b.md", blob)
        (self.repo / "docs" / "other.md").write_text("y\n")
        self._git("add", "-A")
        self._git("commit", "-q", "-m",
                  "automation: plain\n\nhngh: candidate %s\n"
                  % ("f" * 64))
        out = self._run_check()
        self.assertEqual(out["fails"], [], out)
        self.assertIn("1/1", out["passes"][0][1], out)


if __name__ == "__main__":
    unittest.main()
