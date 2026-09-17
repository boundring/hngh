#!/usr/bin/env bash
# test-research-beat-ingest-redact.sh -- the research-beat ingest seams
# (ensure_lines + followon_queue) must run redact_home over question text
# BEFORE id/slug derivation and BEFORE any write into research-lines.tsv
# / research-subjects.txt (2026-09-17 source-side path-token cure: the
# TSVs are git-tracked and pushed publicly, so the sink-side report-queue
# control can never cover this seam; the leaked
# fail-20260914-Where-exactly-in-home-bricker-Projects-e id proves the
# leak happens at/before derivation). Sources the REAL functions out of
# the cadence script (brace-anchored awk extraction, single source of
# truth -- the same technique as test-config-backup-fail-redact.sh) and
# the REAL lib/redact.sh, against a sandbox AUTOMATION_ROOT. Hermetic:
# no model calls, no kernel repo, no real ledger writes.
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

JOB_NAME="research-beat-ingest-test"
breadcrumb() { :; } # extracted functions only breadcrumb the seed count

# extract exactly the script's real ingest seams (first column-1 closing
# brace after each header, so line drift above/between cannot break the
# cut)
awk '/^ensure_lines\(\) \{/{f=1} f{print} f&&/^\}$/{exit}' \
  "$root/cadence/hour/33-research-beat.sh" >"$sb/ensure_lines.sh"
awk '/^followon_queue\(\) \{/{f=1} f{print} f&&/^\}$/{exit}' \
  "$root/cadence/hour/33-research-beat.sh" >"$sb/followon_queue.sh"
grep -q '^ensure_lines()' "$sb/ensure_lines.sh" || { echo "FAIL: ensure_lines extraction"; exit 1; }
grep -q '^followon_queue()' "$sb/followon_queue.sh" || { echo "FAIL: followon_queue extraction"; exit 1; }
# shellcheck disable=SC1090
. "$sb/ensure_lines.sh"
# shellcheck disable=SC1090
. "$sb/followon_queue.sh"

LINES="$sb/research-lines.tsv"
SUBJECTS="$sb/research-subjects.txt"
: >"$LINES"
: >"$SUBJECTS"

# (a) an absolute /home path in an explicit-id subject must land
# tilde-rendered in the TSV text column; the explicit id is preserved.
printf 'fail-20260917-a\tDoes the gate in /home/testuser/Projects/etc/hngh consume the make exit code?\n' >>"$SUBJECTS"
ensure_lines
row="$(tail -n 1 "$LINES")"
desc="$(printf '%s' "$row" | cut -f4)"
rid="$(printf '%s' "$row" | cut -f1)"
case "$desc" in
 *'/home/testuser'*) ck "a: lines.tsv text redacted" "no /home/testuser" "leak: $desc" ;;
 *'~/Projects/etc/hngh'*) ck "a: lines.tsv text tilde-rendered" "~/ present" "~/ present" ;;
 *) ck "a: lines.tsv text tilde-rendered" "~/Projects/etc/hngh present" "missing: $desc" ;;
esac
ck "a: explicit id preserved" "fail-20260917-a" "$rid"

# (a2) followon_queue: the rid/slug is DERIVED from the question text, so
# redaction must happen before derivation AND before the subjects append.
followon_queue <<'EOF' >"$sb/fq.out"
FOLLOWON: Where exactly in /home/testuser/Projects/etc/hngh does the plan gate consume stderr?
EOF
row2="$(tail -n 1 "$SUBJECTS")"
rid2="$(printf '%s' "$row2" | cut -f1)"
q2="$(printf '%s' "$row2" | cut -f2)"
case "$q2" in
 *'/home/testuser'*) ck "a2: subjects text redacted" "no /home/testuser" "leak: $q2" ;;
 *'~/Projects/etc/hngh'*) ck "a2: subjects text tilde-rendered" "~/ present" "~/ present" ;;
 *) ck "a2: subjects text tilde-rendered" "~/Projects/etc/hngh present" "missing: $q2" ;;
esac
case "$rid2" in
 *testuser*|*home-bricker*) ck "a2: derived rid redacted before slug" "no testuser" "leak: $rid2" ;;
 fail-20260917-Where-exactly-in-*) ck "a2: rid slug from redacted text" "clean" "clean" ;;
 *) ck "a2: rid slug from redacted text" "fail-20260917-Where-exactly-in-* shape" "missing: $rid2" ;;
esac

# (b) repo-relative path text lands unchanged (the guard must not mangle
# in-repo references).
printf 'fail-20260917-b\tShould automation/lib/redact.sh route through lib/scrub.py?\n' >>"$SUBJECTS"
ensure_lines
rowb="$(grep $'^fail-20260917-b\t' "$LINES")"
descb="$(printf '%s' "$rowb" | cut -f4)"
ck "b: repo-relative text unchanged" \
 "Should automation/lib/redact.sh route through lib/scrub.py?" "$descb"

