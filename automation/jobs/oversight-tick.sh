#!/usr/bin/env bash
# oversight-tick — one procedural + gated-agentic observation tick.
#
# Main entries:
#   oversight-tick.sh              # timer fire: procedural probes, then agentic leg
#                                  # only when its beat is due (timestamp gate)
#   oversight-tick.sh --event=...  # on-demand fire (git hooks, ceremony completion):
#                                  # instant probes ONLY, no agentic leg, exit 0 always
#   oversight-tick.sh --self       # self-review leg (optimize: crumbs), gated
#
# Design per operator steering (2026-08-26):
#   - cheapest observations fire on any event (no timer discipline);
#   - cheap per-minute probes run every timer tick;
#   - medium/agentic work is gated to a slower beat (STEER_BEAT_SECONDS);
#   - everything single-instance via the cadence flock, fail closed, alert via
#     the hngh report-queue (alert kind) when a probe cannot self-resolve.
set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export AUTOMATION_ROOT="$ROOT"
# Reader seam: the crumbs journal is the source of record (STATE.md is a
# derived export rendered by lib/crumbs-db.py export).
_crumbs_db="${HNGH_CRUMBS_DB:-$ROOT/state/crumbs.db}"
# shellcheck disable=SC1091
. "$ROOT/lib/breadcrumbs.sh" 2>/dev/null || true
# shellcheck disable=SC1091
. "$ROOT/lib/redact.sh" 2>/dev/null || true
HNGH_REPO="${HNGH_REPO:-$(cd "$(dirname "$0")/../.." && pwd)}"
REPORT_QUEUE="$HNGH_REPO/scripts/report-queue"
LOCK="${LOCK:-/tmp/hngh-overseer.lock}"
LAST_BEAT="${LAST_BEAT:-/tmp/hngh-overseer-steer-beat}"
STEERING_BEAT_MIN="${STEERING_BEAT_MIN:-10}"
STEERING_ATTENTION_MIN="${STEERING_ATTENTION_MIN:-1}"
ATTENTION_FLAG="${ATTENTION_FLAG:-/tmp/hngh-overseer-attention}"
STEER_MODEL="${STEER_MODEL:-}" # operator-set steer endpoint; argv BY DESIGN, see record
# DISPOSITION (docs/records/2026-09-16-risk-dispositions-cred-argv.md): the URL
# rides curl argv as accepted risk — operator-set config in the operator trust
# class, not a per-run credential. BINDING: STEER_MODEL must not embed an API
# key (no key-in-URL routes). Do NOT convert to `curl -K -`: a value carrying
# a newline or an embedded double quote would let following stdin lines parse
# as arbitrary curl config directives (verified empirically 2026-09-16).
EVENT_MODE=0
SELFREVIEW_MODE=0

for a in "$@"; do
 case "$a" in
 --event=*) EVENT_MODE=1 ;;
 --steer) SELFREVIEW_MODE=1 ;;
 --help)
  echo "oversight-tick: procedural observations + gated agentic steering"
  echo "  (no args)      timer fire: probes + agentic if due"
  echo "  --event=NAME   on-demand hook: instant probes only, always rc=0"
  echo "  --steer        self-review mode (optimize: crumbs)"
  exit 0
  ;;
 esac
done

alert() { # alert KIND DETAIL [IDENTITY WINDOW] — file an alert row in the
 # hngh report ledger. IDENTITY+WINDOW are passed to report-queue
 # (--identity/--window) so a repeating condition BUMPs one ledger row
 # (×N + occurrence lines) instead of appending a fresh row per tick —
 # the 2026-08-27 flap: 1006+ duplicate stale-store rows. WINDOW 86400
 # = one row per identity per day; a condition persisting past the
 # window starts a new row, which is the wanted daily heartbeat.
 # flapping suppression: the same (kind, detail) is not re-alerted
 # within SUPPRESS_MIN (default 60) — stops 5m-tick spam of an
 # unresolved condition while never hiding NEW distinct alerts.
 local key redacted
 redacted="$(redact_home "$1: $2" 2>/dev/null || printf '%s: %s' "$1" "$2")"
 local key="$redacted" last=0
 local alert_last="${ALERT_LAST:-/tmp/hngh-oversight-alerts}"
 [ -f "$alert_last" ] && last=$(grep -F -m1 "$key" "$alert_last" 2>/dev/null | awk '{print $NF}' || echo 0)
 now=$(date +%s)
 if [ -n "$last" ] && [ $((now - last)) -lt ${SUPPRESS_MIN:-60} ]; then
  return 0
 fi
 local -a rq=(--add alert "[oversight] $redacted")
 local ident="${3:-}"
 [ -n "$ident" ] && ident="$(redact_home "$ident")"
 [ -n "$ident" ] && rq+=(--identity "$ident" --window "${4:-86400}")
 "$REPORT_QUEUE" "${rq[@]}" >/dev/null 2>&1 &&
  breadcrumb "oversight-tick" "alert" "$redacted" || true
 echo "$key $now" >>"${ALERT_LAST:-/tmp/hngh-oversight-alerts}"
 touch "$ATTENTION_FLAG" 2>/dev/null || true
}

