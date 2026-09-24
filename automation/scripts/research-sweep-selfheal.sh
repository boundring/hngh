#!/usr/bin/env bash
# research-sweep-selfheal.sh -- cadence cure for the 2026-09-22 gate
# flap (alert 81bccb06 x14): overnight agent sessions committed rows
# with raw home tokens past the sealed writer seams; the
# research-tsv-path-sweep --check red-gated `make test` hourly and plan
# acceptance sat blocked until a manual back-redact landed (fc74aa3b,
# 12h later). The sweep already ships the cure -- --apply rewrites
# HEAD blobs through redact_home -- but nothing in the cadence called
# it. This script is that caller: --check; on leaks run --apply and
# commit ONLY the swept paths (staged-index fail-closed guard, the
# research_commit convention). --apply refuses dirty files (live-beat
# churn and uncommitted overnight rows); those stay for the gate alert
# + the beat's own redact-at-write seams. Fail-soft by design: any
# error exits 0 and leaves the gate alert as the backstop.
# Env: AUTOMATION_ROOT (default: the script's parent dir), KERNEL
# (default: AUTOMATION_ROOT), JOB_NAME (breadcrumb job; default this
# script's name).
root="${AUTOMATION_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
kernel="${KERNEL:-$root}"
job="${JOB_NAME:-research-sweep-selfheal.sh}"
[ -f "$root/lib/breadcrumbs.sh" ] && . "$root/lib/breadcrumbs.sh"
sweep="$root/scripts/research-tsv-path-sweep.py"
[ -f "$sweep" ] || exit 0
cd "$kernel" 2>/dev/null || exit 0 # default scope needs a repo CWD

python3 "$sweep" --check >/dev/null 2>&1
[ "$?" -eq 1 ] || exit 0 # green or usage/env error: no heal

out="$(python3 "$sweep" --apply 2>&1)" || :
# rc=2 (dirty refusals) still counts: whatever got rewritten gets
# committed; the refused files stay for the gate alert.
paths=()
while IFS= read -r line; do
  case "$line" in *": rewrote from HEAD "*)
    p="${line%%: rewrote from HEAD*}"
    [ -f "$p" ] || continue
    rel="$(realpath --relative-to="$kernel" "$p" 2>/dev/null)" || continue
    case "$rel" in ..*) continue ;; esac
    paths+=("$rel")
    ;;
  esac
done < <(printf '%s\n' "$out")
[ "${#paths[@]}" -ge 1 ] || exit 0

# staged-index fail-closed (research_commit convention): never commit
# when operator or another writer already staged work.
git -C "$kernel" diff --cached --quiet 2>/dev/null || exit 0
git -C "$kernel" add -- "${paths[@]}" 2>/dev/null || exit 0
git -C "$kernel" -c user.name="boundring" -c user.email="boundring@gmail.com" \
  commit -q -m "automation: sweep self-heal back-redacts raw home tokens (research-tsv-path-sweep --apply)" \
  -- "${paths[@]}" 2>/dev/null &&
  breadcrumb "$job" "sweep-selfheal" "back-redacted: ${paths[*]}"
exit 0
