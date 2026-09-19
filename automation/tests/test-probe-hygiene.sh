#!/usr/bin/env bash
# test-probe-hygiene.sh — probe-measures-itself class guard (peer review
# finding 3, docs/research/2026-09-10-peer-standard-review.md).
#
# real caller uses. The 2026-09-10 kimi lesson: five days of a
# probe measuring its own missing header (kimi 401;
# commits 8db143a, b367b0c) while the real legs worked. The remaining
# deck /health probe is the documented exemption: that endpoint has no
# key gate at all (wall-powered device, breadcrumb-only —
# jobs/credential-health.sh section 3), so there is no authenticated
# path to exercise; it is the only shape-of-the-bug curl allowed.
#
# Mechanical form: join continuation lines, classify every curl in
# jobs/credential-health.sh. Each known key gate (unsloth /v1/models,
# kimi /models, ocgo /models) must appear in exactly one curl invoked
# with the stdin config (`-K -`) fed by a
# `printf 'header = "Authorization: Bearer %s"\n'` directive (the
# 2026-09-16 argv-hygiene conversion: the secret never rides argv —
# docs/records/2026-09-16-notify-token-argv-exposure.md and its
# credential-health follow-up). A curl record carrying "Authorization:"
# on argv is a hard failure (regression guard). The deck /health curl is
# the single exempt bare GET; ANY other non-stdin-config curl fails, and
# the number of probed gates may not exceed the number of Bearer
# directives (fail-closed: a new probe with a new endpoint var must
# authenticate or update this exemption list consciously).
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

# per-known-gate: exactly one stdin-config curl per key-gated endpoint var
for var in 'UNSLOTH_URL' 'kimi_models_url' 'ocgo_models_url'; do
  n="$(printf '%s\n' "${curls[@]}" | grep -c "\$${var}" || true)"
  ck "exactly one curl probes \$$var" "1" "$n"
  k="$(printf '%s\n' "${curls[@]}" | grep "\$${var}" | grep -c ' -K ' || true)"
  ck "the \$${var} probe uses the stdin curl config" "1" "$k"
done

# argv regression guard: no curl record may carry the header on argv —
# after the join, the only legitimate "Authorization: Bearer" lines are
# the printf stdin-config directives, which are not curl records.
for c in "${curls[@]}"; do
  case "$c" in *'Authorization:'*) echo "FAIL: header on curl argv: $c"; fails=$((fails + 1)) ;; esac
done

# credential-value-on-argv guard (the -d blind spot, closed 2026-09-17
# with the refresh-path fix): an interpolated curl body
# (`-d "{...$var...}"`) puts the VALUE on argv — world-readable in
# /proc/<pid>/cmdline for the whole call, same class as the Bearer
# guard above. Bodies must be staged to a file (`-d @"$tmp"`) or be
# static text with no interpolation.
n_body=0
for c in "${curls[@]}"; do
  if printf '%s' "$c" | grep -Eq -- '(-d|--data) "(\\.|[^"\\])*\$'; then
    n_body=$((n_body + 1))
    echo "FAIL: interpolated body on curl argv: $c"
  fi
done
ck "interpolated -d bodies on curl argv == 0" "0" "$n_body"

# one printf Bearer directive per probed gate (the $var feeds the stdin
# header; the key vars are tok/kimi_key/ocgo_key)
n_dir="$(grep -c "printf 'header = \"Authorization: Bearer %s\"" "$file" || true)"
ck "exactly three stdin Bearer directives" "3" "$n_dir"
for kv in '"$tok"' '"$kimi_key"' '"$ocgo_key"'; do
  n="$(grep -cF "printf 'header = \"Authorization: Bearer %s\"\\n' $kv" "$file" || true)"
  ck "stdin Bearer directive present for $kv" "1" "$n"
done

# the single documented exemption: bare deck /health GET, no key gate
n="$(printf '%s\n' "${curls[@]}" | grep -c '\$deck_url/health' || true)"
ck "exempt bare probes == 1 (deck /health, no key gate)" "1" "$n"

# fail-closed catch-all: every remaining curl must use the stdin config,
# and directives must cover every probed gate (a new key-gated probe
# without a directive cannot hide)
headerless=0
for c in "${curls[@]}"; do
  case "$c" in *'$deck_url/health'*) continue ;; esac
  case "$c" in *' -K '*) continue ;; esac
  headerless=$((headerless + 1))
  echo "FAIL: headerless curl against non-exempt endpoint: $c"
