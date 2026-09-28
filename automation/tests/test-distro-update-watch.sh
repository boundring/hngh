#!/usr/bin/env bash
# test-distro-update-watch.sh -- hermetic proofs for the weekly distro
# update watcher (31-distro-update-watch.sh, 2026-09-28):
#   a) first run arms all three sources: exactly one armed progress row
#      per source (identity distro-watch:<source>:armed) and per-source
#      state = newest id.
#   b) new ids file one progress row per source (identity
#      distro-watch:<source>:<id>); a re-run files nothing; two new arch
#      news items file two rows oldest-first; arch last-seen absent from
#      the feed re-arms (one alert, no flood).
#   c) one dead source (unreachable feed) files a fetch alert, leaves
#      its state untouched, and does not stop the other sources (a new
#      tag on a live source still files).
#   d) malformed payloads (no items / no tag_name) exit 0, file nothing.
# Hermetic: file:// fixture feeds, sandbox repo copy, no network, no
# ~/.hngh writes, no real telemetry.
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"
sb="$(mktemp -d)"
fx="$(mktemp -d)"
pass=0
fail=0
trap 'rm -rf "$sb" "$fx"' EXIT

mkdir -p "$sb/lib" "$sb/kernel/scripts" "$sb/report-root" \
 "$sb/hnghhome/db" "$sb/cadence/calendar/weekly"
cp -r "$root/lib/." "$sb/lib/"
cp "$root/../scripts/report-queue" "$sb/kernel/scripts/"
cp "$root/cadence/calendar/weekly/31-distro-update-watch.sh" \
 "$sb/cadence/calendar/weekly/"

cat >"$fx/arch-a.xml" <<'EOF'
<?xml version="1.0"?>
<rss><channel><title>Arch Linux: Recent news updates</title>
<item><title>News A</title><guid>https://archlinux.org/news/a/</guid></item>
</channel></rss>
EOF
cat >"$fx/arch-cba.xml" <<'EOF'
<?xml version="1.0"?>
<rss><channel><title>Arch Linux: Recent news updates</title>
<item><title>News C</title><guid>https://archlinux.org/news/c/</guid></item>
<item><title>News B</title><guid>https://archlinux.org/news/b/</guid></item>
<item><title>News A</title><guid>https://archlinux.org/news/a/</guid></item>
</channel></rss>
EOF
cat >"$fx/arch-empty.xml" <<'EOF'
<?xml version="1.0"?>
<rss><channel><title>Arch Linux: Recent news updates</title>
</channel></rss>
EOF
ghjson() { printf '{"url": "x", "tag_name": "%s", "name": "r"}\n' "$1"; }
ghjson v1.0.0 >"$fx/gh-v100.json"
ghjson v1.0.1 >"$fx/gh-v101.json"
ghjson v1.0.2 >"$fx/gh-v102.json"
printf '{"message": "Not Found"}\n' >"$fx/gh-empty.json"

run() { # arch-feed cachyos-feed omarchy-feed -> run watcher in sandbox
 HNGH_HOME="$sb/kernel" HNGH_REPORT_ROOT="$sb/report-root" \
  HNGH_HOME_DIR="$sb/hnghhome" HNGH_DISTRO_ARCH_URL="file://$1" \
  HNGH_DISTRO_CACHYOS_URL="file://$2" HNGH_DISTRO_OMARCHY_URL="file://$3" \
  bash "$sb/cadence/calendar/weekly/31-distro-update-watch.sh"
}
state() { head -n1 "$sb/hnghhome/db/distro-watch/last-$1" 2>/dev/null; }
bodies() { ls "$sb/report-root/docs/project/report-bodies/" 2>/dev/null | wc -l | tr -d ' '; }
ident_count() { # identity-string -> body files carrying it
 grep -rl "$1" "$sb/report-root/docs/project/report-bodies/" 2>/dev/null | wc -l | tr -d ' '
}

ok() { pass=$((pass + 1)); }
bad() {
 fail=$((fail + 1))
 printf 'FAIL: %s\n' "$1" >&2
}
chk() { # desc got want
 if [ "$2" = "$3" ]; then ok; else bad "$1 (got '$2' want '$3')"; fi
}

