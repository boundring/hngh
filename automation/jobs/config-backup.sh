#!/usr/bin/env bash
# config-backup — hngh-governed parity job for git-back-dots (gbd) lanes.
#
# Spike slice: build + prove per-lane parity with gbd. Cutover (disabling the
# gbd timers) is a LATER slice; this job changes nothing about gbd itself.
#
# Usage: config-backup.sh LANE [--dry-run] [--mode push]
#   --dry-run    read-only parity proof: manifest-from-sources vs gbd HEAD.
#   --mode push  push to origin AFTER a clean scan + local commit. Default
#                mode is commit-only. No push ever happens without it.
#
# gbd parity (git-back-dots 0.2.3, src/git_back_dots):
#   - snapshot layout files/<abs source path minus leading />
#   - ALL sources validated before any copy (no partial sync)
#   - files > GBD_MAX_FILE_BYTES are skipped (gbd max_file_bytes)
#   - git add -A, secret-scan staged files, fail closed BEFORE commit
#   - commit only if dirty; push origin only when a remote exists
#     (workaround lanes have none -> push=none, like gbd "push_skipped")
#   - workaround lanes: gbd additionally re-applies apply.sh on drift before
#     syncing; this job only records the file state (apply stays gbd's job
#     until cutover).
#
# Honesty laws: this job is observability/backup only — it never feeds
# governance input. Scan hits name the FILE and the pattern class, never the
# matched value. Fail-closed: missing source, scan hit, or push failure =
# alert report row + exit 1, never a partial push.
set -u
. "$(cd "$(dirname "$0")/.." && pwd)/lib/common.sh"
. "$AUTOMATION_ROOT/lib/breadcrumbs.sh"

report_queue="python3 $HNGH_HOME/scripts/report-queue"
report() { # kind text -> append one hngh report row (best effort)
 $report_queue --add "$1" "$2" >/dev/null 2>&1 || log "report-queue append failed"
}
fail() { # lane detail -> alert row, exit 1
 log "FAIL: $2"
 report alert "config-backup $1: $2"
 breadcrumb "$JOB_NAME" "alert" "config-backup $1: $2"
 exit 1
}

# ---- LANES (declarative: read from jobs/config-lanes.tsv next to this script;
#      operator-editable; mirrors gbd ~/.config/git-back-dots/config.toml) ----
GBD_MAX_FILE_BYTES=1048576
LANE_MANIFEST="$AUTOMATION_ROOT/jobs/config-lanes.tsv"
[ -f "$LANE_MANIFEST" ] || fail "" "lane manifest missing: $LANE_MANIFEST"

lane_row() { # lane -> first manifest row for $1; rc 1 = unknown lane
 [ -f "$LANE_MANIFEST" ] || return 1
 awk -F'\t' -v l="$1" '!/^#/ && $1==l {print; f=1; exit} END {exit f?0:1}' "$LANE_MANIFEST"
}
lane_field() { # lane N -> Nth TSV field of that lane's row; rc 1 = unknown lane
 local row
 row="$(lane_row "$1")" || return 1
 printf '%s' "$row" | awk -F'\t' -v i="$2" '{print $i}'
}
lane_repo() { # lane -> backup repo worktree (manifest stores $HOME-relative)
 local p
 p="$(lane_field "$1" 2)" || return 1
 printf '%s/%s\n' "$HOME" "$p"
}
lane_remote() { # lane -> declared push remote ("" = none, like gbd)
 lane_field "$1" 3 || return 1
}
lane_sources() { # lane -> tracked source paths, one per line (manifest stores $HOME-relative)
 local srcs s
 srcs="$(lane_field "$1" 4)" || return 1
 for s in $srcs; do printf '%s/%s\n' "$HOME" "$s"; done
}

