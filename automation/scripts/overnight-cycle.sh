#!/usr/bin/env bash
# overnight-cycle — one continuous-operation beat. Selector, first match
# wins: (a) an ACCEPTED plan's next unchecked step (docs/project/plans/),
# (b) the top queued lane via the kernel selector (`hngh select-course`
# over queue.md queued rows), (c) the day-tier research beat.
#
# Autonomy rule (also embedded in every beat prompt): governance
# (certificates + green gates) is the only barrier. hngh-automation
# commits are free; hngh changes land via certificate ceremony only with
# a green `make test`; hngh src/tests/Makefile/hngh.asd changes,
# provider/credential config, systemd unit lifecycle, and non-prune
# deletions are CRITICAL — never attempted; park with an alert and move
# on. The cycle never blocks on a human.
#
# Execution: omp-bridge --run-start gates a bounded delegated session
# (`omp -p --model zai/glm-5.3`, timeout-capped); the 5m supervision
# tick auto-replaces stalled runs. Fail-closed: every expected path
# exits 0.
#
# Plan authoring: when nothing is executable (no accepted plan pending,
# no queued lane) the cycle first drafts at most one normal-risk plan
# per day to digest/DRAFT-PLAN-<date>.md via the model chain. Drafts
# are PROPOSALS: status=drafted, never accepted or executed by the
# machine; the operator reviews and accepts (or rejects) each morning.
#
# usage: scripts/overnight-cycle.sh   (via hngh-overnight.timer)
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
KERNEL="${HNGH_HOME:-$HOME/Projects/etc/hngh}"
HNGH_BIN="${HNGH_CLI:-$KERNEL/scripts/hngh}"
BRIDGE="$KERNEL/scripts/omp-bridge"
STORE="$HOME/.hngh-automation/store/overnight-$(date +%Y%m%dT%H%M%S)-$$/"
TIMEOUT_S="${OVERNIGHT_TIMEOUT:-1800}"

. "$ROOT/lib/common.sh"
. "$ROOT/lib/breadcrumbs.sh"
. "$ROOT/lib/causes.sh"
. "$ROOT/lib/notify-email.sh"
. "$ROOT/lib/params.sh"
. "$ROOT/lib/model.sh"
. "$ROOT/lib/failfirst.sh"
. "$ROOT/lib/beat-blockers.sh"

# spend discipline: session cap chain — env OVERNIGHT_MAX_SESSIONS_DAY >
# Inventory row sessions-day-max (operator authorization 2026-09-07:
# 8+/day; row owned by the cadence-tuning lane) > legacy constant 4
# (pre-Inventory behavior).
MAX_SESSIONS_DAY="${OVERNIGHT_MAX_SESSIONS_DAY:-$(get_param sessions-day-max 4)}"

exec 9>"${OVERNIGHT_LOCK:-/tmp/hngh-overnight.lock}"
flock -n 9 || {
 breadcrumb "$JOB_NAME" "tick-skip" "overnight beat already live"
 exit 0
}

# --- crash-safety net (plan 19 step 7) ------------------------------------
# SIGTERM/SIGINT: stop spawning new sessions, record a dated breadcrumb
# with the in-flight session ids, exit non-zero cleanly. No new state
# files: the record lives in STATE.md (breadcrumbs) only. INFLIGHT is a
# /tmp scratch list, same class as RESULTS — never durable state.
STOP=0
INFLIGHT="$(mktemp "${TMPDIR:-/tmp}/hngh-overnight-inflight.XXXXXX")"
over_shutdown() { # sig
 local ids
 ids="$(tr '\n' ',' <"$INFLIGHT" 2>/dev/null | sed 's/,$//')"
 breadcrumb "$JOB_NAME" "shutdown-signal" "signal=$1 in_flight=$ids"
 exit 1
}
trap 'over_shutdown TERM' TERM
trap 'over_shutdown INT' INT

# cold-start idempotency: a shutdown-signal newer than the last
# overnight-done means the previous beat died on a signal (machine halt /
# operator stop) and its in-flight sessions may still be finishing
# orphaned. Report the unclean exit and skip this beat's session batch
# (one tick) instead of double-spawning the same work; this run still
# exits cleanly with overnight-done, which restores the ordering.
_unclean="$(awk -F'|' '/shutdown-signal/{ts=$1} /overnight-done/{ts=""} END{print ts}' \
 "$STATE_FILE" 2>/dev/null)"
if [ -n "${_unclean// /}" ]; then
 breadcrumb "$JOB_NAME" "cold-start-unclean" \
  "previous beat ended on a shutdown signal (ts=${_unclean// /}); skipping this beat's session batch to avoid double-spawning"
 STOP=1 # cold start skips the batch via the same flag the trap honors
fi
# Plan acceptance runs every tick, around the clock: the cycle is
# continuous operation (24/7), not overnight-only — the timer is the
# only clock. Per the kernel contract (docs/project/plans/README.md) a
# proposed normal-risk plan with runnable Verification steps is
# machine-accepted when both repos' gates are green; blocked or
# critical-class plans file alert rows instead of sitting silently.
accept_out="$(python3 "$ROOT/scripts/accept-plans.py" 2>/dev/null || true)"
while IFS= read -r line; do
 [ -n "$line" ] || continue
 breadcrumb "$JOB_NAME" "plan-${line%% *}" "$line"
done <<<"$accept_out"

# spend discipline: at most MAX_SESSIONS_DAY paid sessions per UTC day
# (hard ceiling; the fail-first development tier tunes concurrency
# WITHIN it, never the ceiling itself). slots_day is what this beat may
# still spend.
today_count="$(grep "overnight|" "$ROOT/logs/budget.md" 2>/dev/null | grep -c "$(date -u +%Y-%m-%d)" || true)"
if [ "${today_count:-0}" -ge "$MAX_SESSIONS_DAY" ]; then
 breadcrumb "$JOB_NAME" "budget-cap" "overnight sessions today >= $MAX_SESSIONS_DAY; research-only beat"
 bash "$ROOT/cadence/hour/33-research-beat.sh"
 exit 0
fi
slots_day=$((MAX_SESSIONS_DAY - ${today_count:-0}))

