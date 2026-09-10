#!/usr/bin/env bash
# test-remote-push.sh — sandbox proof for 16-remote-push.sh gate handling:
# a stale gate-red crumb must re-run the repo gate inline (the crumb says
# "run the gate before pushing") and push on fresh green; a red crumb with
# a genuinely red gate still refuses; no crumb pushes on green. Hermetic:
# fixture repos, no real origin, no real gate.
set -u
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
  HNGH_HOME="$1" STATE_FILE="$sb/STATE.md" \
    HNGH_PUSH_LOCK="$sb/push.lock" JOB_NAME=test-push \
    bash "$root/cadence/hour/16-remote-push.sh" 2>&1
}
crumbs() { grep -c "test-push" "$sb/STATE.md"; }
reset_state() { : >"$sb/STATE.md"; }
# fixture: bare origin + worktree one commit ahead, stub gate via Makefile
fixture() { # dir gate-rc
  local d="$1" rc="$2"
  git init -q --bare "$d-origin.git"
  git init -q "$d"
  (cd "$d" &&
   printf 'test:\n\t@exit %s\n' "$rc" > Makefile &&
   git add Makefile &&
   git -c user.email=t@t -c user.name=t commit -qm init &&
   git branch -M main &&
   git remote add origin "$d-origin.git" &&
   git push -q -u origin main)
}
new_commit() { # workdir
  (cd "$1" && echo x >> f.txt && git add f.txt &&
   git -c user.email=t@t -c user.name=t commit -qm more)
}
ahead_count() { git -C "$1" rev-list --count "origin/main..main" 2>/dev/null; }
red_crumb() { printf '2026-09-09T09:00:49Z | 03-gate-check.sh | gate-red | hngh: make test rc=2\n' >> "$sb/STATE.md"; }

# case 1: stale red crumb, gate now green -> gate re-run, push lands
d="$sb/c1"; fixture "$d" 0; new_commit "$d"; red_crumb
run_push "$d" >/dev/null
ck "red-crumb green-gate pushes" "0" "$(ahead_count "$d")"

# case 2: red crumb, gate genuinely red -> refused, still ahead
reset_state; red_crumb
d="$sb/c2"; fixture "$d" 1; new_commit "$d"
run_push "$d" >/dev/null
ck "red-crumb red-gate refuses" "1" "$(ahead_count "$d")"
ck "refusal crumb filed" "1" "$(crumbs)"

# case 3: no crumb, green gate -> push lands (existing contract)
reset_state
d="$sb/c3"; fixture "$d" 0; new_commit "$d"
run_push "$d" >/dev/null
ck "no-crumb green-gate pushes" "0" "$(ahead_count "$d")"

# case 4: red crumb, gate fails -> refusal crumb carries the failure tail
# (evidence, not silence - the 02:00:41Z inline re-run recorded nothing)
reset_state; red_crumb
d="$sb/c4"; fixture "$d" 1; new_commit "$d"
run_push "$d" >/dev/null
ck "failing-gate refusal crumbs" "1" "$(crumbs)"
ck "failure tail captured in crumb" "1" \
  "$(grep -c "FAILED\|Error" "$sb/STATE.md" || true)"

echo "---"
[ "$fails" -eq 0 ] && echo "ALL PASS" || { echo "$fails FAILED"; exit 1; }
