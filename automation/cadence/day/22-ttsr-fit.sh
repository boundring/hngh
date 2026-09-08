#!/usr/bin/env bash
# 22-ttsr-fit -- ttsr alignment: model-free, deterministic, fail-closed
# record-layer screen for oh-my-pi's TTSR (Time Traveling Stream Rules;
# design: hngh docs/design/ttsr-alignment.md). Two legs:
#   VERIFY: the operator's stream rules still exist with non-empty
#     conditions and the omp settings still enable ttsr -- drift means
#     the operator's safety net silently vanished.
#   DETECT: count ttsr injection markers per recent session transcript
#     and run the mirrored rule regexes post-hoc over assistant TEXT
#     (the thinking-scope backstop: stream rules cannot see thinking).
# Alerts are one identity-deduped report row per session; every path
# exits 0. Read-only on operator rule files, settings, and transcripts.
#
# usage: cadence/day/22-ttsr-fit.sh   (via cadence-tick.sh TIER=day)
set -u
. "$(cd "$(dirname "$0")/../.." && pwd)/lib/common.sh"
. "$AUTOMATION_ROOT/lib/breadcrumbs.sh"
. "$AUTOMATION_ROOT/lib/params.sh"

# --- mirrored rule conditions — ONE place --------------------------------
# source of truth: ~/.omp/agent/rules/{no-ungrounded-time-of-day,
# research-continuous-not-batch}.md; re-sync on operator edits.
# These mirror the `condition:` frontmatter regexes (JS flavor); the
# post-hoc scan runs them through python3 re, which honors \b \d \s.
TTSR_RE1="queued for (the )?morning|first thing (tomorrow|in the morning)|tonight'?s? (overnight|workbeat|digest|report|wave|run|pull)|lands? tonight|executes? (them|it) tonight|this evening"
TTSR_RE2='\b(one|\d+)\s+transitions?\s*(per|/)\s*(a\s+)?(beat|day)\b|\b\d+\s*days?\s+to\s+(crystalli[sz]e|drain|clear)\b|\b\d+\s*days?\s+instead\s+of\b|\breviewed one per day\b|\bscheduled once (a|per) day\b|\b\d+\s*days?\b[^.\n]{0,50}\b(crystalli[sz]e|crystallized|research (queue|lines?|beat)|reviewed)\b|\b(crystalli[sz]e|crystallized|research (queue|lines?|beat)|reviewed)[^.\n]{0,50}\b\d+\s*(more\s+)?days?\b'

KERNEL="${HNGH_HOME:-$HOME/Projects/etc/hngh}"
REPORT="python3 $KERNEL/scripts/report-queue"
report_root="${HNGH_REPORT_ROOT:-$KERNEL}"
RULES="${TTSR_RULES_DIR:-$HOME/.omp/agent/rules}"        # read-only probe
SETTINGS="${TTSR_SETTINGS:-$HOME/.omp/agent/config.yml}" # read-only probe
SESS="${TTSR_SESS_DIR:-$HOME/.omp/agent/sessions}"       # read-only probe
threshold="${TTSR_FIT_THRESHOLD:-$(get_param ttsr-fit-threshold 3)}"
JOB_NAME="${JOB_NAME:-22-ttsr-fit}"

file_report() { # kind text identity
  if HNGH_REPORT_ROOT="$report_root" $REPORT --add "$1" "$2" \
    --identity "$3" --window 86400 >/dev/null 2>&1; then
    breadcrumb "$JOB_NAME" "$1" "$3"
  else
    breadcrumb "$JOB_NAME" "report-fail" "could not file $1: $3"
  fi
}