file_alert() { # identity text — the row is the contract; email is convenience
 alert_row "$1" 604800 "[hngh] $1" "$2"
}

# --- model selection (local-cost lever) -----------------------------------
# OVERNIGHT_MODEL (operator override) > best local model from a bench
# result fresher than 24h scoring 5/5 probes (the bench scores exactly 5
# coding/review probes; only a perfect local score is trusted for
# unattended delegated sessions — see jobs/model-bench.sh) > paid
# fallback. The source is logged with every session for spend
# attribution: roguelike budget loop — free local when it proves itself,
# paid only as fallback while the bench keeps re-validating.
select_model() { # -> "model|source" on stdout
 local dm
 declare -F model_demoted >/dev/null ||
  . "$ROOT/lib/model-demote.sh"
 # demotion guard (stall-recovery step 1): a model with 2 consecutive
 # bad-execution outcomes is skipped, whatever rung would have served it
 if [ -n "${OVERNIGHT_MODEL:-}" ] && [ "$(model_demoted "$OVERNIGHT_MODEL")" != 1 ]; then
  printf '%s|env\n' "$OVERNIGHT_MODEL"
  return 0
 fi
 # quota preference (stall-recovery step 9): a session-model-preference
 # cadence-params row names OMP-ADDRESSABLE quota models ahead of the
 # paid fallback; SESSION_MODEL_QUOTA_KEY_PRESENT (set from the leg-key
 # config: the kimi-model row or env) gates the leg -
 # no key config, no quota routing, fail-closed. Demotion applies to
 # quota models like any other rung. Boundary, found and documented:
 # kimi_chat is a curl chat helper, not an omp provider -
 # a delegated omp session cannot run "as kimi"; the row must name an
 # omp-addressable quota model id (e.g. an openrouter free/quota tier).
 if [ "$(get_param session-model-quota-keys 0)" = "1" ] &&
  [ -n "$(get_param session-model-preference "")" ]; then
  pref="$(get_param session-model-preference "")"
  local IFS=',' q
  for q in $pref; do
   q="$(printf '%s' "$q" | sed 's/^ *//; s/ *$//')"
   [ -n "$q" ] || continue
   if [ "$(model_demoted "$q")" = 1 ]; then
    continue
   fi
   # health gate before routing (quota-utilization lesson: never burn a
   # session on a dead credential) - one deduped alert per beat, cached
   if quota_leg_healthy "$q"; then
    printf '%s|quota\n' "$q"
    return 0
   fi
   $ROOT/scripts/report-queue --add alert \
    "quota leg $q failed health probe - skipped for this beat (no session wasted)" \
    --identity "quota-leg-unhealthy:$q" --window 86400 >/dev/null 2>&1 || true
  done
 fi
 local best
 best="$(
  python3 - "$ROOT/stats" <<'PY'
import glob, json, os, sys, time
best, top = "", 0
cutoff = time.time() - 86400
for f in glob.glob(os.path.join(sys.argv[1], "model-bench-*.jsonl")):
    try:
        if os.path.getmtime(f) < cutoff:
            continue
    except OSError:
        continue
    for ln in open(f, errors="replace"):
        try:
            r = json.loads(ln)
        except ValueError:
            continue
        if r.get("score", 0) >= 5 and r.get("score", 0) > top:
            best, top = r.get("model", ""), r["score"]
print(best)
PY
 )"
 [ -n "$best" ] && [ "$(model_demoted "$best")" != 1 ] && {
  printf '%s|local-bench\n' "$best"
  return 0
 }
 # bench leg demoted (or no bench): paid fallback, unless it too is demoted
 local paid="${OVERNIGHT_PAID_MODEL:-zai/glm-5.3}"
 if [ "$(model_demoted "$paid")" != 1 ]; then
  printf '%s|paid-fallback\n' "$paid"
  return 0
 fi
 # every rung demoted: last known non-demoted wins via env leg echo; the
 # session will fail closed through the bridge instead of burning budget
 [ -n "$OVERNIGHT_MODEL" ] && {
  printf '%s|env-all-demoted\n' "$OVERNIGHT_MODEL"
  return 0
 }
 printf '%s|paid-fallback\n' "$paid"
 printf '%s|paid-fallback\n' "${OVERNIGHT_PAID_MODEL:-zai/glm-5.3}"
}
# model routing (future, not implemented): when the KIMI quota
# keys go live (sibling lane), a session-model-preference Inventory row
# can route bounded delegated sessions to a quota model ahead of the
# paid fallback; until that lands, the paid fallback below stays
# load-bearing for overnight leads. Hook point: override SESSION_MODEL
# here from `get_param session-model-preference` when the row exists.
MODEL_SPEC="$(select_model)"
SESSION_MODEL="${MODEL_SPEC%%|*}"
SESSION_SOURCE="${MODEL_SPEC##*|}"
export SESSION_SOURCE
MODEL_SOURCE="${MODEL_SPEC##*|}"

is_critical() { # id+title -> 0 when the item must park for the operator
 printf '%s' "$1" | grep -qiE 'provider|credential|token|systemd|security|secret|delet'
}

# Standing operator grant (2026-09-01, continuous operation), appended to
# every delegated-session prompt: the cycle never blocks on a human, and
# neither may its delegate. Root fix for the 2026-09-02 stall (a session
# paused to ask push confirmation that was already granted).
STANDING_AUTH='## Standing authorizations (operator grant, 2026-09-01)

Push origin whenever a commit exists — push-on-demand is authorized;
Never pause for or ask push confirmation (on push failure: file an
alert row and continue). Never pause to ask the operator anything — a
question is either answerable from repo docs or becomes a parked alert
row. The email digest may run in report mode anytime.'

