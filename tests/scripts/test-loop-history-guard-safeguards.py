#!/usr/bin/env python3
"""Unit cases for the loop-history guard's purge-proof safeguards.

1. reachability self-check: a registered hash that is unreachable from
   HEAD (orphaned by a history rewrite) is flagged, with a message that
   names the re-declaration cure.
2. patch-id fallback: a commit whose hash dangles but whose patch-id
   matches a registered declaration is still exempted.
3. standing table check: every registered exemption is reachable and
   its registered patch-id still matches the real commit.
"""

import importlib.util
import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))


def load_guard():
    spec = importlib.util.spec_from_file_location(
        "loop_history_guard",
        os.path.join(HERE, "test-loop-history-guard.py"))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def main():
    os.chdir(ROOT)
    guard = load_guard()

    def patch_id_of(sha):
        out = subprocess.run(["git", "patch-id", "--stable"],
                             input=subprocess.run(
                                 ["git", "show", sha],
                                 capture_output=True, text=True,
                                 check=True).stdout,
                             capture_output=True, text=True, check=True).stdout
        return out.split()[0]

    # deterministic, never-referenced dangling commit: content-addressed,
    # so the object is created once and reused across runs; it stays
    # unreachable from every ref
    env = dict(os.environ,
               GIT_AUTHOR_NAME="fixture", GIT_AUTHOR_EMAIL="fixture@invalid",
               GIT_AUTHOR_DATE="2026-01-01T00:00:00+0000",
               GIT_COMMITTER_NAME="fixture",
               GIT_COMMITTER_EMAIL="fixture@invalid",
               GIT_COMMITTER_DATE="2026-01-01T00:00:00+0000")
    dangling = subprocess.run(
        ["git", "commit-tree", "ef803bd16e170d18c3b1a644a8b958c117b963a4",
         "-m", "fixture: dangling exemption probe"],
        capture_output=True, text=True, env=env, check=True).stdout.strip()

    # 1. reachability self-check names a dangling exemption hash
    assert not guard.reachable(dangling), "fixture must be unreachable"
    assert "unreachable" in guard.UNREACHABLE_NOTE
    assert "re-declare via ceremony" in guard.UNREACHABLE_NOTE
    # live fixture: the pre-purge original (a2f4d0e), orphaned by the
    # 2026-09-11 secret-scrub filter-branch, is flagged unreachable
    assert not guard.reachable("a2f4d0e"), \
        "orphaned a2f4d0e must fail the reachability check"

    # 2. hash dangles but patch-id matches -> still exempted
    assert guard.exempted_by(
        dangling, table={dangling: {"patch-id": patch_id_of(dangling)}}), \
        "patch-id fallback must exempt a dangling-hash commit"

    # 3. standing table check: reachable hashes, no patch-id drift
    for sha, entry in guard.KNOWN_EXEMPTIONS.items():
        assert guard.reachable(sha), guard.UNREACHABLE_NOTE
        assert entry["patch-id"] == patch_id_of(sha), \
            f"registered patch-id drift for {sha}"

    print("loop-history guard safeguards: ok (reachability + patch-id fallback)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
