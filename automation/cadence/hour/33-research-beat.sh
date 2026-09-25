#!/usr/bin/env bash
# 33-research-beat -- research machine, mounted hourly and fail-first
# gated (lib/failfirst.sh; no pre-set beat interval): advance the oldest
# non-crystallized research line one
# lifecycle transition per beat
# (planned → expanding → contracting → crystallized) using the model
# chain. Commit-per-op (2026-09-12 yield audit): each value-carrying
# transition (crystallize write, review disposition) commits its own
# artifacts immediately via the free-commit lane, so nothing
# research-owned sits uncommitted between the hourly kernel-ledger
# syncs; the hourly sync stays as a backstop and normally carries
# nothing research-owned. Each beat writes digest/RESEARCH-BEAT-<date>-<id>.md; the
# crystallize transition also writes the condensed result into the hngh
# kernel's docs/research/<date>-<id>.md. State: research-lines.tsv at
# the AUTO root (id, state, updated, line); missing/empty state is
# re-seeded from research-subjects.txt. When every line is crystallized
# or reviewed, the beat reviews the oldest crystallized line into a
# terminal disposition (adopted|parked|killed, research-dispositions.tsv,
# state=reviewed). The review is two-sided (2026-09-12 operator
# directive): a supportive pass, an adversarial pass that cross-considers
# related findings, and the verdict -- both passes recorded in the
# dispositions support/oppose/followons columns plus a committed sidecar
# transcript; adopted findings queue up to 2 follow-on subjects per pass
# (fail-<date> id convention). The review also HARVESTS (2026-09-15
# lifecycle audit: adopted dispositions were a terminus that fed
# nothing): lib/research-harvest.py condenses each adopted verdict into
# one actionable row in research-lessons.tsv (keyed by line_id,
# re-adoption refreshes, later non-adopted retires) and, with the
# project vault mounted, appends wiki/sources/LES-<id>.md in the vault's
# own source-page shape (meta/ and raw/ stay the extension's;
# wiki_rebuild_meta indexes the page on its next rebuild).
# Research lines use the orchestrator
# blocker ledger (lib/beat-blockers.sh, scope research:<id>): two
# same-cause failures (dead model lane, junk capture) park a line,
# success clears it, and parked lines auto-unpark after the shared
# cooldown. Fail-first (2026-09-07): the beat fires every hour
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
. "$AUTOMATION_ROOT/lib/beat-blockers.sh"
. "$AUTOMATION_ROOT/lib/redact.sh"
. "$AUTOMATION_ROOT/lib/vip-gate.sh"

# one research transition at a time: the hour beat and the 15-minute
# overflow beat share this body and research-lines.tsv. A beat arriving
# while another holds the lock skips -- the next 15-minute overflow tick
# picks the work up. (Replaces the old 30-minute stagger guard: at a
# 15-minute overflow cadence the hour beat is always "recent", so the
# lock is the race prevention.)
exec 9>"${RESEARCH_LOCK_FILE:-/tmp/.hngh-research-beat-lock}"
flock -w "${RESEARCH_LOCK_WAIT:-300}" 9 || exit 0

# --- 0. Jev per-beat triage (hngh-sy4): one fan-out over live
# city-state (30s verdict cache = safe 2/min lane). Fail-open: without
# key or on any error the beat proceeds untriaged. Verdict recorded
# for the schedule dataset; hot lane logged for worker routing.
if _city_json="$(python3 "$AUTOMATION_ROOT/jobs/city-state.py" 2>/dev/null)"; then
 # typed triage glue hoisted to lib/typesafe.py triage_glue (no
 # urgency tail here -- this site never had one)
 if _triage="$(printf '%s' "$_city_json" | python3 "$AUTOMATION_ROOT/lib/typesafe.py" triage 2>/dev/null)"; then
  breadcrumb "$JOB_NAME" "triage" "jev per-beat fan-out: $_triage"
 fi
fi

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
# directed into the chain), else the design-class quota leg
# (zai glm-5.3 non-flash per the operator's 2026-09-13 benchmark
# priorities). An unarmed
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
  ROUTE_PIN=zai
  ZAI_MODEL="${ZAI_MODEL_DESIGN:-$(get_param zai-model-design '')}"
  breadcrumb "$JOB_NAME" "research-route-quota" \
   "local busy - research routed to $ROUTE_PIN (load ${busy%% *} >= ceiling ${busy##* }; deck unavailable)"
 fi
fi
[ "${RESEARCH_BEAT_GATE_ONLY:-0}" = "1" ] && exit 0

KERNEL="${HNGH_HOME:-$(cd "$(dirname "$0")/../../.." && pwd)}"
REPORT="python3 $KERNEL/scripts/report-queue"
report_root="${HNGH_REPORT_ROOT:-$KERNEL}"
TELEMETRY="$AUTOMATION_ROOT/jobs/telemetry.py"
LINES="$AUTOMATION_ROOT/research-lines.tsv"
SUBJECTS="$AUTOMATION_ROOT/research-subjects.txt"
DISPOSITIONS="$AUTOMATION_ROOT/research-dispositions.tsv"
WIKI_PROJECT_IDX="${HNGH_WIKI_PROJECT_INDEX:-$HOME/Projects/etc/llm-wiki/.llm-wiki/meta/index.md}"
WIKI_PERSONAL_IDX="${HNGH_WIKI_PERSONAL_INDEX:-$HOME/.llm-wiki/meta/index.md}"

