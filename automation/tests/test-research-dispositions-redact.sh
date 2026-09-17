#!/usr/bin/env bash
# test-research-dispositions-redact.sh -- the research-dispositions.tsv
# append seam must run redact_home over every free-text column BEFORE the
# printf (2026-09-17 seam cure; forward-only, no history rewrite). The
# sink-side ingest fix (2e51d01b) redacts at MCP read time, but the TSV is
# git-tracked and pushed publicly (research_commit -> KERNEL), so three
# post-fix rows (latest 732331a7) still carry raw /home/<user> paths in
# evidence (col5) and model-echoed raw paths in support/oppose (cols
# 7/8) -- lib/research-harvest.py then interpolates disp['evidence'] into
# research-lessons.tsv and the vault pages, propagating the leak onward.
# Sources the REAL redact.sh single-source tilde renderer against a
# sandbox AUTOMATION_ROOT; hermetic: no model calls, no kernel repo, no
# real ledger writes.
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"
sb="$(mktemp -d)"
cleanup() { rm -rf "$sb"; }
trap cleanup EXIT
fails=0
ck() {
  if [ "$2" = "$3" ]; then echo "ok: $1"; else
    echo "FAIL: $1 (want [$2] got [$3])"
    fails=$((fails + 1))
  fi
}

# real redaction single source (scrub.sh resolves scrub.py via
# AUTOMATION_ROOT; redact_home is the tilde-rendering form)
export AUTOMATION_ROOT="$root"
# shellcheck disable=SC1090,SC1091
. "$root/lib/redact.sh"
type redact_home >/dev/null 2>&1 || { echo "FAIL: redact_home not sourced"; exit 1; }
breadcrumb() { :; } # extracted impl breadcrumbs the withheld-row path
JOB_NAME="research-dispositions-redact-test" # breadcrumb ledger name

DISPOSITIONS="$sb/research-dispositions.tsv"
schema='line	action	verdict	reviewer	evidence	date	support	oppose	followons'
printf '%b\n' "$schema" >"$DISPOSITIONS"

# the EXACT append seam from the beat script: flatten tabs, then
# redact_home every free-text column (verdict col3 / evidence col5 /
# support col7 / oppose col8 / followons col9 -- all model output), then
# append. Extracted from the beat script (brace-anchored awk, single
# source of truth -- the same technique as
# test-research-beat-ingest-redact.sh), NOT copied here, so seam drift
# cannot silently un-redact the sink. id (col1), reviewer (col4) and
# date (col6) are beat-generated and pass through untouched.
append_disposition() { # id action reason used doc day sup opp followons
 local id="$1" action="$2" reason="$3" used="$4" doc="$5" day="$6"
 local sup_line="$7" opp_line="$8" followons="${9:-}"
 append_disposition_impl "$id" "$action" "$reason" "$used" "$doc" "$day" \
  "$sup_line" "$opp_line" "$followons"
}
beat="$root/cadence/hour/33-research-beat.sh"
awk '/^append_disposition_impl\(\) \{/{f=1} f{print} f&&/^\}$/{exit}' \
 "$beat" >"$sb/append_disposition_impl.sh"
grep -q '^append_disposition_impl()' "$sb/append_disposition_impl.sh" || {
 echo "FAIL: append_disposition_impl extraction from beat script"; exit 1
}
# shellcheck disable=SC1090
. "$sb/append_disposition_impl.sh"

# (a) the committed-leak shape: raw /home path in a fake verdict AND
# evidence column must land tilde-rendered in the TSV row.
append_disposition "fail-20260917-a" "parked" \
 "parked -- cannot verify the gate in /home/testuser/Projects/etc/hngh" \
 "test-model" "/home/testuser/Projects/etc/hngh/docs/x.md" "20260917" \
 "support cites /home/testuser/Projects/etc/hngh files" \
 "oppose echoes /home/testuser/Projects/etc/hngh too" \
 "followon touches /home/testuser/Projects/etc/hngh"
row="$(tail -n 1 "$DISPOSITIONS")"
ck "a: 9 columns intact" "9" "$(printf '%s' "$row" | awk -F'\t' '{print NF}')"
for col in 3 5 7 8 9; do
 v="$(printf '%s' "$row" | cut -f"$col")"
 case "$v" in
  *'/home/testuser'*) ck "a: col$col redacted" "no /home/testuser" "leak: $v" ;;
  *'~/Projects/etc/hngh'*) ck "a: col$col tilde-rendered" "~/ present" "~/ present" ;;
  *) ck "a: col$col tilde-rendered" "~/Projects/etc/hngh present" "missing: $v" ;;
 esac
