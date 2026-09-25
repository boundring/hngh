# causes.sh -- the failure bestiary: deterministic cause classification for
# dead/stalled session logs, plus research-subject intake for the demand-
# driven research beat. Every failure class below is one bestiary entry with
# its countermeasure routing; the case table in classify_cause is the ONE
# place the keyword mapping lives (first match wins, table order is the
# precedence):
#
#   bad-execution     budget/cap failure phrases (failure context required
#                     on the line — bare "budget"/"cap" mentions must not
#                     classify; 2026-09-11 keyword false positive),
#                     exhausted/timeout -- execution failed, the plan was
#                     fine; route back to the owning lane with a smaller
#                     step
#   missing-knowledge  404/not found/unknown command/unknown verb --
#                     Delve: open a research subject, record a disposition,
#                     then fix
#   missing-design     missing design/no design for -- draft or find the
#                     design before any fix; research subject too
#   missing-authority  permission/denied/unauthorized/awaiting-operator --
#                     park for the operator; never retry
#   obsolete           superseded/duplicate/stale -- close the alert or plan
#                     as superseded; no fix
#   unclassified       no keyword matched -- generic investigate, fix or park
#                      (P4: bare cause=unknown is banned on disposition
#                      transitions; unclassifiable is named as such)

classify_cause() { # logfile [rc] -> one cause class on stdout (unclassified if no log)
 local log="$1" rc="${2:-}" text=""
 if [ -n "$log" ] && [ -f "$log" ]; then
  # two-stage classification (2026-09-11 404-in-success false positive):
  # first keep only failure-shaped lines, then run the class table on
  # those alone. Incidental keyword mentions in success prose (research
  # docs citing 404s, budget chatter) never classify; no failure-shaped
  # line in the tail means unclassified regardless of keywords.
  text="$(tail -n 200 "$log" 2>/dev/null |
   grep -iE 'error|fatal|fail|refus|traceback|exit code [1-9]|rc=[1-9]|exit [1-9]|budget excee|budget exhaust|cost limit|cap reach|cap excee|cap hit|exhausted|timeout' |
   tr '[:upper:]' '[:lower:]')"
 fi
 [ -z "$text" ] && {
  # a timeout kill (rc=124) is a transient death by definition
  # (steer-vs-die doctrine) even when the tail is clean — the session
  # never finished inside its budget. The worker-transport-wiring
  # respawn refusal (2026-09-11) classified this unknown and the guard
  # treated it as non-transient.
  [ "$rc" = "124" ] && {
   printf 'bad-execution'
   return 0
  }
  printf 'unclassified'
  return 0
 }
 case "$text" in
 *"missing design"* | *"no design for"*) printf 'missing-design' ;;
 *"404"* | *"not found"* | *"unknown command"* | *"unknown verb"*)
  printf 'missing-knowledge'
  ;;
 *"permission"* | *"denied"* | *"unauthorized"* | *"awaiting-operator"*)
  printf 'missing-authority'
  ;;
 *"budget exceed"* | *"over budget"* | *"budget limit"* | *"budget cap"* | *"budget exhausted"* | *"cost limit"* | *"cap reached"* | *"cap exceeded"* | *"cap hit"* | *"exhausted"* | *"timeout"*) printf 'bad-execution' ;;
 *"superseded"* | *"duplicate"* | *"stale"*) printf 'obsolete' ;;
 *) printf 'unclassified' ;;
 esac
}

# lesson_for_cause -- the self-steering loop's sentence map (2026-09-11,
# hngh opencode configuration layer): one line per cause class that a NEXT
# session should know, derived from the bestiary countermeasures above.
# Consumed by append_ocgo_lesson (launch-session.sh) into
# automation/state/ocgo-agent-lessons.md; executor/scout read the tail at
# session start and steer away from the recorded classes.
lesson_for_cause() { # cause-class -> one sentence on stdout
 case "$1" in
 bad-execution)
  printf 'budget/cap/exhausted/timeout -- the step was too big or never verified: shrink the step and prove the thing works on its own surface before claiming done'
  ;;
 missing-knowledge)
  printf '404/unknown verb/command -- you ran an interface that does not exist: read the real docs or source for the exact name before running anything'
  ;;
 missing-design)
  printf 'there was no design for the change: find or draft the design first, never improvise structure mid-edit'
  ;;
 missing-authority)
  printf 'permission/denied/awaiting-operator -- the boundary is real: never retry around it; park the item and report it'
  ;;
 obsolete)
  printf 'the target was superseded/duplicate/stale -- check the current ledger state before acting on anything you read earlier'
  ;;
 *)
  printf 'the log tail matched no known failure class -- state plainly what you were doing when it failed so the next session can classify it'
  ;;
 esac
}

# The appender is a source-side redaction seam (2026-09-17, same cure
# as the 33-research-beat ingest seams): research-subjects.txt is
# git-tracked and pushed publicly, so the report-queue sink-side guard
# can never cover it. Both the question AND the slug run through
# redact_home (one token family, lib/scrub.py, tilde rendering -- the
# ledger convention) BEFORE id/slug derivation: a pathy question or
# slug must never bake path tokens into the public fail-<date>-<slug>
# id (the leaked fail-20260914-Where-exactly-in-home-bricker-Projects-e
# id is the exact shape). redact.sh/scrub.sh resolve from this file's
# own tree, not AUTOMATION_ROOT: the mimic drill calls this function
# with AUTOMATION_ROOT pointed at a lib-less sandbox. Fail-closed:
# redact_home yields empty output when the guard is broken, and the
# empty-question guard refuses the append -- never a leak.
#
# Dash-form extension (2026-09-17 GAP, gate
# wiki-health-wiring-reconcile): redact_home's token family matches
# slash forms only, so a slug arriving PRE-mangled
# ("Where-exactly-in-home-bricker-Projects-e") passed whole and baked
# the username into the id. After redact_home, both inputs also run
# through scrub_truncate (lib/scrub.sh, same single-source module):
# dash-form pathy text is cut at the first stem segment, stem-starting
# input dies to "" and the append is refused (fail closed). Truncation
# is lossy by design -- router-tick's documented tradeoff.
[ -n "${SCRUB_PY:-}" ] || . "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/redact.sh"

