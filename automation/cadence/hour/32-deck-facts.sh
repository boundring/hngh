#!/usr/bin/env bash
# 32-deck-facts -- hourly desktop-pull of deck facts (deck phase 1, zero
# operator; docs/DECK-NODE.md). The desktop ssh'es into the deck (BatchMode,
# documented key), stages jobs/deck-producer.sh into ~/hngh-deck when it is
# missing or drifted, runs it under a hard timeout, fetches the newest facts
# JSON, validates it, and appends it to deck-facts/deck-facts-<date>.jsonl.
# The deck stays passive: one $HOME directory, no processes, no timers --
# this drop-in and the hour cadence drive everything.
# The deck is an intermittent peer (off / wall-sleeping is normal):
# unreachable is a breadcrumb, never an alert -- unless it answered earlier
# the same UTC day, when the gap files an alert row. An ssh auth failure
# behaves the same (BatchMode means no prompt is ever possible).
# Availability window (stall-recovery step 8, operator directive
# 2026-09-09): the cadence-params row deck-availability (env
# DECK_AVAILABILITY overrides) names the weekday hours the deck is
# EXPECTED reachable (tz name handles EST/EDT). Outside the window an
# unreachable probe is expected-state: status off-duty, no alert. Inside
# the window the alert path is unchanged.
# Fail-closed: exits 0 on every expected path.
#
# usage: cadence/hour/32-deck-facts.sh  (via cadence-tick.sh TIER=hour)
set -u
. "$(cd "$(dirname "$0")/../.." && pwd)/lib/common.sh"
. "$AUTOMATION_ROOT/lib/breadcrumbs.sh"
. "$AUTOMATION_ROOT/lib/params.sh"

enabled="${DECK_NODE_ENABLED:-$(get_param deck-node-enabled 0)}"
[ "$enabled" = "1" ] || exit 0

# machine profile: host identity (deck ssh host) lives in config/machine.env
# (gitignored; example: config/machine.env.example) - peer-review finding 1:
# machine defaults never bake into job code. The profile path is
# env-selectable (HNGH_MACHINE_PROFILE) for tests.
MACHINE_PROFILE="${HNGH_MACHINE_PROFILE:-$AUTOMATION_ROOT/config/machine.env}"
[ -f "$MACHINE_PROFILE" ] && . "$MACHINE_PROFILE"
DECK_HOST="${DECK_HOST:-}" # deck ssh host; machine profile or exported env
# fail-closed: without a machine profile (and no env DECK_HOST) there is no
# deck host to pull from - skip, never fall back to a baked-in address.
if [ -z "$DECK_HOST" ]; then
  breadcrumb "$JOB_NAME" "deck-facts" \
    "no DECK_HOST (config/machine.env missing - see config/machine.env.example): skipped"
  exit 0
fi
DECK_KEY="${DECK_KEY:-$HOME/.ssh/id_ed25519_hngh}"
DECK_DIR="${DECK_DIR:-hngh-deck}"
PRODUCER="$AUTOMATION_ROOT/jobs/deck-producer.sh"
FACTS_DIR="$AUTOMATION_ROOT/deck-facts"
KERNEL="${HNGH_HOME:-$HOME/Projects/etc/hngh}"
REPORT="$KERNEL/scripts/report-queue"
# DECK_NOW overrides the clock (test seam; set by tests, not operators).
deck_now="${DECK_NOW:-$(date -u +%Y-%m-%dT%H:%M:%SZ)}"
day="$(date -u -d "$deck_now" +%F)"
jsonl="$FACTS_DIR/deck-facts-$day.jsonl"

ssh_deck() { # $1 = timeout seconds, rest = remote command
  local t="$1"
  shift
  timeout "$t" ssh -i "$DECK_KEY" -o BatchMode=yes -o ConnectTimeout=10 \
    -o StrictHostKeyChecking=accept-new "$DECK_HOST" "$@"
}

unreachable() { # $1 = context
  if ! deck_on_duty; then
    # outside the availability window, unreachable is expected-state:
    # breadcrumb it and exit, never an alert (stall-recovery step 8)
    breadcrumb "$JOB_NAME" "off-duty" \
      "deck unreachable outside the availability window (expected-state, no alert) ($1)"
  elif [ -s "$jsonl" ]; then
    HNGH_REPORT_ROOT="$KERNEL" python3 "$REPORT" --add alert \
      "deck was reachable earlier today but the pull now fails ($1)" \
      --identity "deck-unreachable-$day" --window 86400 >/dev/null 2>&1 || true
    breadcrumb "$JOB_NAME" "alert" "deck unreachable after earlier success today ($1)"
  else
    breadcrumb "$JOB_NAME" "progress" "deck unreachable (normal) ($1)"
  fi
  exit 0
}

