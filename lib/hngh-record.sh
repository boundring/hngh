# hngh-record.sh — dogfood Hngh by recording every job as a run in the
# automation ledger (best-effort; refusals are DATA, never failures).
#   record_hngh_run MISSION
# Each run gets its OWN fresh store subdirectory, because hngh's identifier
# source is per-process and always starts at "run-1": two create-run calls
# against the SAME store collide (:conflict on the second). A fresh store per
# run makes every create + close succeed and lands a real record.lisp.
# Full CLI output is breadcrumbed verbatim on refusal / unexpected result.
. "$AUTOMATION_ROOT/lib/common.sh"
. "$AUTOMATION_ROOT/lib/breadcrumbs.sh"

record_hngh_run() {
 local mission="${1:-automation activity}"
 [ -x "$HNGH_CLI" ] || {
  breadcrumb hngh "record" "CLI missing ($HNGH_CLI) — dogfooding skipped"
  return 0
 }

 local run_store out rc run close_out close_rc
 run_store="$HNGH_STORE/run-$(date -u +%Y%m%dT%H%M%SZ)-$$"
 mkdir -p "$run_store" 2>/dev/null || {
  breadcrumb hngh "record" "cannot create store dir $run_store"
  return 0
 }

 out="$("$HNGH_CLI" --store="$run_store" create-run "$mission" "$HNGH_ROLE" $HNGH_LOADOUT 2>&1)"
 rc=$?
 if [ "$rc" = "0" ]; then
  run="$(printf '%s\n' "$out" | sed -n 's/^run run-\([0-9][0-9]*\) state=.*/\1/p' | head -1)"
  if [ -z "$run" ]; then
   breadcrumb "$JOB_NAME" "hngh" "created run but could not parse id; output: $out"
   return 0
  fi
  # A completed job closes evacuated (the mission's evacuation-condition).
  # Evacuated is only legal from :running, so drive the closed CLI sequence
  # create -> admit filesystem -> arm -> start -> close evacuated. If any
  # step refuses (refusals are DATA), fall back to close cancelled so the
  # run still terminates and nothing dangles as :created.
  if ! "$HNGH_CLI" --store="$run_store" admit-transport "run-$run" filesystem repository >/dev/null 2>&1 ||
   ! "$HNGH_CLI" --store="$run_store" arm-run "run-$run" >/dev/null 2>&1 ||
   ! "$HNGH_CLI" --store="$run_store" start-run "run-$run" >/dev/null 2>&1; then
   close_out="$("$HNGH_CLI" --store="$run_store" close-run "run-$run" cancelled 2>&1)"
   close_rc=$?
   if [ "$close_rc" = "0" ]; then
    breadcrumb "$JOB_NAME" "hngh" "run-$run lifecycle refused; closed cancelled (data, not failure)"
   else
    breadcrumb "$JOB_NAME" "hngh" "run-$run lifecycle refused and close-cancelled failed rc=$close_rc: $close_out"
   fi
   return 0
  fi
  close_out="$("$HNGH_CLI" --store="$run_store" close-run "run-$run" evacuated 2>&1)"
  close_rc=$?
  if [ "$close_rc" = "0" ]; then
   breadcrumb "$JOB_NAME" "hngh" "recorded run-$run (create+arm+start+close-evacuated ok, store=basename($run_store))"
  else
   breadcrumb "$JOB_NAME" "hngh" "run-$run created but close-evacuated failed rc=$close_rc: $close_out"
  fi
 elif [ "$rc" = "1" ]; then
  breadcrumb "$JOB_NAME" "hngh-refusal" "create-run refused (data, expected): $out"
 else
  breadcrumb "$JOB_NAME" "hngh" "create-run rc=$rc: $out"
 fi
 return 0
}

# count of recorded runs across the ledger (for the dashboard summary)
hngh_run_count() { # -> integer
 if [ -d "$HNGH_STORE" ]; then
  find "$HNGH_STORE" -name record.lisp -type f 2>/dev/null | wc -l
 else
  echo 0
 fi
}
