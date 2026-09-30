#!/usr/bin/env bash
# test-slice-e-seam-surface.sh — governed-fleet slice E surface, hermetic
# (the test-credential-health-argv.sh pattern: the FULL jobs/credential-
# health.sh runs against a stub curl in a sandboxed HOME — no network, no
# secret values, no real report ledger):
# (1) section 9 credential-seam sweep: bare env -> dormant crumbs, exit 0;
#     a mode-600 kimi key file -> one token-only-verified crumb; a 644 key
#     file -> an alert row naming the mode and the VALUE never appears in
#     any sink (reports ledger, crumbs journal, stderr).
# (2) section 10 pinned-key freshness (peer admission wiring): unconfigured
#     PEER_TOKEN_FILE -> silent; a 600 peer key seeds the freshness ledger
#     with one peer-pin digest row (no value); a 644 peer key -> alert row,
#     no seed.
# (3) cadence-params row model-tier-refresh-ola resolves through params.sh
#     to the drop-in's designed default (7776000 = 90d).
# (4) monthly drop-in 02-model-tier-refresh.sh, observed through the
#     report-queue seam (docs/project/reports.md rows under the sandboxed
#     HNGH_REPORT_ROOT): fresh digest -> no alert row; stale digest -> one
#     alert row citing the digest name and the 90d OLA; missing digest ->
#     scope breadcrumb, no alert row; bogus OLA -> fail-open to 90d and
#     still files (in a fresh reports root, dodging identity dedup).
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"
sb="$(mktemp -d)"
trap 'rm -rf "$sb"' EXIT
mkdir -p "$sb/bin" "$sb/home" "$sb/digest" "$sb/queue" "$sb/queue2"
export HNGH_CRUMBS_DB="$sb/home/crumbs.db"
fails=0
ck() { # desc expected actual
  if [ "$2" = "$3" ]; then echo "ok: $1"; else
    echo "FAIL: $1 (want [$2] got [$3])"
    fails=$((fails + 1))
  fi
}
# stub curl: answers HTTP 200 instantly so the section 1-6 probes stay
# quiet and hermetic (no network); the stub never sees a real endpoint.
cat >"$sb/bin/curl" <<'EOF'
#!/usr/bin/env bash
echo "200"
EOF
chmod +x "$sb/bin/curl"

# run the FULL credential-health.sh hermetically; args = extra K=V env.
# The unsloth pair is always armed (600 stub files) so sections 1-6 stay
# quiet; per-case env arms only the seam under test.
call() {
  local kv
  (
    export HOME="$sb" AUTOMATION_ROOT="$root" PATH="$sb/bin:$PATH"
    export JOB_NAME=test-slice-e HNGH_HOME="$root/.."
    export HNGH_REPORT_ROOT="$sb" HNGH_HOME_DIR="$sb/.hngh"
    export CREDENTIAL_FRESHNESS_LEDGER="$sb/fresh.tsv"
    export CREDENTIAL_FRESHNESS_OLA=604800
    export TOKEN_FILE="$sb/tok" REFRESH_FILE="$sb/refresh"
    # the operator's session may arm real channels — hermetic runs start bare
    unset TELEGRAM_BOT_TOKEN TELEGRAM_CHAT_ID HNGH_WEBHOOK_URL HNGH_NOTIFY_EMAIL_CONF
    unset MOONSHOTAI_API_KEY KIMI_AI_KEY KIMI_FOR_CODING_KEY KIMI_KEY_FILE KIMI_URL
    unset OPENCODE_API_KEY OPENCODE_KEY_FILE OCGO_URL
    unset ZAI_KEY_FILE XIAOMI_KEY_FILE REMOTE_TOKEN_FILE PEER_TOKEN_FILE
    printf 'unsloth-stub-not-a-real-key\n' >"$sb/tok"
    printf 'refresh-stub-not-a-real-key\n' >"$sb/refresh"
    chmod 600 "$sb/tok" "$sb/refresh"
    rm -f "$sb/fresh.tsv"
    for kv in "$@"; do export "$kv"; done
    timeout 60 bash "$root/jobs/credential-health.sh" >/dev/null 2>"$sb/stderr.log"
    echo "rc=$?"
  )
}
reports() { cat "${1:-$sb}/docs/project/reports.md" 2>/dev/null; }
crumbs() { python3 -B "$root/lib/crumbs-db.py" export --db "$HNGH_CRUMBS_DB" 2>/dev/null; }
crumbs_reset() { rm -f "$HNGH_CRUMBS_DB" "$HNGH_CRUMBS_DB-wal" "$HNGH_CRUMBS_DB-shm"; }

