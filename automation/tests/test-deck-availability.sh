#!/usr/bin/env bash
# test-deck-availability.sh - stall-recovery step 8: the steamdeck is an
# intermittent peer with COMMITTED weekday hours. The hourly probe
# (cadence/hour/32-deck-facts.sh) reads the cadence-params row
# deck-availability (env DECK_AVAILABILITY overrides) through a DECK_NOW
# clock seam: outside the window, unreachable is expected-state --
# breadcrumb "off-duty", NO alert; inside the window the existing
# alert-by-identity path is unchanged; reachable any time still records
# facts. The digest classifier (scripts/email-digest.py classify_alerts)
# renders an outside-window deck-unreachable row as off-duty instead of
# down/alert. Hermetic: sandbox AUTOMATION_ROOT/HNGH_HOME, stub ssh and
# report-queue on PATH, fixed DECK_NOW.
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"
sb="$(mktemp -d)"
trap 'rm -rf "$sb"' EXIT
fails=0
ck() {
  if [ "$2" = "$3" ]; then echo "ok: $1"; else
    echo "FAIL: $1 (want [$2] got [$3])"
    fails=$((fails + 1))
  fi
}
PROBE="$root/cadence/hour/32-deck-facts.sh"

# sandbox repo shape: the probe resolves AUTOMATION_ROOT from $0, so a
# symlink farm runs the REAL probe against sandbox state.
mkdir -p "$sb/cadence/hour" "$sb/jobs" "$sb/bin" "$sb/scripts" "$sb/remote"
ln -s "$root/lib" "$sb/lib"
ln -s "$PROBE" "$sb/cadence/hour/32-deck-facts.sh"
ln -s "$root/jobs/deck-producer.sh" "$sb/jobs/deck-producer.sh"
WINDOW='Mon-Fri 09:00-17:30 America/New_York'
printf 'deck-availability\t%s\ttest\ttest\n' "$WINDOW" >"$sb/cadence-params.tsv"



# report-queue stub (32-deck-facts runs `python3 "$REPORT" --add alert`,
# REPORT = $HNGH_HOME/scripts/report-queue): every invocation appended
# verbatim to rq.log
printf '#!/usr/bin/env python3\nimport sys\nopen("%s/rq.log", "a").write(" ".join(sys.argv[1:]) + "\\n")\n' \
  "$sb" \
  >"$sb/scripts/report-queue"

# ssh stub: down = transport failure (rc 255); up = replays the four
# probe verbs (cat producer / stage / run / fetch facts JSON).
cat >"$sb/bin/ssh" <<STUB
#!/usr/bin/env bash
sb="\$SSH_STUB_SANDBOX"
printf '%s\n' "\${@: -2}" >>"\$sb/ssh.log" # log the target host (2nd-to-last arg)
[ "\${SSH_STUB_MODE:-down}" = "up" ] || exit 255
cmd="\${@: -1}"
case "\$cmd" in
  *"cat > ~/hngh-deck/deck-producer.sh"*)
    cat >"\$sb/remote/deck-producer.sh"; exit 0;;
  *"cat ~/hngh-deck/deck-producer.sh"*)
    [ -f "\$sb/remote/deck-producer.sh" ] && {
      cat "\$sb/remote/deck-producer.sh"; exit 0; }
    exit 1;;
  *"bash ~/hngh-deck/deck-producer.sh"*)
    mkdir -p "\$sb/remote/facts"
    printf '%s/hngh-deck/facts/facts-1.json\n' "\$sb/remote"
    exit 0;;
  *"cat '"*)
    printf '{"clock_utc":"2026-09-14T12:00:00Z","loadavg":"0.10 0.08 0.05","meminfo_kB":{"MemTotal":16000000,"MemAvailable":8000000}}'
    exit 0;;
esac
exit 255
STUB
chmod +x "$sb/bin/ssh"