# Known-context block appended to every delegated-session prompt.
# Session-cost telemetry (2026-09-07) shows delegated sessions burning
# 2x-70x more input than output tokens re-deriving repo facts (up to
# 3.6M input tokens on a local session); these pointers bound discovery
# to one citation. Bounded, assembled from existing values only.
known_context() { # slug -> block on stdout
 cat <<EOK

## Known context (cite these; do not re-derive)

- Loop tunables live in hngh-automation/cadence-params.tsv (the
  Inventory): read the row, never guess a default.
- Plans feed: hngh docs/project/plans/*.plan.md; queue:
  hngh docs/project/queue.md; backlog: hngh docs/project/backlog.md.
- Crystallized research index: hngh docs/research/ — the budgets prior
  art is docs/research/2026-08-29-unattended-session-budgets.md.
- Ledgers: hngh-automation/STATE.md, agent-handoffs.md,
  hngh-automation/logs/budget.md (session-run rows).
- Verified numbers: hngh docs/project/STATE-OF-PROJECT.md between the
  torch:begin/torch:end sentinels — cite them, do not recount.
- A pre-digested repo map + frontier numbers is regenerated fresh at
  launch at hngh-automation/prompts/overnight/$1.context.txt — read
  that file first instead of re-grepping the repo.
EOK
}

park() { # slug reason
 file_alert "overnight:parked:$1" \
  "overnight parked '$1' for operator: $2 (critical class; cycle moved on)"
 printf 'operator-attention | %s | overnight|%s | parked: %s\n' \
  "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$1" "$2" >>"$ROOT/agent-handoffs.md"
}

pick_lane() { # top queued lane via the kernel selector -> "id|title"
 local q="$KERNEL/docs/project/queue.md"
 [ -f "$q" ] || return 1
 local specs=() id status title n=0 mounted inc out chosen
 while IFS=$'\t' read -r id status title _; do
  [ "$status" = "queued" ] || continue
  n=$((n + 1))
  mounted="false"
  [ -e "$KERNEL/docs/project/heartbeat/$id.slice" ] && mounted="true"
  inc="$(git -C "$KERNEL" log -1 --format=%cI -- \
   "docs/project/heartbeat/$id.slice" 2>/dev/null)"
  specs+=("$id:$mounted:${inc:-}:$n")
 done < <(awk -F'\t' 'NR>1 && $2=="queued"' "$q")
 [ "${#specs[@]}" -ge 1 ] || return 1
 # the kernel selector can stall on large candidate sets (18 lanes hung
 # 300s+); run-autonomous tolerates the same with a 60s cap — refusal
 # falls back to the research beat, never blocks the cycle
 # -k 5: SBCL ignores bare SIGTERM — without the kill-after, timeout hangs
 out="$(timeout -k 5 60 "$HNGH_BIN" select-course "${specs[@]}" 2>/dev/null)" || return 1
 chosen="$(printf '%s' "$out" | sed -n 's/^course \([^:]*\):.*/\1/p')"
 [ -n "$chosen" ] || return 1
 title="$(awk -F'\t' -v c="$chosen" '$1==c{print $3; exit}' "$q")"
 printf '%s|%s\n' "$chosen" "$title"
}

author_draft_plan() { # day -> drafts one normal-risk plan proposal
 local day="$1"
 local out="$ROOT/digest/DRAFT-PLAN-$day.md"
 local backlog alerts lines prompt response used draft
 # source 1: open backlog rows (heading + problem/outcome first lines)
 backlog="$(awk '
    /^## .*— queued/ {hdr=$0; prob=""; outc=""; inh=1; next}
    inh && prob=="" && /^- \*\*Problem:/ {prob=$0; next}
    inh && /^- \*\*Smallest useful outcome:/ {outc=$0; print hdr; print prob; print outc; inh=0}
    inh && /^## / {inh=0}' "$KERNEL/docs/project/backlog.md" 2>/dev/null | marked_cut 4000)"
 # source 2: deduped alert rows from the last 24h (dedup by id, newest wins)
 local cutoff
 cutoff="$(date -u -d '24 hours ago' +%Y-%m-%dT%H:%M)"
 alerts="$(awk -F'|' -v c="$cutoff" '
    $3 ~ /alert/ && $2 >= c {row[$4]=$0}
    END {for (k in row) print row[k]}' "$KERNEL/docs/project/reports.md" 2>/dev/null |
  cut -c1-220 | head -n 15)"
 # source 3: crystallized research lines (text only)
 lines="$(awk -F'\t' '$2=="crystallized"{print $4}' \
  "$ROOT/research-lines.tsv" 2>/dev/null | tail -n 8 | marked_cut 1500)"
 if [ -z "$backlog$alerts$lines" ]; then
  breadcrumb "$JOB_NAME" "plan-draft-skip" "no source material for a draft"
  return 0
 fi
 prompt="You are the hngh night-agent plan author. Draft ONE normal-risk plan the operator will review and accept (or reject) in the morning. Output ONLY the plan body: a '# <date> - <slug>' title line, a 1-2 sentence rationale naming the source row it serves, then a '## Steps' section with 3-6 unchecked steps, one per line, formatted '- [ ] <action> -- verify: <how completion is proven: a runnable command or observable state>'. Steps must be small, concrete, and land as plain commits in hngh-automation (gated by its make test). Normal-risk ONLY. FORBIDDEN, critical class, never include: provider or credential configuration, systemd unit lifecycle, hngh kernel src/tests/Makefile/hngh.asd changes, non-prune deletions, secrets or security posture.

