# git-push.sh — push-on-demand: push the current branch to origin.
# Shared by every path that plain-commits (the sweep tier). Fail-closed:
# success and no-remote are quiet; a failed push files an alert row
# through the same kernel report-queue writer accept-plans.py uses and
# NEVER returns nonzero — a lost push must not block the sweep.
. "$AUTOMATION_ROOT/lib/common.sh"
. "$AUTOMATION_ROOT/lib/breadcrumbs.sh"
. "$AUTOMATION_ROOT/lib/notify-email.sh"

PUSH_REMOTE="${PUSH_REMOTE:-origin}"

push_branch() { # [remote] [branch] -> 0 always
  local remote="${1:-$PUSH_REMOTE}" branch out rc
  git remote get-url "$remote" >/dev/null 2>&1 || return 0
  branch="${2:-$(git branch --show-current)}"
  [ -n "$branch" ] || return 0
  out="$(git push "$remote" "$branch" 2>&1)"
  rc=$?
  if [ "$rc" = "0" ]; then
    breadcrumb "$JOB_NAME" "git-push" "pushed $branch to $remote"
    return 0
  fi
  breadcrumb "$JOB_NAME" "git-push-fail" \
    "push $branch rc=$rc: $(printf '%s' "$out" | tail -n1)"
  alert_row "git-push:$branch" 86400 "[hngh] git push failed: $branch" \
    "git push of $branch to $remote failed rc=$rc: $out"
  return 0
}