# ---- secret scan (CREDENTIAL_PATTERN spirit; content classes, no values) ----
scan_secret() { # file -> echo reason class, rc 0 on hit (mirrors gbd CONTENT_PATTERNS)
 local f="$1"
 [ -s "$f" ] || return 1
 [ "$(head -c 8192 -- "$f" | tr -dc '\0' | wc -c)" -eq 0 ] || return 1 # binary
 if LC_ALL=C grep -Eq -e '-----BEGIN (RSA |EC |OPENSSH |DSA |PGP |ENCRYPTED )?PRIVATE KEY( BLOCK)?-----' -- "$f"; then
  echo 'private key block'
  return 0
 fi
 # Token-assignment class. An ALL-CAPS or ${VAR} value is an
 # environment REFERENCE, not a secret (e.g. hermes config.yaml
 # `api_key: UNSLOTH_API_KEY` pointing at the local inference server
 # -- settled 2026-08-27); any other literal value still trips.
 if LC_ALL=C grep -Ei -e '(api[_-]?key|api[_-]?secret|access[_-]?token|auth[_-]?token)[[:space:]]*[:=][[:space:]]*[^[:space:]]{8,}' -- "$f" |
  LC_ALL=C grep -Eiv -e '(api[_-]?key|api[_-]?secret|access[_-]?token|auth[_-]?token)[[:space:]]*[:=][[:space:]]*(\$\{[A-Za-z0-9_]+\}|[A-Z][A-Z0-9_]{7,})[[:space:]]*$' |
  LC_ALL=C grep -Eq .; then
  echo 'token assignment'
  return 0
 fi
 if LC_ALL=C grep -Eiq -e '(password|passwd)[[:space:]]*[:=][[:space:]]*[^[:space:]]{4,}' -- "$f"; then
  echo 'password assignment'
  return 0
 fi
 if LC_ALL=C grep -Eq -e 'ghp_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}|glpat-[A-Za-z0-9_-]{20,}|AKIA[0-9A-Z]{16}' -- "$f"; then
  echo 'provider token'
  return 0
 fi
 if LC_ALL=C grep -Eiq -e 'aws_secret_access_key[[:space:]]*=[[:space:]]*[^[:space:]]{20,}' -- "$f"; then
  echo 'aws secret key'
  return 0
 fi
 if LC_ALL=C grep -Eiq -e 'PSK[[:space:]]*=[[:space:]]*[^[:space:]]{8,}|^PrivateKey[[:space:]]*=' -- "$f"; then
  echo 'pre-shared/wireguard key'
  return 0
 fi
 if LC_ALL=C grep -Eq -e '\$[156]\$[A-Za-z0-9./$]{20,}' -- "$f"; then
  echo 'password hash'
  return 0
 fi
 return 1
}

# ---- args ----
lane="" dry=0 push_mode=0
mode_pending=0
run_started_s=$SECONDS
for arg in "$@"; do
 case "$arg" in
 --dry-run) dry=1 ;;
 --mode) mode_pending=1 ;;
 push) if [ "$mode_pending" -eq 1 ]; then
  push_mode=1
  mode_pending=0
 else fail "" "unknown argument: $arg"; fi ;;
 commit) if [ "$mode_pending" -eq 1 ]; then mode_pending=0; else fail "" "unknown argument: $arg"; fi ;;
 -*) fail "" "unknown option: $arg" ;;
 *) if [ -z "$lane" ]; then lane="$arg"; else fail "" "exactly one LANE required"; fi ;;
 esac
done
[ "$mode_pending" -eq 0 ] || fail "" "--mode needs push|commit"
[ -n "$lane" ] || {
 echo "usage: config-backup.sh LANE [--dry-run] [--mode push]" >&2
 exit 2
}
lane_sources "$lane" >/dev/null 2>&1 || fail "$lane" "unknown lane (see $LANE_MANIFEST)"

repo="$(lane_repo "$lane")"
[ -d "$repo/.git" ] || fail "$lane" "backup repo missing: $repo"
remote_decl="$(lane_remote "$lane")"

# ---- validate ALL sources before touching anything (gbd parity) ----
srcs="$(lane_sources "$lane")"
[ -n "$srcs" ] || fail "$lane" "no sources declared"
while IFS= read -r s; do
 [ -e "$s" ] || fail "$lane" "missing source: $s"
 if [ -L "$s" ] || [ ! -f "$s" ]; then fail "$lane" "not a regular file: $s"; fi
done <<<"$srcs"

rel_of() { # abs source -> repo-relative snapshot path (files/<path sans />)
 printf 'files/%s\n' "${1#/}"
}

