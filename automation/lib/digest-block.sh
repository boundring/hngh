# digest-block.sh — shell-side digest writer seam (2026-09-16 writer
# census). Every bash lane that appends a block to the daily digest
# (archive/digest/<date>.md) routes the free-text parts of its block
# through append_news_block; scrub() re-exports the ONE identity seam,
# lib/scrub.py via scrub.sh (llc-gate-scrub-site-divergence
# consolidation 2026-09-16 — previously jobs/digest-ledger.py, which now
# imports the same module), so the shell writers and the Python writers
# cannot drift into different marker conventions. Redact at the writer,
# never at the reader: deck B, the email HTML part, the 0.0.0.0
# dashboard route, and the newspaper all render the file verbatim
# downstream. Sourced after common.sh (needs AUTOMATION_ROOT).
set -u

. "$AUTOMATION_ROOT/lib/scrub.sh"

digest_scrub() { # text -> text; host path tokens -> [redacted path]
 scrub_paths "$1"
}

digest_scrub_all() { # multi-line text (stdin) -> text, every line scrubbed
 SCRUB_PY="$AUTOMATION_ROOT/lib/scrub.py" python3 -c '
import importlib.util, os, sys
spec = importlib.util.spec_from_file_location(
    "hngh_scrub", os.environ["SCRUB_PY"])
mod = importlib.util.module_from_spec(spec)
try:
    spec.loader.exec_module(mod)
    for ln in sys.stdin.read().splitlines():
        sys.stdout.write(mod.scrub_paths(ln) + "\n")
except Exception:
    pass  # fail closed: empty output'
}

scrub() { digest_scrub "$@"; }

append_news_block() { # digest_file HHMM DATE model [sources] summary
 local f="$1" hh="$2" day="$3" used="$4" sources="${5:-}" summary="$6"
 {
  printf '\n## %s %s\n' "$hh" "$day"
  printf '_sources: %s | model: %s_\n' "$sources" "$used"
  printf '%s\n' "$(printf '%s' "$summary" | digest_scrub_all)"
 } >>"$f"
}
