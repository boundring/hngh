#!/usr/bin/env bash
# 25-wiki-health -- day-tier wiki-surface probe + automated vault
# rebuild + (weekly) lessons seed
# (design: hngh docs/design/wiki-surface.md). The probe and seed are
# model-free; the rebuild leg is one bounded omp one-shot turn:
#
# 1. HEALTH PROBE: for each llm-wiki vault (personal + project; paths
#    are constants overridable by env) compare pages on disk
#    (wiki/**/*.md, excluding the auto-generated index.md/log.md)
#    against registry.json .pages, and the meta/index.md mtime age.
#    Verdict per vault: healthy (delta 0, meta < stale-days) |
#    UNINDEXED (pages on disk, none/a subset in registry) | STALE (meta
#    older than stale-days) | SPLIT (both). One identity-deduped alert
#    per unhealthy vault naming counts and the exact fix; one silent ok
#    row per healthy vault; 7d dedup window on both.
# 2. AUTO-REBUILD (need-triggered, measured): for each UNHEALTHY vault,
#    unless wiki-auto-rebuild is 0, spawn ONE bounded omp one-shot
#    session with cwd = the vault's parent and the prompt asking the
#    loaded llm-wiki extension to run its wiki_rebuild_meta tool (the
#    rebuild happens INSIDE that session -- Hngh never writes meta/ or
#    raw/). Anti-thrash: at most one attempt per vault per UTC day
#    (stamp file). The attempt is timed, emits one telemetry row
#    (kind=wiki-rebuild: duration, outcome unfrozen|still-unhealthy|
#    attempt-failed, before/after page-vs-registry counts), then the
#    vault is re-probed inline: healthy -> the alert is replaced by an
#    unfrozen ok row; still unhealthy -> the alert stands with
#    'rebuild attempted <ts> -- insufficient' appended. Alert/ok rows
#    carry the vault's 7d rebuild efficacy (attempts / unfrozen) when
#    telemetry has it, so a repeatedly failing vault is a visible
#    pattern. Two consecutive daily non-unfrozen attempts file a
#    research subject (ctx-wiki-rebuild-<vault>): the cycle's own
#    failures become research demand.
# 3. PRODUCTION SEED (Mondays only; the probe went daily, the vault
#    file churn stays weekly, atomic, house conventions): render the
#    hngh kernel's docs/project/lessons-index.md table verbatim into the
#    PROJECT vault as wiki/concepts/hngh-lessons-current.md (frontmatter
#    type: concept; sources point at the hngh docs; one cross-link to
#    the Cistern synthesis page). Idempotent: overwrites only its own
#    file, preserves created:, updates updated:. Hand-written pages are
#    indexed on the extension's next rebuild -- the probe's UNINDEXED
#    alert covers that gap honestly.
#
# Fail-closed: every path exits 0; an absent/unprobeable vault is a
# breadcrumb, never a report row.
#
# usage: cadence/day/25-wiki-health.sh   (via cadence-tick.sh TIER=day)
set -u
. "$(cd "$(dirname "$0")/../.." && pwd)/lib/common.sh"
. "$AUTOMATION_ROOT/lib/breadcrumbs.sh"
. "$AUTOMATION_ROOT/lib/params.sh"
. "$AUTOMATION_ROOT/lib/causes.sh"

KERNEL="${HNGH_HOME:-$HOME/Projects/etc/hngh}"
REPORT="python3 $KERNEL/scripts/report-queue"
report_root="${HNGH_REPORT_ROOT:-$KERNEL}"

WIKI_PERSONAL="${HNGH_WIKI_PERSONAL:-$HOME/.llm-wiki}"
WIKI_PROJECT="${HNGH_WIKI_PROJECT:-$HOME/Projects/etc/llm-wiki/.llm-wiki}"
STALE_DAYS="${HNGH_WIKI_STALE_DAYS:-14}"
WEEK_S=604800 # 7d identity window: one row per vault per week
LESSONS_SRC="$KERNEL/docs/project/lessons-index.md"
AUTO_REBUILD="${WIKI_AUTO_REBUILD:-$(get_param wiki-auto-rebuild 1)}"
REBUILD_TIMEOUT="${WIKI_REBUILD_TIMEOUT:-$(get_param wiki-rebuild-timeout 240)}"
STAMP_DIR="${WIKI_REBUILD_STAMP_DIR:-/tmp}" # once-daily attempt guard
mkdir -p "$STAMP_DIR" 2>/dev/null || true

file_report() { # kind text ident
 if HNGH_REPORT_ROOT="$report_root" $REPORT --add "$1" "$2" \
  ${3:+--identity "$3"} --window "$WEEK_S" >/dev/null 2>&1; then
  breadcrumb "$JOB_NAME" "$1" "$2"
 else
  breadcrumb "$JOB_NAME" "report-fail" "could not file $1: $2"
 fi
}