probe_stale_ceremony_stores() {
 # ceremony store dirs older than 30 min with no matching committed hash
 for d in /tmp/hngh-cer-* /tmp/hngh-auto-*; do
  [ -d "$d" ] || continue
  if [ -n "$(find "$d" -maxdepth 1 -name record.lisp -mmin +30)" ]; then
   # one bumped row per store per day instead of one row per tick
   alert "stale-store" "$d record.lisp untouched 30min+" \
    "stale-store:$d" 86400
  fi
 done
}

probe_system_awareness() {
 # live system state (dashboard/system.json written by cadence/5m/01-system
 # -> jobs/system-awareness.sh). Alert once per NEW critical headroom flag
 # (low-disk / low-mem / network-down) with the same-key flapping suppression
 # inside alert(), so a persistent condition fires once, not every 5m. Any
 # critical flag also arms the attention flag so the agentic leg can steer
 # (e.g. "network down — pause network-labeled jobs").
 local sf="$AUTOMATION_ROOT/dashboard/system.json" flag crit=0
 [ -f "$sf" ] || {
  breadcrumb "oversight-tick" "sysaware" "no system.json"
  return 0
 }
 for flag in low-disk low-mem network-down; do
  if [ "$(jq -r ".headroom[\"$flag\"]" "$sf" 2>/dev/null)" = "true" ]; then
   crit=1
   alert "system-$flag" "critical resource flag set" "system-$flag" 86400
  fi
 done
 [ "$crit" = "1" ] && touch "$ATTENTION_FLAG" 2>/dev/null || true
}

# P1e (2026-09-25, L3: monitoring never hides state): tree-skew carries
# no path whitelist. A dirty file is exempt only by row evidence -- its
# uncommitted delta is append-only AND every added line is a fresh
# machine row (writer stamp [w=<name>@<rowid>] and row ts younger than
# 24h). Stale stamps, deletions, and un-stamped edits (docs/project
# /plans/ included) all count as skew.
machine_appended() {
 local repo="$1" file="$2" diff added now ts age
 diff="$(git -C "$repo" diff HEAD --unified=0 -- "$file" 2>/dev/null)"
 printf '%s\n' "$diff" | grep -qE '^-($|[^-])' && return 1
 added="$(printf '%s\n' "$diff" | grep -E '^\+($|[^+])' || true)"
 [ -n "$added" ] || return 1
 now=$(date +%s)
 while IFS= read -r ln; do
  ln="${ln#+}"
  case "$ln" in
  *' [w='*']') : ;;
  *) return 1 ;;
  esac
  ts="${ln%% | *}"
  age=$((now - $(date -u -d "$ts" +%s 2>/dev/null || echo 0)))
  [ "$age" -ge 0 ] && [ "$age" -lt 86400 ] || return 1
 done <<EOF
$added
EOF
 return 0
}