done
ck "headerless non-exempt curls == 0" "0" "$headerless"
n_gates=0
for c in "${curls[@]}"; do
  case "$c" in *'$deck_url/health'*) continue ;; esac
  n_gates=$((n_gates + 1))
done
ck "Bearer directives cover every probed gate" "yes" \
  "$([ "$n_dir" -ge "$n_gates" ] && echo yes || echo no)"
ck "suite found curl records at all (file not drifted)" "yes" "$([ "${#curls[@]}" -ge 4 ] && echo yes || echo no)"

# --- model.sh (production chat legs; 2026-09-17 bearer-argv conversion) ---
# Same mechanical form over lib/model.sh: after the 2026-09-17 conversion
# (notify-seam pattern; credential-health probes of the SAME endpoints
# were converted first in ccf8d7b5), no curl record may carry the
# Authorization header on argv, every non-exempt curl must use the stdin
# config, and four Bearer directives must exist (_post_chat cfg,
# unsloth_attempt, _unsloth_ctx_limit, beatskip studio /v1/models). The
# single -K exemption is the
# refresh-path curl ($UNSLOTH_URL/api/auth/refresh): it carries no
# Bearer header — but its single-use refresh token is still credential
# material, so (2026-09-17 refresh-hygiene closure) the value rides a
# staged file (`-d @"$btmp"`, path on argv, never the value) and this
# lint pins both the staged form and the absence of ANY interpolated
# `-d "{...$var...}"` body (the -d blind spot the Bearer guard never
# covered).
file2="$root/lib/model.sh"
mapfile -t mcurls < <(
  python3 - "$file2" <<'PY'
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
m_fails=0
mck() { # desc expected actual
  if [ "$2" = "$3" ]; then echo "ok: $1"; else
    echo "FAIL: $1 (want [$2] got [$3])"
    m_fails=$((m_fails + 1))
  fi
}
for c in "${mcurls[@]}"; do
  case "$c" in *'Authorization:'*)
    echo "FAIL: model.sh header on curl argv: $c"; m_fails=$((m_fails + 1)) ;; esac
done
mck "model.sh: no Authorization header on any curl argv" "0" "$m_fails"
m_nonk=0
for c in "${mcurls[@]}"; do
  case "$c" in *'$UNSLOTH_URL/api/auth/refresh'*) continue ;; esac
  case "$c" in *' -K '*) continue ;; esac
  m_nonk=$((m_nonk + 1))
  echo "FAIL: model.sh non-exempt curl without stdin config: $c"
done
mck "model.sh: non-exempt curls without -K - == 0 (refresh path exempt)" "0" "$m_nonk"
n_mdir="$(grep -c "printf 'header = \"Authorization: Bearer %s\"" "$file2" || true)"
mck "model.sh: four stdin Bearer directives" "4" "$n_mdir"
mck "model.sh: suite found curl records at all (file not drifted)" "yes" \
  "$([ "${#mcurls[@]}" -ge 4 ] && echo yes || echo no)"

# model.sh credential-value-on-argv guard: no interpolated curl body
# anywhere (the refresh token historically rode `-d "{\"refresh_
# token\":\"$rtok\"}"` — value world-readable on /proc cmdline; closed
# 2026-09-17 by staging the body to a file). -d @"$tmp" is fine: the
# file PATH is not a secret.
m_nbody=0
for c in "${mcurls[@]}"; do
  if printf '%s' "$c" | grep -Eq -- '(-d|--data) "(\\.|[^"\\])*\$'; then
    m_nbody=$((m_nbody + 1))
    echo "FAIL: model.sh interpolated body on curl argv: $c"
  fi
done
mck "model.sh: interpolated -d bodies on curl argv == 0" "0" "$m_nbody"

# the refresh path, positively pinned: exactly one refresh curl, and it
# must stage its body (`-d @"...` form) — so the class cannot regress
# to an interpolated body OR to any other argv-carried shape.
n_ref="$(printf '%s\n' "${mcurls[@]}" | grep -c '\$UNSLOTH_URL/api/auth/refresh' || true)"
mck "model.sh: exactly one refresh-path curl" "1" "$n_ref"
n_staged="$(printf '%s\n' "${mcurls[@]}" | grep '\$UNSLOTH_URL/api/auth/refresh' | grep -c -- '-d @"' || true)"
mck "model.sh: refresh body staged to a file (-d @)" "1" "$n_staged"

if [ "$fails" -gt 0 ] || [ "$m_fails" -gt 0 ]; then
  echo "probe-hygiene: $((fails + m_fails)) failure(s)"
  exit 1
fi
echo "probe-hygiene contract: all cases passed"
