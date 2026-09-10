#!/usr/bin/env bash
# 16-remote-push — origin push, gate-gated, never forced, event-driven.
#
# When local is ahead of upstream, push the default branch to origin —
# but only when the tree has nothing staged (never push half-landed
# operator work) and the last gate signal for the repo is green (crumb
# recorded by 03-gate-check; no crumb -> run `make test` quietly).
# Refusal, unreachability and auth failures breadcrumb and exit 0 —
# never retried in-script.
# Event-driven (2026-09-08): the git post-commit hook fires this after
# every verified commit; the hour tick is the backstop. A nonblocking
# flock serializes concurrent invocations — rapid commits lose the race
# and exit 0; the winner pushes. The push-cadence-hours stamp gate is
# gone: the commit event plus the script's own quality gates ARE the
# pacing. Automation merged into the kernel repo (one repo, one origin)
# — one push covers both trees.
# Pushing is authorized by hngh AGENTS.md; never --force, only the
# checked-out default branch.
#
# usage: fired by the git post-commit hook; backstop via
#   cadence/hour/16-remote-push.sh   (jobs/cadence-tick.sh TIER=hour)
set -u
. "$(cd "$(dirname "$0")/../.." && pwd)/lib/common.sh"
. "$AUTOMATION_ROOT/lib/breadcrumbs.sh"

KERNEL="${HNGH_HOME:-$HOME/Projects/etc/hngh}"
JOB_NAME="${JOB_NAME:-16-remote-push}"

# serialize concurrent invocations (rapid commits): the first run in
# pushes; later ones find it busy and exit immediately — no duplicate
# make-test runs, no double push
exec 9>"${HNGH_PUSH_LOCK:-/tmp/.hngh-remote-push-lock}"
flock -n 9 || exit 0

# last_gate <label> — echoes "<state> <crumb-iso-ts>" from the latest
# gate-check crumb for that repo (green/red/none + its timestamp).
last_gate() {
 local label="$1" line
 line="$(grep -E "\| [^|]+ \| gate-(green|red) \| $label: " "$STATE_FILE" 2>/dev/null |
  tail -n 1)"
 case "$line" in
 *"| gate-green |"*) echo "green ${line%% | *}" ;;
 *"| gate-red |"*) echo "red ${line%% | *}" ;;
 *) echo none ;;
 esac
}

crumb_epoch() { date -ud "$1" +%s 2>/dev/null || echo 0; }

push_repo() { # name dir
 local name="$1" dir="$2" branch up out
 [ -d "$dir/.git" ] || {
  breadcrumb "$JOB_NAME" "push-refused" "$name: not a git repo ($dir)"
  return 0
 }
 branch="$(git -C "$dir" symbolic-ref --short HEAD 2>/dev/null)" || return 0
 up="$(git -C "$dir" rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null)" || {
  breadcrumb "$JOB_NAME" "push-refused" "$name: no upstream configured"
  return 0
 }
 [ "$branch" = "$(git -C "$dir" rev-parse --abbrev-ref '@{u}' 2>/dev/null | sed 's|^origin/||')" ] || {
  breadcrumb "$JOB_NAME" "push-refused" "$name: checked-out branch $branch is not the remote default"
  return 0
 }
 git -C "$dir" fetch --quiet "$up" 2>/dev/null || true
 ahead="$(git -C "$dir" rev-list --count "@{u}..HEAD" 2>/dev/null)" || ahead=0
 [ "$ahead" -gt 0 ] || {
  breadcrumb "$JOB_NAME" "push-up-to-date" "$name: HEAD equals upstream"
  return 0
 }
 if ! git -C "$dir" diff --cached --quiet; then
  breadcrumb "$JOB_NAME" "push-refused" "$name: staged changes present — not pushing half-landed work"
  return 0
 fi
 set -- $(last_gate "$name")
 gate_state="$1"
 crumb_ts="${2:-}"
 # staleness: a green crumb older than the newest unpushed commit proves
 # nothing about that commit — re-run the repo's own gate inline.
 if [ "$gate_state" = green ] && [ -n "$crumb_ts" ] &&
  [ "$(git -C "$dir" log -1 --format=%ct "@{u}..HEAD")" -gt "$(crumb_epoch "$crumb_ts")" ]; then
  gate_state=stale
 fi
 case "$gate_state" in
 red | none | stale)
  # a red crumb is the last measurement, not the current state: the
  # 2026-09-09 flap left a morning red crumb refusing pushes for ~14h
  # while the gate was intermittently green — re-run the gate inline,
  # exactly what the crumb itself demands
  # unique per invocation: a fixed name let concurrent pushes (hook-fired
  # + tick) and the test fixtures clobber one shared log, cross-
  # contaminating the captured evidence (2026-09-10 diagnosis)
  gate_log="${TMPDIR:-/tmp}/hngh-gate-rerun-$name-$$.log"
  if (cd "$dir" && timeout 290 make test >"$gate_log" 2>&1); then
   [ "$gate_state" != none ] &&
    breadcrumb "$JOB_NAME" "gate-refresh" \
     "$name: gate crumb was $gate_state — make test re-run green"
  else
   gate_tail="$(tail -n 3 "$gate_log" 2>/dev/null | cut -c1-160 | tr '\n' ' ')"
   rr="${GATE_RERUN_DIR:-$AUTOMATION_ROOT/logs}"
   mv "$gate_log" "$rr/gate-rerun-$name-$(date +%H%M%S)-$$.log" \
    2>/dev/null || true
   breadcrumb "$JOB_NAME" "push-refused" \
    "$name: gate $gate_state and make test failed — not pushing; tail: $gate_tail"
   return 0
  fi
  ;;
 esac
 if out="$(git -C "$dir" push "${up%%/*}" "$branch" 2>&1)"; then
  breadcrumb "$JOB_NAME" "push-done" "$name: pushed $ahead commit(s) to $up"
 else
  breadcrumb "$JOB_NAME" "push-refused" \
   "$name: push failed (not retried): $(printf '%s' "$out" | tail -n 1 | cut -c1-200)"
 fi
}

push_repo hngh "$KERNEL"
exit 0