# sweep self-heal (2026-09-22 gate-flap cure): the research-tsv
# sweep's orphaned --apply mode wired into the cadence, so committed
# raw-home-token rows back-redact within the hour instead of blocking
# plan acceptance until a manual cure (fc74aa3b precedent, alert
# 81bccb06 x14). Fail-soft: the gate alert remains the backstop for
# anything this leaves behind (dirty churn, staged-index refusals).
[ -x "$AUTOMATION_ROOT/scripts/research-sweep-selfheal.sh" ] &&
 KERNEL="$KERNEL" JOB_NAME="$JOB_NAME" \
  "$AUTOMATION_ROOT/scripts/research-sweep-selfheal.sh" || :

# commit-per-op (2026-09-12 yield audit): commit exactly the artifacts a
# value-carrying transition just wrote, in the same beat. Free-commit
# lane (machine-managed research surfaces, per the plans/README autonomy
# reference). Fail-closed: no git repo, operator-staged work, or any
# path outside the repo (hermetic sandboxes) -> quiet no-op, hourly
# ledger sync remains the backstop. Never pushes (sweep tier owns push).
# Staged-change refusal mirrors 30-kernel-ledger-sync so the two never
# entangle each other's commits.
research_commit() { # id state path... -> commits exactly the named paths
 local id="$1" state="$2"
 shift 2
 local paths=() p rel
 [ -d "$KERNEL/.git" ] || return 0
 git -C "$KERNEL" diff --cached --quiet 2>/dev/null || return 0
 for p in "$@"; do
  [ -f "$p" ] || continue
  rel="$(realpath --relative-to="$KERNEL" "$p" 2>/dev/null)" || continue
  case "$rel" in ..*) continue ;; esac
  git -C "$KERNEL" add -- "$rel" 2>/dev/null || continue
  paths+=("$rel")
 done
 [ "${#paths[@]}" -ge 1 ] || return 0
 git -C "$KERNEL" -c user.name="boundring" -c user.email="boundring@gmail.com" \
  commit -q -m "research: $id $state" -- "${paths[@]}" \
  2>/dev/null &&
  breadcrumb "$JOB_NAME" "research-commit" "$id $state: ${paths[*]}"
 return 0
}

file_report() {
 local kind="$1" text="$2" ident="${3:-}" win="${4:-86400}"
 if HNGH_REPORT_ROOT="$report_root" $REPORT --add "$kind" "$text" \
  ${ident:+--identity "$ident"} --window "$win" >/dev/null 2>&1; then
  breadcrumb "$JOB_NAME" "$kind" "$text"
 else
  breadcrumb "$JOB_NAME" "report-fail" "could not file $kind: $text"
 fi
}

# operator directive 2026-09-17: both ingest seams redact source-side
# before id/slug derivation and before any TSV write (research-lines.tsv
# and research-subjects.txt are git-tracked and pushed publicly; the
# report-queue sink-side guard can never cover this seam, and the leaked
# fail-20260914-Where-exactly-in-home-bricker-Projects-e id proved the
# leak happens at/before derivation). Single token family via lib/scrub.py
# (redact_home = tilde rendering, the ledger convention; fail-closed to
# empty output if scrub.py breaks). scrub_truncate (2026-09-17 GAP)
# additionally cuts the dash-mangled form (home-bricker-...) that
# redact_home's slash-form family cannot see: the tab-less branch
# DERIVES the id from the text, so a pre-mangled dash-form line is cut
# at the stem before derivation (empty = whole-input path-derived ->
# the line is discarded, never a username-bearing id).
ensure_lines() {
 local line
 local id
 local desc
 SEEDED=0
 while IFS= read -r line; do
  [ -n "$line" ] || continue
  desc="$(redact_home "$line")"
  line="$desc"
  case "$line" in
  *$'\t'*)
   id="${line%%$'\t'*}"
   desc="${line#*$'\t'}"
   ;;
  *)
   line="$(scrub_truncate "$line")"
   [ -n "$line" ] || continue # dash-form pathy whole-input -> discard
   id="$(printf '%s' "$line" | tr -cs 'a-zA-Z0-9' '-' | sed 's/^-*//; s/-*$//')"
   ;;
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
 for f in "$DIGEST_DIR"/RESEARCH-BEAT-*-"$1".md; do
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
  filter_parked |
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
    sort | cut -f2- | filter_parked | pick_doc_row)"
   [ -n "$crow" ] && {
    ROW="$crow"
    REVIEW=1
   }
  fi
  [ -n "$ROW" ] || ROW="$row"
  return 0
 fi
 row="$(awk -F'\t' '$2=="crystallized"{print $3"\t"$0}' "$LINES" 2>/dev/null |
  sort | cut -f2- | filter_parked | pick_doc_row)"
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
 # LOCAL-RESERVE (hngh-wc4): the demand synthesizer rides the same
 # reserve rule as the main transition -- local only inside the midnight
 # window with the operator idle, else the zai quota leg (falls through
 # to local inside model_call if unarmed; the synthesis is capped and
 # daily-stamped, so a quota miss costs one empty day at most).
 if vip_in_window && ! vip_skip_verdict; then
  MODEL_PIN=local
 else
  MODEL_PIN=zai
  ZAI_MODEL="${ZAI_MODEL_DESIGN:-${ZAI_MODEL:-$(get_param zai-model-design '')}}"
 fi
 # plan synthesis is commit-range sized: deep tier (2026-09-22 context
 # lane), scoped to this call so the beat's later model_call sites stay
 # on ctx-standard
 resp="$(printf '%s' "$prompt" | MODEL_CTX="${MODEL_CTX:-$(get_param ctx-deep 32768)}" model_call 1024)"
 printf '%s\n' "$day" >"$synth_stamp" 2>/dev/null
 accepted=0
 while IFS= read -r ln; do
  [ -n "$ln" ] || continue
  sid="${ln%%$'\t'*}"
  sq="${ln#*$'\t'}"
  [ "$sq" != "$ln" ] || continue # no TAB -> malformed, discard
  q="$(redact_home "$sq")"
  sq="$q"
  [ -n "$sq" ] || continue # redaction fail-closed empty -> discard
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

