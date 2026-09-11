#!/usr/bin/env bash
# lint-identifiers — fail-closed cross-reference over the shell config surface.
# Extracts every $UPPER / ${UPPER} reference and every UPPER= definition
# (plain, indented, local/readonly/export) from config.env, lib/, jobs/,
# and scripts/. Flags referenced-but-never-defined and
# defined-but-never-referenced names. Exits 1 on any finding.
#
# Lint vs parser: a line-oriented lint — deliberately pragmatic. A
# `${NAME:-default}` reference satisfies the name in BOTH directions
# (never flagged as referenced-undefined, and counts as a use of a
# config.env definition).
# Heredoc scoping: a quoted heredoc body (<<'TAG', <<"TAG", <<\TAG) is
# written literally — the generating shell expands nothing in it — so
# NAME= lines inside are definitions of the GENERATED script and only
# satisfy $NAME references in the same heredoc body; references inside
# are not checked against outer definitions. Unquoted heredoc bodies DO
# expand at generation, so their references count at file level while
# their NAME= lines stay literal text (not definitions). Ceiling:
# single-level heredocs only (a heredoc nested inside a body is body
# text); case-pattern assignments are not parsed as definitions (such
# names join IGNORED_NAMES); `#` inside quoted strings truncates like a
# comment; values containing `NAME=` inside quoted strings could
# false-positive; none do today (bench probe prompts spell variables as
# literals and are added to IGNORED_NAMES when needed).
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