Grounded constraints (binding):
1. Every 'verify:' command MUST exist in this repository. Allowed verifications ONLY: 'make test' (the repo's ONLY gate), 'bash -n <file>', 'bash <script>', 'python3 <script>' (stdlib only), 'node --check <file>', 'git log'/'git status'/'grep' checks. NEVER pytest, jsonschema, npm, curl-based test suites, or make targets other than the existing ones (test, smoke, sweep, adhoc, enable, disable, status).
2. Every path a step creates or edits MUST be an hngh-automation path that exists or is plainly creatable under jobs/, scripts/, cadence/, lib/, dashboard/, digest/ — never new top-level directories, never kernel-repo paths.
3. 3-6 steps, each independently verifiable.
4. Prefer the freshest signal: if a deduplicated alert row below names unresolved work, make it the plan's subject, implemented as a small awk/python3 step in jobs/ or in scripts/overnight-cycle.sh itself.

Sources for this draft:
--- open backlog rows (title / problem / smallest useful outcome) ---
$backlog
--- deduplicated alert rows (last 24h) ---
$alerts
--- crystallized research lines ---
$lines"
 response="$(printf '%s' "$prompt" | model_call 4096)"
 used="$(last_model_used)"
 if [ "$used" = "none:archive-only" ] || [ -z "$response" ]; then
  breadcrumb "$JOB_NAME" "plan-draft-fail" "model chain down ($used)"
  return 0
 fi
 if ! printf '%s' "$response" | grep -q '^- \[ \]'; then
  breadcrumb "$JOB_NAME" "plan-draft-fail" "model output had no checklist steps"
  file_alert "overnight:plan-draft-bad:$day" \
   "drafted plan output malformed (no '- [ ]' steps); discarded"
  return 0
 fi
 if printf '%s' "$response" | grep -qE 'pytest|jsonschema|npm '; then
  breadcrumb "$JOB_NAME" "plan-draft-fail" "draft invented absent tooling (pytest/jsonschema/npm)"
  file_alert "overnight:plan-draft-bad:$day" \
   "drafted plan referenced tooling absent from this repo (pytest/jsonschema/npm); discarded"
  return 0
 fi
 draft="<!-- plan: status=drafted risk=normal author=machine accepted=never -->
# DRAFT plan — $day (machine-night-agent)

**DRAFT — operator must review and accept; execution machinery will not
run this.** This proposal lives in hngh-automation/digest/ (outside the
kernel plans feed; it will not appear in dashboard plans.json until
promoted). To accept: copy this file into
hngh docs/project/plans/$day-draft.plan.md and flip the header to
status=accepted with accepted=<UTC ts>; the overnight cycle then
executes its steps as usual. To reject: delete this file.

$response"
 if [ "${DRY_RUN:-0}" = "1" ]; then
  printf '%s\n' "$draft"
  return 0
 fi
 printf '%s\n' "$draft" >"$out"
 breadcrumb "$JOB_NAME" "plan-drafted" "digest/DRAFT-PLAN-$day.md via $used"
 HNGH_REPORT_ROOT="$KERNEL" python3 "$KERNEL/scripts/report-queue" \
  --add progress \
  "plan draft ready for operator review: digest/DRAFT-PLAN-$day.md (status=drafted; never auto-executed)" \
  --identity "overnight:plan-draft:$day" --window 86400 >/dev/null 2>&1 || true
}

synthesize_dev_plan() { # adopted research -> one PROPOSED development plan
 # The grow side of the demand synthesizer (audit 2026-09-12): the
 # queue-dry precondition is gone — synthesized plans APPEND to the
 # rotation at lower selector priority instead of requiring an empty
 # queue. Capped to failfirst-dev-synth-daily syntheses per UTC day
 # (env DEV_SYNTH_DAILY overrides) and never runs with no session
 # budget left today (slots_day < 1). Pinned local model chain (cheap,
 # low-stakes: admission gates it anyway). The plan lands in the
 # kernel plans feed as status=proposed — accept-plans.py at the next
 # tick start runs the one admission path (runnable Verification, both
 # gates green) and accepts or blocks it; this beat never self-accepts.
 local day synth_max n=0 f adopted docs first slug prompt response used
 day="$(date -u +%F)"
 synth_max="${DEV_SYNTH_DAILY:-$(get_param failfirst-dev-synth-daily 1)}"
 case "$synth_max" in '' | *[!0-9]* | 0) synth_max=1 ;; esac
 # additional cap: never spend a synth draft without session budget
 if [ "${slots_day:-0}" -lt 1 ]; then
  breadcrumb "$JOB_NAME" "dev-synth-skip" "no session budget left today"
  return 0
 fi
 for f in "$ROOT"/digest/SYNTH-PLAN-"$day"*.md; do
  [ -e "$f" ] && n=$((n + 1))
 done
 if [ "$n" -ge "$synth_max" ]; then
  breadcrumb "$JOB_NAME" "dev-synth-skip" \
   "daily synthesis bound reached ($n/$synth_max)"
  return 0
 fi
 adopted="$(awk -F'\t' -v c="$(date -u -d '7 days ago' +%Y-%m-%d)" \
  '$2=="adopted" && $6>=c {print $1 "\t" $5}' \
  "$ROOT/research-dispositions.tsv" 2>/dev/null | tail -n 5)"
 if [ -z "$adopted" ]; then
  breadcrumb "$JOB_NAME" "dev-synth-skip" "no recently adopted research"
  return 0
 fi
 docs="" first=""
 while IFS=$'\t' read -r id path; do
  [ -n "$id" ] || continue
  [ -n "$first" ] || first="$id"
  [ -n "$path" ] && [ -f "$path" ] || continue
  docs+="--- adopted research line: $id ($path) ---
$(marked_cut 2000 "$path")

"
 done <<<"$adopted"
 slug="dev-$(printf '%s' "$first" | tr -cs 'a-zA-Z0-9._-' '-' |
  sed 's/^-*//; s/-$//' | cut -c1-40)"
 prompt="You are the hngh development-plan synthesizer. The research
machine has adopted the findings below.
Turn the ADOPTED findings into ONE normal-risk development plan for
hngh-automation. Output ONLY the plan body: a 1-2 sentence rationale
naming the research line it implements, then a '## Steps' section with
3-6 unchecked steps, one per line, each followed on the next line by an
indented 'Verification: <how completion is proven: a runnable command or
observable state>' line (that exact capitalization — machine admission
parses it). Format:

## Steps

- [ ] <action>
  Verification: <runnable command or observable state>

Steps must be small, concrete, and land as plain commits in
hngh-automation (gated by its make test). Normal-risk ONLY. FORBIDDEN,
critical class, never include: provider or credential configuration,
systemd unit lifecycle, hngh kernel src/tests/Makefile/hngh.asd
changes, non-prune deletions, secrets or security posture.

Grounded constraints (binding):
1. Every 'verify:' command MUST exist in this repository. Allowed
   verifications ONLY: 'make test', 'bash -n <file>', 'bash <script>',
   'python3 <script>' (stdlib only), 'node --check <file>', git/grep
   checks. NEVER pytest, jsonschema, npm, or other make targets.
2. Every path a step creates or edits MUST be an hngh-automation path
   under jobs/, scripts/, cadence/, lib/, tests/, dashboard/, digest/.
3. 3-6 steps, each independently verifiable.

