#!/usr/bin/env bash
# test-arc-to-slice.sh -- hermetic proofs for the arc->slice converter
# beat (29-arc-to-slice.sh, 2026-09-27):
#   a) no dispositions file -> exit 0, no rows.
#   b) parked arc (line crystallized/reviewed) dispositioned today ->
#      one queue row (identity arc-to-slice:<id>), state row.
#   c) rerun files nothing new (state dedupe), state file atomic (no .new).
#   d) killed arc -> typed lane still consulted -> queue row.
#   e) typed unavailable (no TYPESAFE_API_KEY) -> ONE typed-unavailable
#      alert row, no candidate row.
#   f) arc older than the 7-day residue cap -> skipped, no row.
#   g) needs-operator verdict -> operator-item queue row
#      (arc-to-slice-op:<id>).
#   h) no-slice verdict -> no row, state still records the decision.
#   i) planned (never-crystallized) line with parked disposition -> no row.
#   j) malformed tsv row -> fail-closed skip: no crash, no row; a
#      well-formed eligible arc in the same file still converts.
# Hermetic: sandbox repo copy, stubbed typesafe module, no network,
# no ~/.hngh writes, no real telemetry.
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"
sb="$(mktemp -d)"
fx="$(mktemp -d)"
pass=0
fail=0
trap 'rm -rf "$sb" "$fx"' EXIT

mkdir -p "$sb/lib" "$sb/kernel/scripts" "$sb/report-root" "$sb/hnghhome/db" \
 "$sb/cadence/calendar/daily"
cp -r "$root/lib/." "$sb/lib/"
cp "$root/../scripts/report-queue" "$sb/kernel/scripts/"
cp "$root/cadence/calendar/daily/29-arc-to-slice.sh" \
 "$sb/cadence/calendar/daily/"

# typesafe stub (park-on-untyped harness, test-research-review.sh pattern):
# no TYPESAFE_API_KEY -> {} fail-closed; with a key, every question is
# answered TYPESAFE_STUB_VERDICT at TYPESAFE_STUB_CONF (default 0.90).
cat >"$sb/lib/typesafe.py" <<'PYEOF'
import os
def ask_choices(state, questions):
    if not os.environ.get("TYPESAFE_API_KEY"):
        return {}
    verdict = os.environ.get("TYPESAFE_STUB_VERDICT", "")
    if not verdict:
        return {}
    try:
        conf = float(os.environ.get("TYPESAFE_STUB_CONF", "0.90"))
    except ValueError:
        conf = 0.0
    return {name: (verdict, conf) for name in questions}
PYEOF

today8="$(date -u +%Y%m%d)"
today="$(date -u +%Y-%m-%d)"
old8="$(date -u -d '8 days ago' +%Y%m%d)"

disp_header() { printf 'line\taction\tverdict\treviewer\tevidence\tdate\tsupport\toppose\tfollowons\n' >"$sb/research-dispositions.tsv"; }
line_row() { # id status
 printf '%s\t%s\t%sT00:00:00Z\ttopic text for %s\n' "$1" "$2" "$1" "$1" >>"$sb/research-lines.tsv"
}
arc_doc() { # id -> doc path on stdout (also creates it)
 printf '# Research Line Crystallization: %s\n\n## 1. Findings\n\n### 1.1 Core\n\nA one-line proposed slice lives here.\n' "$1" >"$fx/doc-$1.md"
 printf '%s' "$fx/doc-$1.md"
}
seed() { # reset fixtures to empty schemas
 disp_header
 printf 'line\tstatus\ttimestamp\ttopic\n' >"$sb/research-lines.tsv"
}
reset_run() { # fresh state + queue between case groups
 rm -rf "$sb/hnghhome" "$sb/report-root"
 mkdir -p "$sb/hnghhome/db" "$sb/report-root"
}

run() { # [K=V ...] -> one beat run in the sandbox
 env HNGH_HOME="$sb/kernel" HNGH_HOME_DIR="$sb/hnghhome" \
  HNGH_REPORT_ROOT="$sb/report-root" "$@" \
  bash "$sb/cadence/calendar/daily/29-arc-to-slice.sh" >/dev/null 2>&1
}
state() { cat "$sb/hnghhome/db/arc-to-slice/state.tsv" 2>/dev/null; }
state_count() { state | grep -c .; }
bodies() { ls "$sb/report-root/docs/project/report-bodies/" 2>/dev/null | wc -l | tr -d ' '; }
ident_count() { # identity-substring -> body files carrying it
 grep -rl "$1" "$sb/report-root/docs/project/report-bodies/" 2>/dev/null | wc -l | tr -d ' '
}

ok() { pass=$((pass + 1)); }
bad() {
 fail=$((fail + 1))
 echo "FAIL: $1"
}
chk() { # desc got want
 if [ "$2" = "$3" ]; then ok; else bad "$1 (got '$2' want '$3')"; fi
}

# --- a) no dispositions file -> quiet exit 0 ------------------------------
rm -f "$sb/research-dispositions.tsv"
printf 'line\tstatus\ttimestamp\ttopic\n' >"$sb/research-lines.tsv"
run TYPESAFE_API_KEY=stub-key
chk "a: rc 0 without dispositions file" "$?" "0"
chk "a: no rows" "$(bodies)" "0"

# --- b) parked + crystallized arc -> one queue row ------------------------
seed
doc_b="$(arc_doc arc-$today8-alpha)"
printf 'arc-%s-alpha\tparked\ttyped verdict parked (confidence 0.90)\tmodel:test\t%s\t%s\ts\to\tf\n' \
 "$today8" "$doc_b" "$today" >>"$sb/research-dispositions.tsv"
