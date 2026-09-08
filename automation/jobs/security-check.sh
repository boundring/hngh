#!/usr/bin/env bash
# security-check — every 4h: hngh repo upstream diff + local test run, local
# model-server health, breadcrumbs, dogfood. Fail-closed: exits 0.
set -u
. "$(cd "$(dirname "$0")/.." && pwd)/lib/common.sh"
. "$AUTOMATION_ROOT/lib/breadcrumbs.sh"
. "$AUTOMATION_ROOT/lib/hngh-record.sh"

TS="$(date +%H%M)"

# --- 1. hngh repo upstream movement (read-only; we never modify the repo) ---
if [ -d "$HNGH_HOME/.git" ]; then
  upstream_before="$(git -C "$HNGH_HOME" rev-parse origin/main 2>/dev/null || echo unknown)"
  git -C "$HNGH_HOME" fetch origin main >/dev/null 2>&1
  fetch_rc=$?
  upstream_after="$(git -C "$HNGH_HOME" rev-parse origin/main 2>/dev/null || echo unknown)"
  if [ "$fetch_rc" = "0" ] && [ "$upstream_before" != "$upstream_after" ]; then
    breadcrumb "$JOB_NAME" "hngh-upstream" "origin/main moved: $upstream_before -> $upstream_after"
    test_out="$( (cd "$HNGH_HOME" && make test) 2>&1 )"
    test_rc=$?
    if [ "$test_rc" = "0" ]; then
      breadcrumb "$JOB_NAME" "hngh-test" "make test PASSED on moved origin/main"
    else
      tail="$(printf '%s\n' "$test_out" | tail -n 12)"
      breadcrumb "$JOB_NAME" "hngh-test" "make test FAILED rc=$test_rc; tail: $tail"
    fi
  else
    breadcrumb "$JOB_NAME" "hngh-upstream" "origin/main unchanged (fetch rc=$fetch_rc)"
  fi
else
  breadcrumb "$JOB_NAME" "hngh-upstream" "HNGH_HOME has no .git; skipped"
fi

# --- 2. local model-server health ---
u_ok=0; o_ok=0
curl -s --max-time 10 -o /dev/null -w '%{http_code}' "$UNSLOTH_URL/v1/models" 2>/dev/null | grep -q '^200' && u_ok=1
curl -s --max-time 10 -o /dev/null "$OLLAMA_URL/api/tags" 2>/dev/null && o_ok=1
breadcrumb "$JOB_NAME" "health" "unsloth=$u_ok ollama=$o_ok"

# --- 2.5 identifier lint (fail-closed: typos stop the world before they ship) ---
if out="$(bash "$AUTOMATION_ROOT/scripts/lint-identifiers.sh" 2>&1)"; then
  breadcrumb "$JOB_NAME" "lint" "identifier lint clean"
else
  breadcrumb "$JOB_NAME" "lint" "IDENTIFIER LINT FAILED: $out"
fi

# --- 3. repo public stats + traffic snapshot (launch observability) ---
if command -v gh >/dev/null 2>&1; then
  stats="$(gh repo view boundring/hngh --json stargazerCount,forkCount,watchers \
             --jq '{stars: .stargazerCount, forks: .forkCount, watchers: .watchers.totalCount}' 2>/dev/null || true)"
  views="$(gh api repos/boundring/hngh/traffic/views \
             --jq '{views_14d: .count, uniques_14d: .uniques}' 2>/dev/null || true)"
  clones="$(gh api repos/boundring/hngh/traffic/clones \
              --jq '{clones_14d: .count, uniques_14d: .uniques}' 2>/dev/null || true)"
  if [ -n "$stats" ]; then
    mkdir -p "$AUTOMATION_ROOT/stats"
    printf '{"ts":"%s","stats":%s,"views":%s,"clones":%s}\n' \
      "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$stats" \
      "${views:-null}" "${clones:-null}" >> "$AUTOMATION_ROOT/stats/repo-stats.jsonl"
    prev="$(cat "$AUTOMATION_ROOT/tmp-repo-stats-prev" 2>/dev/null || true)"
    if [ -n "$prev" ] && [ "$prev" != "$stats" ]; then
      breadcrumb "$JOB_NAME" "repo-stats" "public stats changed: $prev -> $stats"
    fi
    printf '%s' "$stats" > "$AUTOMATION_ROOT/tmp-repo-stats-prev"
  else
    breadcrumb "$JOB_NAME" "repo-stats" "gh unavailable or unauthenticated; skipped"
  fi
fi

# --- 4. dogfood ---
record_hngh_run "security check $TS"
exit 0