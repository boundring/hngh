# failfirst.sh — fail-first self-tuning engine (TCP congestion control for
# cycled operations). The old throttles were pre-set guesses about where the
# ceiling is; fail-first removes the guesses: run at maximum natural speed,
# let the model chain's fail-closed-skip (lib/model.sh, untouched) detect
# what actually breaks, and self-tune to just below the observed failure
# point. Additive increase, multiplicative decrease:
#   full (1)     run every tick                     <- fresh state starts here
#   standard (2) run every 2nd tick after degradation
#   cautious (3) run every 4th tick after a second degradation or a script error
#   For development (delegated sessions cost real money) the same three
#   speeds map to CONCURRENCY instead of pace alone: full = up to 3
#   concurrent sessions per beat, standard = 2, cautious = 1 (Inventory
#   rows failfirst-dev-concurrent-*). The spend ceiling itself
#   (sessions-day-max) is a hard constraint above the tuning and never
#   moves; the caller caps the batch at (ceiling - sessions used today).
#   ok outcomes at standard/cautious promote one level after
#   failfirst-promote-threshold (Inventory, default 3) consecutive oks;
#   degraded (archive-only model chain) demotes one level immediately and
#   records the observed ceiling; failed (a real bug, not saturation) drops
#   to cautious AND files a report-queue alert through the caller's
#   file_report when one exists.
# Interface:
#   failfirst_gate <operation> [state-file] -> echoes GO or THROTTLE:<reason>
#   record_outcome <operation> <speed> <result> [state-file]   (ok|degraded|failed)
#   deck_up -> exit 0 when the deck leg is armed AND responsive (quick
#              /health probe; any HTTP answer counts, transport failure does not)
# Routing (load and deck availability are CAPACITY signals, not throttles):
#   the caller routes on busy local via load_busy + deck_up -- it shifts the
#   pin to the deck or a quota leg; it never defers. This file only owns the
#   speed state machine and the probe.
# State: one key=value file per operation under FAILFIRST_STATE_DIR
# (default /tmp/hngh-failfirst). Tick seconds: FAILFIRST_TICK_S (default
# 3600 = the hour tier; the 15-minute overflow exports 900). Caller must
# have sourced params.sh (get_param) and breadcrumbs.sh (fallback alert);
# both hold for every cadence drop-in.
set -u

FF_DIR="${FAILFIRST_STATE_DIR:-/tmp/hngh-failfirst}"

failfirst_state_file() { # op -> default state path
 printf '%s/failfirst-%s\n' "$FF_DIR" "$1"
}

failfirst_load() { # op [statefile] -> FF_* globals (fresh defaults when absent)
 FF_SPEED=1
 FF_OKS=0
 FF_LAST=none
 FF_CEILING=0
 FF_LAST_RUN=0
 FF_NOK=0
 FF_NDEG=0
 FF_NFAIL=0
 local f="${2:-$(failfirst_state_file "$1")}" k v
 [ -r "$f" ] || return 0
 while IFS='=' read -r k v; do
  case "$k" in
  speed) case "$v" in 1 | 2 | 3) FF_SPEED="$v" ;; esac ;;
  oks) case "$v" in '' | *[!0-9]*) ;; *) FF_OKS="$v" ;; esac ;;
  last) FF_LAST="$v" ;;
  ceiling) case "$v" in '' | *[!0-9]*) ;; *) FF_CEILING="$v" ;; esac ;;
  lastrun) case "$v" in '' | *[!0-9]*) ;; *) FF_LAST_RUN="$v" ;; esac ;;
  n_ok) case "$v" in '' | *[!0-9]*) ;; *) FF_NOK="$v" ;; esac ;;
  n_deg) case "$v" in '' | *[!0-9]*) ;; *) FF_NDEG="$v" ;; esac ;;
  n_fail) case "$v" in '' | *[!0-9]*) ;; *) FF_NFAIL="$v" ;; esac ;;
  esac
 done <"$f"
}

failfirst_save() { # op statefile
 mkdir -p "${2%/*}" 2>/dev/null
 printf 'speed=%s\noks=%s\nlast=%s\nceiling=%s\nlastrun=%s\nn_ok=%s\nn_deg=%s\nn_fail=%s\n' \
  "$FF_SPEED" "$FF_OKS" "$FF_LAST" "$FF_CEILING" "$FF_LAST_RUN" \
  "$FF_NOK" "$FF_NDEG" "$FF_NFAIL" >"$2" 2>/dev/null
}

