#!/usr/bin/env bash
# test-digest-send-schedule.sh — hermetic proof for the 2026-09-27
# three-digests-a-day doctrine (course-correction slice 2):
# cadence/subhour/57-digest-send.sh fires email-digest.py --html + the
# notify-email send ONLY at the NY slots 0730/1530/2200 (+-3 min), exactly
# once per slot per NY day (stamp file), and honours the operator/demo
# escape HNGH_DIGEST_FORCE_SLOT=<HHMM> only when HNGH_DIGEST_TEST=1 is
# also set. A missing conf is dormant (artifacts still written); a send
# failure files an alert row and does NOT retry within the slot.
# Stubs: digest command via HNGH_DIGEST_BIN, notify-email.py copied into
# the sandbox scripts/ (the path lib/notify-email.sh resolves), report-queue
# stub in the sandbox kernel. No real send, no real ledger, no network.
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"
sb="$(mktemp -d)"
trap 'rm -rf "$sb"' EXIT
mkdir -p "$sb/kernel/scripts" "$sb/auto/bin" "$sb/auto/scripts" \
  "$sb/auto/logs" "$sb/auto/lib" "$sb/stamps"
ln -s "$root/lib/notify-email.sh" "$sb/auto/lib/"
ln -s "$root/lib/breadcrumbs.sh" "$sb/auto/lib/"
ln -s "$root/lib/common.sh" "$sb/auto/lib/"
cp "$root/scripts/notify-email.py" "$sb/auto/scripts/notify-email.py"
DIGEST="$root/cadence/subhour/57-digest-send.sh"
[ -f "$DIGEST" ] || {
  echo "FAIL: $DIGEST missing"
  exit 1
}

fails=0
check() { # check <desc> <expected> <actual>
  if [ "$2" = "$3" ]; then printf 'ok %s\n' "$1"; else
    printf 'FAIL %s: expected [%s] got [%s]\n' "$1" "$2" "$3"
    fails=$((fails + 1))
  fi
}

# stub digest command: touches the marker (proves it ran)
cat >"$sb/auto/bin/digest-stub" <<'EOF'
#!/usr/bin/env bash
touch "$DIGEST_MARKER"
EOF
chmod +x "$sb/auto/bin/digest-stub"

# sandbox notify-email.py: records sends; exit code from SEND_RC
cat >"$sb/auto/scripts/notify-email.py" <<'EOF'
#!/usr/bin/env python3
import os, sys
with open(os.environ["SEND_LOG"], "a") as f:
    f.write(" ".join(sys.argv[1:]) + "\n")
sys.exit(int(os.environ.get("SEND_RC", "0")))
EOF

# kernel report-queue stub (the drop-in invokes it via python3)
cat >"$sb/kernel/scripts/report-queue" <<'EOF'
#!/usr/bin/env python3
import os, sys
with open(os.environ["RQ_LOG"], "a") as f:
    f.write(" ".join(sys.argv[1:]) + "\n")
EOF
chmod +x "$sb/kernel/scripts/report-queue"

# conf exists -> the send path is armed (the stub is the transport)
: >"$sb/notify-email.conf"
chmod 600 "$sb/notify-email.conf"

sends() {
  if [ -f "$sb/sends.log" ]; then
    grep -c -- '--subject' "$sb/sends.log"
  else
    printf '0'
  fi
}

run() { # run [K=V ...] — extra K=V pairs land in env (last wins)
  local rc=0
  (cd "$sb" && env HNGH_HOME="$sb/kernel" HNGH_AUTOMATION_ROOT="$sb/auto" \
    HNGH_DIGEST_STAMP_DIR="$sb/stamps" PATH="$sb/auto/bin:$PATH" \
    DIGEST_MARKER="$sb/marker" SEND_LOG="$sb/sends.log" \
    RQ_LOG="$sb/rq.log" HNGH_NOTIFY_EMAIL_CONF="$sb/notify-email.conf" \
    HNGH_CRUMBS_DB="$sb/crumbs.db" \
    HNGH_DIGEST_BIN="$sb/auto/bin/digest-stub" \
    "$@" \
    bash "$DIGEST") || rc=$?
  printf '%s' "$rc"
}
reset_stamps() {
  rm -rf "$sb/stamps" "$sb/marker" "$sb/sends.log" "$sb/rq.log"
  mkdir -p "$sb/stamps"
}

# 1) off-slot run: no digest, no send, exit 0
reset_stamps
out="$(run HNGH_DIGEST_NOW_HHMM=1200)"
check "off-slot exits 0" "0" "$out"
check "off-slot runs no digest" "" "$([ -f "$sb/marker" ] && echo x)"
check "off-slot sends nothing" "0" "$(sends)"

# 2) force slot with TEST flag: fires exactly once; second run no-ops
reset_stamps
out="$(run HNGH_DIGEST_TEST=1 HNGH_DIGEST_FORCE_SLOT=1530)"
check "force slot exits 0" "0" "$out"
check "force slot ran the digest" "x" "$([ -f "$sb/marker" ] && echo x)"
check "force slot sent one digest" "1" "$(sends)"
rm -f "$sb/marker"
out="$(run HNGH_DIGEST_TEST=1 HNGH_DIGEST_FORCE_SLOT=1530)"
check "second same-slot run exits 0" "0" "$out"
check "no digest re-run within the slot" "" "$([ -f "$sb/marker" ] && echo x)"
check "no second send within the slot" "1" "$(sends)"

# 3) force without the TEST flag is ignored (live-safety interlock)
reset_stamps
out="$(run HNGH_DIGEST_FORCE_SLOT=1530)"
check "force without TEST flag exits 0" "0" "$out"
check "force without TEST flag runs nothing" "" \
  "$([ -f "$sb/marker" ] && echo x)"

# 4) send failure: alert row filed, exactly-once preserved (no retry)
reset_stamps
out="$(run HNGH_DIGEST_TEST=1 HNGH_DIGEST_FORCE_SLOT=0730 SEND_RC=1)"
check "send failure still exits 0 (fail-closed doctrine)" "0" "$out"
grep -q -- '--add alert' "$sb/rq.log" 2>/dev/null
check "send failure filed an alert row" "0" "$?"
out="$(run HNGH_DIGEST_TEST=1 HNGH_DIGEST_FORCE_SLOT=0730 SEND_RC=0)"
check "retry attempt after failure exits 0" "0" "$out"
check "failed slot did not retry the send" "1" "$(sends)"

if [ "$fails" -gt 0 ]; then
  printf '%d check(s) failed\n' "$fails"
  exit 1
fi
echo "digest-send schedule: all checks passed"