# --- 1. bare env (no kimi/peer keys): dormant crumbs, exit 0, no crash ---
crumbs_reset
out="$(call)"
ck "bare env: exit 0" "rc=0" "$out"
ck "bare env: no crash" "0" "$(grep -c 'command not found' "$sb/stderr.log" 2>/dev/null || true)"
ck "bare env: kimi dormant crumb" "1" "$(crumbs | grep -cF 'kimi: dormant' || true)"
ck "bare env: no seam alert" "0" "$(reports | grep -c 'credential seam-' || true)"

# --- 2. 600 kimi key: token-only verified crumb ---
printf 'kimi-stub-not-a-real-key\n' >"$sb/kimi-key"
chmod 600 "$sb/kimi-key"
crumbs_reset
out="$(call KIMI_KEY_FILE="$sb/kimi-key")"
ck "600 kimi: exit 0" "rc=0" "$out"
ck "600 kimi: verified crumb" "1" "$(crumbs | grep -cF 'kimi: token-only verified' || true)"

# --- 3. 644 kimi key: alert row, value never read ---
chmod 644 "$sb/kimi-key"
crumbs_reset
out="$(call KIMI_KEY_FILE="$sb/kimi-key")"
ck "644 kimi: exit 0" "rc=0" "$out"
ck "644 kimi: mode alert row" "1" "$(reports | grep -cF 'seam-kimi' || true)"
leaked=never-read
{ reports; crumbs; cat "$sb/stderr.log"; } | grep -qF 'kimi-stub' && leaked=leaked
ck "644 kimi: value never read" "never-read" "$leaked"

# --- 4. peer unconfigured: silent ---
rm -f "$sb/kimi-key"
crumbs_reset
out="$(call)"
ck "peer unconfigured: no peer-pin crumb" "0" "$(crumbs | grep -cF 'peer-pin' || true)"
ck "peer unconfigured: no peer alert" "0" "$(reports | grep -cF 'peer-pin' || true)"

# --- 5. peer 600: ledger seeded with a digest-only peer-pin row ---
printf 'peer-stub-not-a-real-key\n' >"$sb/peer-key"
chmod 600 "$sb/peer-key"
crumbs_reset
out="$(call PEER_TOKEN_FILE="$sb/peer-key")"
ck "peer 600: exit 0" "rc=0" "$out"
ck "peer 600: ledger seeded" "1" "$(grep -cP '^peer-pin\t' "$sb/fresh.tsv" 2>/dev/null || true)"
leaked=digest-only
grep -qF 'peer-stub' "$sb/fresh.tsv" && leaked=leaked
ck "peer 600: ledger digest-only" "digest-only" "$leaked"
ck "peer 600: freshness checked crumb" "1" "$(crumbs | grep -cF 'peer key freshness checked' || true)"

# --- 6. peer 644: alert row, seed refused ---
chmod 644 "$sb/peer-key"
crumbs_reset
out="$(call PEER_TOKEN_FILE="$sb/peer-key")"
ck "peer 644: mode alert row" "1" "$(reports | grep -c 'peer-pin.*too open' || true)"
[ -e "$sb/fresh.tsv" ] && peer_rows="$(grep -cP '^peer-pin\t' "$sb/fresh.tsv" 2>/dev/null || true)" || peer_rows=0
ck "peer 644: no peer-pin row (unsloth rows may exist; section 7 bootstraps first)" "0" "$peer_rows"

