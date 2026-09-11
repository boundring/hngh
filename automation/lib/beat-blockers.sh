# beat-blockers.sh — the orchestrator's blocker ledger (as-above-so-below,
# 2026-09-11). The run domain models stalls as dead runs routed through the
# bestiary; this gives the orchestrator itself the same treatment at its own
# level: a stalled plan is one durable row in state/beat-blockers.tsv
#   id<TAB>scope<TAB>cause<TAB>first-seen<TAB>attempts<TAB>state<TAB>last-update
# written by the beat watchdog (jobs/beat-watchdog.py, detector) and the
# overnight beat (scripts/overnight-cycle.sh, remediation loop). One row per
# plan/lane scope: success clears it, a same-cause failure bumps attempts, a
# different cause restarts the diagnosis (new class = new problem), and
# attempts >= blocker-escalate-n parks it (state=parked) — bounded retries,
# never infinite; the operator still sees every re-park (the escalation path
# files the beat-parked alert each time), but parked rows auto-unpark after
# blocker-park-cooldown-hours (blocker_tick, called at beat start): attempts
# reset to 0 and the diagnosis restarts (dream re-preps via
# blocker_prompt_line). state/ is runtime data (gitignored), same TSV
# convention as the rest of state/.
set -u

BEAT_BLOCKERS_FILE="${BEAT_BLOCKERS_FILE:-${AUTOMATION_ROOT:-${ROOT:-.}}/state/beat-blockers.tsv}"

blocker_row_for() { # scope -> row (id\t...\tstate) or ""
  local row=""
  [ -f "$BEAT_BLOCKERS_FILE" ] &&
    row="$(awk -F'\t' -v s="$1" '$2 == s { print; exit }' "$BEAT_BLOCKERS_FILE" 2>/dev/null)"
  printf '%s' "$row"
}

blocker_record() { # scope cause -> attempts on stdout (0 = ledger write refused)
  local scope="$1" cause="$2" f="$BEAT_BLOCKERS_FILE" attempts
  [ -n "$scope" ] && [ -n "$cause" ] || {
    printf '0'
    return 0
  }
  mkdir -p "$(dirname "$f")" 2>/dev/null
  touch "$f" 2>/dev/null || {
    printf '0'
    return 0
  }
  attempts="$(awk -F'\t' -v s="$scope" -v c="$cause" \
    '$2 == s { a = ($3 == c) ? $5 + 1 : 1 } END { print a + 0 }' "$f" 2>/dev/null)"
  awk -F'\t' -v OFS='\t' -v s="$scope" -v c="$cause" -v a="$attempts" \
    -v ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    -v id="blk-$(date -u +%Y%m%d)-$(printf '%s' "$scope" | tr -cs 'a-zA-Z0-9._-' '-')" '
    $2 == s { $3 = c; $5 = a; $6 = "active"; $7 = ts; f = 1 }  # same cause: bump; new cause: new diagnosis
    { print }
    END { if (!f) print id, s, c, ts, a, "active", ts }
  ' "$f" >"$f.tmp.$$" 2>/dev/null && mv "$f.tmp.$$" "$f" || {
    rm -f "$f.tmp.$$" 2>/dev/null
    printf '0'
    return 0
  }
  printf '%s' "$attempts"
}

blocker_park() { # scope -> marks the row parked (escalation; auto-unparks after cooldown)
  local f="$BEAT_BLOCKERS_FILE"
  [ -f "$f" ] || return 0
  awk -F'\t' -v OFS='\t' -v s="$1" -v ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    '$2 == s { $6 = "parked"; $7 = ts } { print }' \
    "$f" >"$f.tmp.$$" 2>/dev/null && mv "$f.tmp.$$" "$f" || rm -f "$f.tmp.$$"
}

blocker_tick() { # [hours] -> unpark rows whose last update is older than the cooldown
  # Called from the overnight beat start (overnight-cycle.sh, before plan
  # selection): parked rows return to active with attempts reset to 0 once
  # blocker-park-cooldown-hours (default 24) have passed since the last
  # park/update. The diagnosis restarts from scratch (dream pass re-preps
  # via blocker_prompt_line). Repeat offenders remain visible: every
  # re-park files a fresh beat-parked alert.
  local f="$BEAT_BLOCKERS_FILE" hours="${1:-24}" cutoff
  [ -f "$f" ] || return 0
  cutoff="$(date -u -d "-${hours} hours" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null)" || return 0
  awk -F'\t' -v OFS='\t' -v cutoff="$cutoff" '
    $6 == "parked" {
      lu = ($7 != "" ? $7 : $4)
      if (lu != "" && lu < cutoff) { $5 = 0; $6 = "active"; print; next }
    }
    { print }
  ' "$f" >"$f.tmp.$$" 2>/dev/null && mv "$f.tmp.$$" "$f" || rm -f "$f.tmp.$$"
}

blocker_clear() { # scope -> success removes the row entirely
  local f="$BEAT_BLOCKERS_FILE"
  [ -f "$f" ] || return 0
  awk -F'\t' -v s="$1" '$2 != s' "$f" >"$f.tmp.$$" 2>/dev/null &&
    mv "$f.tmp.$$" "$f" || rm -f "$f.tmp.$$"
}

blocker_prompt_line() { # scope -> the dream/plan blocker sentence ("" when no row)
  local cause
  cause="$(blocker_row_for "$1" | cut -f3)"
  [ -n "$cause" ] || return 0
  printf 'BLOCKER (orchestrator ledger, state/beat-blockers.tsv): this plan/lane previously died with cause class %s. Read state/beat-blockers.tsv and the tail of automation/state/ocgo-agent-lessons.md, state what you will do differently this attempt, and assert it in your sanity-checks.' "$cause"
}
