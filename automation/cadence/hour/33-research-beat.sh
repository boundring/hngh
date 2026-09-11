#!/usr/bin/env bash
# 33-research-beat -- research machine, mounted hourly and fail-first
# gated (lib/failfirst.sh; no pre-set beat interval): advance the oldest
# non-crystallized research line one
# lifecycle transition per beat
# (planned → expanding → contracting → crystallized) using the model
# chain. Each beat writes digest/RESEARCH-BEAT-<date>-<id>.md; the
# crystallize transition also writes the condensed result into the hngh
# kernel's docs/research/<date>-<id>.md. State: research-lines.tsv at
# the AUTO root (id, state, updated, line); missing/empty state is
# re-seeded from research-subjects.txt. When every line is crystallized
# or reviewed, the beat reviews the oldest crystallized line into a
# terminal disposition (adopted|parked|killed, research-dispositions.tsv,
# state=reviewed). Fail-first (2026-09-07): the beat fires every hour
# tick and failfirst_gate decides GO vs THROTTLE -- full speed until the
# model chain actually degrades, then paced (standard/cautious) until
# consecutive ok outcomes promote it back. Load is a ROUTING signal, not
# a throttle: busy local shifts the pin to the deck (when armed AND
# responsive) or a quota leg -- the beat never defers. The review
# interleave (RESEARCH_REVIEW_INTERLEAVE, default 3) and the demand
# synthesizer (empty pool below RESEARCH_DEMAND_FLOOR, default 3) stay:
# they are coverage and supply, not throttles. Fail-closed: model-chain
# failure records a degraded outcome, files an alert and exits 0 —
# never hangs the tick.
#
# usage: cadence/hour/33-research-beat.sh   (via cadence-tick.sh TIER=hour)
set -u
. "$(cd "$(dirname "$0")/../.." && pwd)/lib/common.sh"
. "$AUTOMATION_ROOT/lib/breadcrumbs.sh"
. "$AUTOMATION_ROOT/lib/model.sh"
. "$AUTOMATION_ROOT/lib/params.sh"
. "$AUTOMATION_ROOT/lib/failfirst.sh"

# one research transition at a time: the hour beat and the 15-minute
# overflow beat share this body and research-lines.tsv. A beat arriving
# while another holds the lock skips -- the next 15-minute overflow tick
# picks the work up. (Replaces the old 30-minute stagger guard: at a
# 15-minute overflow cadence the hour beat is always "recent", so the
# lock is the race prevention.)
exec 9>"${RESEARCH_LOCK_FILE:-/tmp/.hngh-research-beat-lock}"
flock -w "${RESEARCH_LOCK_WAIT:-300}" 9 || exit 0

# fail-first gate: the beat fires every hour tick; the gate decides GO
# vs THROTTLE. Full speed (fresh state or after promotions) always runs;
# after a degradation the speed ladder paces the beat (standard = every
# 2nd tick, cautious = every 4th, FAILFIRST_TICK_S=3600 here) until
# consecutive ok outcomes promote it back. No pre-set beat interval: the
# old RESEARCH_BEAT_HOURS stamp gate is gone -- degradation is detected
# empirically by the model chain's fail-closed-skip, never guessed.
# The stamp survives only as a last-beat record (the overflow beat
# redirects it so the hour record stays the hour's); the EXIT trap
# writes it -- a run that errors still leaves its timestamp.
RESEARCH_STAMP="${RESEARCH_STAMP_FILE:-/tmp/.hngh-research-beat-last}" # seam for hermetic tests
now="$(date +%s)"
OVERFLOW_PIN="${OVERFLOW_PIN:-}"
FF_OP="${FAILFIRST_OP:-research}"
FF_SF="$(failfirst_state_file "$FF_OP")"
failfirst_load "$FF_OP" "$FF_SF"
if [ -z "$OVERFLOW_PIN" ]; then
 verdict="$(failfirst_gate "$FF_OP" "$FF_SF")"
 if [ "$verdict" != "GO" ]; then
  breadcrumb "$JOB_NAME" "research-throttled" \
   "failfirst: $verdict - $FF_OP paced below its observed ceiling"
  exit 0
 fi
fi