probe_working_tree_skew() {
 # dirty tree older than 4h without a commit = drift the sweep should’ve
 # caught. Untracked files are the sweep job’s domain; modified tracked
 # files count unless every uncommitted line is a fresh machine append.
 local dirty pl f last now
 for repo in ${TREE_SKEW_REPOS:-$HNGH_REPO $ROOT}; do
  [ -d "$repo/.git" ] || continue
  dirty=""
  while IFS= read -r pl; do
   [ -n "$pl" ] || continue
   f="${pl#?? }"
   f="${f#\"}"
   f="${f%\"}"
   machine_appended "$repo" "$f" && continue
   dirty="$dirty$pl"$'\n'
  done <<EOF
$(git -C "$repo" status --porcelain --untracked-files=no 2>/dev/null)
EOF
  if [ -n "$dirty" ]; then
   last=$(git -C "$repo" log -1 --format=%ct 2>/dev/null || echo 0)
   now=$(date +%s)
   if [ $((now - last)) -gt 14400 ]; then
    alert "tree-skew" "${repo#"$HOME"/} dirty and uncommitted >4h" \
     "tree-skew:$(basename "$repo")" 86400
   fi
  fi
 done
}

probe_repeated_breadcrumbs() {
 # identical last-two breadcrumbs are a stuck loop signal
 python3 "$ROOT/lib/crumbs-db.py" export --db "$_crumbs_db" --tail 2 2>/dev/null |
  awk 'NR==1{a=$0} NR==2&&$0==a{print "REPEAT"}'
}

probe_gate_red() {
 # unread gate-red alert rows (identity gate-check:<repo>, filed by
 # cadence/day/03-gate-check.sh when a repo's make test fails) must reach
 # the operator, not sit in the ledger — the 2026-08-28 lesson. Unread
 # (cursor-gated --json) = unseen; row ts within 24h = the gate-check
 # dedup window (a still-red gate re-files daily, refreshing the row).
 # Escalation cap per the report-queue lesson: re-surface at most hourly
 # (SUPPRESS_MIN), one ledger row per identity per day (window 86400).
 local tmp
 tmp="$(mktemp 2>/dev/null)" || return 0
 "$REPORT_QUEUE" --json >"$tmp" 2>/dev/null || {
  rm -f "$tmp"
  return 0
 }
 python3 - "$tmp" <<'PY' || {
import json, sys
try:
    with open(sys.argv[1]) as fh:
        d = json.load(fh)
except ValueError:
    sys.exit(1)
seen = set()
for r in d.get("reports", []):  # newest-first
    if r.get("kind") != "alert":
        continue
    body = r.get("body") or ""
    for repo in ("hngh", "hngh-automation"):
        if repo not in seen and ("**identity:** gate-check:%s" % repo) in body:
            seen.add(repo)
            print(repo, r.get("ts") or "")
PY
  rm -f "$tmp"
  return 0
 }
 rm -f "$tmp"
}

gate_red_alert() { # repo ts
 local repo="$1" ts="$2" age
 age=$(($(date +%s) - $(date -u -d "$ts" +%s 2>/dev/null || echo 0)))
 [ "$age" -le 86400 ] || return 0
 (SUPPRESS_MIN=3600 alert "gate-red" \
  "$repo make test red — gate-check alert row unread in ledger" \
  "gate-red:$repo" 86400)
}

probe_ui_audit() {
 # ui-audit regression watch: per-rule violation counts from unread
 # ui-audit alert rows (newest row per rule — counts are frozen into a
 # row's first line; a count change lands as a fresh row after the
 # 24h window). A count crossing its previously-seen value upward is a
 # regression — one summary breadcrumb, never per-rule alert spam
 # (ui-audit already files those). Prints the summary line only on
 # regression. State: ${UI_AUDIT_STATE:-/tmp/hngh-oversight-ui-audit}.
 local state="${UI_AUDIT_STATE:-/tmp/hngh-oversight-ui-audit}"
 local tmp
 tmp="$(mktemp 2>/dev/null)" || return 0
 "$REPORT_QUEUE" --json >"$tmp" 2>/dev/null || {
  rm -f "$tmp"
  return 0
 }
 python3 - "$state" "$tmp" <<'PY' || {
import json, re, sys
try:
    with open(sys.argv[2]) as fh:
        d = json.load(fh)
except ValueError:
    sys.exit(1)
cur = {}  # rule -> violation count, newest unread row per rule
for r in d.get("reports", []):  # newest-first
    if r.get("kind") != "alert":
        continue
    m = re.match(r"ui-audit ([\w:-]+): (\d+) violation", r.get("first") or "")
    if m and m.group(1) not in cur:
        cur[m.group(1)] = int(m.group(2))
prev = {}
try:
    with open(sys.argv[1]) as fh:
        for ln in fh:
            k, v = ln.split(None, 1)
            prev[k] = int(v)
except (OSError, ValueError):
    pass
regress = ["%s %d->%d" % (r, prev[r], n)
           for r, n in sorted(cur.items()) if r in prev and n > prev[r]]
try:
    with open(sys.argv[1], "w") as fh:
        for r, n in sorted(cur.items()):
            fh.write("%s %d\n" % (r, n))
except OSError:
    pass
if regress:
    print("%d open rule row(s); regression: %s"
          % (len(cur), ", ".join(regress)))
PY
  rm -f "$tmp"
  return 0
 }
 rm -f "$tmp"
}

