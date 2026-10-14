#!/usr/bin/env bash
# test-unit-model-env.sh — no unit may re-introduce an OVERNIGHT_MODEL
# override.
#
# This guard was INVERTED on 2026-10-14. It used to assert that every unit
# which can reach overnight-cycle.sh (directly via hngh-overnight.service,
# or via the hour-tier workbeat lane 20-workbeat.sh exec'ing it under
# hngh-cadence-hour.service) *did* carry OVERNIGHT_MODEL, because the
# 2026-09-10 flap had a workbeat session silently fall to a different model
# when only one of the two units had the drop-in.
#
# That flap is now structurally impossible: the env rung is gone from
# select_model, so there is no lane-dependent env to drop. An env in a unit
# is inert, and worse, it is *misleading* — it reads like operator steering
# while launch-session.sh already overrides it with cadence-params
# `opencode-model` on the common path. So the guard now asserts absence, and
# the comment in each unit points here.
#
# See docs/records/2026-10-14-overnight-model-pin-removal.md.
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
  ck "$u does not re-pin OVERNIGHT_MODEL" "0" "$v"
done
# The selector must not read the variable either: a rung that can still be
# reached by env would make the unit assertions above cosmetic.
if grep -q 'OVERNIGHT_MODEL' "$root/scripts/overnight-cycle.sh"; then
  echo "FAIL: overnight-cycle.sh still reads OVERNIGHT_MODEL"
  fails=$((fails + 1))
else
  echo "ok: overnight-cycle.sh no longer reads OVERNIGHT_MODEL"
fi
echo "---"
[ "$fails" -eq 0 ] && echo "ALL PASS" || { echo "$fails FAILED"; exit 1; }
