#!/usr/bin/env bash
# test-omp-changelog-watch.sh -- hermetic proofs for the omp changelog
# watcher (2026-09-27):
#   a) first run arms: exactly one progress row (identity
#      omp-changelog-watch:armed) and state = newest version.
#   b) one new upstream version files exactly one progress row
#      (identity omp-changelog:<ver>); a re-run files nothing;
#      two new versions file two rows oldest-first; state tracks newest.
#   c) failed fetch files an alert row (identity
#      omp-changelog-watch:fetch) and leaves state untouched.
#   d) last-seen absent from upstream headings (history rewrite)
#      re-arms: one alert row, state jumps to newest, no flood.
# Hermetic: file:// fixture changelogs, sandbox repo copy, no network,
# no ~/.hngh writes, no real telemetry.
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"
sb="$(mktemp -d)"
fx="$(mktemp -d)"
pass=0
fail=0
trap 'rm -rf "$sb" "$fx"' EXIT

mkdir -p "$sb/lib" "$sb/kernel/scripts" "$sb/report-root" "$sb/hnghhome/db" \
 "$sb/cadence/calendar/daily"
cp -r "$root/lib/." "$sb/lib/"
cp "$root/../scripts/report-queue" "$sb/kernel/scripts/"
cp "$root/cadence/calendar/daily/28-omp-changelog-watch.sh" \
 "$sb/cadence/calendar/daily/"

cat >"$fx/v35.md" <<'EOF'
# Changelog

## [Unreleased]
- pending thing

## [18.3.5] - 2026-09-27
- prompt-cache warming
- web search fallback

## [18.3.3] - 2026-09-25
- predictive text engine
EOF
cat >"$fx/v36.md" <<'EOF'
# Changelog

## [Unreleased]
- pending thing

## [18.3.6] - 2026-09-28
- newer thing

## [18.3.5] - 2026-09-27
- prompt-cache warming
EOF
cat >"$fx/v378.md" <<'EOF'
# Changelog

## [Unreleased]
- pending

## [18.3.8] - 2026-09-30
- eight

## [18.3.7] - 2026-09-29
- seven

## [18.3.6] - 2026-09-28
- newer thing
EOF

run() { # fixture -> run watcher in sandbox
 HNGH_HOME="$sb/kernel" HNGH_REPORT_ROOT="$sb/report-root" \
  HNGH_HOME_DIR="$sb/hnghhome" HNGH_OMP_CHANGELOG_URL="file://$1" \
  bash "$sb/cadence/calendar/daily/28-omp-changelog-watch.sh"
}
state() { head -n1 "$sb/hnghhome/db/omp-changelog/last-seen" 2>/dev/null; }
bodies() { ls "$sb/report-root/docs/project/report-bodies/" 2>/dev/null | wc -l | tr -d ' '; }
ident_count() { # identity-string -> body files carrying it
 grep -rl "$1" "$sb/report-root/docs/project/report-bodies/" 2>/dev/null | wc -l | tr -d ' '
}

ok() { pass=$((pass + 1)); }
bad() {
 fail=$((fail + 1))
 echo "FAIL: $1"
}
chk() { # desc got want
 if [ "$2" = "$3" ]; then ok; else bad "$1 (got '$2' want '$3')"; fi
}

# (a) first run arms
run "$fx/v35.md"
chk "a: armed row filed" "$(ident_count "omp-changelog-watch:armed")" "1"
chk "a: state = newest" "$(state)" "18.3.5"
chk "a: exactly one body" "$(bodies)" "1"

# (b1) re-run on same fixture files nothing new (identity window)
before="$(bodies)"
run "$fx/v35.md"
chk "b1: idempotent re-run" "$(bodies)" "$before"

# (b2) one new version -> one row, state advances
run "$fx/v36.md"
chk "b2: version row filed" "$(ident_count "omp-changelog:18.3.6")" "1"
chk "b2: state advanced" "$(state)" "18.3.6"

# (b3) two new versions -> two rows, oldest first
run "$fx/v378.md"
chk "b3: 18.3.7 row" "$(ident_count "omp-changelog:18.3.7")" "1"
chk "b3: 18.3.8 row" "$(ident_count "omp-changelog:18.3.8")" "1"
chk "b3: state = newest" "$(state)" "18.3.8"
order="$(grep -o "18.3.7 released\|18.3.8 released" \
 "$sb/report-root/docs/project/reports.md" 2>/dev/null | head -2 | grep -o "18.3.[78]" | tr '\n' ' ' | xargs)"
chk "b3: oldest filed first" "$order" "18.3.7 18.3.8"

# (c) failed fetch -> alert, state untouched
run "$fx/no-such-fixture.md"
chk "c: fetch alert filed" "$(ident_count "omp-changelog-watch:fetch")" "1"
chk "c: state untouched" "$(state)" "18.3.8"

# (d) history rewrite -> re-arm, no flood
printf '9.9.9\n' >"$sb/hnghhome/db/omp-changelog/last-seen"
run "$fx/v35.md"
chk "d: rearm alert filed" "$(ident_count "omp-changelog-watch:rearm")" "1"
chk "d: no flood rows" "$(ident_count "omp-changelog:18.3.5")" "0"
chk "d: state = newest" "$(state)" "18.3.5"

echo "test-omp-changelog-watch: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
