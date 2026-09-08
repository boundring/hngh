#!/usr/bin/env bash
# service-ctl — allowlisted systemd --user unit control (operator grant).
#
# Operator grant 2026-09-07 (decisions.md 2026-09-07): Hngh holds
# STANDING authority to manage system services (supersedes the
# 2026-09-03 grant). service-ctl remains the single gated path; every
# action is a recorded disposition; a failure is an alert, never a
# retry-in-the-dark. Credential- or payment-bearing configuration still
# needs per-action operator instruction or certificate (Keyring law).
# Formal contract:
#   hngh docs/design/service-management.md  (landing in parallel)
#
# usage: scripts/service-ctl.sh [--json] <unit> <verb>
#   unit:  llama-server.service | unsloth-warm.service | unsloth-studio.service
#   verb:  start | stop | restart | status   (status is read-only)
#
# Fail-closed order: (1) allowlist, (2) verb grant, (3) installed check —
# anything else exits 2 BEFORE any state-changing call, and nothing else
# runs. All three units are '--user' units; a unit that fails
# `systemctl --user cat` is reported honestly (it may be a system unit —
# system units are NEVER touched; parked for the operator).
#
# Every start/stop/restart (success or failure) writes a breadcrumb + a
# progress row via the kernel report-queue (HNGH_REPORT_ROOT pattern),
# including who/what/when and the unit's resulting ActiveState.
# DRY_RUN=1 prints the intended action without executing anything.
#
# Seams: HNGH_SERVICE_SYSTEMCTL (systemctl binary / PATH stub for hermetic
# tests), HNGH_HOME + HNGH_REPORT_ROOT (report writer), STATE_FILE.
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
. "$ROOT/lib/common.sh"
. "$ROOT/lib/breadcrumbs.sh"

ALLOWLIST="llama-server.service unsloth-warm.service unsloth-studio.service"
SYSTEMCTL="${HNGH_SERVICE_SYSTEMCTL:-systemctl}" # env seam for tests
KERNEL="${HNGH_HOME:-$HOME/Projects/etc/hngh}"
VERBS="start stop restart status"

JSON=0
[ "${1:-}" = "--json" ] && JSON=1 && shift
UNIT="${1:-}"
VERB="${2:-}"

emit() { # json_text  |  plain_text
  if [ "$JSON" = "1" ]; then printf '%s\n' "$1"; else printf '%s\n' "$2" >&2; fi
}

refuse() { # reason  -> exit 2, nothing else ever runs
  if [ "$JSON" = "1" ]; then
    printf '{"refused": "%s", "unit": "%s", "verb": "%s"}\n' \
      "$1" "$UNIT" "$VERB"
  else
    printf 'refused: %s\n' "$1" >&2
  fi
  exit 2
}

# 1. allowlist FIRST — any other unit is refused before anything else.
case " $ALLOWLIST " in
*" $UNIT "*) ;;
*) refuse "unit not allowlisted (${ALLOWLIST// /|})" ;;
esac

# 2. verb grant — lifecycle changes (enable/disable/mask/unmask/link/
#    preset) stay critical-class and are refused here.
case " $VERBS " in
*" $VERB "*) ;;
*) refuse "verb not granted ($VERB); lifecycle changes are critical-class (park)" ;;
esac

# 3. installed check — must be an installed --user unit.
if ! "$SYSTEMCTL" --user cat "$UNIT" >/dev/null 2>&1; then
  refuse "$UNIT is not an installed user unit (system units are out of scope — parked)"
fi

unit_state() { # -> ActiveState value or unknown
  "$SYSTEMCTL" --user show -p ActiveState --value "$UNIT" 2>/dev/null || echo unknown
}

if [ "$VERB" = "status" ]; then
  if [ "$JSON" = "1" ]; then
    "$SYSTEMCTL" --user show -p ActiveState,SubState,UnitFileState,ExecMainStartTimestamp \
      --value "$UNIT" 2>/dev/null |
      python3 -c '
import json, sys
keys = ("active_state", "sub_state", "unit_file_state", "start_timestamp")
vals = [ln.strip() for ln in sys.stdin.read().splitlines() if ln.strip()] + [""] * 4
print(json.dumps(dict(zip(keys, vals[:4]))))'
  else
    exec "$SYSTEMCTL" --user status "$UNIT" --no-pager
  fi
  exit 0
fi

# DRY_RUN: print the intended action, write nothing, change nothing.
if [ "${DRY_RUN:-0}" = "1" ]; then
  emit "{\"dry_run\": true, \"verb\": \"$VERB\", \"unit\": \"$UNIT\"}" \
    "dry-run: would run systemctl --user $VERB $UNIT"
  exit 0
fi

out="$("$SYSTEMCTL" --user "$VERB" "$UNIT" 2>&1)"
rc=$?
state="$(unit_state)"
when="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
who="$(id -un 2>/dev/null || echo unknown)@$(hostname 2>/dev/null || echo unknown)"

breadcrumb "service-ctl" "$VERB" "$UNIT rc=$rc state=$state by=$who"

row="service-ctl: $who ran '$VERB $UNIT' at $when — rc=$rc, resulting ActiveState=$state"
[ "$rc" = "0" ] || row="$row | systemctl output: ${out:-<none>}"
HNGH_REPORT_ROOT="${HNGH_REPORT_ROOT:-$KERNEL}" python3 \
  "$KERNEL/scripts/report-queue" --add progress "$row" \
  --identity "service-ctl:$UNIT:$VERB" --window 3600 >/dev/null 2>&1 || true

if [ "$JSON" = "1" ]; then
  printf '{"verb": "%s", "unit": "%s", "rc": %d, "active_state": "%s"}\n' \
    "$VERB" "$UNIT" "$rc" "$state"
else
  printf '%s %s: rc=%d ActiveState=%s\n' "$VERB" "$UNIT" "$rc" "$state"
  [ "$rc" = "0" ] || printf '%s\n' "$out" >&2
fi
exit 0 # the action result is recorded, not raised: fail-closed cadence