# --- 7. cadence-params row resolves through params.sh ---
ola="$( . "$root/lib/params.sh"; get_param model-tier-refresh-ola MISSING )"
ck "params row resolvable" "7776000" "$ola"

# --- 8. monthly drop-in: fresh digest => no alert row ---
run_dropin() { # extra K=V env -> rc; alerts land in $sb/queue
  local kv
  (
    export HOME="$sb" AUTOMATION_ROOT="$root"
    export JOB_NAME=test-slice-e HNGH_HOME="$root/.."
    export HNGH_REPORT_ROOT="$sb/queue" HNGH_HOME_DIR="$sb/.hngh"
    export HNGH_CRUMBS_DB="$sb/home/crumbs.db" CRUMBS_WRITER="$root/lib/crumbs.py"
    export DIGEST_DIR="$sb/digest"
    for kv in "$@"; do export "$kv"; done
    bash "$root/cadence/calendar/monthly/02-model-tier-refresh.sh" >/dev/null 2>&1
    echo "rc=$?"
  )
}
alerts() { cat "$sb/queue/docs/project/reports.md" 2>/dev/null | grep -c 'model-tier refresh OLA exceeded' || true; }
crumbs_reset
touch "$sb/digest/BENCH-fresh.md"
out="$(run_dropin)"
ck "drop-in rc 0 (fresh)" "rc=0" "$out"
ck "fresh digest: no alert row" "0" "$(alerts)"

# --- 9. stale digest => one alert row citing the digest name + 90d OLA ---
rm -f "$sb/digest/BENCH-fresh.md"
touch -d '2001-02-03 04:05:06' "$sb/digest/BENCH-stale.md"
out="$(run_dropin)"
ck "drop-in rc 0 (stale)" "rc=0" "$out"
ck "stale digest: one alert row" "1" "$(alerts)"
row_hits="$(reports "$sb/queue" | grep -c 'BENCH-stale.md' || true)"
[ "$row_hits" -ge 1 ] && got=cited || got=missing
ck "alert cites digest name" "cited" "$got"

# --- 10. missing digest => scope crumb, no new alert row ---
rm -f "$sb/digest"/BENCH-*.md
out="$(run_dropin)"
ck "drop-in rc 0 (no digest)" "rc=0" "$out"
ck "no digest: no new alert row" "1" "$(alerts)"
ck "no digest: scope crumb" "1" "$(crumbs | grep -cF 'no bench digest yet' || true)"

# --- 11. bogus OLA => fail-open 90d, still files (fresh reports root) ---
touch -d '2001-02-03 04:05:06' "$sb/digest/BENCH-stale.md"
(
  export HOME="$sb" AUTOMATION_ROOT="$root"
  export JOB_NAME=test-slice-e HNGH_HOME="$root/.."
  export HNGH_REPORT_ROOT="$sb/queue2" HNGH_HOME_DIR="$sb/.hngh"
  export HNGH_CRUMBS_DB="$sb/home/crumbs.db" CRUMBS_WRITER="$root/lib/crumbs.py"
  export DIGEST_DIR="$sb/digest" MODEL_TIER_REFRESH_OLA=not-a-number
  bash "$root/cadence/calendar/monthly/02-model-tier-refresh.sh" >/dev/null 2>&1
)
ck "bogus OLA: fail-open alert filed" "1" \
  "$(cat "$sb/queue2/docs/project/reports.md" 2>/dev/null | grep -c '(OLA 90d)' || true)"

[ "$fails" = 0 ] && echo "test-slice-e-seam-surface: all pass" || {
  echo "test-slice-e-seam-surface: $fails failure(s)"
  exit 1
}
