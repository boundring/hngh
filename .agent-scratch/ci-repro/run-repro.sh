#!/usr/bin/env bash
# Reproduce the CI 'Test local kernel' failure exactly:
# scratch HOME + seeded session-store fixture + HNGH_CI=1, as in .github/workflows/ci.yml
set -u
REPO=/home/bricker/Projects/etc/hngh
SCRATCH="$REPO/.agent-scratch/ci-repro"
mkdir -p "$SCRATCH/home/.hngh-automation/store"
cp -r "$REPO/.github/fixtures/ci-store/run-1" "$SCRATCH/home/.hngh-automation/store/"
cd "$REPO"
env HOME="$SCRATCH/home" HNGH_CI=1 make test > "$SCRATCH/test.log" 2>&1
echo "rc=$?"
tail -5 "$SCRATCH/test.log"
echo "--- failures ---"
grep -nE "FAIL" "$SCRATCH/test.log" | head -20