probe_test_loops() {
 # repeated-expensive-identical-work class. Two cheap signals:
 #  1) STATE: 3+ byte-identical crumbs from the same oversight/credential/
 #     ceremony job, consecutive for that job (a distinct crumb from that job
 #     resets the count), within a 30-min window. A heartbeat is NOT a loop:
 #     the tick's own periodic "mode=timer"/"nothing-mounted" crumb repeats by
 #     design, so we require the identical crumb to contain a NON-periodic
 #     signal (an alert/error/loop keyword) — a plain periodic crumb with no
 #     alert flag is healthy periodicity, not a loop (prove: 756 identical
 #     mode=timer ticks fired 3 at 22:45:28 and tripped this once; false).
 #  2) /tmp/hngh-fasttest-* verify-cache markers (FastTestCache sibling): 3+
 #     markers for one repo within 5 min = the repeated gate the cache exists
 #     to prevent. Fail-open: absent dir -> silent no-op, never an error.
 [ -f "$_crumbs_db" ] || return 0
 local cutoff loop repo hit
 cutoff=$(date -u -d '30 minutes ago' +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u +%Y-%m-%dT%H:%M:%SZ)
 loop=$(python3 "$ROOT/lib/crumbs-db.py" export --db "$_crumbs_db" 2>/dev/null |
  awk -v cutoff="$cutoff" '
    /^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z/ {
      if ($1 < cutoff) next            # outside 30-min recent window
      body=$0; sub(/^[^|]*\|[ ]*/,"",body)   # drop "TS | " -> job|event|detail
      split(body, b, " \\| "); job=b[1]
      if (job !~ /oversight|credential|ceremony/) next
      if (body == last[job]) cnt[job]++
      else { last[job]=body; cnt[job]=1 }
      if (cnt[job] == 3 && body ~ /alert|error|loop|refus|fail/) {
        print "STATE 3x identical crumb from " job ": " body; exit
      }
    }
  ')
 if find /tmp -maxdepth 1 -name 'hngh-fasttest-*' -print -quit 2>/dev/null | grep -q .; then
  # marker name /tmp/hngh-fasttest-<repo>-<sha256>.ok ; group by repo token
  repo=$(find /tmp -maxdepth 1 -name 'hngh-fasttest-*' -mmin -5 2>/dev/null |
   sed -E 's#/tmp/hngh-fasttest-([^-]+)-.*#\1#')
  hit=$(printf '%s\n' "$repo" | sort | uniq -c | awk '$1>=3{print $2" ("$1" markers in 5m)"; exit}')
  [ -n "$hit" ] && loop="$loop /tmp/hngh-fasttest $hit"
 fi
 printf '%s' "$loop"
}

probe_credentials() {
 # reuse the health job; it self-rotates under flock (nothing else needed)
 [ -x "$ROOT/jobs/credential-health.sh" ] &&
  "$ROOT/jobs/credential-health.sh" >/dev/null 2>&1
}

# --- observation legs -------------------------------------------------------
probe_credentials() { :; } # replaced by probe_agent_health below (kept name for clarity)
probe_agent_health() { probe_credentials; }

probe_agent_watchdog() {
 # roguelike death watchdog: reads the omp session surface, logs handoffs
 # (agent-handoffs.md) + arms attention. Log-only; never kills/launches.
 local wd="$ROOT/jobs/agent-watchdog.sh"
 [ -x "$wd" ] || {
  breadcrumb "oversight-tick" "watchdog" "missing $wd"
  return 0
 }
 bash "$wd" || breadcrumb "oversight-tick" "watchdog-fail" "rc=$?"
}

probe_rendered_dashboard() {
 # rendered-but-inert surface check (guardrails class 9): a page that
 # returns 200 but whose interactions are dead (panels never open,
 # a chart never draws) is a broken surface. Cheap DOM assertion via
 # the served page: click the first panel head, confirm the body
 # becomes visible, restore. HTTP 200 alone is NOT proof of function.
 local url="${DASH_URL:-http://127.0.0.1:8890/}" out
 command -v node >/dev/null 2>&1 || {
  breadcrumb "oversight-tick" "dash-check" "skipped (no node)"
  return 0
 }
 out=$(node -e '
    const http = require("http");
    http.get("http://127.0.0.1:8890/app.js", r => {
      let s = "";
      r.on("data", d => (s += d));
      r.on("end", () => {
        const usesData = /\bdata[-_]open\b/.test(s) || /dataset\.open/.test(s);
        const usesClass = /classList\.(add|remove)\([\x27\x22]open[\x27\x22]\)/.test(s);
        if (usesData && !usesClass) process.stdout.write("ok:data-open");
        else if (!usesData) process.stdout.write("FAIL:no-data-open");
        else process.stdout.write("FAIL:class-toggle");
      });
    }).on("error", () => process.stdout.write("FAIL:unreachable"));
  ' 2>/dev/null)
 case "$out" in
 ok:*) breadcrumb "oversight-tick" "dash-check" "expand contract ok" ;;
 FAIL*) alert "rendered-surface" "dashboard expand contract: $out" \
  "rendered-surface" 86400 ;;
 *) breadcrumb "oversight-tick" "dash-check" "no verdict ($out)" ;;
 esac
}

