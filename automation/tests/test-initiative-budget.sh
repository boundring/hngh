#!/usr/bin/env bash
# P7 acceptance: route expiry (router-tick.py), the initiative filing
# budget (lib/filing_budget.py + its four mint seams), and loop
# re-queue (jobs/agent-supervision.py). Hermetic: every surface runs
# in a mktemp sandbox wired through the same env seams the code reads
# (HNGH_PLANS, HNGH_FILING_STATE, HNGH_REPORT_IDENTITIES,
# SUPERVISION_*), the report-queue is a stub binary logging argv, and
# no live model or repo state is touched.
set -u
cd "$(dirname "$0")/.."
FAIL=0
ck() {
 local d=$1
 shift
 if "$@" >/dev/null 2>&1; then
  printf 'ok - %s\n' "$d"
 else
  printf 'FAIL - %s\n' "$d"
  FAIL=1
 fi
}
ckno() { # negated: passes when the command fails
 local d=$1
 shift
 if ! "$@" >/dev/null 2>&1; then
  printf 'ok - %s\n' "$d"
 else
  printf 'FAIL - %s\n' "$d"
  FAIL=1
 fi
}
T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT
TODAY=$(date -u +%F)
TOMORROW=$(date -u -d tomorrow +%F)

# ---------------------------------------------------------------- (a)
# router: expires-header chain retirement + budget-gated mint
ra=$T/router
mkdir -p "$ra/plans" "$ra/auto" "$ra/home/docs/project/plans" "$ra/filing"
cat >"$ra/queue.sh" <<STUB
#!/usr/bin/env bash
printf '%s\n' "\$*" >> "$ra/queue.log"
STUB
chmod +x "$ra/queue.sh"

