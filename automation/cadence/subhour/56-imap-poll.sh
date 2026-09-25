#!/usr/bin/env bash
# cadence/subhour — imap-poll (operator meta-agentic surface: stall-recovery
# plan step 11, authorized by docs/records/2026-09-09-operator-flexibility-
# doctrine.md s4). Reads UNSEEN operator replies on the notify mailbox and
# files them as operator-items; plan decisions land as DRAFT proposals in
# automation/digest/ (never auto-accepted). Fail-closed: scripts/
# imap-poll.py exits 0 with a breadcrumb whenever the IMAP config is
# absent/unreadable (dormant channel is a normal state — missing creds
# are an operator setup item, never an alert). Processed messages are
# marked \Seen; never deleted, never expunged. Numbered 56: between
# 55-feedback-apply.sh and 58-patrol.sh; drop-ins run in lexical order
# and this has no ordering dependency.
# self-gate (31-heartbeat stamp pattern): one real run per 1800s - the
# former 30m beat, paced by stamp since the 2026-09-24 tier collapse.
STAMP="/tmp/.hngh-cadence-56-imap-poll-last"; now="$(date +%s)"
last="$(cat "$STAMP" 2>/dev/null || printf '0')"; last="${last//[!0-9]/}"; last="${last:-0}"
[ $((now - last)) -ge 1800 ] || exit 0
printf '%s\n' "$now" >"$STAMP"

root="$(cd "$(dirname "$0")/../.." && pwd)"
exec timeout 120 python3 "$root/scripts/imap-poll.py" "$@"
