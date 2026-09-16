# redact.sh — shared path-redaction backstop for public-bound text.
# The kernel report ledger (docs/project/reports.md) and its body files
# are git-tracked and pushed to the public origin, and STATE.md crumbs
# are routinely quoted into reports; no machine-local path prefix may
# reach either (2026-09-16 boundary redaction). Emitters redact BEFORE
# filing; scripts/report-queue re-checks the same class at the
# alert-kind boundary as a sink-side guard. Markers: ~ = /home/<user>
# (operator home), ~tmp = /tmp (machine-local scratch) — distinct so
# rows stay readable ("~/dots/vimrc missing", "~tmp/hngh-cer-x.store
# untouched"). The lookbehind-style guard keeps mid-token matches
# (e.g. https://x.io/home/u/f) untouched.
set -u

redact_home() { # text -> text with /home/<user>/... -> ~/... and /tmp/... -> ~tmp/...
 local text="$1"
 text="$(printf '%s' "$text" | sed -E \
  -e 's/(^|[^[:alnum:].~\/-])\/home\/[^\/[:space:]]+/\1~/g' \
  -e 's/(^|[^[:alnum:].~\/-])\/tmp\//\1~tmp\//g')"
 printf '%s' "$text"
}