run_probe() { # DECK_NOW SSH_STUB_MODE [extra env via env]
  rm -f "$sb/rq.log"
  DECK_NODE_ENABLED=1 DECK_HOST="${DECK_HOST-deck@stub}" DECK_KEY="$sb/id_test" \
    DECK_AVAILABILITY="${DECK_AVAILABILITY:-}" \
    HNGH_MACHINE_PROFILE="${HNGH_MACHINE_PROFILE:-}" DECK_NOW="$1" \
    SSH_STUB_MODE="$2" SSH_STUB_SANDBOX="$sb" AUTOMATION_ROOT="$sb" \
    HNGH_HOME="$sb" PATH="$sb/bin:$PATH" \
    bash "$sb/cadence/hour/32-deck-facts.sh"
}
alerts_filed() { # -> count of --add alert rows in the stub log
  if [ -f "$sb/rq.log" ]; then grep -c -- "--add alert" "$sb/rq.log" || :;
  else printf 0; fi
}
crumb_kind() { # kind -> count in the sandbox STATE.md
  if [ -f "$sb/STATE.md" ]; then grep -c " | $1 | " "$sb/STATE.md" || :;
  else printf 0; fi
}
ssh_calls() { # -> count of stub ssh invocations
  if [ -f "$sb/ssh.log" ]; then grep -c . "$sb/ssh.log" || :;
  else printf 0; fi
}

# (a) outside-window unreachable (Mon 19:00 EDT, past 17:30) -> no alert
#     row, off-duty breadcrumb instead
run_probe "2026-09-14T23:00:00Z" down
ck "outside-window unreachable files no alert" "0" "$(alerts_filed)"
ck "outside-window unreachable crumbed off-duty" "1" "$(crumb_kind off-duty)"
ck "outside-window unreachable files no alert crumb" "0" "$(crumb_kind alert)"

# (b) inside-window unreachable (Mon 10:00 EDT) -> existing alert retained:
#     the deck answered earlier the same UTC day (jsonl pre-seeded, the
#     'reachable earlier today' precondition the alert text speaks of),
#     identity + text unchanged, alert breadcrumb kept
mkdir -p "$sb/deck-facts"
printf '{"clock_utc":"2026-09-14T14:00:00Z"}\n' >"$sb/deck-facts/deck-facts-2026-09-14.jsonl"
run_probe "2026-09-14T14:00:00Z" down
ck "inside-window unreachable files the alert" "1" "$(alerts_filed)"
grep -q -- "--identity deck-unreachable-2026-09-14" "$sb/rq.log" &&
  ck "alert identity unchanged" "y" "y" ||
  ck "alert identity unchanged" "y" "n"
grep -q "deck was reachable earlier today but the pull now fails" "$sb/rq.log" &&
  ck "alert text unchanged" "y" "y" ||
  ck "alert text unchanged" "y" "n"
ck "inside-window unreachable crumbed alert" "1" "$(crumb_kind alert)"

# (c) reachable inside the window -> unchanged, facts recorded, no alert
# (the (b) pre-seed line stays; the up-probe appends a second fact)
rm -f "$sb/deck-facts/deck-facts-2026-09-14.jsonl"
run_probe "2026-09-14T14:00:00Z" up
ck "reachable inside window files no alert" "0" "$(alerts_filed)"
ck "reachable inside window records facts" "1" \
  "$(wc -l <"$sb/deck-facts/deck-facts-2026-09-14.jsonl" 2>/dev/null || printf 0)"

# (d) reachable outside the window -> unchanged, facts still recorded
run_probe "2026-09-13T14:00:00Z" up
ck "reachable outside window files no alert" "0" "$(alerts_filed)"
ck "reachable outside window records facts" "1" \
  "$(wc -l <"$sb/deck-facts/deck-facts-2026-09-13.jsonl" 2>/dev/null || printf 0)"

# (e) no window row -> old behavior (fail toward alerting, on-duty)
printf '# nothing here\n' >"$sb/cadence-params.tsv"
DECK_AVAILABILITY= run_probe "2026-09-14T23:00:00Z" down
ck "no window row keeps the alert path" "1" "$(alerts_filed)"
printf 'deck-availability\t%s\ttest\ttest\n' "$WINDOW" >"$sb/cadence-params.tsv"