done
ck "a: generated cols untouched" \
 "fail-20260917-a	parked	model:test-model	20260917" \
 "$(printf '%s' "$row" | cut -f1,2,4,6)"

# (b) /tmp paths become ~tmp in the free-text columns.
append_disposition "fail-20260917-b" "adopted" \
 "adopted -- script lives in /tmp/scratch-build" \
 "test-model" "/tmp/scratch-build/out.md" "20260917" \
 "see /tmp/scratch-build log" "no /tmp/scratch-build conflict" ""
rowb="$(tail -n 1 "$DISPOSITIONS")"
for col in 3 5 7 8; do
 vb="$(printf '%s' "$rowb" | cut -f"$col")"
 case "$vb" in
  *'/tmp/scratch-build'*) ck "b: col$col tmp redacted" "no /tmp/scratch-build" "leak: $vb" ;;
  *'~tmp/scratch-build'*) ck "b: col$col ~tmp rendered" "~tmp present" "~tmp present" ;;
  *) ck "b: col$col ~tmp rendered" "~tmp/scratch-build present" "missing: $vb" ;;
 esac
done

# (c) the exact live-leak rendering: the format-string question evidence
# (732331a7 shape) must come out tilde-form, byte-identical to what a
# clean row should carry.
append_disposition "fail-20260916-What-is-the-exact-format-string-used-by-" \
 "parked" \
 "parked -- Core question unresolved due to lack of tool execution" \
 "test-model" \
 "/home/testuser/Projects/etc/hngh/docs/records/2026-09-16-x.md" \
 "20260917" "" ""
rowc="$(tail -n 1 "$DISPOSITIONS")"
ck "c: 732331a7-shape evidence tilde-rendered" \
 "~/Projects/etc/hngh/docs/records/2026-09-16-x.md" \
 "$(printf '%s' "$rowc" | cut -f5)"
case "$(printf '%s' "$rowc" | cut -f5)" in
 *'/home/testuser'*) ck "c: no raw path survives" "clean" "leak" ;;
 *) ck "c: no raw path survives" "clean" "clean" ;;
esac

# (d) repo-relative and already-tilde'd text is idempotent: no mangling,
# no double rewrite (~~), and a re-appended clean row stays clean.
append_disposition "fail-20260917-d" "parked" \
 "parked -- see automation/lib/redact.sh and ~/Projects/etc/hngh notes" \
 "test-model" "~/Projects/etc/hngh/docs/notes.md" "20260917" \
 "automation/lib/redact.sh unchanged" "no ~~ doubling expected" ""
rowd="$(tail -n 1 "$DISPOSITIONS")"
ck "d: evidence tilde idempotent" "~/Projects/etc/hngh/docs/notes.md" \
 "$(printf '%s' "$rowd" | cut -f5)"
case "$(printf '%s' "$rowd" | cut -f3)" in
 *'~~'*) ck "d: no double rewrite" "no ~~" "doubled" ;;
 *'automation/lib/redact.sh'*) ck "d: repo-relative untouched" "clean" "clean" ;;
 *) ck "d: repo-relative untouched" "present" "missing" ;;
esac

# (e) fail-closed seam: redact_home yielding empty (broken scrub backend
# behind the shim) must NOT append a raw-path row -- empty output wins.
redact_home() { :; } # simulate shim fail-closed (empty stdout)
pre="$(wc -l <"$DISPOSITIONS")"
append_disposition "fail-20260917-e" "parked" \
 "parked -- raw /home/testuser/Projects/etc/hngh verdict" \
 "test-model" "/home/testuser/Projects/etc/hngh/docs/y.md" "20260917" \
 "" "" "" 2>/dev/null
ck "e: broken guard appends nothing" "$pre" "$(wc -l <"$DISPOSITIONS")"
grep -q '/home/testuser' "$DISPOSITIONS" 2>/dev/null &&
  { ck "e: no raw path in tsv" "clean" "leak"; } ||
  ck "e: no raw path in tsv" "clean" "clean"

echo "---"
[ "$fails" -eq 0 ] && echo "ALL PASS" || {
  echo "$fails FAILED"
  exit 1
}