$docs"
 response="$(printf '%s' "$prompt" | MODEL_PIN=local model_call 4096)"
 used="$(last_model_used)"
 if [ "$used" = "none:archive-only" ] || [ -z "$response" ]; then
  breadcrumb "$JOB_NAME" "dev-synth-fail" "model chain down ($used)"
  return 0
 fi
 if ! printf '%s' "$response" | grep -q '^- \[ \]' ||
  ! printf '%s' "$response" | grep -q 'Verification:'; then
  breadcrumb "$JOB_NAME" "dev-synth-fail" \
   "synthesized plan malformed (no '- [ ]'/'Verification:' steps); discarded"
  file_alert "overnight:dev-synth-bad:$day" \
   "synthesized development plan malformed (no verifiable steps); discarded"
  return 0
 fi
 if printf '%s' "$response" | grep -qE 'pytest|jsonschema|npm '; then
  breadcrumb "$JOB_NAME" "dev-synth-fail" \
   "synthesized plan invented absent tooling (pytest/jsonschema/npm)"
  file_alert "overnight:dev-synth-bad:$day" \
   "synthesized plan referenced tooling absent from this repo; discarded"
  return 0
 fi
 local body="<!-- plan: status=proposed risk=normal accepted=- -->
# $day - $slug (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

$response"
 if [ "${DRY_RUN:-0}" = "1" ]; then
  printf '%s\n' "$body"
  return 0
 fi
 printf '%s\n' "$body" >"$ROOT/digest/SYNTH-PLAN-$day-$slug.md"
 printf '%s\n' "$body" >"$KERNEL/docs/project/plans/$day-$slug.plan.md"
 breadcrumb "$JOB_NAME" "dev-synth-proposed" \
  "docs/project/plans/$day-$slug.plan.md from $first (admission on next tick)"
}

# grow side (audit 2026-09-12): adopted research becomes a proposed
# development plan (bounded, admitted on the next tick) — appended to
# the rotation, no queue-dry precondition
synthesize_dev_plan

# --- selector (a): accepted plan's next unchecked step -------------------
# (held plans are non-supply by construction: only status=accepted matches)
# ALL open accepted plans are collected: the fail-first development tier
# runs up to `concurrency` of them as parallel sessions in one beat.
# Steps WITHIN a plan stay sequential (step 2 may need step 1).
# Ordering (2026-09-09 schedule-optimization step 2): accepted plans
# carrying `priority=high` in the front-matter comment sort ahead of the
# rest; ties and absence fall back to filename order (the glob).
# Ordering (audit 2026-09-12): synth-origin plans ("synthesized from
# adopted research") sort LAST — slot 0 goes to an operator/accepted
# plan whenever one is pending; synth plans only run in leftover slots.
plan_slugs=() plan_files=() plan_steps=() prio_hi=() prio_hif=() prio_hist=()
synth_slugs=() synth_files=() synth_steps=()
blocker_tick "$(get_param blocker-park-cooldown-hours 24)"
for f in "$KERNEL"/docs/project/plans/*.plan.md; do
 [ -f "$f" ] || continue
 grep -q "status=accepted" "$f" 2>/dev/null || continue
 step="$(grep -m1 '^\- \[ \]' "$f" | sed 's/^- \[ \]//; s/^ *//; s/ *$//')"
 [ -n "$step" ] || continue
 pslug="$(basename "$f" .plan.md)"
 # parked blocker: the remediation loop already handed this plan to the
 # operator (escalate threshold) — leave it out of the rotation until
 # the ledger row is cleared
 [ "$(blocker_row_for "$pslug" | cut -f6)" = "parked" ] && continue
 # synth-origin plans always sort last (audit 2026-09-12)
 if grep -q 'synthesized from adopted research' "$f" 2>/dev/null; then
  synth_slugs+=("$pslug")
  synth_files+=("$f")
  synth_steps+=("$step")
 # priority=high front-matter flag: bucket 0 sorts ahead of bucket 1
 # (append to the high bucket in glob order: ties keep filename order)
 elif head -n1 "$f" | grep -q 'priority=high'; then
  prio_hi+=("$pslug")
  prio_hif+=("$f")
  prio_hist+=("$step")
 else
  plan_slugs+=("$pslug")
  plan_files+=("$f")
  plan_steps+=("$step")
 fi
done
plan_slugs=("${prio_hi[@]}" "${plan_slugs[@]}" "${synth_slugs[@]}")
plan_files=("${prio_hif[@]}" "${plan_files[@]}" "${synth_files[@]}")
plan_steps=("${prio_hist[@]}" "${plan_steps[@]}" "${synth_steps[@]}")

plan_slug=""
plan_file=""
plan_step=""
if [ "${#plan_slugs[@]}" -ge 1 ]; then
 plan_slug="${plan_slugs[0]}"
 plan_file="${plan_files[0]}"
 plan_step="${plan_steps[0]}"
fi

build_plan_prompt() { # slug plan_file step -> prompt path on stdout
 local slug="$1" pfile="$2" step="$3"
 mkdir -p "$ROOT/prompts/overnight"
 local wake unread
 wake="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
 unread="$(python3 "$KERNEL/scripts/report-queue" --json 2>/dev/null |
  python3 -c 'import json,sys; print(json.load(sys.stdin).get("unread", 0))' 2>/dev/null || echo '?')"
 {
  printf 'WAKE CONTEXT: %s UTC. You are waking mid-stream — read the plan\nand ledger state before acting. Unread ledger alerts: %s.\n\n' \
   "$wake" "$unread"
  printf 'PLAN-FILE RULE: never overwrite an existing plan file. New plans\nget new slugs (docs/project/plans/<date>-<slug>.plan.md); check the\ndirectory for the filename before writing.\n\n'
  cat "$pfile"
  cat <<'RULE'

## Autonomy rule (binding for this session)

Governance — certificates and green gates — is the only barrier. Do not
wait for or ask for human approval. hngh-automation commits are free.
hngh changes land via the certificate ceremony ONLY with a green
`make test`. hngh kernel src/, tests/, Makefile, and hngh.asd changes
are FORBIDDEN this session — if a step requires one, stop that step,
note it in the plan file, and move to the next step. Never touch
provider or credential configuration, systemd unit state, tracked
deletions outside the 48h prune, or secrets. If blocked, write what
blocked you into the plan file and move on; other work always exists.
RULE
  known_context "$slug"
  printf '\n%s\n' "$STANDING_AUTH"
 } >"$ROOT/prompts/overnight/$slug.md"
 printf '%s\n' "$ROOT/prompts/overnight/$slug.md"
}