# (a) first run arms all three sources
rc=0
run "$fx/arch-a.xml" "$fx/gh-v100.json" "$fx/gh-v100.json" || rc=$?
chk "a: rc 0" "$rc" "0"
chk "a: arch armed row" "$(ident_count "distro-watch:arch:armed")" "1"
chk "a: cachyos armed row" "$(ident_count "distro-watch:cachyos:armed")" "1"
chk "a: omarchy armed row" "$(ident_count "distro-watch:omarchy:armed")" "1"
chk "a: arch state = newest" "$(state arch)" "https://archlinux.org/news/a/"
chk "a: cachyos state = tag" "$(state cachyos)" "v1.0.0"
chk "a: omarchy state = tag" "$(state omarchy)" "v1.0.0"
chk "a: exactly three bodies" "$(bodies)" "3"

# (b1) re-run on same fixtures files nothing
before="$(bodies)"
run "$fx/arch-a.xml" "$fx/gh-v100.json" "$fx/gh-v100.json"
chk "b1: idempotent re-run" "$(bodies)" "$before"

# (b2) two new arch items -> two rows oldest-first, state tracks newest
run "$fx/arch-cba.xml" "$fx/gh-v100.json" "$fx/gh-v100.json"
chk "b2: B row filed" "$(ident_count "distro-watch:arch:https://archlinux.org/news/b/")" "1"
chk "b2: C row filed" "$(ident_count "distro-watch:arch:https://archlinux.org/news/c/")" "1"
chk "b2: state = newest" "$(state arch)" "https://archlinux.org/news/c/"
order="$(grep -o "News [BC]" "$sb/report-root/docs/project/reports.md" 2>/dev/null |
 head -2 | grep -o "News [BC]" | tr '\n' ' ' | xargs)"
chk "b2: oldest filed first" "$order" "News B News C"

# (b3) one new tag per github source -> one row each, state advances
run "$fx/arch-cba.xml" "$fx/gh-v101.json" "$fx/gh-v101.json"
chk "b3: cachyos row" "$(ident_count "distro-watch:cachyos:v1.0.1")" "1"
chk "b3: omarchy row" "$(ident_count "distro-watch:omarchy:v1.0.1")" "1"
chk "b3: cachyos state advanced" "$(state cachyos)" "v1.0.1"
chk "b3: omarchy state advanced" "$(state omarchy)" "v1.0.1"
chk "b3: no duplicate arch rows" \
 "$(ident_count "distro-watch:arch:https://archlinux.org/news/c/")" "1"

# (b4) arch last-seen absent from feed -> re-arm, no flood
printf '9.9.9\n' >"$sb/hnghhome/db/distro-watch/last-arch"
run "$fx/arch-a.xml" "$fx/gh-v101.json" "$fx/gh-v101.json"
chk "b4: rearm alert filed" "$(ident_count "distro-watch:arch:rearm")" "1"
chk "b4: no flood rows" \
 "$(ident_count "distro-watch:arch:https://archlinux.org/news/a/")" "0"
chk "b4: state = newest" "$(state arch)" "https://archlinux.org/news/a/"

# (c) dead source skipped silently while live sources still checked
run "$fx/arch-a.xml" "$fx/no-such.json" "$fx/gh-v102.json"
chk "c: fetch alert filed" "$(ident_count "distro-watch:cachyos:fetch")" "1"
chk "c: cachyos state untouched" "$(state cachyos)" "v1.0.1"
chk "c: live omarchy still checked" "$(ident_count "distro-watch:omarchy:v1.0.2")" "1"
chk "c: omarchy state advanced" "$(state omarchy)" "v1.0.2"

# (d) malformed payloads exit 0 and file nothing
before="$(bodies)"
rc=0
run "$fx/arch-empty.xml" "$fx/gh-empty.json" "$fx/gh-empty.json" || rc=$?
chk "d: rc 0 on parse-empty" "$rc" "0"
chk "d: nothing filed" "$(bodies)" "$before"

echo "test-distro-update-watch: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
