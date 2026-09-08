# news-screen.sh — pre-ingest security screening for the news pipeline.
# Operator directive 2026-09-07: fetched content is screened for obvious or
# obfuscated malicious patterns BEFORE any agent sees it. The pattern table
# lives in ONE place: edit the list, not the logic (same shape as
# news-importance.sh). Quarantined content NEVER reaches a model prompt:
# screen_day_names drops the source from the model input list before the
# importance screen runs (quarantine takes precedence) and before
# build_prompt. The snapshot file itself is never touched — snapshots are
# the evidence record; the trail is one report-queue alert row
# (identity news-quarantine:<sha1-of-file>, kind alert, 7d window, house
# identity+window dedup) plus a breadcrumb. The digest stays clean.
#
# False-positive budget: these classes are deliberately broad (a Phoronix
# article about `rm -rf` WILL trip execution-smuggling). The cost of a trip
# is one excluded snapshot + one deduped alert row; the cost of a miss is a
# hostile instruction inside a model prompt. The asymmetry favors the net.
. "$AUTOMATION_ROOT/lib/common.sh"
. "$AUTOMATION_ROOT/lib/breadcrumbs.sh"

# Class table: one line per class, `class:ERE-alternation`. Every class is
# matched case-insensitively EXCEPT model-artifact (token forgery is
# case-shaped: `SYSTEM:` vs "system:" — the lowercase form is already
# instruction-override's "system prompt:"). Literal pipes/brackets/plus are
# ERE-escaped ([|], \[, \]) because grep -E gives them structural meaning.
NEWS_SCREEN_PATTERNS='
instruction-override:ignore (all )?(previous|prior|above) instructions|disregard (your |the )?(system )?prompt|\[PROMPT_INJECTION\]|system prompt:
identity-override:you are now|act as (an? )?(admin|root|system)
execution-smuggling:rm -rf|curl .*[|][[:space:]]*[a-z]*sh|curl .*>[[:space:]]*/tmp|wget .*[|][[:space:]]*[a-z]*sh|chmod \+x
model-artifact:<[|]im_start|<[|]im_end|assistant:|SYSTEM:
obfuscation:__BUILTIN__
'

# obfuscation sub-checks, in one place, first match wins:
#   1. base64 blob — 300+ contiguous base64 chars in one line
#   2. zero-width chars U+200B..U+200F — UTF-8 bytes E2 80 [8B..8F]
#   3. homoglyph-heavy line — 60+ bytes, >30% non-ASCII (byte proxy for
#      lookalike-script mixing; LC_ALL=C keeps it deterministic)
screen_obfuscation() { # file -> first offending line (120 chars) or empty
  local f="$1" line
  line="$(LC_ALL=C grep -m1 -E '[A-Za-z0-9+/]{300,}' "$f" 2>/dev/null)" && {
    printf '%s' "${line:0:120}"
    return 0
  }
  line="$(LC_ALL=C grep -m1 -P '\xe2\x80[\x8b-\x8f]' "$f" 2>/dev/null)" && {
    printf '%s' "${line:0:120}"
    return 0
  }
  line="$(LC_ALL=C gawk '{
    L = length($0)
    if (L >= 60) {
      n = 0
      for (i = 1; i <= L; i++) if (substr($0, i, 1) !~ /[[:ascii:]]/) n++
      if (n * 10 > L * 3) { print substr($0, 1, 120); exit }
    }
  }' "$f" 2>/dev/null)" && {
    printf '%s' "$line"
    return 0
  }
  return 0
}

# screen_fetched SNAPSHOT-FILES... -> one QUARANTINE line per offending file:
#   QUARANTINE <class> <file> <first-120-chars-of-matching-line>
# or empty. First matching class wins per file; the file is never modified.
screen_fetched() { # snapshot-files... -> QUARANTINE lines or empty
  local f spec class pat line
  for f in "$@"; do
    [ -f "$f" ] || continue
    while IFS= read -r spec; do
      [ -n "$spec" ] || continue
      class="${spec%%:*}"
      pat="${spec#*:}"
      if [ "$class" = "obfuscation" ]; then
        line="$(screen_obfuscation "$f")"
      elif [ "$class" = "model-artifact" ]; then
        line="$(LC_ALL=C grep -m1 -E "$pat" "$f" 2>/dev/null)"
      else
        line="$(LC_ALL=C grep -m1 -i -E "$pat" "$f" 2>/dev/null)"
      fi
      if [ -n "$line" ]; then
        printf 'QUARANTINE %s %s %s\n' "$class" "$f" "$(printf '%s' "$line" | cut -c1-120)"
        break
      fi
    done <<EOF
$NEWS_SCREEN_PATTERNS
EOF
  done
  return 0
}

# screen_file_alert CLASS FILE CTX — one report-queue alert row, identity-
# deduped (house pattern). Pipes are stripped (report-queue writes the first
# line into a markdown table row). Fail-closed: a failed row is a
# breadcrumb, never a job failure.
screen_file_alert() {
  local class="$1" file="$2" ctx="$3" kernel text
  kernel="${HNGH_HOME:-$HOME/Projects/etc/hngh}"
  text="news-quarantine $class $file: $(printf '%s' "$ctx" | tr '|' ';')"
  HNGH_REPORT_ROOT="${HNGH_REPORT_ROOT:-$kernel}" python3 \
    "$kernel/scripts/report-queue" --add alert "$text" \
    --identity "news-quarantine:$(sha1sum "$file" | cut -d' ' -f1 | cut -c1-64)" \
    --window 604800 >/dev/null 2>&1 ||
    breadcrumb "${JOB_NAME:-news-screen}" "quarantine" \
      "alert row failed for $file (data, not failure)"
}

# screen_day_names DAY NAME... -> filtered NAME... on stdout (newline-
# separated, empty when every source is quarantined). A source whose newest
# snapshot trips a screen class is dropped from the model input list; its
# alert row + breadcrumb are filed here, so callers (ping-hourly,
# morning-digest) need only re-count the names they keep.
screen_day_names() { # DAY NAME... -> filtered names
  local day="$1"
  shift
  local dir="$AUTOMATION_ROOT/snapshots/$day" n f hit kept=""
  for n in "$@"; do
    f="$(newest_snapshot "$dir" "$n")"
    [ -n "$f" ] || continue
    hit="$(screen_fetched "$f")"
    if [ -n "$hit" ]; then
      while IFS=' ' read -r _ qclass qfile qctx; do
        [ -n "${qfile:-}" ] || continue
        screen_file_alert "${qclass:-unknown}" "$qfile" "${qctx:-}"
      done <<<"$hit"
      breadcrumb "${JOB_NAME:-news-screen}" "quarantine" \
        "$f excluded from model input (evidence kept on disk)"
    else
      kept="${kept:+$kept
}$n"
    fi
  done
  [ -n "$kept" ] && printf '%s\n' "$kept"
  return 0
}
