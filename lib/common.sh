# common.sh — shared bootstrap for every job and lib.
# Sources config.env, defines AUTOMATION_ROOT, prompt builder, dashboard
# updater. Every script MUST source this first (before any other lib).
set -u

AUTOMATION_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
[ -f "$AUTOMATION_ROOT/config.env" ] && . "$AUTOMATION_ROOT/config.env"

JOB_NAME="${JOB_NAME:-$(basename "$0")}"

log() { # console line (breadcrumbs are separate)
 printf '%s [%s] %s\n' "$(date -u +%H:%M:%S)" "$JOB_NAME" "${*-}" >&2
}

mkdir -p "$AUTOMATION_ROOT/snapshots" "$AUTOMATION_ROOT/digest" \
 "$AUTOMATION_ROOT/archive" "$AUTOMATION_ROOT/dashboard"

# newest snapshot file for a source in a day dir ("" if none).
# Filenames are <name>-<HHMM>.json; iterate the sorted glob and keep the last
# match (= highest HHMM = newest). Optional 3rd arg excludes a filename (the
# file this run just wrote) so "previous" means the run before it.
newest_snapshot() { # dir name [exclude] -> path|empty
 local d="$1" n="$2" x="${3:-}" f newest=""
 for f in "$d"/"$n"-[0-9][0-9][0-9][0-9].json; do
  [ -e "$f" ] || continue
  [ "$(basename "$f")" = "$x" ] && continue
  newest="$f"
 done
 printf '%s' "$newest"
}

# format one snapshot as a bounded prompt block: "--- name ---\ncontent"
source_block() { # file budget -> stdout
 local f="$1" budget="$2" name
 [ -n "$f" ] || return 0
 name="$(basename "$f" | sed -E 's/^([^-]+)-[0-9]{4}\.json$/\1/')"
 printf '%s\n%s\n' "--- $name ---" "$(marked_cut "$budget" "$f")"
}

# bounded read that never lies: like head -c, but appends a visible
# "[truncated at N bytes]" marker when the input was longer. An unmarked
# mid-word cut reads as a corrupted file to model consumers — review
# findings 55db79ae ("plan supply r") and 622e68f0 ("is an un") were
# phantoms from exactly this: the packet cap, not the file, was cut.
# ponytail: buffers the whole input (packets here are <= ~64KB); stream
# with split if a huge corpus ever needs this.
marked_cut() { # bytes [file] -> stdout (stdin when no file)
 local bytes="$1" f="${2:--}" data n
 data="$(cat "$f" 2>/dev/null)" || return 0
 n="$(printf '%s' "$data" | wc -c)"
 if [ "$n" -gt "$bytes" ]; then
  printf '%s' "$data" | head -c "$bytes"
  printf '\n[truncated at %s bytes]' "$bytes"
 else
  printf '%s' "$data"
 fi
}

# build the summarization prompt on stdout.
# usage: build_prompt DAY NAMES MAX_WORDS MODE   (MODE=ping|morning)
build_prompt() {
 local day="$1" names="$2" max_words="$3" mode="$4"
 local dir="$AUTOMATION_ROOT/snapshots/$day" n budget name
 n="$(printf '%s\n' "$names" | grep -c . || true)"
 [ "${n:-0}" -gt 0 ] 2>/dev/null || n=1
 budget=$((MAX_SOURCE_CHARS / n))
 printf 'You write Hngh'"'"'s hourly dispatch. Below are raw JSON snapshots from an aggregator.\n'
 if [ "$mode" = "ping" ]; then
  printf 'Register: captions in the margin of a quiet megastructure. Evidence first; commentary never. Report only what is NEW in at most %s words, three tiers:\n' "$max_words"
 else
  printf 'Register: captions in the margin of a quiet megastructure. Evidence first; commentary never. Summarize everything reported so far today in at most %s words, three tiers:\n' "$max_words"
 fi
 printf '[CRITICAL] active exploitation or human harm (1-3 bullets)\n'
 printf '[NOTABLE] self-hosting/infrastructure relevance (3-5 bullets)\n'
 printf '[CONTEXT] background (2-4 bullets)\n'
 printf 'Rules:\n'
 printf '%s\n' '- One line per item: a plain declarative sentence with concrete nouns. No significance adjectives (banned: historic, significant, major, groundbreaking, "sparking discussion"). No editorializing about what a thing means.'
 printf '%s\n' '- Quote proper nouns verbatim from the sources: companies, products, codenames, place names. Never paraphrase, respell, or guess a name; if unsure, drop the item.'
 printf '%s\n' '- Citations: when an item in the snapshot JSON carries a url, end that item line with the bare URL in parentheses, like (https://example.com/post). Never invent, shorten, or reformat a URL; omit the parentheses when the item has none.'
 printf '%s\n' '- Items under ALREADY REPORTED are old; repeat one only if its state changed (new severity, resolution, escalation, or a material fact added).'
 printf '%s\n' '- If nothing is new, return exactly: none — quiet window'
 printf 'Plain text only: one bullet per line, each starting with CRITICAL:/NOTABLE:/CONTEXT:. Bare prefix, colon, space; nothing else on the line. No markdown headers, no preamble, no trailing commentary.\n\n'
 for name in $names; do
  source_block "$(newest_snapshot "$dir" "$name")" "$budget"
 done
}

# regenerate dashboard/data.json — the ONLY dynamic dashboard artifact.
# usage: update_dashboard JOB DAY TIME
update_dashboard() {
 local job="$1" day="$2" t="$3" runs=0
 [ -d "$HNGH_STORE" ] && runs="$(find "$HNGH_STORE" -name record.lisp -type f 2>/dev/null | wc -l)"
 python3 - "$job" "$day" "$t" "$runs" \
  "$AUTOMATION_ROOT/digest/MORNING-$day.md" \
  "$AUTOMATION_ROOT/digest/$day.md" \
  "$AUTOMATION_ROOT/STATE.md" \
  "$AUTOMATION_ROOT/dashboard/data.json" <<'PY'
import datetime, json, os, sys
job, day, t, runs, morning, ping, state, outpath = sys.argv[1:9]
out = {
    "generated_at": datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
    "job": job, "date": day, "time": t,
    "hngh_runs": int(runs),
    "digest": "", "breadcrumbs": [],
}
parts = []
for f in (ping, morning):  # newest block first: today's digest, its morning report
    if f and os.path.exists(f):
        parts.append(open(f, errors="replace").read())
digest = "\n\n".join(parts)
if len(digest) > 20000:  # never cut mid-token: break on a whitespace boundary
    digest = digest[:20000].rsplit(None, 1)[0]
    if not digest:  # degenerate: no whitespace in the window; keep the hard cut
        digest = "\n\n".join(parts)[:20000]
    digest += "\n\u2026"
out["digest"] = digest
crumbs = []
if os.path.exists(state):
    for ln in open(state, errors="replace"):
        p = [x.strip() for x in ln.rstrip("\n").split("|", 3)]
        if len(p) == 4:
            crumbs.append({"ts": p[0], "job": p[1], "event": p[2], "detail": p[3]})
out["breadcrumbs"] = crumbs[-60:]
tmp = "%s.%d.tmp" % (outpath, os.getpid())
with open(tmp, "w") as fh:
    json.dump(out, fh, indent=1)
    fh.write("\n")
os.replace(tmp, outpath)
PY
 if declare -F breadcrumb >/dev/null 2>&1; then
  breadcrumb "$job" "dashboard" "data.json regenerated ($day $t, hngh runs=$runs)"
 fi
}
