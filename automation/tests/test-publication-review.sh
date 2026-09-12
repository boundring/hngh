#!/usr/bin/env bash
# test-publication-review.sh -- standing publication review cycle proofs
# (2026-09-12 operator directive, docs/research/
# 2026-09-12-publication-review-01.md): the day-tier beat reviews the
# latest manga draft + dispatch with deterministic two-pass checklists,
# files findings, and escalates persistent reds through the blocker
# ledger at scope publication:<artifact>.
# Hermetic: sandbox repo copy, no real model, no report-queue state, no
# live beat blockers.
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"
sb="$(mktemp -d)"
trap 'rm -rf "$sb"' EXIT
mkdir -p "$sb/lib" "$sb/jobs" "$sb/cadence/day" "$sb/docs/media/manga" \
 "$sb/docs/dispatch" "$sb/automation/digest" "$sb/scripts"
cp -r "$root/lib/." "$sb/lib/"
cp "$root/jobs/publication-review.py" "$sb/jobs/"
cp "$root/cadence/day/26-publication-review.sh" "$sb/cadence/day/"
cp "$root/../scripts/report-queue" "$sb/scripts/"

good_draft() { # -> writes a compliant draft + rendered panel svg
 cat >"$sb/docs/media/manga/sample-draft.json" <<'EOF'
{"band":"NOTABLE","headline":"test headline","url":"https://example.com/n",
 "style_id":"manga-panel","image_prompt":"p","cameo":"nightwatch",
 "scene":"s","caption":"MEANWHILE, IN WORLD NEWS...",
 "dialogue":"The log says this happened at 3 AM. It is 3 AM.",
 "sfx":"KRAK",
 "narrative":"Grounded event: test headline (severity NOTABLE). Source cited below.",
 "attribution":"[DRAMATIZATION - procedural gag, not a real quote] -- GDELT 2.0 export, https://example.com/n"}
EOF
 cat >"$sb/docs/media/manga/sample-draft.svg" <<'EOF'
<svg><rect x="14" y="14" width="996" height="640"/><image href="a.png"/><ellipse cx="682" cy="227" rx="244" ry="98"/></svg>
EOF
 # the checker looks for <image in the svg text
}

good_dispatch() {
 cat >"$sb/docs/dispatch/2026-09-12.md" <<'EOF'
# The Machine Hall - Daily Dispatch (public edition)

## Deck A - News from the Outside World

### 0000 UTC

- CRITICAL: test headline (https://example.com/n)
_quip: the hall files it under weather._

### 0200 UTC

- none ? quiet window
EOF
}

fails=0
ck() { # desc expected actual
 if [ "$2" = "$3" ]; then echo "ok: $1"; else
  echo "FAIL: $1 (want '$2' got '$3')"
  fails=$((fails + 1))
 fi
}
run_check() { # -> python checker against sandbox; stdout captured
 python3 "$sb/jobs/publication-review.py" --repo "$sb" \
  --report-root "$sb" --date 2026-09-12 2>&1
}

# --- a) a good draft passes clean -----------------------------------------
good_draft
good_dispatch
out="$(run_check)"
rc=$?
ck "good fixtures: exit 0" "0" "$rc"
ck "good fixtures: zero FAIL lines" "0" "$(printf '%s\n' "$out" | grep -c '^FAIL')"

# --- b) empty/missing panel fails naming the artifact ----------------------
rm -f "$sb/docs/media/manga/sample-draft.svg"
out="$(run_check)"
ck "missing panel: FAIL printed" "1" \
 "$(printf '%s\n' "$out" | grep -c 'panel-art-missing')"
printf '%s\n' "$out" | grep -q 'sample-draft.json' &&
 echo "ok: missing panel names the artifact" ||
 {
  echo "FAIL: artifact not named"
  fails=$((fails + 1))
 }

# --- c) quip-budget overage flagged ----------------------------------------
good_draft
python3 - "$sb" <<'EOF'
import json, sys
path = sys.argv[1] + "/docs/media/manga/sample-draft.json"
d = json.load(open(path))
d["dialogue"] = "word " * 30
json.dump(d, open(path, "w"))
EOF
out="$(run_check)"
ck "overage: quip-budget-overage FAIL" "1" \
 "$(printf '%s\n' "$out" | grep -c 'quip-budget-overage')"
ck "overage: supportive quip-budget MISS recorded" "1" \
 "$(grep -c 'MISS] quip-budget' "$sb/automation/digest/PUBLICATION-REVIEW-2026-09-12.md" || true)"

# --- d) day wrapper: persistent red escalates, green clears ----------------
: >"$sb/STATE.md"
BEAT_BLOCKERS_FILE="$sb/blockers.tsv"
export BEAT_BLOCKERS_FILE
wrapper() {
 (cd "$sb" && HNGH_HOME="$sb" HNGH_REPORT_ROOT="$sb" \
  bash "$sb/cadence/day/26-publication-review.sh" 2>&1)
}
rm -f "$sb/docs/media/manga/sample-draft.svg"
good_draft # single red cause only: panel-art-missing (no quip overage)
rm -f "$sb/docs/media/manga/sample-draft.svg"
wrapper >/dev/null
wrapper >/dev/null
row="$(awk -F'\t' '$2 == "publication:sample-draft.json"' "$BEAT_BLOCKERS_FILE" | tail -n 1)"
[ "$(printf '%s' "$row" | awk -F'\t' '{print $6}')" = "parked" ] &&
 echo "ok: persistent red parks publication:sample-draft.json" ||
 {
  echo "FAIL: blocker row not parked (row: $row)"
  fails=$((fails + 1))
 }
good_draft
wrapper >/dev/null
[ -f "$BEAT_BLOCKERS_FILE" ] &&
 awk -F'\t' '$2 ~ /^publication:/ { found=1 } END { exit !found }' \
  "$BEAT_BLOCKERS_FILE" &&
 {
  echo "FAIL: green review did not clear the blocker row"
  fails=$((fails + 1))
 } ||
 echo "ok: green review clears the blocker row"

echo
if [ "$fails" -eq 0 ]; then echo "ALL OK"; else
 echo "FAILED: $fails check(s)"
 exit 1
fi
