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
#   unknown            no keyword matched -- generic investigate, fix or park

classify_cause() { # logfile -> one cause class on stdout (unknown if no log)
 local log="$1" text=""
 if [ -n "$log" ] && [ -f "$log" ]; then
  # two-stage classification (2026-09-11 404-in-success false positive):
  # first keep only failure-shaped lines, then run the class table on
  # those alone. Incidental keyword mentions in success prose (research
  # docs citing 404s, budget chatter) never classify; no failure-shaped
  # line in the tail means unknown regardless of keywords.
  text="$(tail -n 200 "$log" 2>/dev/null |
   grep -iE 'error|fatal|fail|refus|traceback|exit code [1-9]|rc=[1-9]|exit [1-9]|budget excee|budget exhaust|cost limit|cap reach|cap excee|cap hit|exhausted|timeout' |
   tr '[:upper:]' '[:lower:]')"
 fi
 [ -z "$text" ] && {
  printf 'unknown'
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
 *) printf 'unknown' ;;
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

append_research_subject() { # slug question -> appends to research-subjects.txt
 local slug="$1" q="$2" root file id
 [ -n "$slug" ] && [ -n "$q" ] || return 1
 slug="$(printf '%s' "$slug" | tr -cs 'a-zA-Z0-9._-' '-' | sed 's/^-*//; s/-$//')"
 [ -n "$slug" ] || return 1
 root="${AUTOMATION_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
 file="$root/research-subjects.txt"
 id="fail-$(date -u +%Y%m%d)-$slug"
 touch "$file" 2>/dev/null || return 1
 # refuse duplicates by id prefix match: the subject is already queued
 awk -F'\t' -v id="$id" 'index($1, id) == 1 {found=1} END{exit !found}' \
  "$file" 2>/dev/null && return 0
 printf '%s\t%s\n' "$id" "$q" >>"$file"
}