deck_on_duty() { # exit 0 = inside the deck-availability window
  local w="${DECK_AVAILABILITY:-$(get_param deck-availability '')}"
  [ -n "$w" ] || return 0 # no window row = always on duty (pre-step-8)
  local days span tz rest d1 d2 s e dow hm
  days="${w%% *}"; rest="${w#* }"; span="${rest%% *}"; tz="${rest#* }"
  [ -n "$tz" ] || tz=UTC
  d1="$(_day_num "${days%-*}")"; d2="$(_day_num "${days#*-}")"
  s="${span%-*}"; e="${span#*-}"
  [ "$d1" -ge 1 ] && [ "$d1" -le "$d2" ] || return 0 # malformed = on duty
  case "$s$e" in *[!0-9:]*) return 0 ;; esac # non time chars = on duty
  dow="$(TZ="$tz" date -d "$deck_now" +%u 2>/dev/null)" || return 0
  hm="$(TZ="$tz" date -d "$deck_now" +%H%M 2>/dev/null)" || return 0
  [ "$dow" -ge "$d1" ] && [ "$dow" -le "$d2" ] \
    && [ "$((10#$hm))" -ge "$((10#${s//:}))" ] \
    && [ "$((10#$hm))" -lt "$((10#${e//:}))" ]
}
_day_num() { # Mon..Sun -> 1..7, anything else 0
  case "$1" in Mon) printf 1;; Tue) printf 2;; Wed) printf 3;;
    Thu) printf 4;; Fri) printf 5;; Sat) printf 6;; Sun) printf 7;;
    *) printf 0;; esac
}

[ -f "$PRODUCER" ] || {
  breadcrumb "$JOB_NAME" "error" "producer missing: $PRODUCER"
  exit 0
}

# 1. probe the staged producer (rc 255/124 = connection/auth/timeout, treat as
#    unreachable; rc 1 = file absent, a first-run stage)
rc=0
remote_now="$(ssh_deck 20 "cat ~/$DECK_DIR/deck-producer.sh 2>/dev/null")" || rc=$?
if [ "$rc" -ne 0 ] && [ "$rc" -ne 1 ]; then
  unreachable "probe rc=$rc"
fi

# 2. stage the producer when drifted (stdin redirect; never a remote edit)
if [ "$remote_now" != "$(cat "$PRODUCER")" ]; then
  ssh_deck 20 "mkdir -p ~/$DECK_DIR/facts && cat > ~/$DECK_DIR/deck-producer.sh" \
    <"$PRODUCER" || unreachable "stage rc=$?"
  breadcrumb "$JOB_NAME" "stage" "producer staged to ~/$DECK_DIR (first run or drift)"
fi

# 3. run the producer under a hard timeout
rc=0
run_out="$(ssh_deck 120 "bash ~/$DECK_DIR/deck-producer.sh" 2>&1)" || rc=$?
remote_path="$(printf '%s\n' "$run_out" | awk 'NF {p=$0} END {print p}')"
if [ "$rc" -ne 0 ] || [ -z "$remote_path" ]; then
  unreachable "producer rc=$rc out=$(printf '%s' "$run_out" | tail -n 1 | cut -c1-80)"
fi
breadcrumb "$JOB_NAME" "producer" "ran ~/$DECK_DIR/deck-producer.sh -> $remote_path"

# 4. fetch the newest facts file
rc=0
facts_json="$(ssh_deck 20 "cat '$remote_path'")" || rc=$?
if [ "$rc" -ne 0 ] || [ -z "$facts_json" ]; then
  unreachable "fetch rc=$rc"
fi

# 5. validate JSON before it may enter the record
if ! printf '%s' "$facts_json" | python3 -c 'import json,sys; json.load(sys.stdin)' 2>/dev/null; then
  breadcrumb "$JOB_NAME" "invalid-json" "fetched facts failed JSON validation: $remote_path"
  exit 0
fi

# 6. append to the day's jsonl
mkdir -p "$FACTS_DIR"
# compact to exactly one JSONL line regardless of the producer's formatting
line="$(printf '%s' "$facts_json" | python3 -c 'import json,sys; print(json.dumps(json.load(sys.stdin),sort_keys=True,separators=(",",":")))')" ||
  {
    breadcrumb "$JOB_NAME" "invalid-json" "compaction failed: $remote_path"
    exit 0
  }
printf '%s\n' "$line" >>"$jsonl"
summary="$(printf '%s' "$line" | python3 -c 'import json,sys; d=json.load(sys.stdin); m=d.get("meminfo_kB") or {}; print("load=%s mem=%s ts=%s" % (d.get("loadavg","?"), m.get("MemTotal","?"), d.get("clock_utc","?")))' 2>/dev/null || echo '?')"
breadcrumb "$JOB_NAME" "facts-pulled" "$summary"
exit 0
