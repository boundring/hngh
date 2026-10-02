#!/usr/bin/env bash
# test-review-prep-sections.sh -- duplicate-review-evidence fix
# (2026-10-02). 04-review-prep.sh's two packet sections were byte
# identical: repo_review() ran the same unscoped `git log` twice (kernel
# and automation are ONE git repo since the 2026-09-07 subtree import),
# so every review double-counted the same range. Fixed shape: repo_review
# <dir> <label> <pathspec...> splits one history (kernel surface
# . ':(exclude)automation' vs the automation subtree automation), and the
# packet headings, range lines, and both verdict loops share the same
# literal labels (K_LABEL=hngh / A_LABEL=hngh-automation) -- never a
# basename-derived one (findings were filed under "hngh-automation" while
# the progress loop matched basename=automation and reported 0 findings).
# 09-email-digest.sh carried the same duplication class in its two commit
# gathers; this pins their pathspec split too.
# Hermetic: mktemp fixture repo, no network, no model, no repo writes.
set -u
unset GIT_DIR GIT_WORK_TREE
root="$(cd "$(dirname "$0")/.." && pwd)"
script="$root/cadence/calendar/daily/04-review-prep.sh"
dscript="$root/cadence/calendar/daily/09-email-digest.sh"
fails=0
ck() { # desc expected actual
 if [ "$2" = "$3" ]; then echo "ok: $1"; else
  echo "FAIL: $1 (want [$2] got [$3])"
  fails=$((fails + 1))
 fi
}
yesno() { if "$@" >/dev/null 2>&1; then echo yes; else echo no; fi; }
prefix() { case "$2" in "$1"*) echo yes ;; *) echo no ;; esac }

# --- static: the label seam is literal and shared -----------------------
ck "K_LABEL literal defined" yes "$(yesno grep -qE '^K_LABEL=hngh$' "$script")"
ck "A_LABEL literal defined" yes \
 "$(yesno grep -qE '^A_LABEL=hngh-automation$' "$script")"
ck "no basename-derived automation label" no \
 "$(yesno grep -qF 'basename "$AUTOMATION_ROOT"' "$script")"
ck "verdict loops use the labels (x2)" 2 \
 "$(grep -cF 'for repo in "$K_LABEL" "$A_LABEL"' "$script")"
ck "kernel call site: root minus automation" yes \
 "$(yesno grep -qF "repo_review \"\$KERNEL\" \"\$K_LABEL\" . ':(exclude)automation'" "$script")"
ck "automation call site: subtree only" yes \
 "$(yesno grep -qF "repo_review \"\$KERNEL\" \"\$A_LABEL\" automation" "$script")"
ck "repo_review passes pathspec to both git logs (x2)" 2 \
 "$(sed -n '/^repo_review()/,/^}/p' "$script" | grep -cF -- '-- "$@"')"

# --- behavioral: the real repo_review() splits one repo's history -------
fn="$(sed -n '/^repo_review()/,/^}/p' "$script")"
if [ -z "$fn" ]; then
 echo "FAIL: repo_review() not extractable from $script"
 exit 1
fi
eval "$fn"
marked_cut() { cat; } # stub the packet cap

fix="$(mktemp -d)"
trap 'rm -rf "$fix"' EXIT
git -C "$fix" init -q
git -C "$fix" config user.email t@t
git -C "$fix" config user.name t
printf one >"$fix/README.md"
git -C "$fix" add README.md
git -C "$fix" commit -qm "root-only commit"
mkdir -p "$fix/automation"
printf two >"$fix/automation/x.sh"
git -C "$fix" add automation/x.sh
git -C "$fix" commit -qm "automation-only commit"
printf three >"$fix/NOTES.md"
git -C "$fix" add NOTES.md
git -C "$fix" commit -qm "second root commit"

packet=""
ranges=""
repo_review "$fix" hngh . ':(exclude)automation'
r_k="$ranges"
p_k="$packet"
packet=""
ranges=""
repo_review "$fix" hngh-automation automation
r_a="$ranges"
p_a="$packet"

ck "ranges differ across sections" no "$(yesno test "$r_k" = "$r_a")"
ck "packets differ across sections" no "$(yesno test "$p_k" = "$p_a")"
ck "kernel range line labeled hngh" yes "$(prefix '- hngh: ' "$r_k")"
ck "automation range line labeled hngh-automation" yes \
 "$(prefix '- hngh-automation: ' "$r_a")"
ck "kernel heading ## hngh (x1)" 1 \
 "$(printf '%s' "$p_k" | grep -cFx '## hngh')"
ck "kernel section keeps root commits" yes \
 "$(yesno grep -qF 'root-only commit' <<<"$p_k")"
ck "kernel section second root commit" yes \
 "$(yesno grep -qF 'second root commit' <<<"$p_k")"
ck "kernel section free of automation commits" no \
 "$(yesno grep -qF 'automation-only commit' <<<"$p_k")"
ck "automation heading ## hngh-automation (x1)" 1 \
 "$(printf '%s' "$p_a" | grep -cFx '## hngh-automation')"
ck "automation section keeps automation commits" yes \
 "$(yesno grep -qF 'automation-only commit' <<<"$p_a")"
ck "automation section free of root commits" no \
 "$(yesno grep -qF 'root-only commit' <<<"$p_a")"

# --- 09-email-digest.sh: same duplication class, same pathspec split ----
ck "digest kernel gather excludes automation" yes \
 "$(yesno grep -qF "log --since='24 hours ago' --oneline --no-decorate -- . ':(exclude)automation'" "$dscript")"
ck "digest automation gather is subtree only" yes \
 "$(yesno grep -qF "log --since='24 hours ago' --oneline --no-decorate -- automation " "$dscript")"

if [ "$fails" -gt 0 ]; then
 echo "test-review-prep-sections: $fails failure(s)"
 exit 1
fi
echo "test-review-prep-sections: all pass"
exit 0
