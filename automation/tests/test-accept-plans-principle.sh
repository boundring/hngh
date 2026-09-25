#!/usr/bin/env bash
# test-accept-plans-principle.sh -- refoundation P9 canon seam at the
# plan-acceptance boundary (2026-09-25): accept-plans.py accepts a
# proposed normal-risk plan only when its preamble (everything before
# the first '## ' heading) carries a `principle:` line naming one
# closed principle + doc anchor; a principle-less plan is blocked
# (`blocked <slug> missing-principle`), never accepted, never
# parked-as-critical, and never reaches the gates.
# Hermetic: mktemp sandboxes, stub gate + report-queue scripts, no
# network, no live model, no repo writes.
set -u
# fixture containment: never inherit repo selection from the caller's shell
unset GIT_DIR GIT_WORK_TREE
root="$(cd "$(dirname "$0")/.." && pwd)"
fails=0
ck() { # desc expected actual
 if [ "$2" = "$3" ]; then echo "ok: $1"; else
  echo "FAIL: $1 (want [$2] got [$3])"
  fails=$((fails + 1))
 fi
}

# mk_sandbox <dir> -- one disposable accept-plans world: kernel plans
# dir, automation root, stub gates (exit rc from $1), stub report queue.
mk_sandbox() {
 mkdir -p "$1/kernel/docs/project/plans" "$1/auto"
 cat >"$1/gate.sh" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$1 \$PWD" >> "$1/gate.log"
exit "\$1"
EOF
 chmod +x "$1/gate.sh"
 cat >"$1/queue.sh" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$*" >> "$1/queue.log"
EOF
 chmod +x "$1/queue.sh"
}

# write_plan <dir> <with-principle 1|0> -- minimal proposed normal-risk
# plan; the Verification line is indented per the runnable-check regex.
write_plan() {
 {
  printf '<!-- plan: status=proposed risk=normal accepted=- -->\n'
  printf '# fixture plan\n\n'
  [ "$2" = 1 ] &&
   printf 'principle: fail-closed — GOVERNANCE.md §6 (docs/project/decisions.md 2026-08-11)\n\n'
  printf '## Steps\n\n'
  printf -- '- [ ] Step 1: trivial\n'
  printf '      Verification: hermetic stub check\n'
 } >"$1/kernel/docs/project/plans/2026-09-25-principle-fixture.plan.md"
}

# run_accept <dir> -- run accept-plans.py against the sandbox; all env
# seams pointed inside it (email sidechannel disabled via absent conf).
run_accept() {
 DRY_RUN=0 \
  HNGH_HOME="$1/kernel" \
  HNGH_AUTOMATION_ROOT="$1/auto" \
  ACCEPT_KERNEL_GATE="$1/gate.sh 0" \
  ACCEPT_AUTOMATION_GATE="$1/gate.sh 0" \
  HNGH_REPORT_QUEUE="$1/queue.sh" \
  HNGH_REPORT_ROOT="$1/kernel" \
  ACCEPT_LOG="$1/auto/acceptance.log" \
  HNGH_RESEARCH_SUBJECTS="$1/research-subjects.txt" \
  HNGH_REPORT_IDENTITIES="$1/report-identities.json" \
  HNGH_NOTIFY_EMAIL_CONF="$1/notify-email-absent.conf" \
  python3 "$root/scripts/accept-plans.py"
}

# --- fixture A: plan WITH a principle line + green stub gates -> accepted
fa="$(mktemp -d)"
fb="$(mktemp -d)"
trap 'rm -rf "$fa" "$fb"' EXIT
mk_sandbox "$fa"
write_plan "$fa" 1
outa="$(run_accept "$fa")"
rca=$?
ck "A: exit 0 (fail-closed convention)" "0" "$rca"
ck "A: accepted line printed" "1" \
 "$(printf '%s\n' "$outa" | grep -c '^accepted 2026-09-25-principle-fixture ')"
ck "A: front-matter flipped to accepted" "1" \
 "$(grep -c 'status=accepted risk=normal accepted=2' \
  "$fa/kernel/docs/project/plans/2026-09-25-principle-fixture.plan.md")"
ck "A: both stub gates ran green" "2" "$([ -f "$fa/gate.log" ] && wc -l <"$fa/gate.log" || echo 0)"

# --- fixture B: identical plan WITHOUT the principle line -> blocked
mk_sandbox "$fb"
write_plan "$fb" 0
outb="$(run_accept "$fb")"
rcb=$?
ck "B: exit 0 (expected path)" "0" "$rcb"
ck "B: blocked missing-principle line" "1" \
 "$(printf '%s\n' "$outb" | grep -c '^blocked 2026-09-25-principle-fixture missing-principle$')"
ck "B: not parked" "0" \
 "$(printf '%s\n' "$outb" | grep -c '^parked ')"
planb="$fb/kernel/docs/project/plans/2026-09-25-principle-fixture.plan.md"
ck "B: front-matter unchanged (proposed, accepted=-)" "1" \
 "$(grep -c 'status=proposed risk=normal accepted=-' "$planb")"
ck "B: gates never ran" "0" "$([ -e "$fb/gate.log" ] && echo 1 || echo 0)"
ck "B: alert row filed naming missing-principle" "1" \
 "$(grep -c 'no principle line' "$fb/queue.log" 2>/dev/null || true)"

echo
if [ "$fails" -eq 0 ]; then echo "test-accept-plans-principle: ALL OK"; else
 echo "test-accept-plans-principle: $fails failure(s)"
 exit 1
fi
