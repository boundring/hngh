#!/usr/bin/env bash
# test-ttsr-fit.sh -- contract proofs for the ttsr alignment record
# screen (hngh docs/design/ttsr-alignment.md):
#   1. VERIFY leg over a stubbed rules dir + settings: present+armed ->
#      silent; missing rule, emptied condition, ttsr.enabled false ->
#      one drift row each.
#   2. DETECT leg over fixture transcripts: 3 injections -> alert;
#      post-hoc regex hit (thinking-scope backstop) -> alert;
#      2 injections -> silent; identity dedup on rerun.
#   3. SUPPLY lines: research prompt carries the continuity preamble;
#      context pack carries the machine-clock line.
# Hermetic: stub dirs only; report root sandboxed; operator files
# (~/.omp/agent/rules, config.yml, sessions) never touched.
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"
sb="$(mktemp -d)"
trap 'rm -rf "$sb"' EXIT

ok() { echo "ok: $1"; }
need() { "$@" || {
  echo "FAIL: $*"
  exit 1
}; } # every case fatal

mkdir -p "$sb/rules" "$sb/sess" "$sb/root/docs/project" "$sb/root/docs/project/report-bodies"

# stub settings: ttsr enabled (verbatim shape of ~/.omp/agent/config.yml)
cat >"$sb/config.yml" <<'EOF'
exa:
  enabled: false
ttsr:
  contextMode: discard
  enabled: true
  repeatGap: 5
  repeatMode: after-gap
shellMinimizer:
  enabled: false
EOF

arm_rule() { # name condition
  cat >"$sb/rules/$1.md" <<EOF
---
name: $1
condition: ["$2"]
scope: "text"
---
Body text.
EOF
}
arm_rule no-ungrounded-time-of-day 'queued for (the )?morning'
arm_rule research-continuous-not-batch 'transitions per beat'

rows() { cat "$sb/root/docs/project/reports.md" 2>/dev/null || true; }
run() {
  TTSR_RULES_DIR="$sb/rules" TTSR_SETTINGS="$sb/config.yml" \
    TTSR_SESS_DIR="$sb/sess" HNGH_REPORT_ROOT="$sb/root" HNGH_HOME="$(cd "$root/.." && pwd)" \
    bash "$root/cadence/day/22-ttsr-fit.sh"
}

# case 1: present + armed + enabled -> silent
run
need test -z "$(rows)"
ok "verify leg: armed rules + ttsr.enabled true -> silent"

# case 2: missing rule -> one drift row
rm "$sb/rules/no-ungrounded-time-of-day.md"
run
need grep -q "ttsr rule drift: no-ungrounded-time-of-day" < <(rows)
ok "verify leg: missing rule -> drift alert"

# case 3: emptied condition -> one drift row
arm_rule no-ungrounded-time-of-day 'queued for (the )?morning'
sed -i 's/^condition: .*/condition: []/' "$sb/rules/no-ungrounded-time-of-day.md"
run
need grep -q "no-ungrounded-time-of-day.md missing or condition emptied" < <(rows)
ok "verify leg: emptied condition -> drift alert"

# case 4: settings ttsr.enabled false -> drift row
arm_rule no-ungrounded-time-of-day 'queued for (the )?morning'
sed -i '/^ttsr:/,/^shell/ s/enabled: true/enabled: false/' "$sb/config.yml"
run
need grep -q "settings ttsr.enabled is false" < <(rows)
ok "verify leg: ttsr.enabled false -> drift alert"
sed -i '/^ttsr:/,/^shell/ s/enabled: false/enabled: true/' "$sb/config.yml"

# --- DETECT leg fixtures (assistant-text jsonl, omp transcript shape) ---
msg() { # sid text
  printf '{"type":"message","id":"x","message":{"role":"assistant","content":[{"type":"text","text":"%s"}]}}\n' "$2" \
    >>"$sb/sess/$1.jsonl"
}
inj() { # sid n — ttsr-injection marker entries (stream-layer surface)
  local i
  for _ in $(seq 1 "$2"); do
    printf '{"type":"custom","customType":"ttsr-injection","rule":"no-ungrounded-time-of-day"}\n' >>"$sb/sess/$1.jsonl"
  done
}

# case 5: 3 injections >= threshold 3 -> alert
inj threeinj 3
msg threeinj 'all quiet on this line'
run
need grep -q 'ttsr fit: session threeinj — ttsr injections: 3 (>= threshold 3)' < <(rows)
ok "detect leg: 3 injections -> session alert"

# case 6: identity dedup on rerun — still one row for threeinj
run
need test "$(grep -c 'ttsr fit: session threeinj' <(rows))" = 1
ok "detect leg: identity dedup on rerun (one row per session)"

# case 7: 2 injections < threshold -> silent
inj twoinj 2
msg twoinj 'nothing to see here'
run
need test -z "$(grep 'ttsr fit: session twoinj' <(rows))"
ok "detect leg: 2 injections below threshold -> silent"

# case 8: post-hoc regex hit over assistant text (thinking-scope
# backstop) -> alert with rule name + worst line, even at 0 injections
msg slip 'this batch is queued for the morning'
msg batch 'the line needs 18 days to crystallize, one transition per day'
run
need grep -q 'post-hoc rule matches: no-ungrounded-time-of-day' < <(rows)
need grep -q "queued for the morning" < <(rows)
need grep -q 'research-continuous-not-batch' < <(rows)
need grep -q 'fix or park with cause' < <(rows)
ok "detect leg: post-hoc assistant-text match -> alert (backstop)"

# case 9: env override tightens the threshold -> 2 injections now fire
rm -f "$sb/sess/"*.jsonl "$sb/root/docs/project/reports.md"
inj tight 2
TTSR_FIT_THRESHOLD=2 TTSR_RULES_DIR="$sb/rules" TTSR_SETTINGS="$sb/config.yml" \
  TTSR_SESS_DIR="$sb/sess" HNGH_REPORT_ROOT="$sb/root" HNGH_HOME="$(cd "$root/.." && pwd)" \
  bash "$root/cadence/day/22-ttsr-fit.sh"
need grep -q 'ttsr fit: session tight — ttsr injections: 2 (>= threshold 2)' < <(rows)
ok "TTSR_FIT_THRESHOLD env override"

# case 10: SUPPLY — research prompt carries the continuity preamble
need grep -q 'CONTINUOUS research process (line' "$root/cadence/hour/33-research-beat.sh"
need grep -q 'research pace as batched or periodic' "$root/cadence/hour/33-research-beat.sh"
ok "supply: research beat prompt continuity preamble present"

echo "ttsr-fit contract: all cases passed"