page_count() { # vault -> wiki pages on disk (generated surfaces excluded)
 find "$1/wiki" -name '*.md' -type f ! -name index.md ! -name log.md \
  2>/dev/null | wc -l | tr -d ' '
}

reg_count() { # vault -> registry.json .pages count (array/object length
 # or scalar: the extension emits an object map slug -> metadata)
 jq -r '.pages | if type == "object" or type == "array" then length
  else . end' \
  "$1/meta/registry.json" 2>/dev/null
}

index_age_days() { # vault -> whole days since meta/index.md mtime ("" absent)
 local m
 m="$(stat -c %Y "$1/meta/index.md" 2>/dev/null)" || return 0
 echo $((($(date +%s) - m) / 86400))
}

probe_vault() { # vault -> verdict in "$1"; sets DISK REG AGE
 local vault="$1"
 DISK="$(page_count "$vault")"
 REG="$(reg_count "$vault")"
 AGE="$(index_age_days "$vault")"
 [ -n "$REG" ] || return 1 # no registry -> unprobeable, caller skips
 VERDICT=healthy
 [ "$DISK" -gt "$REG" ] && VERDICT=UNINDEXED
 if [ -n "$AGE" ] && [ "$AGE" -ge "$STALE_DAYS" ]; then
  [ "$VERDICT" = "UNINDEXED" ] && VERDICT=SPLIT || VERDICT=STALE
 fi
 return 0
}

seed_lessons_page() { # -> 0 when the page was written
 [ -f "$LESSONS_SRC" ] || {
  breadcrumb "$JOB_NAME" "seed-skip" "lessons-index.md missing"
  return 1
 }
 local dir="$WIKI_PROJECT/wiki/concepts"
 local out="$dir/hngh-lessons-current.md"
 local created updated today body
 today="$(date -u +%Y-%m-%d)"
 mkdir -p "$dir" 2>/dev/null || return 1
 created="$(sed -n 's/^created: //p' "$out" 2>/dev/null | head -1)"
 created="${created:-$today}"
 body="$(awk '
  /^\| Lesson \|/{f=1}
  f && /^\|/{print; next}
  f && !/^\|/{exit}' "$LESSONS_SRC" |
  LC_ALL=C sed 's/[^[:print:]]//g')" || body=""
 [ -n "$body" ] || {
  breadcrumb "$JOB_NAME" "seed-skip" "no lesson table rows found"
  return 1
 }
 updated="$today"
 cat >"$out.tmp" <<EOF
---
title: "Hngh Lessons -- Current"
type: concept
created: $created
updated: $updated
domain: engineering
tags:
  - hngh
  - lessons
  - agent-process
sources:
  - $KERNEL/docs/project/lessons-index.md
  - $KERNEL/docs/design/wiki-surface.md
---

Current hngh kernel lessons, rendered verbatim from the kernel's
lessons index (the wiki copy is a derived view; the kernel table is
canonical). Related synthesis: [[syntheses/delegated-subagent-steering]].

$body

Back to [[index]].
EOF
 mv "$out.tmp" "$out" || return 1
 breadcrumb "$JOB_NAME" "seed" "wrote $out (created $created, updated $updated)"
 return 0
}