# Initiative budget (refoundation P7b): shared one-filing-per-cause-per-
# UTC-day counter plus the filing-about-filing demotion check, both via
# the same shell->python seam pattern as redact.sh (resolved relative to
# BASH_SOURCE; a missing module or interpreter fails OPEN = allowed, so
# lib-less sandboxes never beat).
_filing_budget_py="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/filing_budget.py"
_crumbs_py="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/crumbs.py"
_filing_budget_allow() { # family cause root -> rc0 allowed, rc1 over budget
 local rc=0
 python3 "$_filing_budget_py" --family "$1" --cause "$2" \
  --state-dir "${HNGH_FILING_STATE:-$3/state}" >/dev/null 2>&1 || rc=$?
 [ "$rc" -eq 1 ] && return 1 # rc1 = over budget; anything else fails open
 return 0
}
_filing_about_filing() { # text -> rc1 = disposition echo, demote
 python3 "$_filing_budget_py" --check-disposition --text "$1" >/dev/null 2>&1
}
_filing_crumb() { # event detail -> journal row, never fatal
 local db_args=()
 [ -n "${HNGH_CRUMBS_DB:-}" ] && db_args=(--db "$HNGH_CRUMBS_DB")
 python3 "$_crumbs_py" "${db_args[@]}" causes "$1" "$2" >/dev/null 2>&1 || :
}

append_research_subject() { # slug question -> appends to research-subjects.txt
 local slug redacted q root file id norm match_id rid rnorm
 slug="$1" q="$2"
 [ -n "$slug" ] && [ -n "$q" ] || return 1
 redacted="$(redact_home "$q")"
 [ -n "$redacted" ] || return 1 # redaction fail-closed empty -> refuse
 q="$(scrub_truncate "$redacted")"
 [ -n "$q" ] || return 1 # dash-form pathy -> refuse
 redacted="$(redact_home "$slug")"
 [ -n "$redacted" ] || return 1
 slug="$(scrub_truncate "$redacted")"
 [ -n "$slug" ] || return 1 # dash-form pathy -> refuse
 slug="$(printf '%s' "$slug" | tr -cs 'a-zA-Z0-9._-' '-' | sed 's/^-*//; s/-$//')"
 [ -n "$slug" ] || return 1
 root="${AUTOMATION_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
 file="$root/research-subjects.txt"
 # question-not-beat (refoundation P6): when an OPEN research line
 # (planned|contracting|crystallized) or an existing subject entry
 # already carries this normalized slug, the question lands under
 # THAT literal id (full-line dedup) instead of minting a parallel
 # fail-<date> entry. norm = lowercase; every run of non-[a-z0-9] ->
 # single '-'; trim leading/trailing '-'.
 norm="$(printf '%s' "$slug" | tr '[:upper:]' '[:lower:]' |
  tr -cs 'a-z0-9' '-' | sed 's/^-*//; s/-$//')"
 match_id=""
 if [ -n "$norm" ]; then
  match_id="$(
   {
    [ -f "$root/research-lines.tsv" ] &&
     awk -F'\t' \
      '$2=="planned"||$2=="contracting"||$2=="crystallized"{print $1}' \
      "$root/research-lines.tsv"
    [ -f "$file" ] && cut -f1 "$file"
   } 2>/dev/null |
    while IFS= read -r rid; do
     [ -n "$rid" ] || continue
     rnorm="$(printf '%s' "$rid" | tr '[:upper:]' '[:lower:]' |
      tr -cs 'a-z0-9' '-' | sed 's/^-*//; s/-$//')"
     if [ "$rnorm" = "$norm" ]; then
      printf '%s' "$rid"
      break
     fi
    done
  )"
 fi
 if [ -n "$match_id" ]; then
  id="$match_id"
  # full-line dedup: the question is already recorded under this id
  awk -F'\t' -v id="$id" -v q="$q" \
   '$1==id && $2==q {found=1} END{exit !found}' "$file" 2>/dev/null &&
   return 0
 else
  id="fail-$(date -u +%Y%m%d)-$slug"
  # refuse duplicates by id prefix match: the subject is already queued
  awk -F'\t' -v id="$id" 'index($1, id) == 1 {found=1} END{exit !found}' \
   "$file" 2>/dev/null && return 0
  # filing-about-filing (P7b): a subject whose text is (contained in)
  # an existing disposition verdict is the machine filing about its own
  # filings -- always a crumb, never a row, regardless of budget.
  # _filing_about_filing rc1 = the text echoes a disposition
  if ! _filing_about_filing "$q"; then
   _filing_crumb filing-about-filing \
    "$id demoted (subject echoes an existing disposition): $q"
   return 0
  fi
  # initiative budget (P7b): one NEW fail-subject per cause per UTC
  # day; over budget the id demotes to a crumb and nothing appends
  # (callers keep working, nothing beats). rc1 = over budget.
  if ! _filing_budget_allow fail "$slug" "$root"; then
   _filing_crumb research-subject-demoted \
    "$id over daily filing budget (subject not filed): $q"
   return 0
  fi
 fi
 touch "$file" 2>/dev/null || return 1
 printf '%s\t%s\n' "$id" "$q" >>"$file"
}