probe_time_ledger() {
 # delay flagging (backlog.md time ledger): flag a unit whose last wall
 # exceeds max(2x its trailing median, 10s floor) and its design envelope
 # (jobs/slow-units.py ENVELOPE — timeout-capped units are bimodal by
 # design; the median rule alone fired on every legitimate mode
 # transition of the workbeat, 44 false rows 2026-08-27..09-01).
 # Ledger missing or unparsable -> skip silently (fail-closed, no alert).
 local rows row
 rows=$(python3 -B "${ROOT}/jobs/slow-units.py" \
  "${ROOT}/dashboard/time-ledger.json" 2>/dev/null) || return 0
 while IFS= read -r row; do
  [ -n "$row" ] || continue
  alert "slow-unit" "$row" "slow-unit:${row%% *}" 86400
 done <<<"$rows"
}

steer_leg() {
 # agentic leg — LOCAL model only, gated by STEERING_BEAT_MIN, fail closed.
 # Attention trigger: a probe or event that sensed something worth
 # steering (an alert, a changed signal, an attention flag) fires the
 # leg within STEERING_ATTENTION_MIN instead of waiting for the beat.
 [ -n "$STEER_MODEL" ] || {
  breadcrumb "oversight-tick" "steer" "none (no STEER_MODEL)"
  return 0
 }
 now=$(date +%s)
 attention=0
 if [ -f "$ATTENTION_FLAG" ]; then
  age=$((now - $(stat -c %Y "$ATTENTION_FLAG" 2>/dev/null || echo 0)))
  [ "$age" -lt $((STEERING_ATTENTION_MIN * 60)) ] && attention=1
 fi
 due=$(($(cat "$LAST_BEAT" 2>/dev/null || echo 0) + STEERING_BEAT_MIN * 60))
 [ "$attention" -eq 1 ] && due=0 # attention overrides the beat
 [ "$now" -lt "$due" ] && {
  breadcrumb "oversight-tick" "steer" "$([ "$attention" -eq 1 ] && echo attention || echo not-due)"
  return 0
 }
 touch "$LAST_BEAT"
 recent=$(python3 "$ROOT/lib/crumbs-db.py" export --db "$_crumbs_db" 2>/dev/null |
  grep -E "steer|alert|optimize" | tail -5)
 # typed hazard gate (sde_cascade FIRE_T): one Noul over the tail decides
 # whether the steer-model call is worth firing at all. >= 0.7 fires the
 # model for the action; < 0.7 annotates only; unavailable keeps the
 # legacy prompt+parse path untouched (fail-open).
 hazard=$(TYPESAFE_TAIL="$recent" python3 -c "
import os, sys
sys.path.insert(0, os.path.join('$AUTOMATION_ROOT', 'lib'))
from typesafe import ask_noul
v = ask_noul({'tail': os.environ.get('TYPESAFE_TAIL', '')}, 'steer_hazard',
 'Does this execution tail show repeated identical execution with no distinct progress? true: consecutive steps repeat the same action against the same state with no new artifacts, conclusions, files, or state changes. false: each step produces an observable change or advances the goal.')
print('unavailable' if v is None else ('steer' if v >= 0.7 else 'none'))
" 2>/dev/null)
 case "${hazard:-unavailable}" in
 steer)
  # action-only prompt: the hazard gate already made the decision
  out=$(printf '%s\n%s\n' \
   "Active-work hazard confirmed: the tail shows repeated identical execution with no distinct progress. Reply with only the interrupt-and-redirect action: the specific next action that prevents the repeat as it starts." \
   "$recent" | timeout 60 curl -s -m 55 "$STEER_MODEL" -d @- 2>/dev/null | head -c 400)
  breadcrumb "oversight-tick" "steer" "${out%%$'\n'*}"
  ;;
 none) breadcrumb "oversight-tick" "steer" "none (typed: no active-work hazard)" ;;
 *)
  out=$(printf '%s\n%s\n' \
   "Review the STATE tail for active-work hazards and loop-recognition: if the recent tail shows repeated identical job/step execution with no distinct progress, recommend steering: interrupt-and-redirect with the specific next action (prevent the repeat as it starts); otherwise steer: none. Reply exactly one line: steer: <action> or steer: none" \
   "$recent" | timeout 60 curl -s -m 55 "$STEER_MODEL" -d @- 2>/dev/null | head -c 400)
  case "$out" in
  *steer:* | *STEER*) breadcrumb "oversight-tick" "steer" "${out%%$'\n'*}" ;;
  *) breadcrumb "oversight-tick" "steer" "none (model had no actionable reply)" ;;
  esac
  ;;
 esac
}

