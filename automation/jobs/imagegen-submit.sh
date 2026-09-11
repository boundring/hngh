#!/usr/bin/env bash
# imagegen-submit.sh -- submit one image-generation job for a style row in
# automation/config/imagegen-styles.tsv.
#
# Interface (design docs/research/2026-09-11-imagegen-integration.md s4/s6):
#   imagegen-submit.sh --list-styles
#   imagegen-submit.sh [--free] --style <style-id> --subject "<text>" \
#       [--out-dir DIR] [--timeout S]
#
# Legs:
#   --free  keyless remote bootstrap leg: GET
#           {base}/{urlencoded prompt}?width=W&height=H&seed=S&nologo=true
#           against image.pollinations.ai (probe-verified HTTP 200 with an
#           image, no key, 2026-09-11). Remote, so the VRAM/load gates DO
#           NOT apply. Honest caveats: third-party service, prompts leave
#           the machine, no SLA -- fail-closed bootstrap, never primary.
#   else    local operator-run ComfyUI: endpoint = env IMAGEGEN_URL
#           (overrides) or the cadence-params row `imagegen-endpoint`.
#           Empty row AND no env = leg skipped fail-closed, exit 0
#           (exactly deck-model-endpoint semantics in lib/model.sh).
#           STUBBED in P0 -- the POST /prompt -> poll /history -> fetch
#           /view path and the VRAM/load/night-beat gates land after the
#           operator repair (torch wheel + checkpoint, design s6); until
#           then an armed-but-stubbed leg exits 1 with a note. The
#           VRAM/load gate checks below are live for the day the stub
#           goes real; the night-beat tenancy gate needs the cadence
#           schedule and is deferred to that cutover (design s4 gate 3).
#
# Fail-closed everywhere: non-200/timeout -> exit 1 + stderr note, no
# partial files (temp file + atomic mv on success only). The free leg
# answers JPEG regardless of the .png request path (probe-verified), so
# the driver sniffs the body magic: PNG passes through, JPEG is
# normalized to PNG with magick (system binary) when present, anything
# else (or no magick) fails closed.
# Output: docs/media/imagegen/<style-id>-<UTC-timestamp>.png.
# Test seams: IMAGEGEN_OUT_DIR, IMAGEGEN_STYLES_TSV, IMAGEGEN_TIMEOUT,
# IMAGEGEN_URL, IMAGEGEN_POLLINATIONS_BASE, IMAGEGEN_LOADAVG_FILE,
# IMAGEGEN_VRAM_MAX_USED (tests stub curl via PATH).
set -u

aut="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$aut/lib/params.sh"

tsv="${IMAGEGEN_STYLES_TSV:-$aut/config/imagegen-styles.tsv}"
out_dir="${IMAGEGEN_OUT_DIR:-$(cd "$aut/.." && pwd)/docs/media/imagegen}"
timeout_s="${IMAGEGEN_TIMEOUT:-120}"
poll_base="${IMAGEGEN_POLLINATIONS_BASE:-https://image.pollinations.ai/prompt}"
free=0 style="" subject=""

while [ $# -gt 0 ]; do
  case "$1" in
  --free) free=1 ;;
  --style)
    style="${2:?--style needs a value}"
    shift
    ;;
  --subject)
    subject="${2:?--subject needs a value}"
    shift
    ;;
  --out-dir)
    out_dir="${2:?--out-dir needs a value}"
    shift
    ;;
  --timeout)
    timeout_s="${2:?--timeout needs a value}"
    shift
    ;;
  --list-styles)
    [ -f "$tsv" ] || {
      echo "imagegen: styles tsv missing: $tsv" >&2
      exit 1
    }
    awk -F'\t' '$1 !~ /^#/ && NF >= 6 {print $1}' "$tsv"
    exit 0
    ;;
  *)
    echo "imagegen: unknown argument: $1" >&2
    exit 2
    ;;
  esac
  shift
done

[ -n "$style" ] || {
  echo "imagegen: --style required (or --list-styles)" >&2
  exit 2
}
[ -f "$tsv" ] || {
  echo "imagegen: styles tsv missing: $tsv" >&2
  exit 1
}
row="$(awk -F'\t' -v s="$style" '$1==s && NF>=6 {print; exit}' "$tsv")"
[ -n "$row" ] || {
  echo "imagegen: unknown style: $style (try --list-styles)" >&2
  exit 2
}
size_pair="$(printf '%s' "$row" | cut -f3)"
seed="$(printf '%s' "$row" | cut -f4)"
template="$(printf '%s' "$row" | cut -f5)"
w="${size_pair%x*}"
h="${size_pair#*x}"

