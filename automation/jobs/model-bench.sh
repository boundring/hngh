#!/usr/bin/env bash
# model-bench — rank the local Unsloth fleet on coding/review-shaped probes.
# Three deterministic probes per model (structured review JSON, closed-format
# instruction following, one-expression code fix); a python judge scores each
# answer and appends one JSON line per model to stats/model-bench-<date>.jsonl.
# Ends by reloading the primary model so the next hourly job starts warm.
# Fail-closed: exits 0.
set -u
. "$(cd "$(dirname "$0")/.." && pwd)/lib/common.sh"
. "$AUTOMATION_ROOT/lib/breadcrumbs.sh"
. "$AUTOMATION_ROOT/lib/model.sh"
. "$AUTOMATION_ROOT/lib/hngh-record.sh"

DATE="$(date +%F)"
TS="$(date +%H%M)"
OUT="$AUTOMATION_ROOT/stats/model-bench-$DATE.jsonl"
mkdir -p "$AUTOMATION_ROOT/stats"

# Probe 1: structured review output (rung-6 review-adapter shape) with two
# planted defects: #+ is a reader macro (not #'+), and empty-list division.
P1='Reply with ONLY a JSON object (no markdown fences, no prose) with keys: verdict (string, "findings" or "clean"), findings (array of short strings), confidence (number 0-1). Review this Common Lisp function for defects: (defun safe-avg (xs) (/ (reduce #+ xs) (length xs)))'
# Probe 2: closed-format instruction discipline (tier tags, exact shape).
P2='Output exactly three lines, no other text, each line starting with its tag: [CRITICAL] the defect in this shell command: rm -rf "$DEST/" when DEST is empty; [NOTABLE] why it is dangerous; [CONTEXT] one concrete fix.'
# Probe 3: one-expression code correction.
P3='Reply with ONLY the corrected Common Lisp expression that computes the average of list xs returning 0 for an empty list. No markdown, no explanation, one expression.'

for m in $BENCH_MODELS; do
 log "benching $m"
 d="$(mktemp -d)"
 unsloth_chat "$P1" 400 "$m" >"$d/a1" 2>/dev/null || true
 unsloth_chat "$P2" 400 "$m" >"$d/a2" 2>/dev/null || true
 unsloth_chat "$P3" 300 "$m" >"$d/a3" 2>/dev/null || true
 python3 - "$m" "$d/a1" "$d/a2" "$d/a3" >>"$OUT" <<'PY'
import datetime, json, re, sys
model, f1, f2, f3 = sys.argv[1:5]
def read(p):
    try:
        return open(p, errors="replace").read().strip()
    except OSError:
        return ""
a1, a2, a3 = read(f1), read(f2), read(f3)
r = {
    "ts": datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
    "model": model, "p1_json": 0, "p1_div0": 0, "p1_reader": 0,
    "p2_format": 0, "p3_fix": 0,
}
# p1: find a JSON object anywhere in the answer and check its shape
start, end = a1.find("{"), a1.rfind("}")
if start >= 0 and end > start:
    try:
        o = json.loads(a1[start:end + 1])
        if isinstance(o, dict) and "verdict" in o and isinstance(o.get("findings"), list):
            r["p1_json"] = 1
    except ValueError:
        pass
low1 = a1.lower()
r["p1_div0"] = int(any(k in low1 for k in ("empty", "zero", "divis")))
r["p1_reader"] = int("#+" in a1 or any(k in low1 for k in ("reader", "syntax", "malformed", "sharp")))
# p2: exactly three lines with the right tags in order
lines = [l for l in a2.splitlines() if l.strip()]
tags = ("[CRITICAL]", "[NOTABLE]", "[CONTEXT]")
r["p2_format"] = int(len(lines) == 3 and all(l.startswith(t) for l, t in zip(lines, tags)))
# p3: mentions length and guards the empty list
low3 = a3.lower()
r["p3_fix"] = int("length" in low3 and any(k in low3 for k in ("null", "cond", "(if", "(or", "when")))
r["score"] = sum(r[k] for k in ("p1_json", "p1_div0", "p1_reader", "p2_format", "p3_fix"))
print(json.dumps(r, sort_keys=True))
PY
 rm -rf "$d"
done

# summary + breadcrumb
best="$(
 python3 - "$OUT" <<'PY'
import json, sys
best, top = None, -1
for ln in open(sys.argv[1], errors="replace"):
    try:
        r = json.loads(ln)
    except ValueError:
        continue
    if r.get("score", 0) > top:
        best, top = r.get("model"), r.get("score", 0)
print(f"{best} ({top}/5)")
PY
)"
breadcrumb "$JOB_NAME" "bench" "$(wc -l <"$OUT" 2>/dev/null || echo 0) models probed; best: $best"

# ranking summary for the morning report
python3 - "$OUT" "$AUTOMATION_ROOT/digest/BENCH-$DATE.md" <<'PY'
import json, os, sys
src, dst = sys.argv[1:3]
rows = []
for ln in open(src, errors="replace"):
    try:
        rows.append(json.loads(ln))
    except ValueError:
        pass
rows.sort(key=lambda r: (-r.get("score", 0), r.get("model", "")))
day = os.path.basename(dst).replace("BENCH-", "").replace(".md", "")
lines = ["# Fleet bench %s" % day, "",
         "| score | model | json | div0 | reader | fmt | fix |",
         "|---|---|---|---|---|---|---|"]
for r in rows:
    lines.append("| {score}/5 | {model} | {json} | {div0} | {reader} | {fmt} | {fix} |".format(
        score=r.get("score", 0), model=r.get("model", ""),
        json=r.get("p1_json", 0), div0=r.get("p1_div0", 0),
        reader=r.get("p1_reader", 0), fmt=r.get("p2_format", 0),
        fix=r.get("p3_fix", 0)))
lines.append("")
if rows:
    lines.append("Best: %s. Suggested chain: ranked order above with outright failures dropped." % rows[0]["model"])
else:
    lines.append("No bench rows recorded.")
open(dst, "w").write("\n".join(lines) + "\n")
PY
breadcrumb "$JOB_NAME" "bench" "digest/BENCH-$DATE.md written for the morning report"

# reload the primary so the next hourly job starts warm
unsloth_chat "ping" 8 "$MODEL" >/dev/null 2>&1 || true
record_hngh_run "model benchmark $DATE $TS"
exit 0
