#!/usr/bin/env bash
# test-remote-push.sh — sandbox proof for 16-remote-push.sh gate handling:
# a stale gate-red crumb must re-run the repo gate inline (the crumb says
# "run the gate before pushing") and push on fresh green; a red crumb with
# a genuinely red gate still refuses; no crumb pushes on green. A held
# gate lock defers the push (never races a gate evaluation). Hermetic:
# fixture repos, no real origin, no real gate.
set -u
# fixture containment: never inherit repo selection from the caller's shell (2026-09-17 kernel-contamination lesson)
unset GIT_DIR GIT_WORK_TREE
root="$(cd "$(dirname "$0")/.." && pwd)"
sb="$(mktemp -d)"
trap 'rm -rf "$sb"' EXIT
mkdir -p "$sb"
: >"$sb/STATE.md"
fails=0
ck() { # desc expected actual
 if [ "$2" = "$3" ]; then echo "ok: $1"; else
  echo "FAIL: $1 (want [$2] got [$3])"
  fails=$((fails + 1))
 fi
}
run_push() { # repo-dir -> runs the real script against it
 mkdir -p "$sb/logs" "$sb/tmp"
 HNGH_HOME="$1" HNGH_CRUMBS_DB="$sb/crumbs.db" \
  HNGH_PUSH_LOCK="$sb/push.lock" JOB_NAME=test-push \
  GATE_RERUN_DIR="$sb/logs" GATE_LOCK="$sb/gate.lock" TMPDIR="$sb/tmp" \
  bash "$root/cadence/hour/16-remote-push.sh" 2>&1
}
crumbs() {
 python3 "$root/lib/crumbs-db.py" export --db "$sb/crumbs.db" |
  grep -c "test-push"
}
reset_state() {
 : >"$sb/STATE.md"
 rm -f "$sb/crumbs.db" "$sb/crumbs.db-wal" "$sb/crumbs.db-shm"
}
# fixture: bare origin + worktree one commit ahead, stub gate via Makefile
fixture() { # dir gate-rc
 local d="$1" rc="$2"
 git init -q --bare "$d-origin.git"
 git init -q "$d"
 (cd "$d" &&
  printf 'test:\n\t@exit %s\n' "$rc" >Makefile &&
  git add Makefile &&
  git -c user.email=t@t -c user.name=t commit -qm init &&
  git branch -M main &&
  git remote add origin "$d-origin.git" &&
  git push -q -u origin main)
}
new_commit() { # workdir
 (cd "$1" && echo x >>f.txt && git add f.txt &&
  git -c user.email=t@t -c user.name=t commit -qm more)
}
ahead_count() { git -C "$1" rev-list --count "origin/main..main" 2>/dev/null; }
red_crumb() {
 printf '2026-09-09T09:00:49Z | 03-gate-check.sh | gate-red | hngh: make test rc=2\n' >>"$sb/STATE.md"
 python3 "$root/lib/crumbs-db.py" sync --state "$sb/STATE.md" --db "$sb/crumbs.db"
}

# case 1: stale red crumb, gate now green -> gate re-run, push lands
d="$sb/c1"
fixture "$d" 0
new_commit "$d"
red_crumb
run_push "$d" >/dev/null
ck "red-crumb green-gate pushes" "0" "$(ahead_count "$d")"

# case 2: red crumb, gate genuinely red -> refused, still ahead
reset_state
red_crumb
d="$sb/c2"
fixture "$d" 1
new_commit "$d"
run_push "$d" >/dev/null
ck "red-crumb red-gate refuses" "1" "$(ahead_count "$d")"
ck "refusal crumb filed" "1" "$(crumbs)"

# case 3: no crumb, green gate -> push lands (existing contract)
reset_state
d="$sb/c3"
fixture "$d" 0
new_commit "$d"
run_push "$d" >/dev/null
ck "no-crumb green-gate pushes" "0" "$(ahead_count "$d")"

