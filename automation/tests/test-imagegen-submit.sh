#!/usr/bin/env bash
# test-imagegen-submit.sh -- hermetic proof for the imagegen P0 driver
# (jobs/imagegen-submit.sh): the style TSV parses (7 columns, 3 seeded
# rows, no artist names in prompts), --list-styles works, prompt
# URL-encoding is correct, the free leg honours the filename convention
# and body-magic sniffing, a dead endpoint and a garbage body fail
# closed with no partial files, the timeout cap reaches curl, and an
# empty endpoint row skips exit-0. No real network: curl is stubbed via
# PATH.
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"
sb="$(mktemp -d)"
trap 'rm -rf "$sb"' EXIT
mkdir -p "$sb/automation/config" "$sb/automation/lib" "$sb/automation/jobs" \
  "$sb/docs/media/imagegen" "$sb/shim"
ln -s "$root/lib/params.sh" "$sb/automation/lib/params.sh"
ln -s "$root/jobs/imagegen-submit.sh" "$sb/automation/jobs/imagegen-submit.sh"
cp "$root/config/imagegen-styles.tsv" "$sb/automation/config/imagegen-styles.tsv"
: >"$sb/curl-hits"

# curl stub: records full argv to $CURL_STUB_HITS (last arg = URL),
# prints the emulated HTTP code on stdout, and in non-dead modes writes
# a body to the -o target.
cat >"$sb/shim/curl" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"${CURL_STUB_HITS:?}"
mode="${CURL_STUB_MODE:-ok-png}"
[ "$mode" = dead ] && exit 7
out=""
prev=""
for a in "$@"; do
  [ "$prev" = -o ] && out="$a"
  prev="$a"
done
case "$mode" in
  ok-png) printf '\x89PNG\r\n\x1a\nSTUBBODY' >"$out" ;;
  ok-jpeg) printf '\xff\xd8\xff\xe0STUBJPG' >"$out" ;;
  garbage) printf 'not an image at all' >"$out" ;;
esac
echo 200
EOF
chmod +x "$sb/shim/curl"

fails=0
ck() { # desc expected actual
  if [ "$2" = "$3" ]; then echo "ok: $1"; else
    echo "FAIL: $1 (want [$2] got [$3])"
    fails=$((fails + 1))
  fi
}
run() { # args... -> stdout; stderr passes through for the caller to catch
  (
    export PATH="$sb/shim:$PATH"
    export IMAGEGEN_STYLES_TSV="$sb/automation/config/imagegen-styles.tsv"
    export IMAGEGEN_OUT_DIR="${TEST_OUT_DIR:-$sb/docs/media/imagegen}"
    export CURL_STUB_HITS="$sb/curl-hits"
    unset IMAGEGEN_URL IMAGEGEN_POLLINATIONS_BASE
    bash "$sb/automation/jobs/imagegen-submit.sh" "$@"
  )
}

tsv="$root/config/imagegen-styles.tsv"

# 1. committed TSV parses: 3 data rows, exactly 7 columns, lora slots
# empty in the seed rows, and no artist names anywhere in the prompts.
ck "tsv: 3 data rows" "3" \
  "$(awk -F'\t' '$1 !~ /^#/ && NF {print}' "$tsv" | wc -l)"
ck "tsv: every data row has >=6 columns" "" \
  "$(awk -F'\t' '$1 !~ /^#/ && NF && NF < 6 {print $1}' "$tsv")"
ck "tsv: lora slots empty in seed rows" "" \
  "$(awk -F'\t' '$1 !~ /^#/ && $7 != "" {print $1}' "$tsv")"
ck "tsv: no artist names in prompts" "0" \
  "$(awk -F'\t' '$1 !~ /^#/ {print tolower($5)}' "$tsv" |
    grep -ci 'nihei\|hayashida\|matsumoto' || true)"

# 2. --list-styles
ck "list-styles: three ids" "hero-banner
section-spacer
environment" "$(run --list-styles)"

# 3. free leg, happy path (PNG stub): exit 0, conventional filename,
# PNG magic preserved, status line points at the written file.
rm -f "$sb/curl-hits"
status="$(run --free --style hero-banner --subject 'test hall')"
rc=$?
ck "free leg: exit 0" "0" "$rc"
png="$(ls "$sb/docs/media/imagegen" 2>/dev/null | head -1)"
case "$png" in hero-banner-????????T??????Z.png) ck "free leg: filename convention" ok ok ;;
*) ck "free leg: filename convention" "hero-banner-<UTC-ts>.png" "${png:-<none>}" ;; esac
case "$status" in *"docs/media/imagegen/$png"*) ck "free leg: status names the file" ok ok ;;
*) ck "free leg: status names the file" "path in status line" "missing" ;; esac
magic="$(head -c 4 "$sb/docs/media/imagegen/$png" | od -An -tx1 | tr -d ' \n')"
ck "free leg: png magic preserved" "89504e47" "$magic"