# (c) already-tilde'd text is idempotent: no double rewrite, and reseeding
# dedups on the redacted text (no duplicate row).
printf 'fail-20260917-c\tDoes ~/Projects/etc/hngh pass the scrub guard?\n' >>"$SUBJECTS"
ensure_lines
rowc="$(grep $'^fail-20260917-c\t' "$LINES")"
descc="$(printf '%s' "$rowc" | cut -f4)"
ck "c: tilde text idempotent" "Does ~/Projects/etc/hngh pass the scrub guard?" "$descc"
case "$descc" in
 *'~~'*) ck "c: no double rewrite" "no ~~" "double: $descc" ;;
 *) ck "c: no double rewrite" "clean" "clean" ;;
esac
ensure_lines
ck "c: reseed dedups on redacted desc" "1" "$(grep -c $'^fail-20260917-c\t' "$LINES")"

# (d) /tmp paths become ~tmp in the text column.
printf 'fail-20260917-d\tWhat lives in /tmp/scratch-dir after the sweep?\n' >>"$SUBJECTS"
ensure_lines
rowd="$(grep $'^fail-20260917-d\t' "$LINES")"
deskd="$(printf '%s' "$rowd" | cut -f4)"
case "$deskd" in
 *'/tmp/scratch-dir'*) ck "d: /tmp redacted in text" "no /tmp/scratch-dir" "leak: $deskd" ;;
 *'~tmp/scratch-dir'*) ck "d: text tilde-tmp rendered" "~tmp present" "~tmp present" ;;
 *) ck "d: text tilde-tmp rendered" "~tmp/scratch-dir present" "missing: $deskd" ;;
esac

# (d2) tab-less subject: the id slug is derived from the text, so
# redaction must happen BEFORE that derivation too (this is exactly the
# fail-20260914-Where-exactly-in-home-bricker-Projects-e leak shape).
printf 'Check the exit-code consumer in /home/testuser/Projects/etc/hngh now\n' >>"$SUBJECTS"
ensure_lines
ridh="$(grep 'exit-code consumer' "$LINES" | cut -f1)"
case "$ridh" in
 *testuser*|*home-bricker*) ck "d2: tab-less id redacted before derivation" "no testuser" "leak: $ridh" ;;
 Check-the-exit-code-consumer-in-*) ck "d2: id slug from redacted text" "clean" "clean" ;;
 *) ck "d2: id slug from redacted text" "Check-the-exit-code-consumer-in-* shape" "missing: $ridh" ;;
esac

# (e) dash-mangled path fragment (the exact audited leak shape
# fail-20260914-Where-exactly-in-home-bricker-Projects-e): redact_home's
# token family matches slash forms only, so a pre-mangled dash-form
# question passed whole and the slug cut from it baked the username
# into the public id. The slug-cut path must additionally truncate
# dash-form pathy tokens at the stem (class/word prefix preserved).
followon_queue <<'EOF' >"$sb/fq2.out"
FOLLOWON: Where exactly in home-bricker-Projects-etc-hngh does the gate run?
EOF
rowe="$(tail -n 1 "$SUBJECTS")"
ride="$(printf '%s' "$rowe" | cut -f1)"
qe="$(printf '%s' "$rowe" | cut -f2)"
case "$ride" in
 *bricker*|*'-home-'*) ck "e: dash-form derived rid cut at stem" "no bricker/home token" "leak: $ride" ;;
 fail-20260917-Where-exactly-in*) ck "e: rid slug truncated at pathy token" "clean" "clean" ;;
 *) ck "e: rid slug truncated at pathy token" "fail-20260917-Where-exactly-in* shape" "missing: $ride" ;;
esac
case "$qe" in
 *bricker*) ck "e: dash-form question text cut at stem" "no bricker" "leak: $qe" ;;
 *) ck "e: dash-form question text cut at stem" "clean" "clean" ;;
esac

# (e2) fully path-derived dash-form input: truncation yields nothing ->
# nothing is written (fail closed, the refuse half of the contract).
before_e2="$(wc -l <"$SUBJECTS")"
followon_queue <<'EOF' >"$sb/fq3.out"
FOLLOWON: home-bricker-Projects-etc-hngh
EOF
ck "e2: whole-path-derived input refused" "$before_e2" "$(wc -l <"$SUBJECTS")"

# (f) tab-less subject whose TEXT carries the dash-form fragment: the id
# slug is derived from the text, so the cut must happen BEFORE that
# derivation too (same leak shape as d2, dash form).
printf 'Check the exit-code consumer in home-bricker-Projects-etc-hngh now\n' >>"$SUBJECTS"
ensure_lines
ridf="$(grep 'exit-code consumer' "$LINES" | tail -n 1 | cut -f1)"
case "$ridf" in
 *bricker*|*'-home-'*) ck "f: dash-form text-derived id cut at stem" "no bricker/home token" "leak: $ridf" ;;
 Check-the-exit-code-consumer-in*) ck "f: id slug truncated at pathy token" "clean" "clean" ;;
 *) ck "f: id slug truncated at pathy token" "Check-the-exit-code-consumer-in* shape" "missing: $ridf" ;;
esac

echo "---"
[ "$fails" -eq 0 ] && echo "ALL PASS" || {
  echo "$fails FAILED"
  exit 1
}