# outcome recording (fail-first tuning input): ok = the model_call
# returned content, degraded = archive-only (chain exhausted), failed =
# a real script error (the EXIT trap). One record per run; the overflow
# caller records to its own operation via FAILFIRST_OP.
FF_RECORDED=0
ff_record() { # result
 [ "$FF_RECORDED" = "0" ] || return 0
 FF_RECORDED=1
 record_outcome "$FF_OP" "$FF_SPEED" "$1" "$FF_SF"
}
trap 'rc=$?; printf "%s\n" "$now" >"$RESEARCH_STAMP" 2>/dev/null
 [ "$rc" -eq 0 ] || ff_record failed' EXIT

# run counter (operator quota directive, 2026-09-07): one increment per
# run that passes the failfirst gate; drives the quota rotations below.
RESEARCH_COUNT_FILE="${RESEARCH_BEAT_COUNT_FILE:-/tmp/.hngh-research-beat-count}"
run_n="$(cat "$RESEARCH_COUNT_FILE" 2>/dev/null)"
run_n="${run_n//[!0-9]/}"
run_n="${run_n:-0}"
run_n=$((run_n + 1))
printf '%s\n' "$run_n" >"$RESEARCH_COUNT_FILE" 2>/dev/null

# routing (fail-first: load is a CAPACITY signal, not a throttle --
# the machine never stops researching because the desktop is busy; it
# routes around it). loadavg1 at or above research-load-ceiling * nproc
# (Inventory; env RESEARCH_LOAD_CEILING overrides) does not defer
# anything: the pin SHIFTS. Deck first when armed AND responsive (deck_up
# probe in lib/failfirst.sh -- the deck is idle hardware the operator
# directed into the chain), else a quota leg by run parity (odd kimi,
# even lobehub -- same convention as the overflow beat). An unarmed
# quota pin falls through to the local chain inside model_call, so
# routing never blocks. Test seams: RESEARCH_LOADAVG_FILE (loadavg
# source), RESEARCH_BEAT_GATE_ONLY=1 (exit 0 right after the gates).
load_busy() { # -> exit 0 when the machine is busy; prints "<loadavg1> <limit>"
 local ceiling="${RESEARCH_LOAD_CEILING:-$(get_param research-load-ceiling 0.7)}"
 local limit load
 limit="$(awk -v c="$ceiling" -v n="$(nproc)" 'BEGIN{printf "%.2f", c * n}')"
 load="$(cut -d' ' -f1 "${RESEARCH_LOADAVG_FILE:-/proc/loadavg}")"
 if awk -v l="$load" -v c="$limit" 'BEGIN{exit !(l >= c)}'; then
  printf '%s %s\n' "$load" "$limit"
  return 0
 fi
 return 1
}
ROUTE_PIN=""
if [ -z "$OVERFLOW_PIN" ] && busy="$(load_busy)"; then
 if deck_up; then
  ROUTE_PIN=deck
  breadcrumb "$JOB_NAME" "research-route-deck" \
   "local busy - research routed to deck (load ${busy%% *} >= ceiling ${busy##* }; deck responsive)"
 else
  ROUTE_PIN=kimi
  [ $(((run_n + 1) % 2)) -eq 0 ] && ROUTE_PIN=lobehub
  breadcrumb "$JOB_NAME" "research-route-quota" \
   "local busy - research routed to $ROUTE_PIN (load ${busy%% *} >= ceiling ${busy##* }; deck unavailable)"
 fi
fi
[ "${RESEARCH_BEAT_GATE_ONLY:-0}" = "1" ] && exit 0

KERNEL="${HNGH_HOME:-$HOME/Projects/etc/hngh}"
REPORT="python3 $KERNEL/scripts/report-queue"
report_root="${HNGH_REPORT_ROOT:-$KERNEL}"
TELEMETRY="$AUTOMATION_ROOT/jobs/telemetry.py"
LINES="$AUTOMATION_ROOT/research-lines.tsv"
SUBJECTS="$AUTOMATION_ROOT/research-subjects.txt"
DISPOSITIONS="$AUTOMATION_ROOT/research-dispositions.tsv"
WIKI_PROJECT_IDX="${HNGH_WIKI_PROJECT_INDEX:-$HOME/Projects/etc/llm-wiki/.llm-wiki/meta/index.md}"
WIKI_PERSONAL_IDX="${HNGH_WIKI_PERSONAL_INDEX:-$HOME/.llm-wiki/meta/index.md}"

