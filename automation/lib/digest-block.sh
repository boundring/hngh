# digest-block.sh — shell-side digest writer seam (2026-09-16 writer
# census). Every bash lane that appends a block to the daily digest
# (archive/digest/<date>.md) routes the free-text parts of its block
# through append_news_block; scrub() re-exports the ONE identity seam,
# jobs/digest-ledger.py scrub_paths, so the shell writers and the
# Python writers cannot drift into different marker conventions. Redact
# at the writer, never at the reader: deck B, the email HTML part, the
# 0.0.0.0 dashboard route, and the newspaper all render the file
# verbatim downstream. Sourced after common.sh (needs AUTOMATION_ROOT).
set -u

digest_scrub() { # text -> text; host path tokens -> [redacted path]
 python3 -c '
import importlib.util, sys
spec = importlib.util.spec_from_file_location(
    "digest_ledger", sys.argv[2] + "/jobs/digest-ledger.py")
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)
print(mod.scrub_paths(sys.argv[1]))' "$1" "$AUTOMATION_ROOT"
}

digest_scrub_all() { # multi-line text (stdin) -> text, every line scrubbed
 python3 -c '
import importlib.util, sys
spec = importlib.util.spec_from_file_location(
    "digest_ledger", sys.argv[1] + "/jobs/digest-ledger.py")
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)
text = sys.stdin.read()
sys.stdout.write("".join(mod.scrub_paths(ln) + "\n"
                         for ln in text.splitlines()))' "$AUTOMATION_ROOT"
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