# 4. URL shape and prompt encoding: one '?', exactly three '&' (width/
# height/seed separators; params only -- any raw '&' in the prompt
# would have broken the query),
# spaces -> %20, subject substituted into the template, seed and size
# pair taken from the row.
url="$(tail -1 "$sb/curl-hits")"
ck "url: single query separator" "1" "$(printf '%s' "$url" | tr -cd '?' | wc -c)"
ck "url: exactly three '&' (param separators)" "3" "$(printf '%s' "$url" | grep -o '&' | wc -l)"
ck "url: row params" "width=1536&height=512&seed=511&nologo=true" \
  "${url#*\?}"
case "$url" in *'test%20hall'*) ck "url: subject encoded+substituted" ok ok ;;
*) ck "url: subject encoded+substituted" "test%20hall present" "missing" ;; esac
rm -f "$sb/curl-hits"
run --free --style hero-banner --subject 'moss & bone' >/dev/null 2>&1
url2="$(tail -1 "$sb/curl-hits")"
case "$url2" in *'moss%20%26%20bone'*) ck "url: ampersand encoded" ok ok ;;
*) ck "url: ampersand encoded" "moss%20%26%20bone present" "missing" ;; esac
ck "url: ampersand still exactly three" "3" "$(printf '%s' "$url2" | grep -o '&' | wc -l)"

outdir="$sb/docs/media/imagegen"

# 5. dead endpoint (curl exit 7 -> HTTP 000): fail-closed exit 1,
# stderr note, no file and no temp leftovers.
rm -f "$outdir"/*.png "$outdir"/.imagegen-* "$sb/curl-hits"
err="$(CURL_STUB_MODE=dead run --free --style hero-banner --subject 'x' 2>&1 >/dev/null)"
rc=$?
ck "dead endpoint: exit 1" "1" "$rc"
case "$err" in *'fail-closed'*) ck "dead endpoint: stderr note" ok ok ;;
*) ck "dead endpoint: stderr note" "fail-closed note" "missing" ;; esac
ck "dead endpoint: no output files" "" "$(ls "$outdir" 2>/dev/null)"
ck "dead endpoint: no temp leftovers" "" "$(ls -A "$outdir" 2>/dev/null)"

# 6. HTTP 200 with a garbage body: fail-closed, nothing written.
rm -f "$outdir"/* "$outdir"/.imagegen-* 2>/dev/null
err="$(CURL_STUB_MODE=garbage run --free --style hero-banner --subject 'x' 2>&1 >/dev/null)"
rc=$?
ck "garbage body: exit 1" "1" "$rc"
ck "garbage body: no output files" "" "$(ls -A "$outdir" 2>/dev/null)"

# 7. the timeout cap reaches curl: --max-time <IMAGEGEN_TIMEOUT> in argv.
rm -f "$sb/curl-hits"
IMAGEGEN_TIMEOUT=7 run --free --style hero-banner --subject 'x' >/dev/null 2>&1
case "$(tail -1 "$sb/curl-hits")" in
*'--max-time 7'*) ck "timeout cap passed to curl" ok ok ;;
*) ck "timeout cap passed to curl" "--max-time 7 in argv" "missing" ;; esac

# 8. empty endpoint row (no --free): leg skipped, exit 0, zero curl calls.
rm -f "$sb/curl-hits"
err="$(run --style hero-banner --subject 'x' 2>&1 >/dev/null)"
rc=$?
ck "empty endpoint row: exit 0" "0" "$rc"
case "$err" in *'skipped fail-closed'*) ck "empty endpoint row: skip note" ok ok ;;
*) ck "empty endpoint row: skip note" "skip note" "missing" ;; esac
ck "empty endpoint row: no curl call" "" "$(cat "$sb/curl-hits" 2>/dev/null)"

# 9. unknown style is a caller error, not a network event.
run --free --style nope --subject 'x' >/dev/null 2>&1
rc=$?
ck "unknown style: exit 2" "2" "$rc"

rm -rf "$outdir" "$sb/curl-hits"
[ "$fails" = 0 ] && echo "test-imagegen-submit: all pass" || {
  echo "test-imagegen-submit: $fails failure(s)"
  exit 1
}