# --- VERIFY leg -----------------------------------------------------------
# Rule presence + non-empty condition frontmatter; drift = alert.
verify_rules() {
  local r f cond
  for r in no-ungrounded-time-of-day research-continuous-not-batch; do
    f="$RULES/$r.md"
    cond=""
    [ -s "$f" ] && cond="$(sed -n 's/^condition:[[:space:]]*//p' "$f" | head -1 | tr -d '[]\"')"
    if [ -z "$cond" ]; then
      file_report alert \
        "ttsr rule drift: $r.md missing or condition emptied — the stream-layer safety net for '$r' is gone; fix or park with cause" \
        "ttsr-rule-drift:$r"
    fi
  done
  # Settings probe: ttsr.enabled !== false. Settings location discovered
  # 2026-09-07 (config.yml, ttsr: block) — if it ever moves and the probe
  # finds no file, the settings leg is unimplementable and is skipped;
  # rule presence above still runs.
  if [ -r "$SETTINGS" ]; then
    enabled="$(awk '/^ttsr:/{f=1; next} f && /^[^ \t]/{f=0} f && $1 == "enabled:" {print $2; exit}' "$SETTINGS")"
    if [ "$enabled" = "false" ]; then
      file_report alert \
        "ttsr rule drift: settings ttsr.enabled is false — stream-rule enforcement is switched off; fix or park with cause" \
        "ttsr-rule-drift:ttsr-enabled-settings"
    fi
  fi
}

# --- DETECT leg -----------------------------------------------------------
posthoc() { # transcripts on argv -> "sid<TAB>count<TAB>rules<TAB>worst"
  TTSR_RE1="$TTSR_RE1" TTSR_RE2="$TTSR_RE2" python3 - "$@" <<'PY'
import json, os, re, sys
pats = [(re.compile(os.environ["TTSR_RE1"]), "no-ungrounded-time-of-day"),
        (re.compile(os.environ["TTSR_RE2"]), "research-continuous-not-batch")]
for path in sys.argv[1:]:
    sid = os.path.basename(path)[:-6]
    n, worst, worstlen, names = 0, "", 0, set()
    try:
        fh = open(path, encoding="utf-8", errors="replace")
    except OSError:
        continue
    with fh:
        for line in fh:
            try:
                e = json.loads(line)
            except ValueError:
                continue
            if e.get("type") != "message":
                continue
            m = e.get("message") or {}
            if m.get("role") != "assistant":
                continue
            content = m.get("content")
            if isinstance(content, str):
                content = [{"type": "text", "text": content}]
            for c in content or []:
                if isinstance(c, str):
                    c = {"type": "text", "text": c}
                if isinstance(c, dict) and c.get("type") == "text":
                    for ln in str(c.get("text", "")).splitlines():
                        for rx, name in pats:
                            if rx.search(ln):
                                n += 1
                                names.add(name)
                                if len(ln) > worstlen:
                                    worst, worstlen = ln, len(ln)
    if n:
        print("%s\t%d\t%s\t%s" % (sid, n, "+".join(sorted(names)), worst[:120]))
PY
}

detect() {
  local tmp inj ph phn rules worst text
  tmp="$(mktemp)"
  find "$SESS" -name '*.jsonl' -type f -mmin -1440 2>/dev/null | sort >"$tmp"
  [ -s "$tmp" ] || {
    rm -f "$tmp"
    return 0
  }
  while IFS= read -r f; do
    sid="$(basename "$f" .jsonl)"
    inj="$(grep -cE 'ttsr-injection|rule_violation|ttsr_triggered' "$f" 2>/dev/null || true)"
    ph="$(posthoc "$f")"
    phn=0
    rules=""
    worst=""
    [ -n "$ph" ] && {
      phn="$(printf '%s' "$ph" | cut -f2)"
      rules="$(printf '%s' "$ph" | cut -f3)"
      worst="$(printf '%s' "$ph" | cut -f4)"
    }
    # one identity-deduped alert per session: threshold crossings on
    # injection markers, OR any post-hoc (thinking-scope backstop) match
    if [ "${inj:-0}" -ge "$threshold" ] || [ "$phn" -gt 0 ]; then
      text="ttsr fit: session $sid — ttsr injections: ${inj:-0}"
      [ "${inj:-0}" -ge "$threshold" ] &&
        text="$text (>= threshold $threshold)"
      [ -n "$rules" ] && text="$text — post-hoc rule matches: $rules ('$worst')"
      file_report alert "$text — fix or park with cause" "ttsr-fit:$sid"
    fi
  done <"$tmp"
  rm -f "$tmp"
}

verify_rules
detect
exit 0