filter_parked() { # TSV rows on stdin -> rows whose id has no parked
 # research:<id> blocker row (parked lines are held out of every pick).
 local pv
 pv="$(awk -F'\t' '$6=="parked" && $2 ~ /^research:/ {print substr($2, 10)}' \
  "$BEAT_BLOCKERS_FILE" 2>/dev/null | paste -sd, -)"
 [ -n "$pv" ] || {
  cat
  return 0
 }
 awk -F'\t' -v pv="$pv" 'BEGIN{n=split(pv,a,/,/); for(i=1;i<=n;i++) p[a[i]]=1}
  !($1 in p)'
}

block_escalate() { # id cause -> records a same-cause research failure;
 # at blocker-escalate-n consecutive same-cause outcomes the line parks
 # and the alert files (bounded retries, never infinite; cooldown
 # auto-unparks via blocker_tick). attempts 0 = ledger write refused.
 local id="$1" cause="$2" n esc
 n="$(blocker_record "research:$id" "$cause")"
 esc="$(get_param blocker-escalate-n 2)"
 case "$esc" in '' | *[!0-9]*) esc=2 ;; esac
 if [ "$n" -ge 1 ] && [ "$esc" -gt 0 ] && [ "$n" -ge "$esc" ]; then
  blocker_park "research:$id"
  file_report alert \
   "research line $id parked after $n consecutive $cause outcomes (blocker-escalate-n=$esc); auto-unparks after blocker-park-cooldown-hours" \
   "research-beat:line-parked:$id" 86400
 fi
}

pass_line() { # response -> one-line distillation of a review pass
 printf '%s\n' "$1" | grep -v '^[[:space:]]*$' | head -1 |
  tr '\t' ' ' | LC_ALL=C sed 's/[^[:print:]]//g' | cut -c1-160
}

append_disposition_impl() { # id action reason used doc day sup opp fon ->
 # append one 9-column research-dispositions.tsv row, sealed: every
 # free-text column (verdict col3 / evidence col5 / support col7 /
 # oppose col8 / followons col9 -- all model output) runs redact_home
 # AFTER tab-flattening and BEFORE the printf (2026-09-17 sink cure,
 # forward-only: the sink-side ingest fix 2e51d01b redacts at MCP read
 # time but the TSV is git-tracked and pushed publicly via
 # research_commit, and post-fix rows still carried raw /home/<user>
 # paths; harvest then interpolates evidence onward). id, reviewer and
 # date are beat-generated and pass through untouched. Fail-closed: a
 # broken redact backend yields EMPTY output; a row whose free-text
 # columns redacted to empty from non-empty input is never written
 # (the line stays crystallized and the next beat re-reviews it).
 local id="$1" action="$2" reason="$3" used="$4" doc="$5" day="$6"
 local sup_line="$7" opp_line="$8" followons="${9:-}"
 # text fields are model output: tabs would widen the row past the schema
 reason="$(printf '%s' "$reason" | tr '\t' ' ')"
 sup_line="$(printf '%s' "$sup_line" | tr '\t' ' ')"
 opp_line="$(printf '%s' "$opp_line" | tr '\t' ' ')"
 followons="$(printf '%s' "$followons" | tr '\t' ' ')"
 local reason_r="$reason" doc_r="$doc" sup_r="$sup_line" opp_r="$opp_line"
 local fon_r="$followons"
 # "|| :" keeps a failing backend from aborting a set -e caller: the
 # assignment still yields empty, which the withhold check below turns
 # into a skipped row.
 reason="$(redact_home "$reason")" || :
 doc="$(redact_home "$doc")" || :
 sup_line="$(redact_home "$sup_line")" || :
 opp_line="$(redact_home "$opp_line")" || :
 followons="$(redact_home "$followons")" || :
 if { [ -n "$reason_r" ] && [ -z "$reason" ]; } ||
  { [ -n "$doc_r" ] && [ -z "$doc" ]; } ||
  { [ -n "$sup_r" ] && [ -z "$sup_line" ]; } ||
  { [ -n "$opp_r" ] && [ -z "$opp_line" ]; } ||
  { [ -n "$fon_r" ] && [ -z "$followons" ]; }; then
  breadcrumb "$JOB_NAME" "research-disposition-withheld" \
   "$id: redact_home yielded empty output; disposition row not appended"
  return 0
 fi
 # writer schema; upgrade a stale header (older schema) in place before
 # appending 9-column rows, so the MCP reader never trips on column drift.
 local schema='line\taction\tverdict\treviewer\tevidence\tdate\tsupport\toppose\tfollowons'
 if [ -f "$DISPOSITIONS" ]; then
  [ "$(head -n 1 "$DISPOSITIONS")" = "$(printf '%b\n' "$schema")" ] || {
   {
    printf '%b\n' "$schema"
    tail -n +2 "$DISPOSITIONS"
   } >"$DISPOSITIONS.tmp" &&
    mv "$DISPOSITIONS.tmp" "$DISPOSITIONS"
  }
 else
  printf '%b\n' "$schema" >"$DISPOSITIONS"
 fi
 printf '%s\t%s\t%s\tmodel:%s\t%s\t%s\t%s\t%s\t%s\n' \
  "$id" "$action" "$reason" "$used" "$doc" "$day" \
  "$sup_line" "$opp_line" "$followons" >>"$DISPOSITIONS"
}