# =============================== DRY RUN ===============================
# Read-only parity proof: manifest-from-sources vs gbd HEAD tree.
if [ "$dry" -eq 1 ]; then
 echo "== config-backup dry-run: $lane (repo $repo)"
 added=0 changed=0 same=0 skipped=0
 while IFS= read -r s; do
  if [ "$(wc -c <"$s")" -gt "$GBD_MAX_FILE_BYTES" ]; then
   echo "  SKIP(too large, gbd max_file_bytes): $s"
   skipped=$((skipped + 1))
   continue
  fi
  r="$(rel_of "$s")"
  mine="$(git hash-object "$s")"
  head_blob="$(git -C "$repo" rev-parse -q --verify "HEAD:$r" 2>/dev/null || true)"
  if [ -z "$head_blob" ]; then
   echo "  ADDED vs HEAD: $r"
   added=$((added + 1))
  elif [ "$mine" = "$head_blob" ]; then
   same=$((same + 1))
  else
   echo "  CHANGED vs HEAD: $r"
   changed=$((changed + 1))
  fi
 done <<<"$srcs"
 head_only=0
 while IFS= read -r r; do
  echo "  HEAD-only (leftover, not in lane): $r"
  head_only=$((head_only + 1))
 done < <(git -C "$repo" ls-tree -r --name-only HEAD -- files/ | grep -Fvx -f <(lane_sources "$lane" | while IFS= read -r s; do rel_of "$s"; done) || true)
 echo "  parity: same=$same added=$added changed=$changed skipped=$skipped head-only=$head_only"
 if [ "$changed" -eq 0 ] && [ "$added" -eq 0 ]; then
  echo "  manifest PARITY with gbd HEAD"
 else
  echo "  manifest DIFFERS from gbd HEAD (drift since gbd's last timer commit is expected)"
 fi
 exit 0
fi

# =============================== REAL RUN ===============================
# 1. stage: atomic copies (gbd parity)
copied=0 skipped=0
while IFS= read -r s; do
 if [ "$(wc -c <"$s")" -gt "$GBD_MAX_FILE_BYTES" ]; then
  log "skip too large (> ${GBD_MAX_FILE_BYTES}B): $s"
  skipped=$((skipped + 1))
  continue
 fi
 d="$repo/$(rel_of "$s")"
 mkdir -p "$(dirname "$d")"
 tmp="$d.tmp.$$"
 cp -p -- "$s" "$tmp" && mv -f -- "$tmp" "$d" || {
  rm -f -- "$tmp"
  fail "$lane" "copy failed: $s"
 }
 copied=$((copied + 1))
done <<<"$srcs"

# 2. MANIFEST.sha256 of every backed-up file (content-addressed, no ts -> idempotent)
: >"$repo/MANIFEST.sha256"
while IFS= read -r s; do
 [ "$(wc -c <"$s")" -le "$GBD_MAX_FILE_BYTES" ] || continue
 r="$(rel_of "$s")"
 printf '%s  %s\n' "$(sha256sum "$repo/$r" | awk '{print $1}')" "$r" >>"$repo/MANIFEST.sha256"
done <<<"$srcs"
sort -k2 "$repo/MANIFEST.sha256" -o "$repo/MANIFEST.sha256"

# 3. stage + secret-scan (fail closed BEFORE commit, gbd parity)
git -C "$repo" add -A
staged="$(git -C "$repo" diff --cached --name-only || true)"
if [ -n "$staged" ]; then
 while IFS= read -r r; do
  hit="$(scan_secret "$repo/$r" || true)"
  if [ -n "$hit" ]; then
   fail "$lane" "refused: secret-scan $r ($hit)"
  fi
 done <<<"$staged"
fi

# 4. commit only if dirty
committed=0
if ! git -C "$repo" diff --cached --quiet; then
 ts="$(date '+%Y-%m-%d %H:%M:%S')"
 git -C "$repo" commit -q -m "config-backup: $lane $ts" || fail "$lane" "git commit failed"
 committed=1
fi

# 5. push only when declared remote exists AND --mode push
pushed=0 push_target=none
if [ "$push_mode" -eq 1 ]; then
 if [ -z "$remote_decl" ]; then
  log "$lane: no declared remote; push=none (gbd parity: push_skipped)"
 elif origin="$(git -C "$repo" remote get-url origin 2>/dev/null)"; then
  push_target="$origin"
  if timeout 15 git -C "$repo" push -q origin HEAD; then
   pushed=1
  else
   fail "$lane" "push failed to $push_target (local commit intact, nothing partial)"
  fi
 else
  log "$lane: declared remote but repo has no origin; push=none"
 fi
fi

# 6. one progress row (wall seconds feed the time ledger's estimates:
# test-and-time now, tracked on every execute)
[ -n "${run_started_s:-}" ] || run_started_s=$SECONDS
walls=$((SECONDS - run_started_s))
[ "$pushed" -eq 1 ] || push_target=none
report progress "config-backup $lane: ok $copied files push=$push_target wall=${walls}s"
breadcrumb "$JOB_NAME" "progress" "config-backup $lane: ok copied=$copied skipped=$skipped committed=$committed pushed=$pushed"
log "$lane: ok copied=$copied skipped=$skipped committed=$committed pushed=$pushed target=$push_target"
