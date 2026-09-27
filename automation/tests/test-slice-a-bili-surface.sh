#!/usr/bin/env bash
# test-slice-a-bili-surface.sh — governed-fleet slice A surface, hermetic:
# (1) telemetry.py accepts tokens_cached as a --data key and persists it;
# (2) unknown --data keys still fail closed (best-effort: no row, rc 0);
# (3) an old-schema events table is ALTERed in place so the column
#     backfills live (the additive-only schema migration, governed-fleet
#     slice A S1: telemetry.py FIRST, then model.sh);
# (4) model.sh _model_emit forwards tokens_cached from TOKCACHED_FILE into
#     the emitted row and clears the tmp files (no stale inheritance);
# (5) a lone tokens_cached (no usage pair) still emits exactly one row;
# (6) security-check.sh carries the bili=$b_ok breadcrumbs
#     (presence of the bili check in the job body; real driving is the
#     4h timer, never asserted against the live host here).
# No real proxy, no network, no secrets: the fixture db + tmp files are
# sandbox-local.
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"
sb="$(mktemp -d)"
trap 'rm -rf "$sb"' EXIT
mkdir -p "$sb/home/db" "$sb/jobs" "$sb/lib" "$sb/archive" "$sb/dashboard"
ln -s "$root/jobs/telemetry.py" "$sb/jobs/telemetry.py"
ln -s "$root/lib/model.sh" "$root/lib/params.sh" "$root/lib/common.sh" \
  "$root/lib/breadcrumbs.sh" "$root/lib/scrub.sh" "$root/lib/scrub.py" "$sb/lib/"
fails=0
ck() { # desc expected actual
  if [ "$2" = "$3" ]; then echo "ok: $1"; else
    echo "FAIL: $1 (want [$2] got [$3])"
    fails=$((fails + 1))
  fi
}
db="$sb/home/db/telemetry.db"
q() { sqlite3 "$db" "$1" 2>/dev/null; }

emit() { # data... -> runs telemetry.py against the fixture db
  (export HNGH_HOME_DIR="$sb/home" HOME="$sb"
   python3 "$root/jobs/telemetry.py" emit --kind model --source leg \
     "$@" >/dev/null 2>&1)
}

# --- 1. tokens_accepted: accepted, persisted beside tokens_in.
emit --data '{"tokens_in":100,"tokens_cached":80}'
ck "tokens_cached persisted" "100|80" "$(q 'select tokens_in, tokens_cached from events')"

# --- 2. unknown-key fail closed: no row added, still best-effort rc 0.
before="$(q 'select count(*) from events')"
emit --data '{"tokens_cached":1,"bogus":2}'
ck "unknown key: rc 0" "0" "$?"
ck "unknown key: no row" "$before" "$(q 'select count(*) from events')"

# --- 3. old-schema ALTER backfill.
rm -f "$db"
python3 - "$db" <<'PY'
import sqlite3, sys
conn = sqlite3.connect(sys.argv[1])
conn.execute("CREATE TABLE events(ts TEXT, source TEXT, kind TEXT,"
             " identity TEXT, lane TEXT, unit TEXT, model TEXT,"
             " tokens_in INTEGER, tokens_out INTEGER, cost_usd REAL,"
             " wall_s REAL, subject TEXT, refs TEXT, body TEXT)")
conn.commit()
conn.close()
PY
emit --data '{"tokens_cached":42}'
ck "old-schema ALTER backfill" "42" "$(q 'select tokens_cached from events')"

# --- 4/5. _model_emit forwards TOKCACHED_FILE and clears the tmp files;
#          a lone tokc without the usage pair still emits one row.
rm -f "$db"
printf '100' >"$root/tmp-walls.txt"
printf '4400' >"$root/tmp-tokensin.txt"
printf '' >"$root/tmp-tokensout.txt"
printf '4100' >"$root/tmp-tokenscached.txt"
(
  export AUTOMATION_ROOT="$root" HNGH_HOME_DIR="$sb/home" HOME="$sb" JOB_NAME=test
  . "$root/lib/params.sh" 2>/dev/null || true
  . "$root/lib/model.sh"
  _model_emit unsloth "fixture/leg" 2>/dev/null
)
ck "_model_emit: in+cached forwarded" \
  "unsloth|fixture/leg|4400|4100" \
  "$(q "select source, model, tokens_in, tokens_cached from events")"
ck "_model_emit: tmp files cleared" "0" \
  "$(ls "$root"/tmp-walls.txt "$root"/tmp-tokensin.txt "$root"/tmp-tokensout.txt "$root"/tmp-tokenscached.txt 2>/dev/null | wc -l)"

# lone tokc (no in/out): fresh fixture so the count is exact
rm -f "$db"
printf '' >"$root/tmp-tokensin.txt"
printf '' >"$root/tmp-tokensout.txt"
printf '7000' >"$root/tmp-tokenscached.txt"
printf '' >"$root/tmp-walls.txt"
(
  export AUTOMATION_ROOT="$root" HNGH_HOME_DIR="$sb/home" HOME="$sb" JOB_NAME=test
  . "$root/lib/params.sh" 2>/dev/null || true
  . "$root/lib/model.sh"
  _model_emit kimi "k3" 2>/dev/null
)
ck "lone tokc: one row" "1" "$(q 'select count(*) from events')"
ck "lone tokc: value forwarded" "7000" "$(q 'select tokens_cached from events')"
rm -f "$root/tmp-walls.txt" "$root/tmp-tokensin.txt" "$root/tmp-tokensout.txt" "$root/tmp-tokenscached.txt"

# --- 6. security-check carries the bili breadcrumb (design section-2
#        watch: security-check bili=$b_ok).
grep -qF 'bili=$b_ok' "$root/jobs/security-check.sh" &&
  ck "security-check: bili breadcrumb present" "ok" "ok" ||
  ck "security-check: bili breadcrumb present" "ok" "missing"

[ "$fails" = 0 ] && echo "test-slice-a-bili-surface: all pass" || {
  echo "test-slice-a-bili-surface: $fails failure(s)"
  exit 1
}
