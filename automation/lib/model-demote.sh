# model-demote.sh — consecutive-bad-outcome demotion for delegated-session
# models. The 2026-09-09 evidence: 9 sessions in a day all ended
# rc=0 cancelled cause=bad-execution on unsloth/Ornith-1.0-35B (local-bench)
# — the fail-first ladder paced spend but never demoted the model, so the
# budget kept burning on a model that never lands.
#
# Counter state (key=value, one file):
#   DEMOTE_STATE="${DEMOTE_STATE:-$AUTOMATION_ROOT/state/model-demote.tsv}"
#   <model>\t<consecutive_bad>\t<demoted(0|1)>\t<last_outcome>\t<last_ts>
#
# Interface:
#   record_model_outcome MODEL RESULT   (ok | bad-execution | dead | unknown)
#       ok resets that model's counter and clears demotion;
#       bad-execution increments; any other class is neither (recorded only).
#   model_demoted MODEL -> 0/1 on stdout
#   model_demotion_filter BENCH_JSON_DIR -> prints bench models NOT demoted
#       (reads the same model-bench-*.jsonl glob select_model scans; the
#       filter is a no-op passthrough when the dir is absent)
#   model_health_json -> one JSON object on stdout (the on-demand surface)
#
# Demotion: at >=2 consecutive bad-execution outcomes, file an alert row
# (identity model-demotion:<model>, window 86400) and set demoted=1.
# The alert re-files only after the window expires (report-queue dedup).
set -u
DEMOTE_STATE="${DEMOTE_STATE:-$AUTOMATION_ROOT/state/model-demote.tsv}"
DEMOTE_THRESHOLD="${DEMOTE_THRESHOLD:-2}"
REPORT="${REPORT:-python3 ${HNGH_HOME:-$HOME/Projects/etc/hngh}/scripts/report-queue}"

_demote_load() { # -> sets D_BAD D_DEM for $1 (model)
 local m="$1" line
 line="$(grep -F "$(printf '%s\t' "$m")" "$DEMOTE_STATE" 2>/dev/null | head -1)"
 if [ -n "$line" ]; then
  D_BAD="$(printf '%s' "$line" | cut -f2)"
  D_DEM="$(printf '%s' "$line" | cut -f3)"
 else
  D_BAD=0; D_DEM=0
 fi
 case "$D_BAD" in '' | *[!0-9]*) D_BAD=0 ;; esac
 case "$D_DEM" in 0 | 1) ;; *) D_DEM=0 ;; esac
}

_demote_save() { # m bad dem — one row per model, atomically rewritten
 local m="$1" bad="$2" dem="$3" tmp
 mkdir -p "$(dirname "$DEMOTE_STATE")" 2>/dev/null || return 0
 tmp="$DEMOTE_STATE.tmp.$$"
 { grep -v -F "$(printf '%s\t' "$m")" "$DEMOTE_STATE" 2>/dev/null
   printf '%s\t%s\t%s\n' "$m" "$bad" "$dem"; } >"$tmp" 2>/dev/null
 mv "$tmp" "$DEMOTE_STATE" 2>/dev/null || true
}

record_model_outcome() { # model result
 local m="$1" res="$2" bad dem
 [ -n "$m" ] || return 0
 _demote_load "$m"
 case "$res" in
  ok)
   if [ "$D_DEM" = 1 ]; then
    $REPORT --add progress "model $m back in rotation (ok outcome; demotion cleared)" \
      --identity "model-demotion-cleared:$m" --window 86400 >/dev/null 2>&1 || true
   fi
   _demote_save "$m" 0 0
   ;;
  bad-execution)
   bad=$((D_BAD + 1))
   if [ "$bad" -ge "$DEMOTE_THRESHOLD" ] && [ "$D_DEM" != 1 ]; then
    $REPORT --add alert \
     "model $m demoted: $bad consecutive bad-execution outcomes (threshold $DEMOTE_THRESHOLD) — skipped in select_model until an ok outcome" \
     --identity "model-demotion:$m" --window 86400 >/dev/null 2>&1 || true
    dem=1
   else
    dem="$D_DEM"
   fi
   _demote_save "$m" "$bad" "$dem"
   ;;
  *)
   # dead/unknown: recorded, not counted — only bad-execution cancellations
   # feed the demotion counter (the step-1 evidence class)
   _demote_save "$m" "$D_BAD" "$D_DEM"
   ;;
 esac
 return 0
}

model_demoted() { # model -> 0/1
 local m="$1"
 _demote_load "$m"
 printf '%s' "$D_DEM"
}

model_health_json() { # -> JSON on stdout (fail-closed: empty object on trouble)
 python3 - "$DEMOTE_STATE" <<'PY'
import json, sys
out = {}
try:
    for ln in open(sys.argv[1], errors="replace"):
        p = ln.rstrip("\n").split("\t")
        if len(p) >= 3:
            out[p[0]] = {"consecutive_bad": int(p[1]) if p[1].isdigit() else 0,
                         "demoted": p[2] == "1"}
except OSError:
    pass
import json as j
print(j.dumps(out, sort_keys=True))
PY
}

model_demotion_filter() { # dir -> prints models from bench scores that are demoted (one per line)
 local dir="$1" m
 [ -d "$dir" ] || return 0
 python3 - "$dir" <<'PY' 2>/dev/null
import glob, json, os, sys, time
cutoff = time.time() - 86400
for f in glob.glob(os.path.join(sys.argv[1], "model-bench-*.jsonl")):
    try:
        if os.path.getmtime(f) < cutoff:
            continue
    except OSError:
        continue
    for ln in open(f, errors="replace"):
        try:
            r = json.loads(ln)
        except ValueError:
            continue
        m = r.get("model", "")
        if m:
            print(m)
PY
}
