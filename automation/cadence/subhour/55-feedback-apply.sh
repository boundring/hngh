#!/usr/bin/env bash
# cadence/subhour — feedback auto-apply beat (operator interactivity, apply
# slice 2026-09-11): applies whitelisted [quick] css-theme/data-format
# operator feedback to dashboard/style.css (clamped, capped, reversible
# via jobs/feedback-apply.py --revert-last), runs named checks for
# correction items, files inspection rows. Dashboard surface is the
# gitignored runtime directory; edits there are reversible file edits.
# self-gate (31-heartbeat stamp pattern): one real run per 1800s - the
# former 30m beat, paced by stamp since the 2026-09-24 tier collapse.
STAMP="/tmp/.hngh-cadence-55-feedback-apply-last"; now="$(date +%s)"
last="$(cat "$STAMP" 2>/dev/null || printf '0')"; last="${last//[!0-9]/}"; last="${last:-0}"
[ $((now - last)) -ge 1800 ] || exit 0
printf '%s\n' "$now" >"$STAMP"

root="$(cd "$(dirname "$0")/../.." && pwd)"
exec python3 "$root/jobs/feedback-apply.py"
