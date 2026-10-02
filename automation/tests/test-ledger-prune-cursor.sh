#!/usr/bin/env bash
# test-ledger-prune-cursor.sh — S1 close-half refactor: the daily ledger
# prune (a) splits horizons (progress folds at 7d, alerts archive at
# 14d) and (b) self-heals a rotted report-cursor. A cursor id pruned
# from reports.md failed open in the kernel — every row unread forever
# (the 2026-10-02 1,416-row backlog). Hermetic: sandbox kernel with a
# seeded reports.md + rotted cursor; the real kernel report-queue does
# the pruning so the split horizons are integration-true.
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"
td="$(mktemp -d)"
trap 'rm -rf "$td"' EXIT
fails=0
ck() { if [ "$2" = "$3" ]; then printf 'ok - %s\n' "$1"; else
 printf 'NOT OK - %s: want [%s] got [%s]\n' "$1" "$2" "$3"
 fails=$((fails + 1))
fi; }

kernel="$td/kernel"
mkdir -p "$kernel/docs/project" "$kernel/scripts" "$td/automation"

# real kernel binary, sandboxed via HNGH_HOME (ROOT seam, :190-191)
cp "$root/../scripts/report-queue" "$kernel/scripts/"
[ -x "$kernel/scripts/report-queue" ] || chmod +x "$kernel/scripts/report-queue"

# rows: alert 15d (id rot), alert 10d (must survive), progress 10d
# (must fold), progress 1d (must survive + become the cursor target)
now="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
d15="$(date -u -d '15 days ago' +%Y-%m-%dT%H:%M:%SZ)"
d10="$(date -u -d '10 days ago' +%Y-%m-%dT%H:%M:%SZ)"
d1="$(date -u -d '1 day ago' +%Y-%m-%dT%H:%M:%SZ)"
cat >"$kernel/docs/project/reports.md" <<EOF
| timestamp | kind | id | first line | body |
| $d15 | alert | aaa-rot-15d | old alert | |
| $d10 | alert | bbb-keep-10d | ten day alert | |
| $d10 | progress | ccc-fold-10d | ten day progress | |
| $d1 | progress | ddd-keep-1d | fresh progress | |
EOF
printf 'aaa-rot-15d\n' >"$kernel/docs/project/report-cursor"

# job copy anchors AUTOMATION_ROOT (lib/common.sh derives it from
# BASH_SOURCE; env overrides lose) — same dance as the config-backup test
mkdir -p "$td/automation/cadence/calendar/daily"
cp "$root/cadence/calendar/daily/02-ledger-prune.sh" \
 "$td/automation/cadence/calendar/daily/"
mkdir -p "$td/automation/state"
cp -r "$root/lib" "$td/automation/lib"

env HNGH_HOME="$kernel" HNGH_CRUMBS_DB="$td/automation/state/crumbs.db" \
 HNGH_REPORT_IDENTITIES="$td/automation/state/report-identities.json" \
 bash "$td/automation/cadence/calendar/daily/02-ledger-prune.sh" \
 >/dev/null 2>&1
rc=$?

ck "prune run exits 0" "0" "$rc"
rows() { grep -c "$1" "$kernel/docs/project/reports.md" 2>/dev/null || true; }
ck "15d alert pruned" "0" "$(rows aaa-rot-15d)"
ck "10d alert kept (14d horizon)" "1" "$(rows bbb-keep-10d)"
ck "10d progress folded (7d horizon)" "0" "$(rows ccc-fold-10d)"
ck "1d progress kept" "1" "$(rows ddd-keep-1d)"
ck "cursor self-healed to newest row" "ddd-keep-1d" \
 "$(tr -d '[:space:]' <"$kernel/docs/project/report-cursor" 2>/dev/null)"

# idempotence: a valid cursor is never touched
printf 'ddd-keep-1d\n' >"$kernel/docs/project/report-cursor"
env HNGH_HOME="$kernel" HNGH_CRUMBS_DB="$td/automation/state/crumbs.db" \
 HNGH_REPORT_IDENTITIES="$td/automation/state/report-identities.json" \
 bash "$td/automation/cadence/calendar/daily/02-ledger-prune.sh" \
 >/dev/null 2>&1
ck "valid cursor untouched" "ddd-keep-1d" \
 "$(tr -d '[:space:]' <"$kernel/docs/project/report-cursor" 2>/dev/null)"

if [ "$fails" -gt 0 ]; then
 printf '%d check(s) failed\n' "$fails"
 exit 1
fi
echo "ledger-prune cursor contract: all checks passed"