file_report() {
 local kind="$1" text="$2" ident="${3:-}" win="${4:-86400}"
 if HNGH_REPORT_ROOT="$report_root" $REPORT --add "$kind" "$text" \
  ${ident:+--identity "$ident"} --window "$win" >/dev/null 2>&1; then
  breadcrumb "$JOB_NAME" "$kind" "$text"
 else
  breadcrumb "$JOB_NAME" "report-fail" "could not file $kind: $text"
 fi
}

ensure_lines() {
 local line
 local id
 local desc
 SEEDED=0
 while IFS= read -r line; do
  [ -n "$line" ] || continue
  desc="$line"
  case "$line" in
  *$'\t'*)
   id="${line%%$'\t'*}"
   desc="${line#*$'\t'}"
   ;;
  *) id="$(printf '%s' "$line" | tr -cs 'a-zA-Z0-9' '-' | sed 's/^-*//; s/-*$//')" ;;
  esac
  awk -F'\t' -v id="$id" -v desc="$desc" \
   '$1==id || $4==desc{found=1} END{exit !found}' "$LINES" && continue
  printf '%s\tplanned\t%s\t%s\n' \
   "$id" \
   "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$desc" >>"$LINES"
  SEEDED=$((SEEDED + 1))
 done <"$SUBJECTS"
 [ "$SEEDED" -gt 0 ] && breadcrumb "$JOB_NAME" "lines-seed" \
  "seeded $SEEDED missing research line(s) from subjects"
 return 0
}