# (f) machine profile supplies the deck host (step 2c): HNGH_MACHINE_PROFILE
#     points at a sandbox profile setting DECK_HOST; the ssh stub must see
#     that host and never the runner default (profile wins over absence)
mkdir -p "$sb/config"
printf 'DECK_HOST="deck@profile"\n' >"$sb/config/machine.env"
rm -f "$sb/ssh.log" # cases (a)-(e) logged stub calls under deck@stub
DECK_HOST= HNGH_MACHINE_PROFILE="$sb/config/machine.env" \
  run_probe "2026-09-14T14:00:00Z" up
ck "profile DECK_HOST drives the ssh stub" "3" \
  "$(grep -c 'deck@profile' "$sb/ssh.log" || :)"
ck "no fallback host reaches ssh" "0" "$(grep -c 'deck@stub' "$sb/ssh.log" || :)"
rm -f "$sb/config/machine.env" "$sb/ssh.log"

# (g) no profile file and no DECK_HOST: fail-closed skip - exit 0, one
#     breadcrumb, zero ssh invocations (never a baked-in address)
HNGH_MACHINE_PROFILE="$sb/config/absent.env" DECK_HOST= \
  run_probe "2026-09-14T23:00:00Z" up
ck "no-DECKHOST skip exits 0" "0" "$?"
ck "no-DECKHOST skip crumbed" "1" "$(crumb_kind deck-facts)"
grep -q "no DECK_HOST (config/machine.env missing" "$sb/STATE.md" &&
  ck "skip breadcrumb text" "y" "y" ||
  ck "skip breadcrumb text" "y" "n"
ck "no-DECKHOST skip makes no ssh calls" "0" "$(ssh_calls)"

# --- digest classifier (scripts/email-digest.py classify_alerts): an
# outside-window deck-unreachable row renders off-duty, not down/alert.
classify() { # NOW [env|tsv] row... -> "offduty=N critical=N info=N";
#             env = DECK_AVAILABILITY override, tsv = sandbox TSV row
  local tnow="$1" tmode=env
  case "${2:-}" in tsv) tmode=tsv; shift;; esac
  shift
  T_SRC="$root/scripts/email-digest.py" T_ROOT="$sb" T_WINDOW="$WINDOW" \
    T_MODE="${tmode:-env}" DECK_NOW="$tnow" python3 - "$@" <<'PY'
import os, sys
from importlib.machinery import SourceFileLoader
if os.environ["T_MODE"] == "env":
    os.environ["DECK_AVAILABILITY"] = os.environ["T_WINDOW"]
else:
    os.environ.pop("DECK_AVAILABILITY", None)
os.environ["HNGH_AUTOMATION_ROOT"] = os.environ["T_ROOT"]
mod = SourceFileLoader("ed", os.environ["T_SRC"]).load_module()
c = mod.classify_alerts(sys.argv[1:])
print("offduty=%d critical=%d info=%d"
      % (len(c["offduty"]), len(c["critical"]), len(c["info"])))
PY
}
DECKROW="deck was reachable earlier today but the pull now fails (probe rc=255)"
P0ROW="plan acceptance blocked: kernel make test FAILED (rc=2)"
ck "off-duty digest row leaves the down/alert tiers" \
  "offduty=1 critical=1 info=0" \
  "$(classify 2026-09-14T23:00:00Z "$DECKROW" "$P0ROW")"
ck "inside-window digest row keeps its old tier" \
  "offduty=0 critical=1 info=1" \
  "$(classify 2026-09-14T14:00:00Z "$DECKROW" "$P0ROW")"
ck "digest reads the deck-availability row" \
  "offduty=1 critical=1 info=0" \
  "$(classify 2026-09-14T23:00:00Z tsv "$DECKROW" "$P0ROW")"

echo "---"
[ "$fails" -eq 0 ] && echo "ALL PASS" || {
  echo "$fails FAILED"
  exit 1
}
