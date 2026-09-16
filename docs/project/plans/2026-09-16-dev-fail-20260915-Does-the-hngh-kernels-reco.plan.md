<!-- plan: status=proposed risk=normal accepted=- -->
# 2026-09-16 - dev-fail-20260915-Does-the-hngh-kernels-reco (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

The plan implements the research line `fail-20260915-If-drift-is-confirmed-in-the-scroll-beha`, which identifies a systemic "duplicated-and-diverged" failure class in dashboard behaviors (e.g., verdict rules, timezone rendering) lacking shared contract tests. It addresses this by establishing a single source of truth for dashboard state logic and adding regression tests to prevent silent divergence between nominally-shared surfaces.

## Steps

- [ ] Create `lib/dashboard/state.py` defining the canonical state transition logic for tab persistence and scroll behavior.
  Verification: python3 -c "import sys; sys.path.insert(0, 'lib'); from dashboard.state import get_state; print(get_state('init'))"

- [ ] Add `tests/test_dashboard_state.py` to assert that the shared state module produces consistent outputs for known input sequences.
  Verification: make test

- [ ] Update `dashboard/index.html` to remove inline JavaScript logic for tab-state persistence and import from the shared state definition.
  Verification: grep -q "import.*state" dashboard/index.html

- [ ] Create `scripts/check_dashboard_drift.sh` to verify that no duplicate state logic exists in other dashboard files.
  Verification: bash -n scripts/check_dashboard_drift.sh

- [ ] Run the drift check script against the repository to confirm no divergent copies remain.
  Verification: bash scripts/check_dashboard_drift.sh