research_doc() { # id -> crystallized doc path on stdout (empty = none)
 local f
 for f in "$KERNEL"/docs/research/*-"$1".md; do
  [ -f "$f" ] && {
   printf '%s\n' "$f"
   return 0
  }
 done
 for f in "$AUTOMATION_ROOT"/digest/RESEARCH-BEAT-*-"$1".md; do
  [ -f "$f" ] && {
   printf '%s\n' "$f"
   return 0
  }
 done
 return 1
}

pick_doc_row() { # rows on stdin -> first whose crystallized doc exists
 local r
 while IFS= read -r r; do
  [ -n "$(research_doc "$(printf '%s' "$r" | cut -f1)")" ] &&
   {
    printf '%s\n' "$r"
    return 0
   }
 done
 return 1
}

pick_line() { # finish lines before starting them: contracting first, then
 # expanding, then planned; oldest-updated within a state. When every line
 # is crystallized or reviewed, returns the OLDEST crystallized line for
 # the review transition (sets ROW + REVIEW globals: a command-substitution
 # subshell could not hand the flag back).
 REVIEW=0
 ROW=""
 local row interleave crow
 row="$(grep -vE $'\t(crystallized|reviewed)\t' "$LINES" 2>/dev/null |
  sort -t$'\t' -k2,2 -k3,3 |
  awk -F'\t' '{order["contracting"]=0; order["expanding"]=1; order["planned"]=2;
               print order[$2] "\t" $0}' | sort -t$'\t' -k1,1n -k3,3 |
  head -n 1 | cut -f2-)"
 if [ -n "$row" ]; then
  # review interleave (acceleration wave 2): every Nth run
  # (research-review-interleave; env RESEARCH_REVIEW_INTERLEAVE overrides,
  # 0 = never) reviews the oldest crystallized line instead of advancing
  # a planned one, so the review backlog drains while the pool is alive.
  # Shares the run counter with the quota rotation: a %N run reviews and
  # its pin still follows the normal rotation.
  # interleave default 3 (Inventory row removed 2026-09-07 with the
  # pre-set pacing family; the coverage mechanism stays).
  interleave="${RESEARCH_REVIEW_INTERLEAVE:-3}"
  case "$interleave" in '' | *[!0-9]*) interleave=0 ;; esac
  if [ "$interleave" -gt 0 ] && [ $((run_n % interleave)) -eq 0 ]; then
   crow="$(awk -F'\t' '$2=="crystallized"{print $3"\t"$0}' "$LINES" 2>/dev/null |
    sort | cut -f2- | pick_doc_row)"
   [ -n "$crow" ] && {
    ROW="$crow"
    REVIEW=1
   }
  fi
  [ -n "$ROW" ] || ROW="$row"
  return 0
 fi
 row="$(awk -F'\t' '$2=="crystallized"{print $3"\t"$0}' "$LINES" 2>/dev/null |
  sort | cut -f2- | pick_doc_row)"
 [ -n "$row" ] && {
  ROW="$row"
  REVIEW=1
 }
}

demand_synthesize() { # -> replacement pick row after one bounded synthesis
 # Demand synthesizer (acceleration wave 2, the starvation fix): when
 # pick_line returns empty (every line crystallized/reviewed) and the
 # planned pool sits below research-demand-floor (env
 # RESEARCH_DEMAND_FLOOR overrides), make ONE bounded local-model call
 # (max 1024 tokens; max one synthesis per UTC day, stamped at
 # RESEARCH_SYNTH_STAMP_FILE) reading recent machine outputs. Each
 # proposed subject must name a SPECIFIC source item verbatim or it is
 # discarded at parse; accepted subjects append to research-subjects.txt
 # (ensure_lines picks them up, dedup by id). Daily-capped or zero
 # sourced parse -> return empty: the caller falls through to the
 # existing skip path.
 local synth_stamp planned floor disp les backlog alerts prompt resp
 local srcs src sid sq n accepted ok ln
 synth_stamp="${RESEARCH_SYNTH_STAMP_FILE:-/tmp/.hngh-research-synth-last}"
 [ "$(cat "$synth_stamp" 2>/dev/null || true)" = "$day" ] && return 0
 planned="$(awk -F'\t' '$2=="planned"' "$LINES" 2>/dev/null | wc -l | tr -d ' ')"
 # floor default 3 (Inventory row removed 2026-09-07 with the pre-set
 # pacing family; the supply mechanism stays).
 floor="${RESEARCH_DEMAND_FLOOR:-3}"
 case "$floor" in '' | *[!0-9]*) floor=0 ;; esac
 [ "$planned" -lt "$floor" ] || return 0
 disp="$(tail -n 20 "$DISPOSITIONS" 2>/dev/null || true)"
 les="$(tail -n 20 "$KERNEL/docs/project/lessons-index.md" 2>/dev/null || true)"
 backlog="$(tac "$AUTOMATION_ROOT/docs/BACKLOG.md" 2>/dev/null |
  awk '/^## /{c++} c<=3' | tac || true)"
 alerts="$(HNGH_REPORT_ROOT="$report_root" $REPORT --json 2>/dev/null | python3 -c '
import json, sys
try:
    rows = json.load(sys.stdin).get("reports", [])
except Exception:
    rows = []
out = []
for r in [x for x in rows if x.get("kind") == "alert"][:5]:
    ident = ""
    for ln in (r.get("body") or "").splitlines():
        if ln.startswith("identity:"):
            ident = ln.split(":", 1)[1].strip()
            break
    out.append(ident or r.get("id", ""))
print("\n".join(x for x in out if x))' || true)"
 # source tokens: disposition line ids, lesson ids, backlog section
 # titles, alert identities. A question citing none is discarded.
 srcs="$(
  { [ -f "$DISPOSITIONS" ] && cut -f1 "$DISPOSITIONS" | grep -vx 'line'; } 2>/dev/null
  awk -F'|' '/^\|[^-]/ && $2 !~ /^ *Lesson *$/ {gsub(/^ +| +$/, "", $2); print $2}' \
   "$KERNEL/docs/project/lessons-index.md" 2>/dev/null
  grep '^## ' "$AUTOMATION_ROOT/docs/BACKLOG.md" 2>/dev/null |
   sed 's/^## //; s/ *([0-9][^)]*) *$//'
  printf '%s\n' "$alerts"
 )"
 wiki_prior="$(prior_art "$les $backlog $alerts")"
 prompt="Read these recent machine outputs:
$disp

${wiki_prior:+Prior art (llm-wiki vault; read-only pointers):
$wiki_prior
}

Recent lessons (docs/project/lessons-index.md tail):
$les

Last sections of hngh-automation/docs/BACKLOG.md:
$backlog

Recent report-queue alert identities:
$alerts

Propose 2-3 research subjects the continuous research process should
carry next, each derived from a SPECIFIC named item above; name that
item verbatim inside the question text. Output exactly one subject per
line, shaped:
synth-$day-<n><TAB><one-line question>
with n = 1, 2, 3 and a literal TAB between id and question. No other
output."
 MODEL_PIN=local
 resp="$(printf '%s' "$prompt" | model_call 1024)"
 printf '%s\n' "$day" >"$synth_stamp" 2>/dev/null
 accepted=0
 while IFS= read -r ln; do
  [ -n "$ln" ] || continue
  sid="${ln%%$'\t'*}"
  sq="${ln#*$'\t'}"
  [ "$sq" != "$ln" ] || continue # no TAB -> malformed, discard
  case "$sid" in
  synth-"$day"-*) n="${sid#synth-$day-}" ;;
  *) continue ;;
  esac
  case "$n" in '' | *[!0-9]*) continue ;; esac
  grep -qxF "$sid" "$SUBJECTS" 2>/dev/null && continue
  ok=0
  while IFS= read -r src; do
   [ -n "$src" ] || continue
   if printf '%s' "$sq" | grep -qiF -- "$src"; then
    ok=1
    break
   fi
  done <<EOF_SRC
$srcs
EOF_SRC
  [ "$ok" = 1 ] || continue # unsourced synthesis discarded
  printf '%s\t%s\n' "$sid" "$sq" >>"$SUBJECTS"
  accepted=$((accepted + 1))
  [ "$accepted" -ge 3 ] && break
 done <<EOF_SYN
$resp
EOF_SYN
 if [ "$accepted" -eq 0 ]; then
  breadcrumb "$JOB_NAME" "research-synth-empty" \
   "demand synthesizer yielded no sourced subject (daily cap or parse)"
  return 0
 fi
 breadcrumb "$JOB_NAME" "research-synth" \
  "synthesized $accepted sourced subject(s) from machine outputs"
 ensure_lines
 pick_line
 printf '%s' "$ROW"
}

set_state() { # id new_state
 local tmp="$LINES.tmp"
 awk -F'\t' -v id="$1" -v st="$2" -v ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  'BEGIN{OFS="\t"} $1==id{$2=st; $3=ts} {print}' "$LINES" >"$tmp" &&
  mv "$tmp" "$LINES"
}

transition_goal() { # state -> the beat's goal text
 case "$1" in
 planned) echo "Expand this line of research: produce concrete findings and name three distinct angles worth pursuing further." ;;
 expanding) echo "Contract this line: distill the prior material into sharp, concrete recommendations applicable to hngh/hngh-automation." ;;
 contracting) echo "Crystallize this line: produce the final structured summary — findings, recommendations, and open threads — as the line's lasting record." ;;
 esac
}

prior_art() { # text -> bounded wiki prior-art excerpt on stdout (empty
 # when the vaults are absent: the wiki never blocks the beat). Wiki
 # surface consumption wire (hngh docs/design/wiki-surface.md):
 # deterministic word overlap -- each word of >=5 chars in TEXT is
 # grepped -i (first 2 hits) against the two vault meta/index.md files,
 # lines deduped, each capped at 100 chars, the whole block at 6 lines
 # / 600 bytes. Read-only pointers; the extension owns meta/.
 local text="$1" idx w lines=""
 [ -n "$text" ] || return 0
 for idx in "$WIKI_PROJECT_IDX" "$WIKI_PERSONAL_IDX"; do
  [ -f "$idx" ] || continue
  while IFS= read -r w; do
   [ -n "$w" ] || continue
   lines="$lines
$(grep -i -m2 -F -- "$w" "$idx" 2>/dev/null)"
  done <<EOF_W
$(printf '%s\n' "$text" | tr -cs 'A-Za-z0-9' '\n' | awk 'length($0) >= 5' | sort -u | head -12)
EOF_W
 done
 printf '%s\n' "$lines" | sed '/^$/d' | awk '!seen[$0]++' |
  LC_ALL=C sed 's/[^[:print:]]//g' | cut -c1-100 | head -6 | head -c 600
}

day="$(date -u +%Y-%m-%d)"
ensure_lines

pick_line
row="$ROW"
if [ -z "$row" ]; then
 row="$(demand_synthesize)"
fi
if [ -z "$row" ]; then
 breadcrumb "$JOB_NAME" "research-skip" "all research lines crystallized/reviewed"
 exit 0
fi
id="$(printf '%s' "$row" | cut -f1)"
state="$(printf '%s' "$row" | cut -f2)"
line="$(printf '%s' "$row" | cut -f4)"

# MODEL_PIN rotation (operator quota directive, 2026-09-07): every Nth run
# (kimi-research-share; 0/absent-config = never pin) pins the kimi quota leg
# primary, spreading K3 quota across the window -- 1 beat/hour, share 3 ->
# <=8 kimi calls/day against the 40/day cap; quota_pace_blocked still guards
# bursts, and a pace-blocked or 429ing kimi falls through to the local chain
# inside model_call (research never blocks). The live lobehub leg (Responses
# API, lobehub-research-share) takes precedence on its own cycle; the
# OpenCode Go leg (opencode-research-share, 5h-window paced) rotates after
# the kimi cycle. The review transition
# (terminal verdict on a crystallized line) is high-value judgment: ALWAYS
# pin kimi (an unarmed leg falls through immediately, same semantics).
# Precedence (fail-first routing): an overflow caller's OVERFLOW_PIN
# (quota/deck legs only -- the overflow beat never touches the local
# server) wins, then the busy ROUTE_PIN (capacity signal), then the
# rotation below for an otherwise-unpinned (local) run.
MODEL_PIN="${MODEL_PIN:-local}"
if [ -n "$OVERFLOW_PIN" ]; then
 MODEL_PIN="$OVERFLOW_PIN"
elif [ -n "$ROUTE_PIN" ]; then
 MODEL_PIN="$ROUTE_PIN"
elif [ "$MODEL_PIN" = "local" ]; then
 kimi_share="${KIMI_RESEARCH_SHARE:-$(get_param kimi-research-share 3)}"
 case "$kimi_share" in '' | *[!0-9]*) kimi_share=0 ;; esac
 lobehub_share="${LOBEHUB_RESEARCH_SHARE:-$(get_param lobehub-research-share 6)}"
 case "$lobehub_share" in '' | *[!0-9]*) lobehub_share=0 ;; esac
 if [ "$REVIEW" = "1" ]; then
  MODEL_PIN=kimi
 elif [ "$lobehub_share" -gt 0 ] && [ $((run_n % lobehub_share)) -eq 0 ]; then
  MODEL_PIN=lobehub
 elif [ "$kimi_share" -gt 0 ] && [ $((run_n % kimi_share)) -eq 0 ]; then
  MODEL_PIN=kimi
 else
  ocgo_share="${OCGO_RESEARCH_SHARE:-$(get_param opencode-research-share 3)}"
  case "$ocgo_share" in '' | *[!0-9]*) ocgo_share=0 ;; esac
  if [ "$ocgo_share" -gt 0 ] && [ $((run_n % ocgo_share)) -eq 0 ]; then
   MODEL_PIN=ocgo
  fi
 fi
fi

if [ "$REVIEW" = "1" ]; then
 # review transition: nothing left to advance -- give the oldest
 # crystallized line a terminal disposition (adopted | parked | killed)
 # instead of idling the beat.
 doc="$(research_doc "$id")"
 if [ -z "$doc" ]; then
  file_report alert "research review has no crystallized doc for $id" \
   "research-beat:review-no-doc" 86400
  exit 0
 fi
 prompt="Research line: $line (id: $id)
Review the crystallized research document below and issue one terminal
disposition for the line: adopted (its findings should drive work now),
parked (keep the record, no action now), or killed (close the line).
Known duplicate pairs -- when reviewing the first member of a pair, mark
it killed with a pointer to the survivor:
  wiki-viewer-qol -> survivor wiki-viewer-QoL-comparison
  tech-tree-research-ux -> survivor tech-tree-research-UX-precedents
  session-cost-display -> survivor session-cost-display-formats
  gantt-legibility -> survivor gantt-legibility-patterns
End your output with exactly one verdict line:
VERDICT: adopted|parked|killed -- <one-line reason>

--- crystallized document ($doc) ---
$(marked_cut 8000 "$doc")"
 t0=$(date +%s)
 response="$(printf '%s' "$prompt" | model_call 2048)"
 t1=$(date +%s)
 wall=$(awk "BEGIN{printf \"%.1f\", $t1 - $t0}")
 used="$(last_model_used)"
 if [ "$used" = "none:archive-only" ] || [ -z "$response" ]; then
  ff_record degraded
  file_report alert "research review unavailable: model chain down ($used)" \
   "research-beat:unavailable" 86400
  exit 0
 fi
 ff_record ok
 verdict_line="$(printf '%s\n' "$response" |
  grep -m1 -E '^[[:space:]]*VERDICT:[[:space:]]*(adopted|parked|killed)([[:space:]]|$)' || true)"
 action=""
 [ -n "$verdict_line" ] &&
  action="$(printf '%s' "$verdict_line" | cut -d: -f2 | awk '{print $1}')"
 if [ -z "$action" ]; then
  file_report alert "research review verdict unparseable for $id (model $used)" \
   "research-beat:review-unparseable" 86400
  exit 0
 fi
 reason="$(printf '%s' "$verdict_line" | sed 's/^VERDICT:[[:space:]]*//')"
 [ -f "$DISPOSITIONS" ] ||
  printf 'line\taction\tverdict\treviewer\tevidence\tdate\n' >"$DISPOSITIONS"
 printf '%s\t%s\t%s\tmodel:%s\t%s\t%s\n' \
  "$id" "$action" "$reason" "$used" "$doc" "$day" >>"$DISPOSITIONS"
 set_state "$id" "reviewed"
 python3 "$TELEMETRY" emit --kind research --model "$used" --wall-s "$wall" \
  --source research-review --subject "$id:crystallized->reviewed" \
  --data "{\"unit\":\"$id\"}"
 file_report progress "research line $id reviewed: $action ($reason)"
 breadcrumb "$JOB_NAME" "research-review" "$id crystallized->$action via $used"
 exit 0
fi

next="expanding"
[ "$state" = "expanding" ] && next="contracting"
[ "$state" = "contracting" ] && next="crystallized"

prior=""
for f in "$AUTOMATION_ROOT"/digest/RESEARCH-BEAT-*-"$id".md; do
 [ -f "$f" ] || continue
 prior="$prior$(marked_cut 4000 "$f")
"
done

wiki_prior="$(prior_art "$id $line")"

prompt="This is one transition of a CONTINUOUS research process (line
state: research-lines.tsv; prior material below). Never frame the
research pace as batched or periodic; the line is always in motion on
idle hosts.
Research line: $line
Current lifecycle state: $state. $(transition_goal "$state")
Ground every claim in this repository and the hngh kernel repository
($KERNEL): cite concrete file paths only where you are confident they
exist, and end with a References section naming them. Where a claim
needs external sources you cannot verify, say so explicitly instead of
asserting it.
${prior:+Prior material on this line:
$prior}"
[ -n "$wiki_prior" ] && prompt="$prompt
Prior art (llm-wiki vault; read-only pointers):
$wiki_prior
"

