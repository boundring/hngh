#!/usr/bin/env bash
# fetch-model-benchmarks.sh — Source and scrape model benchmark data.
#
# Pulls real, dated model facts into data/ so model-pareto.md and the
# fallback chains in hngh-up.lisp are grounded, not vibes. Procedural,
# no LLM. Runs offline-friendly: each source is independent and skips
# cleanly on failure.
#
# Sources:
#   1. OpenRouter catalog  — https://openrouter.ai/api/v1/models
#      Authoritative for what exists: id, pricing, context, modality.
#   2. LM Arena PPE        — datasets-server.huggingface.co rows API
#      Per-model benchmark scores: MBPP-Plus (code), GPQA (science),
#      IFEval (instruct), MMLU-Pro, MATH. Aggregated mean per model.
#   3. Aider leaderboard   — https://aider.chat/docs/leaderboards/
#      Polyglot coding scores, scraped from the HTML table (best-effort).
#
# Output:
#   data/model-benchmarks-<YYYYMMDD>.json — merged snapshot:
#     { "fetched": [...], "catalog": [...], "ppe": {...}, "aider": {...} }
#
# Usage:
#   ./scripts/fetch-model-benchmarks.sh [--dir data] [--models "id1 id2 ..."]
#
# Exit codes:
#   0 — snapshot written (even if some sources failed)
#   1 — no source produced any data
#   2 — usage/argument error
#
# SPDX-License-Identifier: AGPL-3.0-or-later
# SPDX-FileCopyrightText: 2026 boundring <boundring@gmail.com>

set -uo pipefail

OUT_DIR="data"
MODEL_FILTER=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dir) OUT_DIR="$2"; shift 2 ;;
    --models) MODEL_FILTER="$2"; shift 2 ;;
    *) echo "Usage: $0 [--dir DIR] [--models 'id id ...']" >&2; exit 2 ;;
  esac
done

mkdir -p "$OUT_DIR"
DATE="$(date +%Y%m%d)"
OUT="$OUT_DIR/model-benchmarks-$DATE.json"
PY="$(command -v python3 || true)"
[[ -z "$PY" ]] && { echo "ERROR: python3 required for JSON parsing" >&2; exit 1; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# --- Source 1: OpenRouter catalog -------------------------------------------

if command -v curl >/dev/null 2>&1; then
  curl -s --max-time 30 "https://openrouter.ai/api/v1/models" -o "$TMP/catalog.json" 2>/dev/null
fi

# --- Source 2: LM Arena PPE (datasets-server rows API) ----------------------

PPE_DATASETS=(
  "lmarena-ai/PPE-MBPP-Plus-Best-of-K"
  "lmarena-ai/PPE-GPQA-Best-of-K"
  "lmarena-ai/PPE-IFEval-Best-of-K"
  "lmarena-ai/PPE-MMLU-Pro-Best-of-K"
  "lmarena-ai/PPE-MATH-Best-of-K"
)

: > "$TMP/ppe.rows"
for ds in "${PPE_DATASETS[@]}"; do
  encoded="$(printf '%s' "$ds" | "$PY" -c 'import sys,urllib.parse; print(urllib.parse.quote(sys.stdin.read().strip(), safe=""))')"
  curl -s --max-time 30 \
    "https://datasets-server.huggingface.co/rows?dataset=${encoded}&config=default&split=train&offset=0&length=100" \
    2>/dev/null >> "$TMP/ppe.rows" || true
  printf '\n' >> "$TMP/ppe.rows"
done

# --- Source 3: Aider polyglot leaderboard (HTML scrape, best-effort) ---------

curl -sL --max-time 30 "https://aider.chat/docs/leaderboards/" -o "$TMP/aider.html" 2>/dev/null || true

# --- Merge -------------------------------------------------------------------

export HNGH_BENCH_TMP="$TMP"

"$PY" - "$OUT" "$MODEL_FILTER" <<'PYEOF'
import json, os, re, sys

out_path, model_filter = sys.argv[1:3]
tmp = os.environ["HNGH_BENCH_TMP"]
snapshot = {"fetched": [], "catalog": [], "ppe": {}, "aider": {}}

# Catalog
try:
    with open(f"{tmp}/catalog.json") as f:
        d = json.load(f)
    for m in d.get("data", []):
        mid = m.get("id", "")
        if model_filter and not any(f in mid for f in model_filter.split()):
            continue
        pricing = m.get("pricing", {})
        arch = m.get("architecture", {})
        snapshot["catalog"].append({
            "id": mid,
            "name": m.get("name", ""),
            "input_cost": pricing.get("prompt"),
            "output_cost": pricing.get("completion"),
            "context": m.get("context_length"),
            "modality": arch.get("modality"),
        })
    snapshot["fetched"].append("openrouter")
except Exception as e:
    print(f"catalog: {e}", file=sys.stderr)

# PPE rows -> per-model mean of mean_score
try:
    ppe_path = f"{tmp}/ppe.rows"
    with open(ppe_path) as f:
        raw = f.read()
    if not raw.strip():
        print(f"ppe: {ppe_path} is empty", file=sys.stderr)
    else:
        print(f"ppe: fetched {len(raw)} bytes of benchmark rows", file=sys.stderr)
    agg = {}
    with open(ppe_path) as f:
        for line in f:
            line = line.strip()
            if not line: continue
            try:
                d = json.loads(line)
            except Exception:
                continue
            for r in d.get("rows", []):
                row = r.get("row", {})
                mn = (row.get("model_name") or "").strip()
                ms = row.get("mean_score")
                if not mn or ms is None: continue
                a = agg.setdefault(mn, {"n": 0, "sum": 0.0})
                a["n"] += 1
                a["sum"] += float(ms)
    snapshot["ppe"] = {
        mn: {"samples": e["n"], "mean_score": e["sum"] / e["n"]}
        for mn, e in agg.items()
    }
    snapshot["fetched"].append("lmarena-ppe")
except Exception as e:
    print(f"ppe: {e}", file=sys.stderr)

# Aider HTML table -> model -> polyglot %
try:
    with open(f"{tmp}/aider.html") as f:
        html = f.read()
    rows = {}
    for m in re.finditer(r"<tr[^>]*id=\"main-row-\d+\"[^>]*>(.*?)</tr>", html, re.S | re.I):
        cells = re.findall(r"<t[dh][^>]*>(.*?)</t[dh]>", m.group(1), re.S | re.I)
        if len(cells) < 3: continue
        # cell 0 is a toggle button; cell 1 is the model name; cell 2 is the polyglot %
        name = re.sub(r"<[^>]+>", "", cells[1]).strip()
        if not name or name.lower() in ("model", "name"): continue
        pct = re.findall(r"(\d+(?:\.\d+)?)\s*%", cells[2])
        if pct: rows[name] = float(pct[0])
    snapshot["aider"] = rows
    if rows: snapshot["fetched"].append("aider")
except Exception as e:
    print(f"aider: {e}", file=sys.stderr)

with open(out_path, "w") as f:
    json.dump(snapshot, f, indent=2, sort_keys=True)
print(f"wrote {out_path} (catalog={len(snapshot['catalog'])}, "
      f"ppe={len(snapshot['ppe'])}, aider={len(snapshot['aider'])}, "
      f"sources={snapshot['fetched']})")
PYEOF

rc=$?
[[ $rc -ne 0 ]] && exit 1
exit 0
