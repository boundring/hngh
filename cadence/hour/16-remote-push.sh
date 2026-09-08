#!/usr/bin/env bash
# 16-remote-push — cyclical origin push, hour-tier, gate-gated, never forced.
#
# For each repo (the hngh kernel + this automation repo): when local is
# ahead of upstream, push the default branch to origin — but only when the
# tree has nothing staged (never push half-landed operator work) and the
# last gate signal for that repo is green (crumb recorded by 03-gate-check;
# no crumb -> run `make test` quietly). Refusal, unreachability and auth
# failures breadcrumb and exit 0 — never retried in-script. Runs at most
# once per cadence-hours (cadence-params.tsv `push-cadence-hours`, stamp
# file, same pattern as 11-service-recovery's one-attempt/day stamp).
# Pushing is authorized by hngh AGENTS.md; never --force, only the
# checked-out default branch.
#
# usage: cadence/hour/16-remote-push.sh   (via jobs/cadence-tick.sh TIER=hour)
set -u
. "$(cd "$(dirname "$0")/../.." && pwd)/lib/common.sh"
. "$AUTOMATION_ROOT/lib/breadcrumbs.sh"
. "$AUTOMATION_ROOT/lib/params.sh"

KERNEL="${HNGH_HOME:-$HOME/Projects/etc/hngh}"
AUTO="${HNGH_AUTOMATION_HOME:-$AUTOMATION_ROOT}" # seam for hermetic tests
JOB_NAME="${JOB_NAME:-16-remote-push}"
STAMP="${HNGH_PUSH_STAMP:-$HOME/.hngh-automation/.remote-push-stamp}"
HOURS="$(get_param push-cadence-hours 24)"
HOURS="${HNGH_PUSH_CADENCE_HOURS:-${HOURS:-24}}"

# one run per cadence-hours, not per script invocation
if [ -r "$STAMP" ]; then
 last="$(cat "$STAMP" 2>/dev/null)"
 now="$(date -u +%s)"
 case "$last" in '' | *[!0-9]*) last=0 ;; esac
 [ $((now - last)) -lt $((HOURS * 3600)) ] && exit 0
fi
mkdir -p "$(dirname "$STAMP")" 2>/dev/null || true
date -u +%s >"$STAMP" 2>/dev/null || true

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
 red)
  breadcrumb "$JOB_NAME" "push-refused" "$name: gate-red crumb — run the gate before pushing"
  return 0
  ;;
 none | stale)
  if (cd "$dir" && make test >/dev/null 2>&1); then
   [ "$gate_state" = stale ] &&
    breadcrumb "$JOB_NAME" "gate-refresh" \
     "$name: gate crumb older than HEAD — make test re-run green"
  else
   breadcrumb "$JOB_NAME" "push-refused" \
    "$name: gate $gate_state and make test failed — not pushing"
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
push_repo hngh-automation "$AUTO"
exit 0
