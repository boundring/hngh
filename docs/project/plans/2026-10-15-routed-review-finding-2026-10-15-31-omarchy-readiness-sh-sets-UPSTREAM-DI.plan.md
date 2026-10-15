<!-- plan: status=accepted risk=normal accepted=2026-10-15T11:06:40Z routed-from=review-finding:2026-10-15:31-omarchy-readiness-sh-sets-UPSTREAM-DI -->
<!-- attempt: 1 -->
<!-- expires: 2026-10-22T11:00:12Z -->
principle: routed candidates keep alert lineage machine-visible (docs/project/plans/README.md)
# 2026-10-15 — routed candidate

Routed by scripts/router-tick.py from alert identity `review-finding:2026-10-15:31-omarchy-readiness-sh-sets-UPSTREAM-DI`
at 2026-10-15T11:00:12Z. Alert text: 31-omarchy-readiness.sh sets `UPSTREAM_DIR="$OMARCHY_RUNTIME_DIR"` bare under `set -u` and the script does not source lib/common.sh (it bootstraps standalone, per its own ETC_ROOT seam) — with the var unset the readiness check dies with unbound-variable instead of reporting phase1 a=no; needs `"${OMARCHY_RUNTIME_DIR:-$HOME/.local/share/omarchy}"` like the other standalone jobs. fix or park with cause

## Steps

- [ ] Fix the review finding in docs/automation with a named verification
      Verification: the finding's own check passes; `make test` green