related_findings() { # id line -> bounded block of related crystallized
 # docs (keyword overlap, same deterministic shape as prior_art; the
 # review cross-considers these: agreement/conflict is judged in the
 # adversarial pass). Own doc excluded.
 local id="$1" line="$2" w f out="" files=""
 [ -d "$KERNEL/docs/research" ] || return 0
 while IFS= read -r w; do
  [ -n "$w" ] || continue
  for f in $(LC_ALL=C grep -rilF -- "$w" "$KERNEL/docs/research" 2>/dev/null |
   head -3); do
   case "$f" in *-"$id".md) continue ;; esac
   files="$files $f"
  done
 done <<EOF_W
$(printf '%s\n' "$line" | tr -cs 'A-Za-z0-9' '\n' | awk 'length($0) >= 5' | sort -u | head -8)
EOF_W
 for f in $(printf '%s\n' $files | sort -u | head -5); do
  [ -n "$f" ] || continue
  out="$out$(basename "$f") -- $(LC_ALL=C sed -n '1s/^#[[:space:]]*//p' "$f" | cut -c1-140)
"
 done
 printf '%s' "${out%,}"
}

followon_queue() { # response -> queues up to 2 follow-on subjects from
 # 'FOLLOWON: <question>' lines (supportive/adversarial review passes;
 # operator directive 2026-09-12: an adopted finding that opens NEW
 # questions auto-queues research-subjects entries, fail-<date> id
 # convention). Prints the queued ids, comma-joined ("" = none).
 local q n=0 rid slug
 local out=""
 while IFS= read -r q; do
  case "$q" in FOLLOWON:*) q="${q#FOLLOWON: }" ;; *) continue ;; esac
  # redact BEFORE derivation: the slug is cut from q, so a pathy question
  # would otherwise bake the machine-local path into the public id.
  # scrub_truncate (2026-09-17 GAP) additionally cuts the dash-mangled
  # form (home-bricker-...) redact_home cannot see; empty = whole-input
  # path-derived -> discard, never a username-bearing id.
  q="$(redact_home "$q")"
  [ -n "$q" ] || continue # redaction fail-closed empty -> discard
  q="$(scrub_truncate "$q")"
  [ -n "$q" ] || continue # dash-form pathy whole-input -> discard
  q="$(printf '%s' "$q" | tr -cd '\11\12\15\40-\176' | tr '\t' ' ' |
   sed 's/^ *//; s/ *$//' | cut -c1-240)"
  [ -n "$q" ] || continue
  slug="$(printf '%s' "$q" | tr -cs 'a-zA-Z0-9' '-' | sed 's/^-*//; s/-$//' |
   cut -c1-40)"
  [ -n "$slug" ] || continue
  rid="fail-$(date -u +%Y%m%d)-$slug"
  grep -qxF "$rid	$q" "$SUBJECTS" 2>/dev/null && continue
  printf '%s	%s\n' "$rid" "$q" >>"$SUBJECTS"
  out="$out$rid,"
  n=$((n + 1))
  [ "$n" -ge 2 ] && break
 done
 printf '%s' "$out"
}

day="$(date -u +%Y-%m-%d)"