eff_note() { # label -> " rebuilds 7d: N attempts, M unfrozen" or ""
 local n u
 read -r n u <<EOF
$(sqlite3 "$AUTOMATION_ROOT/dashboard/telemetry.db" \
  -separator ' ' \
  "select count(*), coalesce(sum(body like 'unfrozen%'),0) from events
   where kind='wiki-rebuild' and identity='$1'
   and ts >= strftime('%Y-%m-%dT%H:%M:%SZ','now','-7 days')" 2>/dev/null)
EOF
 [ -n "$n" ] && [ "$n" -gt 0 ] &&
  printf ' rebuilds 7d: %s attempts, %s unfrozen' "$n" "${u:-0}"
}

attempt_rebuild() { # vault label before_disk before_reg
 # -> sets RB_OUTCOME RB_SECS; one bounded omp one-shot turn, telemetry,
 # inline re-probe, once-daily stamp
 local vault="$1" label="$2" bd="$3" br="$4"
 local t0 rc ad ar ts
 t0="$(date +%s)"
 (
  cd "$(dirname "$vault")" && timeout "$REBUILD_TIMEOUT" \
   omp -p "Run the wiki_rebuild_meta tool once, then reply with just: rebuilt."
 ) >/dev/null 2>&1
 rc=$?
 RB_SECS=$(($(date +%s) - t0))
 breadcrumb "$JOB_NAME" "wiki-rebuild-attempt" \
  "wiki rebuild attempt: $vault (${RB_SECS}s)"
 if [ "$rc" -ne 0 ]; then
  RB_OUTCOME=attempt-failed
 elif ! probe_vault "$vault"; then
  RB_OUTCOME=attempt-failed
 elif [ "$VERDICT" = healthy ]; then
  RB_OUTCOME=unfrozen
 else
  RB_OUTCOME=still-unhealthy
 fi
 ad="$(page_count "$vault")"
 ar="$(reg_count "$vault")"
 ts="$(date -u +%FT%TZ)"
 printf '%s %s\n' "$(date -u +%F)" "$RB_OUTCOME" \
  >"$STAMP_DIR/.hngh-wiki-rebuild-$label"
 python3 "$AUTOMATION_ROOT/jobs/telemetry.py" emit --kind wiki-rebuild \
  --source day/25-wiki-health --identity "$label" --wall-s "$RB_SECS" \
  --body "$RB_OUTCOME disk $bd->$ad reg $br->$ar" >/dev/null 2>&1 || true
 case "$RB_OUTCOME" in
 unfrozen)
  file_report progress "wiki-health $label: healthy after rebuild attempt ($DISK pages on disk, $REG in registry, meta $AGE d old; was $bd on disk/$br in registry)$(eff_note "$label")" \
   "wiki-health-ok:$label"
  ;;
 attempt-failed)
  file_report alert "wiki-health $label: $VERDICT -- $DISK pages on disk, $REG in registry, meta $AGE d old (threshold $STALE_DAYS d). rebuild attempted $ts -- attempt failed (rc $rc). Fix: run the llm-wiki rebuild from an omp session with cwd $(dirname "$vault") -- extension tool wiki_rebuild_meta; Hngh never writes meta/$(eff_note "$label")" \
   "wiki-health-rebuild:$label"
  ;;
 *)
  file_report alert "wiki-health $label: $VERDICT -- $DISK pages on disk, $REG in registry, meta $AGE d old (threshold $STALE_DAYS d). rebuild attempted $ts -- insufficient. Fix: run the llm-wiki rebuild from an omp session with cwd $(dirname "$vault") -- extension tool wiki_rebuild_meta; Hngh never writes meta/$(eff_note "$label")" \
   "wiki-health-rebuild:$label"
  ;;
 esac
 # failure routing: two consecutive daily non-unfrozen attempts turn the
 # cycle's own failure into research demand (dedup by id as usual)
 if [ "$RB_OUTCOME" != unfrozen ] && [ -n "$PREV_OUTCOME" ] &&
  [ "$PREV_OUTCOME" != unfrozen ] && [ "$PREV_DAY" != "$(date -u +%F)" ]; then
  append_research_subject "ctx-wiki-rebuild-$label" \
   "why does the $label vault rebuild fail/underperform and what fixes it?"
 fi
 return 0
}

# --- probe both vaults ------------------------------------------------
for vault in "$WIKI_PERSONAL" "$WIKI_PROJECT"; do
 label="$(basename "$(dirname "$vault")")" # bricker / llm-wiki
 if ! probe_vault "$vault"; then
  breadcrumb "$JOB_NAME" "skip" "$vault unprobeable (no registry/wiki)"
  continue
 fi
 if [ "$VERDICT" = healthy ]; then
  file_report progress \
   "wiki-health $label: healthy ($DISK pages on disk, $REG in registry, meta $AGE d old)$(eff_note "$label")" \
   "wiki-health-ok:$label"
  continue
 fi
 # unhealthy: need-triggered rebuild, once per vault per UTC day
 stamp="$STAMP_DIR/.hngh-wiki-rebuild-$label"
 PREV_DAY=""
 PREV_OUTCOME=""
 [ -f "$stamp" ] && { read -r PREV_DAY PREV_OUTCOME _ <"$stamp" || true; }
 if [ "$AUTO_REBUILD" != 1 ] || [ "$PREV_DAY" = "$(date -u +%F)" ]; then
  file_report alert "wiki-health $label: $VERDICT -- $DISK pages on disk, $REG in registry, meta $AGE d old (threshold $STALE_DAYS d). Fix: run the llm-wiki rebuild from an omp session with cwd $(dirname "$vault") -- extension tool wiki_rebuild_meta; Hngh never writes meta/$(eff_note "$label")" \
   "wiki-health:$label"
  continue
 fi
 attempt_rebuild "$vault" "$label" "$DISK" "$REG"
done

# --- production seed (project vault only, Mondays) --------------------
[ "$(date -u +%u)" = 1 ] && seed_lessons_page || true

breadcrumb "$JOB_NAME" "wiki-health-done" "probe + seed pass complete"
exit 0
