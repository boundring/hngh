#!/usr/bin/env bash
# test-dashboard-introspect.sh — hermetic proofs for the dashboard
# metacyclic loop (jobs/dashboard-introspect.py):
#   1. all-met fixture   -> no arc rows filed, grade row still written
#   2. one-gap fixture   -> exactly one arc row (fail-closed-auth)
#   3. regression        -> met then unmet re-fires identity
#                           dashboard-regression:<slug> (window 86400)
#   4. retirement        -> 3 consecutive met grades close the era; a
#                           re-gap files a fresh -r1 arc id
#   5. pacing            -> INTROSPECT_MIN_GAP_HOURS defers arc filing
# The beat runs the real probe code against fixture dashboard files in a
# mktemp sandbox; report-queue is a stub appending its argv to a log.
# (2026-10-03 control-room cut: probes rebased from the retired
# broadsheet surfaces onto the live ones — app.js auth + newspaper.json
# feed/operator/freshness.)
# usage: bash automation/tests/test-dashboard-introspect.sh
set -u
umask 022

AUTOMATION="$(cd "$(dirname "$0")/.." && pwd)"
JOB="$AUTOMATION/jobs/dashboard-introspect.py"
fails=0
ok() { echo "ok: $*"; }
bad() {
 echo "FAIL: $*"
 fails=$((fails + 1))
}
ck() { if [ "$2" = "$3" ]; then ok "$1"; else bad "$1 (want '$2' got '$3')"; fi; }

FX="$(mktemp -d)"
trap 'rm -rf "$FX"' EXIT

# ---- fixture dashboard surface: token-minimal, ALL probes met ----
fixture_app() { # $1 = with_401 (0/1) -> flips fail-closed-auth
 cat <<'V'
var meta = document.querySelector('meta[name="hngh-token"]');
if (resp.status === 401) { err.classList.add("hidden"); }
V
 if [ "${1:-1}" = "0" ]; then
  # drop the 401 branch: the auth probe goes unmet
  sed -i 's/resp.status === 401/resp.status === 500/' "$SB/dash/app.js"
 fi
}
fixture_feed() { # writes $SB/dash/newspaper.json (all feed probes met)
 SB="$SB" python3 - <<'PY'
import json, sys, os
def art(n, cat, head=None, family=None, wire=False):
    a = {"id": "a%d" % n, "headline": head or "t%d" % n, "category": cat,
         "deck": "d", "score": 1, "ts": "2026-09-27T00:00:00Z",
         "body": ["para"], "sources": ["src"] if wire else [],
         "choices": [{"label": "Handle",
                      "outcome": "Marks the item handled."}]}
    if family is not None:
        a["family"] = family
    return a
arts = [art(i, "operator") for i in range(8)]      # voice 80%
arts += [art(8, "politics", wire=True),            # wire, sourced
         art(9, "world", wire=True),
         art(10, "operator", "[feedback:idea] from email",
             family=True)]                         # the family card
d = {"edition": {"date": "2026-09-27", "number": 1, "slot": 1,
                 "weather": None, "system": {}},
     "editions": [],
     "articles": arts}
with open(os.path.join(os.environ["SB"], "dash", "newspaper.json"),
          "w") as f:
    json.dump(d, f)
PY
}

# ---- sandbox runner ----
new_sandbox() { # name -> $SB (dash, subj, state, rq log) fresh
 SB="$FX/$1"
 mkdir -p "$SB/dash"
 fixture_app >"$SB/dash/app.js"
 : >"$SB/subj.txt"
 : >"$SB/state.json"
 python3 - "$SB" <<'PY'
import json, sys
json.dump({"generated_at": "2026-09-27T12:00:00Z", "items": [
    {"id": "i1", "text": "kernel ledger sync drifted",
     "status": "open", "first_seen": "2026-09-27T12:00:00Z",
     "last_seen": "2026-09-27T12:00:00Z"}]},
          open(sys.argv[1] + "/dash/operator-items.json", "w"))
PY
 cat >"$SB/rq" <<STUB
#!/bin/sh
printf '%s\n' "\$*" >>"$SB/rq.log"
exit 0
STUB
 chmod +x "$SB/rq"
}

run_beat() { # $1 = with_401 fixture (fail-closed-auth probe)
 : >"$SB/rq.log"
 fixture_app "$1" >"$SB/dash/app.js"
 fixture_feed
 INTROSPECT_DASH="$SB/dash" INTROSPECT_SUBJECTS="$SB/subj.txt" \
  INTROSPECT_STATE="$SB/state.json" HNGH_REPORT_QUEUE="$SB/rq" \
  HNGH_REPORT_ROOT="$SB" INTROSPECT_JEV=0 \
  INTROSPECT_MIN_GAP_HOURS="${MGH:-1}" \
  python3 -B "$JOB" >/dev/null 2>&1
}