t0=$(date +%s)
response="$(printf '%s' "$prompt" | model_call 4096)"
t1=$(date +%s)
wall=$(awk "BEGIN{printf \"%.1f\", $t1 - $t0}")
used="$(last_model_used)"

if [ "$used" = "none:archive-only" ] || [ -z "$response" ]; then
 ff_record degraded
 file_report alert "research beat unavailable: local model chain down ($used)" \
  "research-beat:unavailable" 86400
 exit 0
fi
ff_record ok

out_rel="digest/RESEARCH-BEAT-$day-$id.md"
mkdir -p "$AUTOMATION_ROOT/digest"
{
 printf '# research beat %s\n\n_line: %s | state: %s -> %s | model: %s | wall_s: %s_\n\n%s\n' \
  "$day" "$line" "$state" "$next" "$used" "$wall" "$response"
} >"$AUTOMATION_ROOT/$out_rel"

if [ "$next" = "crystallized" ]; then
 {
  printf '# %s\n\n' "$line"
  printf 'Status: crystallized %s from research line `%s`; per-beat\n' "$(date -u +%Y-%m-%d)" "$id"
  printf 'material lives in hngh-automation digest/RESEARCH-BEAT-*-%s.md.\n\n' "$id"
  printf '%s\n' "$response"
 } >"$KERNEL/docs/research/$day-$id.md"
fi

set_state "$id" "$next"

python3 "$TELEMETRY" emit --kind research --model "$used" --wall-s "$wall" \
 --source research-beat --subject "$id:$state->$next" \
 --data "{\"unit\":\"$id\"}"
file_report progress "research line $id: $state -> $next -> $out_rel"
breadcrumb "$JOB_NAME" "research-done" "$id $state->$next via $used"
exit 0
