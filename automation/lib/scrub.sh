# scrub.sh — shell wrapper over lib/scrub.py, THE single-source
# path-token redaction definition (llc-gate-scrub-site-divergence
# consolidation 2026-09-16). Every shell scrub/redact seam sources this
# instead of keeping its own regex. Two functions:
#
#   scrub_paths TEXT   -> fail-closed [redacted path] marker output
#   redact_home_impl TEXT -> kernel-ledger tilde rendering (~ / ~tmp)
#
# Fail-closed: python or jq absent / the module failing yields empty
# output, so a broken guard can never leak pathy text through.
set -u

SCRUB_PY="$AUTOMATION_ROOT/lib/scrub.py"

scrub_paths() { # text -> scrubbed text on stdout
 SCRUB_PY="$SCRUB_PY" SCRUB_TEXT="$1" python3 -c '
import importlib.util, os, sys
spec = importlib.util.spec_from_file_location("hngh_scrub", os.environ["SCRUB_PY"])
mod = importlib.util.module_from_spec(spec)
try:
    spec.loader.exec_module(mod)
    sys.stdout.write(mod.scrub_paths(os.environ.get("SCRUB_TEXT", "")))
except Exception:
    pass  # fail closed: empty output'
}

redact_home_impl() { # text -> tilde-rendered text on stdout
 SCRUB_PY="$SCRUB_PY" SCRUB_TEXT="$1" python3 -c '
import importlib.util, os, sys
spec = importlib.util.spec_from_file_location("hngh_scrub", os.environ["SCRUB_PY"])
mod = importlib.util.module_from_spec(spec)
try:
    spec.loader.exec_module(mod)
    sys.stdout.write(mod.redact_home(os.environ.get("SCRUB_TEXT", "")))
except Exception:
    pass  # fail closed: empty output'
}