# roguelike research operations (operator directive, 2026-09-12): research
# lines get the beat-blockers treatment at scope research:<id> -- a line
# failing twice with the same cause (dead model lane, junk capture) parks
# and files the alert; parked lines auto-unpark after the shared
# blocker-park-cooldown-hours and success clears the row outright.
blocker_tick "$(get_param blocker-park-cooldown-hours 24)"

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

# MODEL_PIN rotation (operator quota directive, 2026-09-07; benchmark-priority
# routing 2026-09-13): every Nth run (kimi-research-share; 0/absent-config =
# never pin) pins the design-class quota leg -- zai glm-5.3 non-flash
# (zai-model-design row; verified live on api.z.ai 2026-09-13), spreading
# the Z.AI bucket across the window -- 1 beat/hour, share 2 -> <=12
# pinned calls/day against the 300/5h + 1500/week caps. Kimi K3 (40/day,
# scarce) is conserved for the intelligence-shaped review work only.
# quota_pace_blocked still guards
# bursts, and a pace-blocked or 429ing leg falls through to the local chain
# inside model_call (research never blocks). The
# OpenCode Go leg (opencode-research-share, 5h-window paced) rotates after
# the kimi cycle. The review transition
# (terminal verdict on a crystallized line) is high-value judgment: ALWAYS
# pin kimi (an unarmed leg falls through immediately, same semantics).
# Precedence (fail-first routing): an overflow caller's OVERFLOW_PIN
# (quota/deck legs only -- the overflow beat never touches the local
# server) wins, then the busy ROUTE_PIN (capacity signal), then the
# rotation below for an otherwise-unpinned run.
# LOCAL-RESERVE (hngh-wc4, 2026-09-19): an explicitly preset MODEL_PIN
# always wins; note it here so the reserve shift below never overrides
# an operator override.
_pin_preset=0
[ -n "${MODEL_PIN:-}" ] && _pin_preset=1
MODEL_PIN="${MODEL_PIN:-local}"
# Operator-active guard (2026-09-18 beats hold): when the Jev beat-skip
# verdict says the operator is using the machine, a local pin would hit
# the operator's Unsloth server mid-session. Shift to the kimi quota leg
# instead (falls through inside model_call if unarmed; research never
# blocks). Overflow pins already avoid local; ROUTE_PIN wins as before.
if [ -z "$OVERFLOW_PIN" ] && [ -z "$ROUTE_PIN" ] && [ "$MODEL_PIN" = "local" ]; then
 _skip_file="${VIP_BEATSKIP_FILE:-$AUTOMATION_ROOT/tmp-beatskip.txt}"
 if [ "$(cat "$_skip_file" 2>/dev/null)" = "skip" ]; then
  breadcrumb "$JOB_NAME" "research-reroute" \
   "operator active (beat-skip=skip) — local Unsloth leg shifted to kimi"
  MODEL_PIN=kimi
 fi
fi
if [ -n "$OVERFLOW_PIN" ]; then
 MODEL_PIN="$OVERFLOW_PIN"
elif [ -n "$ROUTE_PIN" ]; then
 MODEL_PIN="$ROUTE_PIN"
elif [ "$MODEL_PIN" = "local" ]; then
 kimi_share="${KIMI_RESEARCH_SHARE:-$(get_param kimi-research-share 3)}"
 case "$kimi_share" in '' | *[!0-9]*) kimi_share=0 ;; esac
 if [ "$REVIEW" = "1" ]; then
  MODEL_PIN=kimi
 elif [ "$kimi_share" -gt 0 ] && [ $((run_n % kimi_share)) -eq 0 ]; then
  MODEL_PIN=zai
  ZAI_MODEL="${ZAI_MODEL_DESIGN:-$(get_param zai-model-design '')}"
 else
  ocgo_share="${OCGO_RESEARCH_SHARE:-$(get_param opencode-research-share 3)}"
  case "$ocgo_share" in '' | *[!0-9]*) ocgo_share=0 ;; esac
  if [ "$ocgo_share" -gt 0 ] && [ $((run_n % ocgo_share)) -eq 0 ]; then
   MODEL_PIN=ocgo
  fi
 fi
fi
# LOCAL-RESERVE (hngh-wc4, 2026-09-19): reserve local Unsloth for the
# midnight window -- the vip-gate pattern from model-bench/night-research.
# Fires only when the rotation above left the pin at local residual (no
# overflow pin, no busy route, no preset, no kimi/zai/ocgo rotation hit,
# no review pin): outside the window, or while the beat-skip verdict says
# the operator is active, shift that residual local pin to the
# design-class zai quota leg (falls through to the local chain inside
# model_call if unarmed, so research never blocks). Overflow-pin behavior
# untouched: OVERFLOW_PIN still wins above and never touches local.
if [ "$_pin_preset" = 0 ] && [ -z "$OVERFLOW_PIN" ] && [ -z "$ROUTE_PIN" ] &&
 [ "$REVIEW" != "1" ] && [ "$MODEL_PIN" = "local" ]; then
 if vip_in_window && ! vip_skip_verdict; then
  breadcrumb "$JOB_NAME" "research-local-reserve" \
   "midnight window open, operator idle -- local Unsloth leg kept"
 else
  MODEL_PIN=zai
  ZAI_MODEL="${ZAI_MODEL_DESIGN:-${ZAI_MODEL:-$(get_param zai-model-design '')}}"
  breadcrumb "$JOB_NAME" "research-local-reserve" \
   "daytime/operator-active -- residual local pin shifted to zai quota leg, local reserved for midnight"
 fi
