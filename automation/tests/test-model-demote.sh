#!/usr/bin/env bash
# test-model-demote.sh — model-outcome demotion contract (stall-recovery
# plan step 1): 2 consecutive bad-execution outcomes demote a model (alert
# identity model-demotion:<model>), an ok outcome resets and clears it,
# and the health JSON reflects the state. Hermetic: sandbox state, stub
# report-queue, no real bench data.
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"
sb="$(mktemp -d)"
trap 'rm -rf "$sb"' EXIT
mkdir -p "$sb/state" "$sb/stats" "$sb/logs"
: >"$sb/queue.log"
fails=0
ck() {
  if [ "$2" = "$3" ]; then echo "ok: $1"; else
    echo "FAIL: $1 (want [$2] got [$3])"
    fails=$((fails + 1))
  fi
}
LIB="$root/lib/model-demote.sh"
stub="$sb/report-queue-stub"
{
  echo '#!/usr/bin/env bash'
  echo "echo \"\$*\" >> '$sb/queue.log'"
  echo 'exit 0'
} >"$stub"
chmod +x "$stub"
record() { # model result
  DEMOTE_STATE="$sb/state/model-demote.tsv" AUTOMATION_ROOT="$root" \
    HNGH_HOME="$root/.." REPORT="$stub" \
    bash -c ". '$LIB'; record_model_outcome \"\$1\" \"\$2\"" _ "$1" "$2"
}
demoted() {
  DEMOTE_STATE="$sb/state/model-demote.tsv" AUTOMATION_ROOT="$root" \
    bash -c ". '$LIB'; model_demoted \"\$1\"" _ "$1"
}
health() {
  DEMOTE_STATE="$sb/state/model-demote.tsv" AUTOMATION_ROOT="$root" \
    bash -c ". '$LIB'; model_health_json"
}

# 1. one bad-execution: no demotion
record unsloth/ornith bad-execution
ck "1 strike: not demoted" "0" "$(demoted unsloth/ornith)"
# 2. second consecutive: demoted + alert filed
record unsloth/ornith bad-execution
ck "2 strikes: demoted" "1" "$(demoted unsloth/ornith)"
ck "alert row filed" "1" "$(grep -c 'model-demotion:unsloth/ornith' "$sb/queue.log")"
# 3. dead does NOT count
record unsloth/ornith dead
ck "dead: demotion unchanged" "1" "$(demoted unsloth/ornith)"
# 4. ok resets
record unsloth/ornith ok
ck "ok resets demotion" "0" "$(demoted unsloth/ornith)"
ck "clear notice filed" "1" "$(grep -c 'model-demotion-cleared:unsloth/ornith' "$sb/queue.log")"
# 5. re-demotion needs 2 fresh strikes
record unsloth/ornith bad-execution
ck "post-reset: 1 strike not demoted" "0" "$(demoted unsloth/ornith)"
record unsloth/ornith bad-execution
ck "post-reset: 2 strikes demote again" "1" "$(demoted unsloth/ornith)"
# 6. health JSON reflects state
ck "health json marks demoted" "True" \
  "$(health | python3 -c 'import json,sys; print(json.load(sys.stdin)["unsloth/ornith"]["demoted"])')"
ck "health json carries count" "2" \
  "$(health | python3 -c 'import json,sys; print(json.load(sys.stdin)["unsloth/ornith"]["consecutive_bad"])')"
# 7. empty state -> fail-closed empty object
ck "health json empty-state is {}" "{}" \
  "$(DEMOTE_STATE="$sb/nonexistent.tsv" AUTOMATION_ROOT="$root" \
    bash -c ". '$LIB'; model_health_json")"

echo "---"
[ "$fails" -eq 0 ] && echo "ALL PASS" || {
  echo "$fails FAILED"
  exit 1
}
