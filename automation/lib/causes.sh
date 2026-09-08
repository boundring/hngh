# causes.sh -- the failure bestiary: deterministic cause classification for
# dead/stalled session logs, plus research-subject intake for the demand-
# driven research beat. Every failure class below is one bestiary entry with
# its countermeasure routing; the case table in classify_cause is the ONE
# place the keyword mapping lives (first match wins, table order is the
# precedence):
#
#   bad-execution     budget/cap/exhausted/timeout -- execution failed, the
#                     plan was fine; route back to the owning lane with a
#                     smaller step
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
  text="$(tail -n 200 "$log" 2>/dev/null | tr '[:upper:]' '[:lower:]')"
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
 *"budget"* | *"cap"* | *"exhausted"* | *"timeout"*) printf 'bad-execution' ;;
 *"superseded"* | *"duplicate"* | *"stale"*) printf 'obsolete' ;;
 *) printf 'unknown' ;;
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