# --- forethought: dream pass (design docs/research/2026-09-10-
# forethought-and-decomposition.md s2/s3/s5): a bounded read-only session
# simulates one plan step before an executor touches it. One cadence row
# (forethought-depth), one classifier, one conditional launch — no
# framework, no new state files, no ledger; advisory-only, fail-open.
FORETHOUGHT_DEPTH="${FORETHOUGHT_DEPTH:-$(get_param forethought-depth 1)}"

is_risky_step() { # step [sibling_steps...] -> 0 = dream-worthy at depth 1
 local step="$1"
 shift
 # kernel-touching: the autonomy rule's critical path set
 printf '%s\n' "$step" | grep -qiE 'src/|tests/|Makefile|hngh\.asd' && return 0
 # unproven-surface markers: a capability not yet proven in-repo
 printf '%s\n' "$step" | grep -qiE 'unverified|unproven|extension|hook|session_start|MCP' && return 0
 # file-sharing with a sibling step: a slash-path both mention (the
 # inventory's file-conflict check, restated as a grep)
 local mine sibling
 mine="$(printf '%s\n' "$step" | grep -oE '[A-Za-z0-9_.-]+/[A-Za-z0-9_./-]+' | sort -u)"
 [ -n "$mine" ] || return 1
 for sibling in "$@"; do
  printf '%s\n' "$sibling" | grep -oE '[A-Za-z0-9_.-]+/[A-Za-z0-9_./-]+' | sort -u |
   grep -qxFf <(printf '%s\n' "$mine") && return 0
 done
 return 1
}

build_dream_prompt() { # slug plan_file step dream_out -> prompt path on stdout
 local slug="$1" pfile="$2" step="$3" dream_out="$4"
 local bline
 mkdir -p "$ROOT/prompts/overnight"
 {
  printf 'WAKE CONTEXT: %s UTC. You are a DREAM pass (forethought design:\ndocs/research/2026-09-10-forethought-and-decomposition.md section 2):\na bounded READ-ONLY simulation of one plan step before an executor\ntouches it. Advisory-only: never mutate the repo, ledgers, or plan\nstate — the ONLY write this session may make is the dream brief named\nbelow. Read the plan and the repo before answering.\n\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf 'Plan step to simulate (plan %s): %s\n\n' "$slug" "$step"
  cat "$pfile"
  cat <<'RULE'

## Dream brief (binding for this session)

Emit the five dream fields in handoff-brief flat field discipline (one
`field: value` line per field, single-line values, `not established`
never guessed):
requirements: facts that must hold before execution
failure-modes: anticipated problems, each tagged with a bestiary class
(bad-execution / missing-knowledge / missing-design / missing-authority / obsolete)
surfaces: required files and surfaces to touch or read
split: proposed subtask decomposition (or `single-session`)
sanity-checks: assertions the executor verifies FIRST, before its first edit

Field schema: docs/research/2026-09-10-forethought-and-decomposition.md
section 2 — cite it, do not restate it. Write the finished brief to the
dream brief path below, then stop. If you cannot establish a field,
write `not established` — never guess.
RULE
  # dream-informed re-attempt (as-above-so-below): a blocker row makes the
  # dream state the counter-lesson explicitly
  bline="$(blocker_prompt_line "$slug")"
  [ -n "$bline" ] && printf '\n%s\n' "$bline"
  printf '\nDream brief path (your single permitted write): %s\n' "$dream_out"
 } >"$ROOT/prompts/overnight/$slug.dream-prompt.md"
 printf '%s\n' "$ROOT/prompts/overnight/$slug.dream-prompt.md"
}

if [ -n "$plan_file" ]; then
 slug="$plan_slug"
 objective="Execute the next step of plan $slug: $plan_step"
 prompt_file="$(build_plan_prompt "$slug" "$plan_file" "$plan_step")"
elif lane_row="$(pick_lane)"; then
 slug="$(printf '%s' "$lane_row" | cut -d'|' -f1)"
 lane_title="$(printf '%s' "$lane_row" | cut -d'|' -f2-)"
 mkdir -p "$ROOT/prompts/overnight"
 wake="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
 if is_critical "$slug $lane_title"; then
  park "$slug" "queued lane is critical-class: $lane_title"
  breadcrumb "$JOB_NAME" "overnight-skip" "lane $slug parked (critical)"
  exit 0
 fi
 objective="Work the queued lane '$slug' ($lane_title): advance it one
verified increment in hngh-automation — small, tested, committed."
 prompt_file="$ROOT/prompts/overnight/$(date +%Y%m%dT%H%M%S)-$slug.md"
 {
  printf 'WAKE CONTEXT: %s UTC. You are waking mid-stream — check the\nplan ledger, queue state, and unread alerts before acting.\n\n' "$wake"
  printf 'PLAN-FILE RULE: never overwrite an existing plan file. New plans\nget new slugs (docs/project/plans/<date>-<slug>.plan.md); check the\ndirectory for the filename before writing.\n\n'
  printf 'Objective: %s\n\n' "$objective"
  cat <<'RULE'

## Autonomy rule (binding for this session)

Governance — certificates and green gates — is the only barrier. Do not
wait for or ask for human approval. hngh-automation commits are free
(small, tested, `fix:`/`feat:` lowercase subjects). hngh changes land
via the certificate ceremony ONLY with a green `make test`. hngh kernel
src/, tests/, Makefile, and hngh.asd changes are FORBIDDEN this session
— park them instead. Never touch provider or credential configuration,
systemd unit state, tracked deletions outside the 48h prune, or
secrets. If blocked, say so in your final message and stop; other work
always exists.
RULE
  known_context "$slug"
  bl="$(blocker_prompt_line "$slug")"
  [ -n "$bl" ] && printf '\n%s\n' "$bl"
  printf '\n%s\n' "$STANDING_AUTH"
 } >"$prompt_file"
 if [ ! -s "$prompt_file" ]; then
  file_alert "overnight:prompt-fail:$slug" "beat prompt write failed — no session launched"
  exit 0
 fi