fi

if [ "$REVIEW" = "1" ]; then
 # review transition: nothing left to advance -- give the oldest
 # crystallized line a terminal disposition (adopted | parked | killed)
 # instead of idling the beat. Two-sided review protocol (operator
 # directive, 2026-09-12): (a) supportive pass -- corroborating
 # evidence; (b) adversarial pass -- attempt to DISCONFIRM, with related
 # findings cross-considered; (c) verdict adopted|parked|killed as
 # before, with BOTH passes recorded (dispositions support/oppose/
 # followons columns + the committed sidecar transcript).
 doc="$(research_doc "$id")"
 if [ -z "$doc" ]; then
  file_report alert "research review has no crystallized doc for $id" \
   "research-beat:review-no-doc" 86400
  exit 0
 fi
 related="$(related_findings "$id" "$line")"
 prior_adopted="$(awk -F'\t' -v id="$id" '$2=="adopted" && $1==id {
   v=$3; if (length(v) > 160) v=substr(v, 1, 160) "...";
   print "- " v }' "$DISPOSITIONS" 2>/dev/null | tail -5)"
 DATE="$(date -u +%F)"
 night_brief=""
 if [ -s "$DIGEST_DIR/RESEARCH-$DATE.md" ]; then
  night_brief="$(marked_cut 2000 "$DIGEST_DIR/RESEARCH-$DATE.md")"
 fi
 sup_prompt="Research line: $line (id: $id)
SUPPORTIVE review pass. Find corroborating evidence FOR the findings in
the crystallized document below: concrete repo files, other research
docs, external feeds (e.g. GDELT news trends). Name what supports each
finding and state explicitly what remains unverified. Then list up to 2
NEW research questions the findings open, one per line, shaped exactly:
FOLLOWON: <one-line question>
--- crystallized document ($doc) ---
$(marked_cut 8000 "$doc")
${related:+
--- related findings (cross-consider these) ---
$related}
${prior_adopted:+
--- prior adopted dispositions (advisory evidence, never the verdict itself) ---
$prior_adopted}
${night_brief:+
--- night research brief (advisory) ---
$night_brief}"
 t0=$(date +%s)
 supportive="$(printf '%s' "$sup_prompt" | model_call 2048)"
 t1=$(date +%s)
 wall="$(awk "BEGIN{printf \"%.1f\", $t1 - $t0}")"
 used="$(last_model_used)"
 if [ "$used" = "none:archive-only" ] || [ -z "$supportive" ]; then
  ff_record degraded
  block_escalate "$id" model-lane-dead
  file_report alert "research review unavailable: model chain down ($used)" \
   "research-beat:unavailable" 86400
  exit 0
 fi
 opp_prompt="Research line: $line (id: $id)
ADVERSARIAL review pass. Attempt to DISCONFIRM the findings: seek
counter-evidence, edge cases, and stale assumptions; cross-consider the
related findings below and state agreement or conflict. Then issue one
terminal disposition for the line: adopted (its findings should drive
work now), parked (keep the record, no action now), or killed (close
the line).
Known duplicate pairs -- when reviewing the first member of a pair, mark
it killed with a pointer to the survivor:
  wiki-viewer-qol -> survivor wiki-viewer-QoL-comparison
  tech-tree-research-ux -> survivor tech-tree-research-UX-precedents
  session-cost-display -> survivor session-cost-display-formats
  gantt-legibility -> survivor gantt-legibility-patterns
Also list up to 2 NEW research questions the findings open, one per
line, shaped exactly:
FOLLOWON: <one-line question>
End your output with exactly one verdict line:
VERDICT: adopted|parked|killed -- <one-line reason>

--- crystallized document ($doc) ---
$(marked_cut 8000 "$doc")
--- supportive pass (what supports the findings) ---
${supportive:-none recorded}
${related:+--- related findings (cross-consider these) ---
$related}
${prior_adopted:+
--- prior adopted dispositions (advisory evidence, never the verdict itself) ---
$prior_adopted}
${night_brief:+
--- night research brief (advisory) ---
$night_brief}"
 t0=$(date +%s)
 response="$(printf '%s' "$opp_prompt" | model_call 2048)"
 t1=$(date +%s)
 wall="$(awk "BEGIN{printf \"%.1f\", $t1 - $t0}")"
 used="$(last_model_used)"
 if [ "$used" = "none:archive-only" ] || [ -z "$response" ]; then
  ff_record degraded
  block_escalate "$id" model-lane-dead
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
 # typed verdict glue (typed-first, fail-closed): ONE Choice over
 # adopted|parked|killed with confidence, arbitrated (min_conf 0.60)
 # against the legacy VERDICT parse above as fallback. Without
 # TYPESAFE_API_KEY, or on any failure, the arbiter keeps the legacy
 # action and nothing changes. Prints "<action> <confidence>", confidence
 # present only when the typed answer won, so the reason can cite it.
 sup_line="$(pass_line "$supportive")"
 doc_cut="$(marked_cut 8000 "$doc")"
 typed_out="$(LEGACY_ACTION="$action" \
  TYPESAFE_LINE="$id $line" \
  TYPESAFE_SUP="$sup_line" \
  TYPESAFE_OPP="$response" \
  TYPESAFE_DOC="$doc_cut" \
  python3 -c "
