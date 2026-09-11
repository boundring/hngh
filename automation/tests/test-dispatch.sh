#!/usr/bin/env bash
# test-dispatch.sh — the daily dispatch frame (2026-09-11), hermetic
# (fixture kernel repo + fixture automation feeds; nothing real touched):
#   a) the journal's DISPATCH lead section is present for a fixture date
#   b) the README sentinel block rewrites its rows and leaves every
#      byte outside the sentinels identical
#   c) a README without sentinels is refused (never injected)
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"
td="$(mktemp -d)"
trap 'rm -rf "$td"' EXIT
ok() { echo "ok: $1"; }
fail() {
 echo "FAIL: $1"
 exit 1
}

kernel="$td/kernel"
mkdir -p "$kernel/docs/journal" "$kernel/docs/project" "$kernel/automation"
: >"$kernel/docs/project/checkin.md"
: >"$kernel/docs/project/timeline.md"
git -C "$kernel" init -q
git -C "$kernel" config user.email t@t
git -C "$kernel" config user.name t
day="$(date -u +%Y-%m-%d)"

# fixture feeds (the automation tree the generator reads as ROOT/automation)
mkdir -p "$kernel/automation/logs" "$kernel/automation/dashboard"
printf '%s | lane-a | session-run\n%s | lane-b | session-run\n' \
 "$day" "$day" >"$kernel/automation/logs/budget.md"
printf '%s | other | cron\n' "$day" >>"$kernel/automation/logs/budget.md"
python3 - "$kernel/automation/dashboard/telemetry.db" <<'PY'
import sqlite3, sys
con = sqlite3.connect(sys.argv[1])
con.execute("CREATE TABLE events(ts TEXT, source TEXT, kind TEXT, identity TEXT,"
            " lane TEXT, unit TEXT, model TEXT, tokens_in INTEGER, tokens_out INTEGER,"
            " cost_usd REAL, wall_s REAL, subject TEXT, refs TEXT, body TEXT)")
con.execute("INSERT INTO events(ts, kind, cost_usd) VALUES"
            " (datetime('now','-1 hour'),'session-cost',1.25),"
            " (datetime('now','-2 hours'),'session-cost',2.50)")
con.commit()
PY
printf '{"items":[{"status":"open"},{"status":"open"},{"status":"handled"}]}' \
 >"$kernel/automation/dashboard/operator-items.json"
printf 'l1\tplanned\t2026-09-01T00:00:00Z\tx\nl2\texpanding\t2026-09-01T00:00:00Z\tx\nl3\treviewed\t2026-09-01T00:00:00Z\tx\n' \
 >"$kernel/automation/research-lines.tsv"

# one commit inside the day so the journal body is machine-generated
git -C "$kernel" add -A
git -C "$kernel" commit -qm "test: fixture"

# --- (a) journal DISPATCH lead section --------------------------------------
HNGH_PUB_ROOT="$kernel" python3 "$root/../scripts/generate-publication" --daily --force "$day" >/dev/null ||
 fail "generate-publication --daily failed"
j="$kernel/docs/journal/$day.md"
grep -q '^## DISPATCH$' "$j" || fail "journal missing the DISPATCH section"
grep -q '\*\*2\*\* sessions launched today' "$j" || fail "dispatch missing session count"
grep -q '\*\*\$3\.75\*\* spent across \*\*2\*\* model calls' "$j" || fail "dispatch missing 24h spend/calls"
grep -q '\*\*2\*\* research lines advancing (expanding 1, planned 1, reviewed 1)' "$j" ||
 fail "dispatch missing research line states"
grep -q '\*\*2\*\* operator items open' "$j" || fail "dispatch missing open operator items"
grep -q '^Verdict: advancing\.$' "$j" || fail "dispatch missing verdict line"
grep -q 'sources: sessions = automation/logs/budget.md' "$j" || fail "dispatch missing source citations"
grep -q '^## The ledger (machine-checked)$' "$j" || fail "DISPATCH displaced the journal's own structure"
ok "journal DISPATCH lead section present with sourced numbers"

# --- (b) README sentinel rewrite, bytes outside identical -------------------
readme="$td/README.md"
{
 printf '# Fixture README\n\n'
 printf 'hand-edited intro line\n\n'
 printf '<!-- dispatch:begin -->\n| 2000-01-01 | 0 | $0.00 | 0 | 0 |\n\nDeep read: [the journal](docs/journal/2000-01-01.md).\n<!-- dispatch:end -->\n\n'
 printf 'tail section stays put\n'
} >"$readme"
HNGH_PUB_ROOT="$kernel" python3 "$root/../scripts/generate-publication" --readme "$readme" "$day" >/dev/null ||
 fail "generate-publication --readme failed"
grep -q "^| $day | 2 | \$3.75 | 2 | 2 |$" "$readme" ||
 fail "README dispatch table row not rewritten with live numbers"
grep -q 'docs/journal/'"$day" "$readme" || fail "README dispatch missing journal deep-read link"
# byte-identical outside the sentinels
sed "/<!-- dispatch:begin -->/,/<!-- dispatch:end -->/d" "$readme" >"$td/outside.new2"
diff <(printf '# Fixture README\n\nhand-edited intro line\n') \
 <(sed -n '1,3p' "$td/outside.new2") >/dev/null || fail "content before the sentinels changed"
grep -q '^tail section stays put$' "$readme" || fail "content after the sentinels changed"
ok "README sentinel block rewrites rows; content outside stays byte-identical"

# --- (c) README without sentinels is refused --------------------------------
noreadme="$td/plain.md"
printf '# no sentinels here\n' >"$noreadme"
if HNGH_PUB_ROOT="$kernel" python3 "$root/../scripts/generate-publication" --readme "$noreadme" "$day" >/dev/null 2>&1; then
 fail "dispatch table injected into a sentinel-less README"
fi
grep -q '^# no sentinels here$' "$noreadme" || fail "sentinel-less README was modified"
ok "README without sentinels refused, left untouched"

echo "daily-dispatch contract: all cases passed"