# case 4: red crumb, gate fails -> refusal crumb carries the failure tail
# (evidence, not silence - the 02:00:41Z inline re-run recorded nothing)
reset_state
red_crumb
d="$sb/c4"
fixture "$d" 1
new_commit "$d"
run_push "$d" >/dev/null
ck "failing-gate refusal crumbs" "1" "$(crumbs)"
ck "failure tail captured in crumb" "1" \
 "$(python3 "$root/lib/crumbs-db.py" export --db "$sb/crumbs.db" |
  grep -c "FAILED\|Error" || true)"
ck "no shared gate log after failing run" "0" \
 "$([ -e /tmp/hngh-gate-rerun-hngh.log ] && echo 1 || echo 0)"
ck "failing rerun logs land in sandbox" "2" \
 "$(ls "$sb/logs"/gate-rerun-* 2>/dev/null | wc -l)"
ck "automation/logs untouched by test" "0" \
 "$(find "$root/logs" -name 'gate-rerun-*' -newer "$sb/STATE.md" 2>/dev/null | wc -l)"

# case 5: gate log hygiene - a run leaves no shared /tmp log behind
# (unique per-invocation names; the fixed name let the fixtures
# cross-contaminate real evidence, 2026-09-10)
reset_state
d="$sb/c5"
fixture "$d" 0
new_commit "$d"
[ -e /tmp/hngh-gate-rerun-hngh.log ] && shared_leak=1 || shared_leak=0
run_push "$d" >/dev/null
ck "no shared gate log after green run" "0" "$shared_leak"

# case 6: red crumb + gate green, but a gate evaluation holds the gate
# lock -> push deferred: no inline re-run, no red crumb, no gate log
# (a busy lock is not a red gate)
reset_state
red_crumb
d="$sb/c6"
fixture "$d" 0
new_commit "$d"
: >"$sb/marker6"
# pkill the -c child too: it inherits the locked fd, and killing the
# flock wrapper alone would leak the shared lock into case 7
flock -s "$sb/gate.lock" -c "touch '$sb/lock-held'; sleep 5" &
flock_pid=$!
for _ in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20; do
 [ -e "$sb/lock-held" ] && break
 sleep 0.1
done
run_push "$d" >/dev/null
pkill -P "$flock_pid" 2>/dev/null
kill "$flock_pid" 2>/dev/null
wait "$flock_pid" 2>/dev/null
ck "held gate lock defers push" "1" "$(ahead_count "$d")"
ck "gate-lock-busy crumb filed" "1" \
 "$(python3 "$root/lib/crumbs-db.py" export --db "$sb/crumbs.db" | grep -c 'gate-lock-busy')"
ck "held gate lock writes no gate log" "0" \
 "$(find "$sb/tmp" "$sb/logs" -name 'gate-rerun-*' -newer "$sb/marker6" 2>/dev/null | wc -l)"
ck "held gate lock files no gate crumb" "0" \
 "$(python3 "$root/lib/crumbs-db.py" export --db "$sb/crumbs.db" | grep -c 'push-refused\|gate-refresh')"

# case 7: red crumb + gate green + gate lock FREE -> the inline re-run
# runs and the push lands (case-1 contract with the lock in play)
reset_state
red_crumb
d="$sb/c7"
fixture "$d" 0
new_commit "$d"
: >"$sb/marker7"
run_push "$d" >/dev/null
ck "free gate lock pushes" "0" "$(ahead_count "$d")"
ck "free gate lock re-runs the gate" "1" \
 "$(find "$sb/tmp" -name 'gate-rerun-*' -newer "$sb/marker7" 2>/dev/null | wc -l)"
ck "free gate lock files gate-refresh crumb" "1" \
 "$(python3 "$root/lib/crumbs-db.py" export --db "$sb/crumbs.db" | grep -c 'gate-refresh')"

echo "---"
[ "$fails" -eq 0 ] && echo "ALL PASS" || {
 echo "$fails FAILED"
 exit 1
}