import os, sys
sys.path.insert(0, os.path.join('$AUTOMATION_ROOT', 'lib'))
from typesafe import ask_choices, arbiter
st = {'line': os.environ.get('TYPESAFE_LINE', ''),
      'supportive': os.environ.get('TYPESAFE_SUP', ''),
      'adversarial': os.environ.get('TYPESAFE_OPP', ''),
      'doc': os.environ.get('TYPESAFE_DOC', '')}
res = ask_choices(st, {'research_verdict': (
    'Classify the review outcome of this research line after a supportive and an adversarial pass. adopted: the evidence supports adopting it (no fatal flaw, no decisively better alternative). parked: uncertain or dependent (missing evidence, unresolved tension, or an operator call). killed: a fatal flaw or a decisively better existing alternative.',
    ['adopted', 'parked', 'killed'])}).get('research_verdict', (None, None))
out = arbiter(res, os.environ.get('LEGACY_ACTION'),
              ['adopted', 'parked', 'killed'], 0.60) or ''
won = res[0] == out and res[1] is not None
print(out + (' %.2f' % res[1] if won else ''))
" 2>/dev/null || true)"
 action="${typed_out%% *}"
 tconf="${typed_out#* }"
 [ "$tconf" = "$typed_out" ] && tconf=""
 if [ -z "$action" ]; then
  file_report alert "research review verdict unparseable for $id (model $used)" \
   "research-beat:review-unparseable" 86400
  exit 0
 fi
 if [ -n "$verdict_line" ]; then
  reason="$(printf '%s' "$verdict_line" | sed 's/^VERDICT:[[:space:]]*//')"
 else
  reason="typed verdict $action (confidence ${tconf:-unknown})"
 fi
 opp_line="$(pass_line "$response")"
 followons=""
 if [ "$action" = "adopted" ]; then
  followons="$({
   printf '%s\n' "$supportive"
   printf '%s\n' "$response"
  } |
   followon_queue)"
 fi
 # sealed append seam (2026-09-17): schema upgrade, tab-flattening and
 # redact_home over every free-text column live in append_disposition_impl
 # (single source; test-research-dispositions-redact.sh extracts it).
 append_disposition_impl "$id" "$action" "$reason" "$used" "$doc" "$day" \
  "$sup_line" "$opp_line" "$followons"
 # harvest (2026-09-15 lifecycle audit: adopted dispositions were a
 # terminus that fed nothing): condense every adopted verdict into ONE
 # actionable lesson row in research-lessons.tsv, keyed by line_id --
 # a re-adoption REFRESHES the row (never duplicates) and a later
 # non-adopted verdict retires it. With the project vault mounted the
 # lesson also lands as wiki/sources/LES-<id>.md in the vault's own
 # source-page shape (meta/ and raw/ stay the extension's;
 # wiki_rebuild_meta indexes the page, the wiki-health UNINDEXED alert
 # covers the gap until then). Fail-closed on malformed input: the
 # disposition above was already recorded, so a harvest failure never
 # loses the verdict -- the alert names it for the operator.
 HARVEST_VAULT="${HNGH_WIKI_PROJECT:-$HOME/Projects/etc/llm-wiki/.llm-wiki}"
 if [ ! -d "$HARVEST_VAULT/wiki" ]; then
  breadcrumb "$JOB_NAME" "research-harvest-skip" \
   "wiki vault absent ($HARVEST_VAULT): lesson TSV only"
  HARVEST_VAULT=""
 fi
 hv_out="$(python3 "$AUTOMATION_ROOT/lib/research-harvest.py" \
  --dispositions "$DISPOSITIONS" --lines "$LINES" \
  --lessons "$AUTOMATION_ROOT/research-lessons.tsv" \
  ${HARVEST_VAULT:+--vault "$HARVEST_VAULT"} 2>&1)" || {
  file_report alert "research harvest failed for $id: $(printf '%s' "$hv_out" | tail -1 | cut -c1-160)" \
   "research-beat:harvest-failed" 86400
 }
 [ -n "$hv_out" ] && breadcrumb "$JOB_NAME" "research-harvest" \
  "$id: $hv_out"
 set_state "$id" "reviewed"
 blocker_clear "research:$id"
 rev_rel="digest/RESEARCH-REVIEW-$day-$id.md"
 {
  printf '# research review %s\n\n_line: %s | verdict: %s | model: %s_\n\n' \
   "$day" "$line" "$action" "$used"
  printf '## Supportive pass\n\n%s\n\n' "$supportive"
  printf '## Adversarial pass\n\n%s\n\n' "$response"
  [ -n "$related" ] &&
   printf '## Related findings cross-considered\n\n%s\n' "$related"
 } >"$AUTOMATION_ROOT/$rev_rel"
 research_commit "$id" "reviewed-$action" "$DISPOSITIONS" "$LINES" \
  "$AUTOMATION_ROOT/$rev_rel" "$AUTOMATION_ROOT/research-lessons.tsv"
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
for f in "$DIGEST_DIR"/RESEARCH-BEAT-*-"$id".md; do
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
 block_escalate "$id" model-lane-dead
 file_report alert "research beat unavailable: local model chain down ($used)" \
  "research-beat:unavailable" 86400
 exit 0
