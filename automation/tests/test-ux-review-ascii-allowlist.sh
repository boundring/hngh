#!/usr/bin/env bash
# test-ux-review-ascii-allowlist — 19-ux-review.sh kernel-docs precheck:
# house-style en/em dashes and typographic quotes (U+2013/U+2014,
# U+2018-U+201D — the writing-register law itself uses them) must NOT
# file a non-ASCII precheck alert; any other non-ASCII byte still fails
# closed. Closes the parked false-positive class (BACKLOG; research-
# subjects class 6e562932).
#
# Hermetic: HNGH_HOME sandbox docs, stub report-queue, sandbox crumbs
# DB, curl stubbed off PATH so the model tail can never fire.
set -u
AT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
KERNEL_ROOT="$(cd "$AT_ROOT/.." && pwd)"

pass=0
fail=0
ok() {
  pass=$((pass + 1))
  echo "ok - $1"
}
bad() {
  fail=$((fail + 1))
  echo "NOT OK - $1"
}

sandbox="$(mktemp -d)"
trap 'rm -rf "$sandbox"' EXIT
mkdir -p "$sandbox/docs/project" "$sandbox/scripts" "$sandbox/bin"
printf '#!/bin/sh\nexit 7\n' >"$sandbox/bin/curl"
chmod +x "$sandbox/bin/curl"

# stub report-queue (invoked as `python3 .../report-queue` by
# file_report): log kind|identity rows for assertions
cat >"$sandbox/scripts/report-queue" <<'EOF'
import os, sys
args = sys.argv[1:]
kind = ident = ""
i = 0
while i < len(args):
    if args[i] == "--add":
        kind = args[i + 1]; i += 2
    elif args[i] == "--identity":
        ident = args[i + 1]; i += 2
    else:
        i += 1
with open(os.path.join(os.environ["HNGH_REPORT_ROOT"], "rows.tsv"),
          "a") as fh:
    fh.write("%s|%s\n" % (kind, ident))
EOF

run_review() { # body -> prints rows.tsv
  printf '%s' "$1" >"$sandbox/docs/README.md"
  cp "$sandbox/docs/README.md" "$sandbox/docs/project/STATE-OF-PROJECT.md"
  : >"$sandbox/rows.tsv"
  (cd "$KERNEL_ROOT" && PATH="$sandbox/bin:$PATH" \
    HNGH_HOME="$sandbox" HNGH_REPORT_ROOT="$sandbox" \
    HNGH_CRUMBS_DB="$sandbox/crumbs.db" \
    UX_REVIEW_SURFACE=kernel-docs \
    TYPESAFE_API_KEY= \
    bash "$AT_ROOT/cadence/calendar/daily/19-ux-review.sh") \
    >/dev/null 2>&1
  cat "$sandbox/rows.tsv"
}

# sanctioned house-style punctuation only: no precheck alert
rows="$(run_review 'Read the map first — start here; the lanes C0–C3 are "law".')"
if printf '%s' "$rows" | grep -q 'precheck'; then
  bad "sanctioned dashes/quotes filed a precheck alert: $rows"
else
  ok "sanctioned dashes/quotes: no precheck alert"
fi

# a genuinely foreign byte still fails closed
rows="$(run_review 'clean ascii plus 中文 foreign text')"
if printf '%s' "$rows" | grep -q 'precheck'; then
  ok "foreign non-ASCII byte still flagged"
else
  bad "foreign non-ASCII byte NOT flagged: $rows"
fi

# mixed: sanctioned punctuation never masks a real byte
rows="$(run_review 'em — dash beside 中文')"
if printf '%s' "$rows" | grep -q 'precheck'; then
  ok "allowlist does not mask a real byte"
else
  bad "mixed evidence NOT flagged: $rows"
fi

echo "passed=$pass failed=$fail"
[ "$fail" -eq 0 ]