shopt -s nullglob
FILES_TARGETS=("$ROOT"/config.env "$ROOT"/lib/*.sh "$ROOT"/jobs/*.sh
 "$ROOT"/scripts/*.sh "$ROOT"/prompts/*.md)

# system-provided, positional, or deliberate-literal names
IGNORED_NAMES=" PATH PWD HOME USER SHELL LANG LC_ALL TERM HOSTNAME UID EUID PPID IFS SHLVL RANDOM OLDPWD CDPATH ENV BASH_ENV BASH_VERSION COLUMNS LINES BASH_SOURCE BASH_REMATCH SECONDS NF DEST PROMPT_FILE MODEL_USED_FILE FILES_TARGETS OMP_BRIDGE_STORE LIVE LOOP STALL GRACE SESSION_SOURCE OPENCODE_CONFIG HTTPS_PROXY NODE_EXTRA_CA_CERTS BILI_MITM_DOMAINS "
HEREDOC_START_RE="<<-?(['\\\"]?)([A-Za-z_]+)"

problems=0
report() {
 printf 'lint-identifiers: %s\n' "$*" >&2
 problems=$((problems + 1))
}
is_ignored() { case "$IGNORED_NAMES" in *" $1 "*) return 0 ;; *) return 1 ;; esac }

# definitions and references cross files freely (config.env defines, jobs
# reference); heredoc scopes are per-file/per-heredoc, checked per file.
declare -A defined referenced satisfied
for f in "${FILES_TARGETS[@]}"; do
 unset hd_defined hd_referenced
 declare -A hd_defined hd_referenced
 refbuf=""
 hidx=0 in_heredoc=0 heredoc_tag="" heredoc_quoted=0 hbuf=""
 while IFS= read -r line; do
  if [ "$in_heredoc" = 1 ]; then
   if [ "$line" = "$heredoc_tag" ]; then
    if [ "$heredoc_quoted" = 1 ]; then
     # quoted body: standalone script — defs and refs scoped to it
     while IFS= read -r name; do
      [ -n "$name" ] && satisfied["$name"]="$f"
     done < <(printf '%s' "$hbuf" |
      grep -oE '\$\{[A-Z][A-Z0-9_]*:-' |
      sed -E 's/^\$\{//; s/:-$//' | sort -u)
     while IFS= read -r name; do
      [ -n "$name" ] && hd_referenced["$hidx $name"]=1
     done < <(printf '%s' "$hbuf" |
      grep -oE '\$\{?[A-Z][A-Z0-9_]*' |
      sed -E 's/^\$\{?//' | grep -E '^[A-Z][A-Z0-9_]*$' | sort -u)
     while IFS= read -r name; do
      [ -n "$name" ] && hd_defined["$hidx $name"]=1
     done < <(printf '%s' "$hbuf" |
      grep -E '^[[:space:]]*[A-Z][A-Z0-9_]*=' |
      sed -E 's/^[[:space:]]*([A-Z][A-Z0-9_]*)=.*/\1/')
     while IFS= read -r name; do
      [ -n "$name" ] && hd_defined["$hidx $name"]=1
     done < <(printf '%s' "$hbuf" |
      grep -E '^[[:space:]]*(local|readonly|export)[[:space:]]+[A-Z][A-Z0-9_]*' |
      sed -E 's/^[[:space:]]*(local|readonly|export)[[:space:]]+([A-Z][A-Z0-9_]*).*/\2/')
    else
     # unquoted body: expands at generation — refs count at file level
     refbuf+="$hbuf"
    fi
    in_heredoc=0 hbuf=""
    continue
   fi
   hbuf+="${line%%#*}"$'\n'
   continue
  fi
  line="${line%%#*}"
  if [[ "$line" =~ $HEREDOC_START_RE ]]; then
   [ -n "${BASH_REMATCH[1]}" ] && heredoc_quoted=1 || heredoc_quoted=0
   heredoc_tag="${BASH_REMATCH[2]}"
   in_heredoc=1 hidx=$((hidx + 1)) hbuf=""
  fi
  if [[ "$line" =~ ^[[:space:]]*([A-Z][A-Z0-9_]*)=(.*)$ ]]; then
   defined["${BASH_REMATCH[1]}"]="$f"
  elif [[ "$line" =~ ^[[:space:]]*(local|readonly|export)[[:space:]]+([A-Z][A-Z0-9_]*) ]]; then
   defined["${BASH_REMATCH[2]}"]="$f"
  fi
  refbuf+="$line"$'\n'
 done <"$f" 2>/dev/null || true

 # file-level references; ${NAME:-default} is self-satisfied
 while IFS= read -r name; do
  [ -n "$name" ] && satisfied["$name"]="$f"
 done < <(printf '%s' "$refbuf" |
  grep -oE '\$\{[A-Z][A-Z0-9_]*:-' |
  sed -E 's/^\$\{//; s/:-$//' | sort -u)
 while IFS= read -r name; do
  [ -n "$name" ] && referenced["$name"]="$f"
 done < <(printf '%s' "$refbuf" |
  grep -oE '\$\{?[A-Z][A-Z0-9_]*' |
  sed -E 's/^\$\{?//' | grep -E '^[A-Z][A-Z0-9_]*$' | sort -u)

 # heredoc-scoped findings for this file
 for key in "${!hd_referenced[@]}"; do
  name="${key#* }"
  is_ignored "$name" && continue
  [ -n "${satisfied[$name]+x}" ] && continue
  [ -n "${hd_defined[$key]+x}" ] && continue
  report "referenced but never defined: \$$name (in $f, quoted heredoc)"
 done
 for key in "${!hd_defined[@]}"; do
  name="${key#* }"
  is_ignored "$name" && continue
  [ -n "${satisfied[$name]+x}" ] && continue
  [ -n "${hd_referenced[$key]+x}" ] && continue
  report "defined but never referenced: $name (in $f, quoted heredoc)"
 done
done

for name in "${!referenced[@]}"; do
 is_ignored "$name" && continue
 [ -n "${satisfied[$name]+x}" ] && continue
 [ -n "${defined[$name]+x}" ] && continue
 report "referenced but never defined: \$$name (in ${referenced[$name]})"
done

for name in "${!defined[@]}"; do
 is_ignored "$name" && continue
 [ -n "${satisfied[$name]+x}" ] && continue
 [ -n "${referenced[$name]+x}" ] && continue
 report "defined but never referenced: $name (in ${defined[$name]})"
done

[ "$problems" -eq 0 ] && {
 echo "lint-identifiers: clean"
 exit 0
}
echo "lint-identifiers: $problems problem(s)" >&2
exit 1