mint_plan() { # file attempt expires|none
 local exp_line="" cause_line=""
 [ "$3" != "none" ] && exp_line="<!-- expires: $3 -->"
 {
  printf '<!-- plan: status=proposed risk=normal accepted=- routed-from=x -->\n'
  printf '<!-- attempt: %s -->\n' "$2"
  [ -n "$exp_line" ] && printf '%s\n' "$exp_line"
  printf 'principle: routed candidates keep alert lineage machine-visible (docs/project/plans/README.md)\n'
  printf -- '- [ ] close the lane\n'
 } >"$ra/plans/$1"
}
# stamps use the exact format the router mints
mint_plan "$TODAY-routed-x.plan.md" 1 2026-01-01T00:00:00Z
mint_plan "$TODAY-routed-x-1.plan.md" 2 2026-01-01T00:00:00Z
mint_plan "$TODAY-routed-x-2.plan.md" 3 2026-01-01T00:00:00Z
mint_plan "$TODAY-routed-x-3.plan.md" 3 none # legacy: no expires stamp
touch -d "2 hours ago" "$ra"/plans/*.plan.md # dedup window is 1h: not live

renv=(env -i PATH="$PATH" HOME="$T"
 HNGH_HOME="$ra/home" HNGH_AUTOMATION_ROOT="$ra/auto"
 HNGH_REPORT_QUEUE="$ra/queue.sh" HNGH_REPORT_ROOT="$ra/kernel"
 HNGH_CRUMBS_DB="$ra/crumbs.db" HNGH_PLANS="$ra/plans"
 HNGH_PLANS_FEED_OUT="$ra/plans.json" HNGH_FILING_STATE="$ra/filing"
 HNGH_REPORT_IDENTITIES="$ra/identities.json"
 HNGH_ROUTER_REROUTE_MAX=3 HNGH_ROUTER_DEDUP_HOURS=1
 HNGH_ROUTER_TTL_HOURS=9999)

"${renv[@]}" python3 scripts/router-tick.py --identity x --text "is the lane done?"
ck "router tick exits 0 on full chain" test $? -eq 0
for f in "$TODAY-routed-x.plan.md" "$TODAY-routed-x-1.plan.md" \
 "$TODAY-routed-x-2.plan.md"; do
 ck "expired: $f" sh -c "grep -q 'status=expired' '$ra/plans/$f' &&
  grep -q 'cause: route-expiry' '$ra/plans/$f'"
done
ck "legacy member without expires never closed" \
 sh -c "grep -q 'status=proposed' '$ra/plans/$TODAY-routed-x-3.plan.md' &&
  ! grep -q 'route-expiry' '$ra/plans/$TODAY-routed-x-3.plan.md'"
ck "exactly one route-expiry row for x" test \
 "$(grep -c "route-expiry:x" "$ra/queue.log")" = 1
ckno "no router:parked row for x" grep -q "router:parked:x" "$ra/queue.log"

# budget-denied mint: routed:y already spent today
printf 'routed:y\t%s\n' "$TODAY" >>"$ra/filing/filing-budget.tsv"
"${renv[@]}" python3 scripts/router-tick.py --identity y --text "anything at all"
ck "over-budget identity mints no plan" test -z "$(ls "$ra/plans" | grep routed-y)"
ck "over-budget identity files one deferral row" \
 grep -q "filing-budget:routed:y" "$ra/queue.log"

# first mint of the day passes the budget and is fully stamped
"${renv[@]}" python3 scripts/router-tick.py --identity z --text "do a thing"
ck "fresh identity mints a plan" test -f "$ra/plans/$TODAY-routed-z.plan.md"
ck "minted plan carries attempt: 1" \
 grep -q '<!-- attempt: 1 -->' "$ra/plans/$TODAY-routed-z.plan.md"
ck "minted plan carries a future expires stamp" \
 grep -q '<!-- expires: 2' "$ra/plans/$TODAY-routed-z.plan.md"
ck "minted plan stays parseable (status in first 400 bytes)" \
 sh -c "test \"\$(head -c 400 '$ra/plans/$TODAY-routed-z.plan.md' | grep -c 'status=proposed')\" = 1"
ckno "no deferral row for the allowed mint" \
 grep -q "filing-budget:routed:z" "$ra/queue.log"

# ---------------------------------------------------------------- (b)
# filing_budget: one filing per family:token per UTC day
rb=$T/budget
mkdir -p "$rb"
python3 lib/filing_budget.py --family fail --cause k1 --state-dir "$rb"
ck "budget: first allow" test $? -eq 0
python3 lib/filing_budget.py --family fail --cause k1 --state-dir "$rb"
ck "budget: same family:cause same day refused" test $? -eq 1
python3 lib/filing_budget.py --family fail --cause k1 --state-dir "$rb" --today "$TOMORROW"
ck "budget: next day allowed" test $? -eq 0
python3 lib/filing_budget.py --family fail --cause "K1" --state-dir "$rb" --today "$TOMORROW"
ck "budget: token normalizes (K1 == k1)" test $? -eq 1

# ---------------------------------------------------------------- (c)
# causes.sh: new-mint seams — disposition echo always demotes; the
# budget demotes same-norm second mints; first mints append
rc_=$T/causes
printf 'line\taction\tverdict\treviewer\tevidence\tdate\tsupport\toppose\tfollowons\n' \
 >"$rc_-dispositions.tsv"
printf 'l1\tkilled\tkilled -- the cache rotates hourly anyway\top\t-\t2026-09-01\t-\t-\t-\n' \
 >>"$rc_-dispositions.tsv"
export AUTOMATION_ROOT="$rc_" HNGH_CRUMBS_DB="$rc_/crumbs.db" \
 HNGH_DISPOSITIONS_TSV="$rc_-dispositions.tsv"
# shellcheck disable=SC1091
. lib/causes.sh
AUTOMATION_ROOT="$rc_" append_research_subject "solo" "a solo question"
ck "causes: first mint appends the subject" test \
 "$(wc -l <"$rc_/research-subjects.txt")" = 1
ck "causes: first mint consumes the budget" \
 grep -q "^fail:solo	$TODAY$" "$rc_/state/filing-budget.tsv"
AUTOMATION_ROOT="$rc_" append_research_subject "Solo" \
 "a different question with the same norm"
ck "causes: same-norm second mint appends nothing" test \
 "$(wc -l <"$rc_/research-subjects.txt")" = 1
ck "causes: same-norm demote leaves a crumb" test \
 "$(python3 lib/crumbs-db.py export --db "$rc_/crumbs.db" | grep -c research-subject-demoted)" = 1
AUTOMATION_ROOT="$rc_" append_research_subject "cache" \
 "the cache rotates hourly anyway"
ck "causes: disposition echo appends nothing" test \
 "$(wc -l <"$rc_/research-subjects.txt")" = 1
ck "causes: disposition echo is always a crumb" test \
 "$(python3 lib/crumbs-db.py export --db "$rc_/crumbs.db" | grep -c filing-about-filing)" = 1

# ---------------------------------------------------------------- (d)
# supervision: stuck (looping) sessions re-queue once, die on the
# second stuck tick, recover when the loop breaks
cat >"$T/sup_loop_test.py" <<'PYEOF'
import hashlib
import importlib.util
import json
import os
import subprocess
import sys
import tempfile
import time
from pathlib import Path

ROOT = Path.cwd()
spec = importlib.util.spec_from_file_location(
    "tas", str(ROOT / "tests" / "test-agent-supervision.py"))
tas = importlib.util.module_from_spec(spec)
spec.loader.exec_module(tas)

fails = []
def ck(desc, cond):
    print(("ok - " if cond else "FAIL - ") + desc)
    if not cond:
        fails.append(desc)

td = tempfile.TemporaryDirectory()
root = Path(td.name)
for name in ("rq-stub", "hngh-stub", "bridge-stub"):
    p = root / name
    p.write_text(
        "#!%s\nimport os, sys\n"
        "open(os.environ['RQ_LOG'], 'a').write("
        "' '.join(sys.argv[1:]) + '\\n')\n" % sys.executable)
    p.chmod(0o755)
sessions = root / "sessions"
sessions.mkdir()
sp = sessions / "loopy.jsonl"
sp.write_text("\n".join(
    tas.tc_line(tas.iso(60 * i), "run_command", {"cmd": "flaky"})
    for i in range(3)) + "\n")
t = time.time() - 60
os.utime(sp, (t, t))
sid = "omp-loopy-%s" % hashlib.md5(str(sp).encode()).hexdigest()[:6]
(root / "state").mkdir()
(root / "state" / "beat-blockers.tsv").touch()
(root / "handoffs.md").touch()
env = {**os.environ,
       "SUPERVISION_SOURCES": str(sessions),
       "SUPERVISION_STATE": str(root / "state.json"),
       "SUPERVISION_REPORT_QUEUE": str(root / "rq-stub"),
       "OMP_BRIDGE_STORE": str(root / "bridge"),
       "HNGH_BIN": str(root / "hngh-stub"),
       "OMP_BRIDGE_BIN": str(root / "bridge-stub"),
       "RQ_LOG": str(root / "rq.log"),
       "SUPERVISION_HANDOFFS": str(root / "handoffs.md"),
       "SUPERVISION_BLOCKERS": str(root / "state" / "beat-blockers.tsv"),
       "SUPERVISION_PARAMS": str(root / "params.tsv"),
       "HNGH_CRUMBS_DB": str(root / "state" / "crumbs.db"),
       "SUPERVISION_CAUSES_SH": str(tas.CAUSES_SH)}

def tick():
    return subprocess.run([sys.executable, str(ROOT / "jobs"
                                                / "agent-supervision.py")],
                          env=env, capture_output=True, text=True,
                          timeout=120)

def rows():
    p = root / "rq.log"
    return p.read_text().splitlines() if p.exists() else []

def state_for():
    return json.loads((root / "state.json").read_text())[sid]

r1 = tick()
ck("supervision tick1 exits 0", r1.returncode == 0)
r1rows = rows()
ck("tick1 files one loop-requeue row",
   any("loop-requeue:%s" % sid in r and "--add progress" in r
       for r in r1rows))
ck("tick1 steers with cause=repeat-loop",
   any(sid in r and "cause=repeat-loop" in r and "--add alert" in r
       for r in r1rows))
ck("tick1 counts stuck_misses=1", state_for().get("stuck_misses") == 1)
r2 = tick()
r2rows = rows()
ck("tick2 dies cause=repeat-loop",
   any("died after 2 missed ticks" in r and "cause=repeat-loop" in r
       for r in r2rows))
# recovery: break the trailing identical loop
sp.write_text("\n".join(
    tas.tc_line(tas.iso(60 * i), "run_command", {"cmd": "flaky", "n": i})
    for i in range(3)) + "\n")
os.utime(sp, (time.time() - 60,) * 2)
r3 = tick()
r3rows = rows()
ck("tick3 files one recovered row",
   any("supervision:%s:recovered" % sid in r for r in r3rows))
ck("recovery resets stuck_misses", state_for().get("stuck_misses") == 0)
td.cleanup()
sys.exit(1 if fails else 0)
PYEOF
python3 "$T/sup_loop_test.py" || FAIL=1

if [ "$FAIL" = 0 ]; then
 printf 'test-initiative-budget: ALL OK\n'
else
 printf 'test-initiative-budget: FAILURES\n'
 exit 1
fi