else
 # plan-authoring leg: with no accepted plan pending (and no lane to
 # work), draft at most one normal-risk proposal per day before the
 # research filler. Drafts are proposals — never auto-accepted, never
 # auto-executed; the operator accepts each morning.
 draft_day="$(date -u +%F)"
 [ -f "$ROOT/digest/DRAFT-PLAN-$draft_day.md" ] ||
  author_draft_plan "$draft_day"
 breadcrumb "$JOB_NAME" "overnight-research" "no plan/lane; falling to research beat"
 bash "$ROOT/cadence/hour/33-research-beat.sh"
 exit 0
fi

# --- fail-first development gate + batch size -----------------------------
# development tunes CONCURRENCY within the hard sessions-day-max ceiling
# (the ceiling itself never moves): full=3 / standard=2 / cautious=1
# concurrent sessions per beat (Inventory rows failfirst-dev-concurrent-*).
# THROTTLE (paced below the observed ceiling) skips the launch entirely —
# the plan stays queued for the next beat. Outcomes feed the development
# state machine: ok = completed with output, degraded = dead or cancelled
# with no output, failed = launch-plane crash (bridge refusal).
ff_dev_sf="$(failfirst_state_file development)"
ff_verdict="$(failfirst_gate development "$ff_dev_sf")"
if [ "$ff_verdict" != "GO" ]; then
 breadcrumb "$JOB_NAME" "failfirst-dev" \
  "$ff_verdict - development paced below its observed ceiling"
 exit 0
fi
failfirst_load development "$ff_dev_sf"
ff_speed="$FF_SPEED"
slots="$(failfirst_concurrency development "$ff_dev_sf")"
[ "$slots" -gt "$slots_day" ] && slots="$slots_day"

# --- gated delegated sessions (up to `slots` per beat) --------------------
# the launcher lives in lib/launch-session.sh (shared with the watchdog
# respawn executor — one launch path, no second implementation).
cd "$ROOT" || exit 0
. "$ROOT/lib/launch-session.sh"

# batch: slot 0 is the selected plan-or-lane session; remaining slots are
# additional accepted plans (steps within one plan stay sequential).
RESULTS="$(mktemp "${TMPDIR:-/tmp}/hngh-overnight-results.XXXXXX")"
BLOCKER_EVENTS="$(mktemp "${TMPDIR:-/tmp}/hngh-overnight-blockers.XXXXXX")"
run_one() { # slug objective prompt_file plan_file [dream_step]
 local slug="$1" objective="$2" prompt_file="$3" pfile="$4" dream_step="$5"
 local start rc run_id log disposition cause result
 local dream_informed=0
 # crash-safety net: never spawn past a stop signal or a cold-start skip
 [ "$STOP" -eq 1 ] && return 0
 printf '%s\n' "$slug" >>"$INFLIGHT" # run id exists only post-completion
 start="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
 # forethought dream pass: one bounded read-only session before the
 # executor; fail-open — a dream that dies files a breadcrumb and the
 # step proceeds undreamed (a dream may delay, never veto). The dream
 # runs inside this slot synchronously and adds one budget row via
 # launch_session (counted in the sessions-day ceiling).
 if [ -n "$dream_step" ]; then
  local dream_out="$ROOT/prompts/overnight/$slug.dream.md"
  rm -f "$dream_out"
  local dprompt
  dprompt="$(build_dream_prompt "$slug" "$pfile" "$dream_step" "$dream_out")"
  local save_ts="$TIMEOUT_S"
  TIMEOUT_S="${OVERNIGHT_DREAM_TIMEOUT:-600}" # bounded dream, never 2x the beat
  launch_session "$slug-dream" \
   "DREAM pass: read-only simulation of plan $slug step before execution" \
   "$dprompt" dream
  TIMEOUT_S="$save_ts"
  if [ "$LAUNCH_RC" -ne 0 ] || [ ! -s "$dream_out" ]; then
   breadcrumb "$JOB_NAME" "forethought-dream-skip" \
    "$slug dream dead/empty (rc=$LAUNCH_RC) — step proceeds undreamed"
  else
   {
    printf '\n## Dream sanity-checks (verify these assertions FIRST, before your first edit)\n\n'
    cat "$dream_out"
   } >>"$prompt_file"
   dream_informed=1
  fi
 fi
 launch_session "$slug" "$objective" "$prompt_file"
 rc="$LAUNCH_RC"
 run_id="$LAUNCH_RUN_ID"
 log="$LAUNCH_LOG"
 disposition="$LAUNCH_DISPOSITION"
 cause="$LAUNCH_CAUSE"
 if [ "$rc" -eq 75 ]; then
  file_alert "overnight:bridge-refused:$slug" \
   "overnight beat $slug could not open a bridge run: $LAUNCH_BRIDGE_MSG"
  printf 'failed\n' >>"$RESULTS" # launch-plane crash, not saturation
  printf '%s\tfailed\tunknown\t%s\n' "$slug" "$dream_informed" >>"$BLOCKER_EVENTS"
  return 0
 fi
 # fail-first outcome for the development state machine: ok = the
 # session completed with deliverable output on its log; degraded =
 # dead (rc!=0, timeout kill) or cancelled with no output
 if [ "$rc" -eq 0 ] && [ -s "$ROOT/$log" ]; then result=ok; else result=degraded; fi
 printf '%s\n' "$result" >>"$RESULTS"
 printf '%s\t%s\t%s\t%s\n' "$slug" "$result" "$cause" "$dream_informed" \
  >>"$BLOCKER_EVENTS"

 # plan lifecycle: an accepted plan whose steps are all checked flips to
 # executed and files its completion row
 if [ -n "$pfile" ] && ! grep -q '^- \[ \]' "$pfile"; then
  sed -i 's/status=accepted/status=executed/' "$pfile"
  HNGH_REPORT_ROOT="$KERNEL" python3 "$KERNEL/scripts/report-queue" \
   --add progress "plan $slug executed (all steps checked)" \
   >/dev/null 2>&1 || true
 fi

 # --- post-session audit: critical paths are alerts, never auto-reverted
 local repo hits repo_display
 for repo in "$ROOT" "$KERNEL"; do
  hits="$(git -C "$repo" log --since="$start" --name-only --format= -- \
   config.env 'systemd/*' '*.token' 'src/*' 'tests/*' 'Makefile' 'hngh.asd' 2>/dev/null |
   sort -u | tr '\n' ' ')"
  # public-content gate: report rows must not carry absolute home paths
  repo_display="~/${repo#"$HOME"/}"
  [ -n "${hits// /}" ] && file_alert "overnight:critical-touch:$slug" \
   "session touched critical paths in $repo_display: $hits"
 done

 printf 'overnight-lead | %s | %s|%s | rc=%d %s log=%s model=%s(%s) cause=%s\n' \
  "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$slug" "$run_id" "$rc" "$disposition" "$log" \
  "$SESSION_MODEL" "$MODEL_SOURCE" "$cause" \
  >>"$ROOT/agent-handoffs.md"

 # failure -> research demand: a dead session classified as a knowledge
 # or design gap seeds the research beat's subject queue so the next
 # research work is demand-driven, not static
 case "$disposition:$cause" in
 dead:missing-knowledge)
  append_research_subject "$slug" "What knowledge was missing for $slug?"
  ;;
 dead:missing-design)
  append_research_subject "$slug" "What design was missing for $slug?"
  ;;
 esac

 python3 "$ROOT/jobs/telemetry.py" emit --kind overnight --source overnight \
  --subject "$slug" --data "{\"unit\":\"$run_id\"}" >/dev/null 2>&1 || true
 return 0
}

