#!/usr/bin/env bash
# cadence/30m — feedback auto-apply beat (operator interactivity, apply
# slice 2026-09-11): applies whitelisted [quick] css-theme/data-format
# operator feedback to dashboard/style.css (clamped, capped, reversible
# via jobs/feedback-apply.py --revert-last), runs named checks for
# correction items, files inspection rows. Dashboard surface is the
# gitignored runtime directory; edits there are reversible file edits.
root="$(cd "$(dirname "$0")/../.." && pwd)"
exec python3 "$root/jobs/feedback-apply.py"