failfirst_concurrency() { # op [statefile] -> max concurrent sessions at the current speed
 failfirst_load "$1" "${2:-$(failfirst_state_file "$1")}"
 local full=3 std=2 cau=1
 if declare -F get_param >/dev/null 2>&1; then
  full="${FAILFIRST_DEV_CONCURRENT_FULL:-$(get_param failfirst-dev-concurrent-full 3)}"
  std="${FAILFIRST_DEV_CONCURRENT_STANDARD:-$(get_param failfirst-dev-concurrent-standard 2)}"
  cau="${FAILFIRST_DEV_CONCURRENT_CAUTIOUS:-$(get_param failfirst-dev-concurrent-cautious 1)}"
 fi
 case "$full$std$cau" in '' | *[!0-9]*) full=3 std=2 cau=1 ;; esac
 case "$FF_SPEED" in
 2) printf '%s\n' "$std" ;;
 3) printf '%s\n' "$cau" ;;
 *) printf '%s\n' "$full" ;;
 esac
}

failfirst_gate() { # op [statefile] -> GO | THROTTLE:<reason> on stdout
 local op="$1" f="${2:-$(failfirst_state_file "$1")}" now tick mult
 failfirst_load "$op" "$f"
 if [ "$FF_SPEED" = 1 ]; then
  FF_LAST_RUN="$(date +%s)"
  failfirst_save "$op" "$f"
  printf 'GO\n'
  return 0
 fi
 # paced speed: full ran into degradation, so hold just below the observed
 # failure point -- standard every 2nd tick, cautious every 4th.
 tick="${FAILFIRST_TICK_S:-3600}"
 case "$tick" in '' | *[!0-9]* | 0) tick=3600 ;; esac
 mult=$((1 << (FF_SPEED - 1)))
 now="$(date +%s)"
 if [ $((now - FF_LAST_RUN)) -ge $((mult * tick)) ]; then
  FF_LAST_RUN="$now"
  failfirst_save "$op" "$f"
  printf 'GO\n'
 else
  printf 'THROTTLE:speed-%s\n' "$FF_SPEED"
 fi
}

record_outcome() { # op speed result [statefile]
 local op="$1" speed="$2" result="$3" f="${4:-$(failfirst_state_file "$1")}"
 local promote
 if declare -F get_param >/dev/null 2>&1; then
  promote="${FAILFIRST_PROMOTE_THRESHOLD:-$(get_param failfirst-promote-threshold 3)}"
 else
  promote="${FAILFIRST_PROMOTE_THRESHOLD:-3}"
 fi
 case "$promote" in '' | *[!0-9]* | 0) promote=3 ;; esac
 failfirst_load "$op" "$f"
 FF_LAST_RUN="$(date +%s)"
 case "$speed" in 1 | 2 | 3) FF_SPEED="$speed" ;; esac
 case "$result" in
 ok)
  FF_LAST=ok
  FF_NOK=$((FF_NOK + 1))
  FF_OKS=$((FF_OKS + 1))
  # additive increase: consecutive oks at a paced speed earn promotion
  if [ "$FF_SPEED" -gt 1 ] && [ "$FF_OKS" -ge "$promote" ]; then
   FF_SPEED=$((FF_SPEED - 1))
   FF_OKS=0
  fi
  ;;
 degraded)
  # multiplicative decrease: one degradation halves the pace (x2 tick)
  FF_LAST=degraded
  FF_NDEG=$((FF_NDEG + 1))
  FF_OKS=0
  [ "$FF_CEILING" = 0 ] && FF_CEILING="$FF_SPEED" # observed ceiling
  [ "$FF_SPEED" -lt 3 ] && FF_SPEED=$((FF_SPEED + 1))
  ;;
 failed)
  # a real bug, not saturation: drop to cautious and make it loud
  FF_LAST=failed
  FF_NFAIL=$((FF_NFAIL + 1))
  FF_OKS=0
  FF_SPEED=3
  if declare -F file_report >/dev/null 2>&1; then
   file_report alert "failfirst $op: script error at speed $speed - dropped to cautious" \
    "failfirst-$op:script-error" 86400
  else
   breadcrumb "${JOB_NAME:-failfirst}" "failfirst-script-error" \
    "$op: error at speed $speed - dropped to cautious"
  fi
  ;;
 esac
 failfirst_save "$op" "$f"
}

deck_up() { # -> exit 0 when the deck leg is armed AND responsive
 local url="${DECK_URL:-$(get_param deck-model-endpoint '')}" code
 [ -n "$url" ] || return 1
 code="$(curl -s --max-time "${DECK_PROBE_TIMEOUT:-4}" -o /dev/null \
  -w '%{http_code}' "$url/health" 2>/dev/null)" || return 1
 [ -n "$code" ] && [ "$code" != "000" ]
}
