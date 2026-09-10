#!/usr/bin/env bash
# test-probe-hygiene.sh — probe-measures-itself class guard (peer review
# finding 3, docs/research/2026-09-10-peer-standard-review.md).
#
# Rule: every credential probe must exercise the authenticated path its
# real caller uses. The 2026-09-10 kimi/lobehub lesson: five days of a
# probe measuring its own missing header (kimi 401, lobehub 404;
# commits 8db143a, b367b0c) while the real legs worked. The remaining
# deck /health probe is the documented exemption: that endpoint has no
# key gate at all (wall-powered device, breadcrumb-only —
# jobs/credential-health.sh section 3), so there is no authenticated
# path to exercise; it is the only shape-of-the-bug curl allowed.
#
# Mechanical form: join continuation lines, classify every curl in
# jobs/credential-health.sh. Each known key gate (unsloth /v1/models,
# lobehub /models, kimi /models) must appear in exactly one curl that
# carries "Authorization: Bearer"; the deck /health curl is the single
# exempt bare GET; ANY other headerless curl fails (fail-closed: a new
# probe with a new endpoint var must authenticate or update this
# exemption list consciously).
#
# Hermetic: static grep of one file; no network, no state.
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"
file="$root/jobs/credential-health.sh"
fails=0
ck() { # desc expected actual
  if [ "$2" = "$3" ]; then echo "ok: $1"; else
    echo "FAIL: $1 (want [$2] got [$3])"
    fails=$((fails + 1))
  fi
}

# curl invocation records: backslash continuations joined into one line
# each, comments and non-curl lines dropped.
mapfile -t curls < <(
  python3 - "$file" <<'PY'
import re, sys
text = open(sys.argv[1]).read()
text = re.sub(r'\\\n\s*', ' ', text)
for line in text.splitlines():
    s = line.strip()
    if s.startswith('#'):
        continue
    if re.search(r'(?<![\w-])curl(?![\w-])', s):
        print(s)
PY
)

# per-known-gate: exactly one authed curl per key-gated endpoint var
for var in 'UNSLOTH_URL' 'lobe_models_url' 'kimi_models_url'; do
  n="$(printf '%s\n' "${curls[@]}" | grep -c "\$${var}" || true)"
  ck "exactly one curl probes \$$var" "1" "$n"
  h="$(printf '%s\n' "${curls[@]}" | grep "\$${var}" | grep -c 'Authorization: Bearer' || true)"
  ck "the \$${var} probe is authenticated" "1" "$h"
done

# the single documented exemption: bare deck /health GET, no key gate
n="$(printf '%s\n' "${curls[@]}" | grep -c '\$deck_url/health' || true)"
ck "exempt bare probes == 1 (deck /health, no key gate)" "1" "$n"

# fail-closed catch-all: every remaining curl must be authenticated
headerless=0
for c in "${curls[@]}"; do
  case "$c" in *'$deck_url/health'*) continue ;; esac
  case "$c" in *'Authorization: Bearer'*) continue ;; esac
  headerless=$((headerless + 1))
  echo "FAIL: headerless curl against non-exempt endpoint: $c"
done
ck "headerless non-exempt curls == 0" "0" "$headerless"
ck "suite found curl records at all (file not drifted)" "yes" "$([ "${#curls[@]}" -ge 4 ] && echo yes || echo no)"

if [ "$fails" -gt 0 ]; then
  echo "probe-hygiene: $fails failure(s)"
  exit 1
fi
echo "probe-hygiene contract: all cases passed"