line_row "arc-$today8-alpha" reviewed
reset_run
run TYPESAFE_API_KEY=stub-key TYPESAFE_STUB_VERDICT=landable-slice
chk "b: queue row filed" "$(ident_count "arc-to-slice:arc-$today8-alpha")" "1"
chk "b: state records the arc" "$(state | grep -c "arc-$today8-alpha")" "1"

# --- c) rerun -> no duplicate, state atomic -------------------------------
run TYPESAFE_API_KEY=stub-key TYPESAFE_STUB_VERDICT=landable-slice
chk "c: no duplicate row on rerun" "$(ident_count "arc-to-slice:arc-$today8-alpha")" "1"
chk "c: state still one row" "$(state_count)" "1"
[ -e "$sb/hnghhome/db/arc-to-slice/state.tsv.new" ] &&
 bad "c: stale .new residue left behind" || ok

# --- d) killed arc -> typed still consulted -------------------------------
seed
doc_d="$(arc_doc arc-$today8-killed)"
printf 'arc-%s-killed\tkilled\tkilled -- fatal flaw\tmodel:test\t%s\t%s\ts\to\tf\n' \
 "$today8" "$doc_d" "$today" >>"$sb/research-dispositions.tsv"
line_row "arc-$today8-killed" reviewed
reset_run
run TYPESAFE_API_KEY=stub-key TYPESAFE_STUB_VERDICT=landable-slice
chk "d: killed arc converts via typed lane" "$(ident_count "arc-to-slice:arc-$today8-killed")" "1"

# --- e) typed unavailable -> ONE alert, no candidate ----------------------
seed
doc_e="$(arc_doc arc-$today8-nokey)"
printf 'arc-%s-nokey\tparked\tparked -- unverified\tmodel:test\t%s\t%s\ts\to\tf\n' \
 "$today8" "$doc_e" "$today" >>"$sb/research-dispositions.tsv"
line_row "arc-$today8-nokey" reviewed
reset_run
run TYPESAFE_API_KEY=
chk "e: typed-unavailable alert filed" "$(ident_count "arc-to-slice:typed-unavailable")" "1"
chk "e: no candidate row" "$(ident_count "arc-to-slice:arc-$today8-nokey")" "0"
chk "e: nothing recorded in state" "$(state_count)" "0"

# --- f) arc older than the 7-day residue cap -> skipped -------------------
seed
doc_f="$(arc_doc arc-$old8-stale)"
printf 'arc-%s-stale\tparked\tparked -- old\tmodel:test\t%s\t%s\ts\to\tf\n' \
 "$old8" "$doc_f" "$today" >>"$sb/research-dispositions.tsv"
line_row "arc-$old8-stale" reviewed
reset_run
run TYPESAFE_API_KEY=stub-key TYPESAFE_STUB_VERDICT=landable-slice
chk "f: stale arc skipped" "$(ident_count "arc-$old8-stale")" "0"
chk "f: stale arc not in state" "$(state | grep -c "arc-$old8-stale")" "0"

# --- g) needs-operator verdict -> operator-item queue row -----------------
seed
doc_g="$(arc_doc arc-$today8-opcall)"
printf 'arc-%s-opcall\tparked\tparked -- operator call needed\tmodel:test\t%s\t%s\ts\to\tf\n' \
 "$today8" "$doc_g" "$today" >>"$sb/research-dispositions.tsv"
line_row "arc-$today8-opcall" reviewed
reset_run
run TYPESAFE_API_KEY=stub-key TYPESAFE_STUB_VERDICT=needs-operator
chk "g: operator-item queue row filed" "$(ident_count "arc-to-slice-op:arc-$today8-opcall")" "1"

# --- h) no-slice verdict -> no row, decision recorded ---------------------
seed
doc_h="$(arc_doc arc-$today8-none)"
printf 'arc-%s-none\tparked\tparked -- nothing actionable\tmodel:test\t%s\t%s\ts\to\tf\n' \
 "$today8" "$doc_h" "$today" >>"$sb/research-dispositions.tsv"
line_row "arc-$today8-none" reviewed
reset_run
run TYPESAFE_API_KEY=stub-key TYPESAFE_STUB_VERDICT=no-slice
chk "h: no-slice files no row" "$(bodies)" "0"
chk "h: no-slice decision recorded" "$(state | grep -c "arc-$today8-none")" "1"

# --- i) planned (never-crystallized) line -> no row -----------------------
seed
doc_i="$(arc_doc arc-$today8-planned)"
printf 'arc-%s-planned\tparked\tparked -- premature\tmodel:test\t%s\t%s\ts\to\tf\n' \
 "$today8" "$doc_i" "$today" >>"$sb/research-dispositions.tsv"
line_row "arc-$today8-planned" planned
reset_run
run TYPESAFE_API_KEY=stub-key TYPESAFE_STUB_VERDICT=landable-slice
chk "i: never-crystallized line skipped" "$(bodies)" "0"

# --- j) malformed tsv row -> fail-closed skip, good row still converts ----
seed
doc_j="$(arc_doc arc-$today8-good)"
printf 'arc-%s-good\tparked\tparked -- convertible\tmodel:test\t%s\t%s\ts\to\tf\n' \
 "$today8" "$doc_j" "$today" >>"$sb/research-dispositions.tsv"
printf 'broken-row\tkilled\n' >>"$sb/research-dispositions.tsv"
line_row "arc-$today8-good" reviewed
reset_run
rc=0
run TYPESAFE_API_KEY=stub-key TYPESAFE_STUB_VERDICT=landable-slice || rc=$?
chk "j: beat exits 0 past malformed row" "$rc" "0"
chk "j: no row for malformed arc" "$(ident_count "broken-row")" "0"
chk "j: well-formed arc still converts" "$(ident_count "arc-to-slice:arc-$today8-good")" "1"

echo "test-arc-to-slice: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