s_slug=("$slug") s_obj=("$objective") s_prompt=("$prompt_file") s_plan=("$plan_file")
dream=""
if [ "$FORETHOUGHT_DEPTH" -ge 2 ]; then
 dream="$plan_step"
elif [ "$FORETHOUGHT_DEPTH" -eq 1 ] && [ -n "$plan_step" ] &&
 { is_risky_step "$plan_step" "${plan_steps[@]:1}" ||
  [ -n "$(blocker_row_for "$slug")" ]; }; then
 dream="$plan_step"
fi
s_dream=("$dream")
i=1
while [ "$i" -lt "$slots" ] && [ "$i" -lt "${#plan_slugs[@]}" ]; do
 s_slug+=("${plan_slugs[$i]}")
 s_obj+=("Execute the next step of plan ${plan_slugs[$i]}: ${plan_steps[$i]}")
 s_prompt+=("$(build_plan_prompt "${plan_slugs[$i]}" "${plan_files[$i]}" "${plan_steps[$i]}")")
 s_plan+=("${plan_files[$i]}")
 dream=""
 if [ "$FORETHOUGHT_DEPTH" -ge 2 ]; then
  dream="${plan_steps[$i]}"
 elif [ "$FORETHOUGHT_DEPTH" -eq 1 ] &&
  { is_risky_step "${plan_steps[$i]}" "${plan_steps[@]:0:$i}" "${plan_steps[@]:$((i + 1))}" ||
   [ -n "$(blocker_row_for "${plan_slugs[$i]}")" ]; }; then
  dream="${plan_steps[$i]}"
 fi
 s_dream+=("$dream")
 i=$((i + 1))
done

if [ "${#s_slug[@]}" -eq 1 ]; then
 run_one "${s_slug[0]}" "${s_obj[0]}" "${s_prompt[0]}" "${s_plan[0]}" "${s_dream[0]}"
else
 for i in "${!s_slug[@]}"; do
  run_one "${s_slug[$i]}" "${s_obj[$i]}" "${s_prompt[$i]}" "${s_plan[$i]}" "${s_dream[$i]}" &
 done
 wait
fi

# outcomes feed the development state machine sequentially (shared state
# file — never recorded from the concurrent subshells)
while IFS= read -r result; do
 [ -n "$result" ] || continue
 record_outcome development "$ff_speed" "$result" "$ff_dev_sf"
done <"$RESULTS"
# blocker-ledger remediation loop (as-above-so-below, 2026-09-11): the
# orchestrator gets the run-domain lifecycle at its own level. Success
# clears the row; a failure records/bumps same-cause attempts; attempts
# >= blocker-escalate-n parks the plan for the operator (bounded, never
# infinite). Sequential — never written from the concurrent subshells.
while IFS=$'\t' read -r b_slug b_outcome b_cause b_dream; do
 [ -n "$b_slug" ] || continue
 if [ "$b_outcome" = ok ]; then
  blocker_clear "$b_slug"
  continue
 fi
 attempts="$(blocker_record "$b_slug" "$b_cause")"
 if [ "${attempts:-0}" -ge "$(get_param blocker-escalate-n 2)" ] &&
  [ "$(blocker_row_for "$b_slug" | cut -f6)" != parked ]; then
  blocker_park "$b_slug"
  file_alert "beat-parked:$b_slug" \
   "orchestrator blocker parked '$b_slug': $attempts consecutive deaths with cause class '$b_cause' (blocker-escalate-n reached). Fix or remove the state/beat-blockers.tsv row to re-admit."
  breadcrumb "$JOB_NAME" "blocker-parked" \
   "$b_slug cause=$b_cause attempts=$attempts"
 fi
done <"$BLOCKER_EVENTS"
rm -f "$BLOCKER_EVENTS"
results_summary="$(tr '\n' ',' <"$RESULTS" | sed 's/,$//')"
rm -f "$RESULTS"

# ceremony-store hygiene: a session's /tmp/hngh-cer-* stores are closed-run
# leftovers once the beat ends; sweep them so oversight does not spam
# stale-store alerts forever (35 min = well past any live ceremony).
find /tmp -maxdepth 1 -name 'hngh-cer-*' -mmin +35 -exec rm -rf {} + 2>/dev/null || true
python3 "$ROOT/jobs/session-cost.py" >>/dev/null 2>&1 || true

breadcrumb "$JOB_NAME" "overnight-done" \
 "sessions=${#s_slug[@]} concurrency=$slots speed=$ff_speed results=$results_summary model=$SESSION_MODEL($MODEL_SOURCE)"
exit 0