# ---- 1. all-met: no arcs, grade still fires ----
new_sandbox s1
run_beat 1
ck "s1 beat exits 0" "0" "$?"
ck "s1 no arc rows filed" "0" "$(grep -c '^arc-' "$SB/subj.txt" || true)"
ck "s1 grade row filed" "1" "$(grep -c 'dashboard-introspect:grade' \
 "$SB/rq.log" || true)"
ck "s1 grade is 6/6" "1" "$(grep -c 'grade 6/6 met' \
 "$SB/rq.log" || true)"
ck "s1 state streak bumped" "1" "$(python3 -c "
import json;print(json.load(open('$SB/state.json'))['probes']['fail-closed-auth']['streak'])")"

# ---- 2. one-gap: exactly one arc row ----
new_sandbox s2
run_beat 0 # drop the 401 branch -> fail-closed-auth unmet
ck "s2 beat exits 0" "0" "$?"
ck "s2 exactly one arc row" "1" "$(grep -c '^arc-' "$SB/subj.txt" || true)"
ck "s2 arc is the auth gap" "1" \
 "$(grep -c '^arc-[0-9]*-dashboard-fail-closed-auth' "$SB/subj.txt" ||
  true)"
ck "s2 grade reflects the gap" "1" "$(python3 -c "
import json;d=json.load(open('$SB/state.json'));print(1 if d['probes']['fail-closed-auth']['last']=='unmet' else 0)")"

# ---- 3. regression: met -> unmet re-fires the identity alert ----
new_sandbox s3
run_beat 1 # met: state learns streak=1
run_beat 0 # unmet: regression alert + arc
ck "s3 regression alert identity" "1" \
 "$(grep -c 'dashboard-regression:fail-closed-auth' "$SB/rq.log" ||
  true)"
ck "s3 alert window 86400" "1" \
 "$(grep 'dashboard-regression:' "$SB/rq.log" |
  grep -c -- '--window 86400' || true)"
ck "s3 alert carries evidence token" "1" \
 "$(grep 'dashboard-regression:' "$SB/rq.log" |
  grep -c -- '--evidence' || true)"
ck "s3 regression arc also filed" "1" \
 "$(grep -c '^arc-[0-9]*-dashboard-fail-closed-auth' "$SB/subj.txt" ||
  true)"

# ---- 4. retirement: era closes after retire-streak met grades; a
#         re-gap files a FRESH -r1 arc id ----
new_sandbox s4
python3 - "$SB/state.json" <<'PY'
import json, sys
st = {"probes": {"fail-closed-auth":
                 {"streak": 2, "era": 0, "last": "met", "detail": ""}},
      "last_file_epoch": 0}
json.dump(st, open(sys.argv[1], "w"))
PY
run_beat 1 # streak 2 -> 3: era closes (era -> 1), nothing unmet
ck "s4 retirement streak reached" "3" "$(python3 -c "
import json;print(json.load(open('$SB/state.json'))['probes']['fail-closed-auth']['streak'])")"
ck "s4 era closed" "1" "$(python3 -c "
import json;print(json.load(open('$SB/state.json'))['probes']['fail-closed-auth']['era'])")"
run_beat 0 # re-gap after retirement: fresh -r1 arc id
ck "s4 re-gap files fresh -r1 arc" "1" \
 "$(grep -c '^arc-[0-9]*-dashboard-fail-closed-auth-r1' \
  "$SB/subj.txt" || true)"
ck "s4 no unsuffixed duplicate" "0" \
 "$(grep -cP '^arc-[0-9]*-dashboard-fail-closed-auth\t' \
  "$SB/subj.txt" || true)"

# ---- 5. pacing: min-gap window closed defers arc filing ----
new_sandbox s5
python3 - "$SB/state.json" <<'PY'
import json, sys, time
json.dump({"probes": {}, "last_file_epoch": int(time.time())},
          open(sys.argv[1], "w"))
PY
MGH=24 run_beat 0 # gap pending but filing window closed for 24h
ck "s5 window closed defers filing" "0" \
 "$(grep -c '^arc-' "$SB/subj.txt" || true)"
ck "s5 beat still exits 0" "0" "$?"

echo
if [ "$fails" = 0 ]; then
 echo "PASS: dashboard-introspect"
 exit 0
fi
echo "FAIL: $fails check(s) red"
exit 1
