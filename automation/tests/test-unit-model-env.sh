#!/usr/bin/env bash
# test-unit-model-env.sh — every unit that can reach overnight-cycle.sh
# (directly via hngh-overnight.service, or via the hour-tier workbeat
# lane 20-workbeat.sh exec'ing it under hngh-cadence-hour.service) must
# carry OVERNIGHT_MODEL in its tracked [Service] section. The 2026-09-10
# flap: only hngh-overnight.service had the drop-in, so the 23:15Z
# workbeat session silently fell to the local-bench model.
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"
fails=0
ck() {
  if [ "$2" = "$3" ]; then echo "ok: $1"; else
    echo "FAIL: $1 (want [$2] got [$3])"
    fails=$((fails + 1))
  fi
}
has_env() { # unit-file -> 0 when [Service] sets OVERNIGHT_MODEL
  awk '/^\[Service\]/{s=1;next} /^\[/{s=0} s && /^Environment=OVERNIGHT_MODEL=/' "$1" | grep -q .
}
# the two lanes that exec scripts/overnight-cycle.sh (direct or via
# cadence/hour/20-workbeat.sh)
for u in hngh-overnight.service hngh-cadence-hour.service; do
  f="$root/systemd/$u"
  [ -f "$f" ] || { echo "FAIL: missing unit $f"; fails=$((fails + 1)); continue; }
  if has_env "$f"; then v=1; else v=0; fi
  ck "$u carries OVERNIGHT_MODEL" "1" "$v"
done
echo "---"
[ "$fails" -eq 0 ] && echo "ALL PASS" || { echo "$fails FAILED"; exit 1; }