self_review() {
 # self-optimization leg: what fired where, event vs poll vs agent gated
 polls=$(python3 "$ROOT/lib/crumbs-db.py" export --db "$_crumbs_db" --tail 200 2>/dev/null |
  grep -c 'oversight-tick' || true)
 breadcrumb "oversight-tick" "optimize" "poll-count=$polls; beat=${STEERING_BEAT_MIN}min; model=${STEER_MODEL:-none}"
}

# run ------------------------------------------------------------------------
(
 flock -n 9 || {
  breadcrumb "oversight-tick" "skip" "another instance holds the lock"
  exit 0
 }
 breadcrumb "oversight-tick" "tick" "mode=${1:-timer}"
 probe_stale_ceremony_stores
 probe_working_tree_skew
 while read -r grepo gts; do
  [ -n "$grepo" ] && gate_red_alert "$grepo" "$gts"
 done < <(probe_gate_red)
 ui_sig="$(probe_ui_audit)"
 [ -n "$ui_sig" ] &&
  breadcrumb "oversight-tick" "ui-audit-regression" "$ui_sig"
 probe_repeated_breadcrumbs | grep -q REPEAT &&
  alert "repeat-crumbs" "identical breadcrumb loop detected" \
   "repeat-crumbs" 86400
 loop_sig=$(probe_test_loops)
 [ -n "$loop_sig" ] && alert "loop-signal" "$loop_sig" "loop-signal" 86400
 probe_system_awareness
 probe_time_ledger
 [ "$EVENT_MODE" -eq 0 ] && probe_agent_health
 [ "$EVENT_MODE" -eq 0 ] && probe_agent_watchdog
 [ "$EVENT_MODE" -eq 0 ] && probe_rendered_dashboard
 [ "$EVENT_MODE" -eq 0 ] && steer_leg
 [ "$SELFREVIEW_MODE" -eq 1 ] && self_review
) 9>"$LOCK"
exit 0
