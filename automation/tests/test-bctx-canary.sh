#!/usr/bin/env bash
# test-bctx-canary.sh -- contract proofs for the billion-context
# config-drift canary (cadence/day/23-bctx-canary.sh) and the stale
# updater fix (scripts/hngh-omp-update.sh):
#   canary: live config matching the Inventory row -> silent ok row;
#     drift (expected vs found) -> ONE identity-deduped alert row;
#     missing config file -> 'bctx config missing' alert;
#     env BCTX_MAX_CONTEXT overrides the Inventory row.
#   updater: the deprecated billion-context-omp/-pi installs are gone
#     and the proxy ensure line is present.
# Hermetic: fixture configs + sandboxed report root; the real
# ~/.config/billion-context is never touched.
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"
sb="$(mktemp -d)"
trap 'rm -rf "$sb"' EXIT

ok() { echo "ok: $1"; }
need() { "$@" || {
  echo "FAIL: $*"
  exit 1
}; } # every case fatal

mkdir -p "$sb/root"

cfg() { # maxContextLimit emergency nudge
  cat >"$sb/cfg.json" <<EOF
{"compress":{"maxContextLimit":"$1","emergencyThresholdPercent":"$2","nudgeGrowthTokens":$3},"providers":{}}
EOF
}
rows() {
  cat "$sb/root/docs/project/reports.md" 2>/dev/null || true
  cat "$sb/root/docs/project/report-bodies/"*.md 2>/dev/null || true
}
run() {
  BCTX_CONFIG="$sb/cfg.json" HNGH_REPORT_ROOT="$sb/root" \
    HNGH_HOME="$(cd "$root/.." && pwd)" \
    bash "$root/cadence/day/23-bctx-canary.sh"
}
reset() {
  rm -rf "$sb/root"
  mkdir -p "$sb/root"
} # fresh report window

# case 1: live 44% matches the Inventory row -> silent ok row
cfg 44% 75 20000
run
need grep -q "expected 44% found 44%" < <(rows)
need grep -q "bctx-canary-ok" < <(rows)
need grep -q "emergencyThresholdPercent=75 nudgeGrowthTokens=20000" < <(rows)
ok "canary: config match -> ok row carries all three knobs"

# case 2: drift (config says 40%, row says 44%) -> drift alert
cfg 40% 75 20000
run
need grep -q "expected 44% found 40%" < <(rows)
need grep -q "bctx-config-drift" < <(rows)
need grep -q "DRIFT" < <(rows)
ok "canary: budget drift -> alert with expected vs found"

# case 3: env override beats the Inventory row -> 40% is then a match
reset
BCTX_CONFIG="$sb/cfg.json" HNGH_REPORT_ROOT="$sb/root" \
  BCTX_MAX_CONTEXT=40% HNGH_HOME="$(cd "$root/.." && pwd)" \
  bash "$root/cadence/day/23-bctx-canary.sh"
need grep -q "expected 40% found 40%" < <(rows)
ok "canary: env BCTX_MAX_CONTEXT overrides the row"

# case 4: missing config file -> 'bctx config missing' alert
rm -f "$sb/cfg.json"
run
need grep -q "bctx config missing" < <(rows)
need grep -q "bctx-config-missing" < <(rows)
ok "canary: missing config -> alert, exit 0"

# case 5: updater cannot resurrect the deprecated extensions
need grep -q "billion-context@latest" "$root/scripts/hngh-omp-update.sh"
need bash -c "! grep -q 'billion-context-omp@latest\|billion-context-pi@latest' '$root/scripts/hngh-omp-update.sh'"
ok "updater: deprecated installs gone, proxy ensure line present"

echo "all bctx-canary cases passed"