case "$template" in
*'{SUBJECT}'*)
  [ -n "$subject" ] || {
    echo "imagegen: style '$style' needs --subject" >&2
    exit 2
  }
  # prefix/suffix splice, not ${var//pat/repl}: bash 5.2+ patsub
  # replacement turns a literal '&' in the subject into the matched
  # placeholder.
  prompt="${template%%\{SUBJECT\}*}${subject}${template#*\{SUBJECT\}}"
  ;;
*) prompt="$template" ;;
esac

if [ "$free" -ne 1 ]; then
  endpoint="${IMAGEGEN_URL:-$(get_param imagegen-endpoint '')}"
  if [ -z "$endpoint" ]; then
    echo "imagegen: imagegen-endpoint row empty and IMAGEGEN_URL unset -- local leg skipped fail-closed (use --free for the keyless bootstrap leg)" >&2
    exit 0
  fi
  # local-leg-only gates (--free is remote; design s4). Skip = exit 0.
  if ! command -v rocm-smi >/dev/null 2>&1; then
    echo "imagegen: VRAM gate: rocm-smi unavailable -- skip" >&2
    exit 0
  fi
  vram_used="$(rocm-smi --showmeminfo vram 2>/dev/null |
    awk '/^GPU\[0\]/ && /Used Memory/ {print $NF; exit}')"
  [ -n "$vram_used" ] || {
    echo "imagegen: VRAM gate: no GPU-0 reading -- skip" >&2
    exit 0
  }
  awk -v u="$vram_used" -v t="${IMAGEGEN_VRAM_MAX_USED:-4294967296}" \
    'BEGIN{exit !(u < t)}' || {
    echo "imagegen: VRAM gate: GPU-0 ${vram_used}B used >= threshold (text model resident) -- skip" >&2
    exit 0
  }
  load="$(cut -d' ' -f1 "${IMAGEGEN_LOADAVG_FILE:-/proc/loadavg}")"
  awk -v l="$load" -v c="${IMAGEGEN_LOAD_CEILING:-$(get_param research-load-ceiling 0.7)}" -v n="$(nproc)" \
    'BEGIN{exit !(l < c * n)}' || {
    echo "imagegen: load gate: loadavg1 $load busy -- skip" >&2
    exit 0
  }
  # P0 stub: the real POST /prompt -> poll /history -> fetch /view path
  # lands at the operator-repair cutover together with the night-beat
  # tenancy gate (design s4 gate 3, s6 repair sequence).
  echo "imagegen: local ComfyUI leg is a P0 stub -- POST/poll/fetch lands after the operator repair (design s6); endpoint: $endpoint" >&2
  exit 1
fi

# --- free bootstrap leg (pollinations, keyless GET) ---
enc="$(jq -rn --arg s "$prompt" '$s|@uri')" || {
  echo "imagegen: jq url-encode failed" >&2
  exit 1
}
url="${poll_base}/${enc}?width=${w}&height=${h}&seed=${seed}&nologo=true"

mkdir -p "$out_dir" || exit 1
ts="$(date -u +%Y%m%dT%H%M%SZ)"
while [ -e "$out_dir/${style}-${ts}.png" ]; do
  sleep 1
  ts="$(date -u +%Y%m%dT%H%M%SZ)"
done
out="$out_dir/${style}-${ts}.png"
tmp="$(mktemp "$out_dir/.imagegen-XXXXXX")" || exit 1

code="$(curl -sS --max-time "$timeout_s" -o "$tmp" -w '%{http_code}' "$url" 2>/dev/null)" || code=000
if [ "$code" != "200" ]; then
  echo "imagegen: pollinations HTTP ${code:-000} (style $style, timeout ${timeout_s}s) -- fail-closed" >&2
  rm -f "$tmp"
  exit 1
fi

magic="$(head -c 8 "$tmp" | od -An -tx1 | tr -d ' \n')"
case "$magic" in
89504e470d0a1a0a)
  mv "$tmp" "$out"
  ;;
ffd8*)
  if command -v magick >/dev/null 2>&1 &&
    magick "$tmp" "$tmp.png" 2>/dev/null && [ -s "$tmp.png" ]; then
    rm -f "$tmp"
    mv "$tmp.png" "$out"
  else
    echo "imagegen: free leg returned JPEG and magick absent/failed -- fail-closed" >&2
    rm -f "$tmp"
    exit 1
  fi
  ;;
*)
  echo "imagegen: pollinations HTTP 200 but body is neither PNG nor JPEG -- fail-closed" >&2
  rm -f "$tmp"
  exit 1
  ;;
esac

echo "imagegen: wrote $out (style $style, ${w}x${h}, seed $seed, HTTP $code)"