fi
ff_record ok

# Capture-side filter (2026-09-11 corpus-loss cure, docs/records/
# 2026-09-11-research-beat-capture-fix.md): raw model tool-call syntax
# never becomes doc prose; a capture stripped to empty files an alert and
# writes nothing (state held for retry); truncation is explicit, never a
# silent mid-token cut. DOC_CAPTURE_CHAR_CAP is a hermetic-test seam.
truncflag=""
[ -n "$(last_model_truncated)" ] && truncflag="--truncated"
body="$(printf '%s' "$response" | python3 "$AUTOMATION_ROOT/lib/docfilter.py" \
 "${DOC_CAPTURE_CHAR_CAP:-16000}" $truncflag 2>"$AUTOMATION_ROOT/.docfilter-inj.$$")" || {
 ff_record degraded
 block_escalate "$id" junk-capture
 file_report alert "research beat capture for $id ($state->$next) stripped to empty: model emitted only tool-call syntax ($used); no doc written, line state held for retry" \
  "research-beat:junk-capture:$id" 86400
 rm -f "$AUTOMATION_ROOT/.docfilter-inj.$$"
 exit 0
}
# security routines (2026-09-12): injection signatures in the capture are
# redacted by docfilter at write time; the hits file an alert (the line
# content is data, never command).
if [ -s "$AUTOMATION_ROOT/.docfilter-inj.$$" ]; then
 file_report alert \
  "injection signature(s) redacted from research capture for $id ($used): $(head -1 "$AUTOMATION_ROOT/.docfilter-inj.$$" | cut -c1-160)" \
  "research-beat:injection:$id" 86400
fi
rm -f "$AUTOMATION_ROOT/.docfilter-inj.$$"

# writer-seam redaction (2026-09-17 GAP cure, wiki-health-wiring-
# reconcile::gate): docfilter covers injection + char cap only, and the
# crystallize transition emits $line verbatim as the docs/research title
# plus $body into the git-tracked, publicly pushed kernel repo -- the
# leaked fail-20260916-If-the-probe-* doc title proved the raw path
# emission. redact_home (lib/scrub.py, the single tilde token family;
# fail-closed to empty output if scrub.py breaks) covers BOTH emitters
# -- the digest beat copy and the crystallized doc -- before any write.
line="$(redact_home "$line")"
[ -n "$line" ] || {
 ff_record degraded
 block_escalate "$id" redaction-failed
 file_report alert "research beat redaction failed for $id ($used): redact_home yielded empty output; no doc written, line state held for retry" \
  "research-beat:redaction-failed:$id" 86400
 exit 0
}
body="$(redact_home "$body")"
[ -n "$body" ] || {
 ff_record degraded
 block_escalate "$id" redaction-failed
 file_report alert "research beat redaction failed for $id ($used): redacted body came back empty; no doc written, line state held for retry" \
  "research-beat:redaction-failed:$id" 86400
 exit 0
}

out_rel="$DIGEST_DIR/RESEARCH-BEAT-$day-$id.md"
mkdir -p "$DIGEST_DIR"
{
 printf '# research beat %s\n\n_line: %s | state: %s -> %s | model: %s | wall_s: %s_\n\n%s\n' \
  "$day" "$line" "$state" "$next" "$used" "$wall" "$body"
} >"$out_rel"

if [ "$next" = "crystallized" ]; then
 {
  printf '# %s\n\n' "$line"
  printf 'Status: crystallized %s from research line `%s`; per-beat\n' "$(date -u +%Y-%m-%d)" "$id"
  printf 'material lives in hngh-automation digest/RESEARCH-BEAT-*-%s.md.\n\n' "$id"
  printf '%s\n' "$body"
 } >"$KERNEL/docs/research/$day-$id.md"
fi

set_state "$id" "$next"
blocker_clear "research:$id"
if [ "$next" = "crystallized" ]; then
 research_commit "$id" "crystallized" \
  "$KERNEL/docs/research/$day-$id.md" \
  "$DIGEST_DIR/RESEARCH-BEAT-$day-$id.md" \
  "$LINES"
fi

python3 "$TELEMETRY" emit --kind research --model "$used" --wall-s "$wall" \
 --source research-beat --subject "$id:$state->$next" \
 --data "{\"unit\":\"$id\"}"
file_report progress "research line $id: $state -> $next -> $out_rel"
breadcrumb "$JOB_NAME" "research-done" "$id $state->$next via $used"
exit 0
