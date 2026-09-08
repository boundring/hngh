#!/usr/bin/env bash
# night-research — 23:40: one free local-model research brief compiled from
# today's accumulated snapshots and daily digest. Local Unsloth/ollama only
# (zero cost). Fail-closed: exits 0.
set -u
. "$(cd "$(dirname "$0")/.." && pwd)/lib/common.sh"
. "$AUTOMATION_ROOT/lib/breadcrumbs.sh"
. "$AUTOMATION_ROOT/lib/sources.sh"
. "$AUTOMATION_ROOT/lib/model.sh"
. "$AUTOMATION_ROOT/lib/hngh-record.sh"

DATE="$(date +%F)"
TS="$(date +%H%M)"
OUT="$AUTOMATION_ROOT/digest/RESEARCH-$DATE.md"

names="$(printf '%s\n' "$SOURCES" | cut -d: -f1 | tr '\n' ' ' | sed 's/ $//')"

# Corpus: today's newest snapshot per source + the daily digest.
corpus=""
for name in $names; do
  f="$(newest_snapshot "$AUTOMATION_ROOT/snapshots/$DATE" "$name")"
  [ -n "$f" ] && corpus+="$(source_block "$f" 4000)"$'\n'
done
[ -f "$AUTOMATION_ROOT/digest/$DATE.md" ] &&
  corpus+="$(marked_cut 6000 "$AUTOMATION_ROOT/digest/$DATE.md")"

if [ -z "$corpus" ]; then
  breadcrumb "$JOB_NAME" "research" "no snapshots and no digest today; nothing to research"
  exit 0
fi

prompt="$(
  cat <<EOF
You write Hngh's nightly research brief from today's accumulated news snapshots and digest.

Focus: AI-research news, business/finance news, and anything impacting Hngh's roadmap (policy-gated agent harnesses, attestation and key pinning, local-model tooling).

Register: captions in the margin of a quiet megastructure. Evidence first; commentary never.

Output exactly three tiers, plain text, one bullet per line, each starting with the tier tag:
CRITICAL: active exploitation or human harm (1-3 bullets)
NOTABLE: self-hosting/infrastructure relevance (3-6 bullets)
CONTEXT: background (2-4 bullets)

Rules:
- One line per item: a plain declarative sentence with concrete nouns. Report only what is NEW today; items already in the daily digest are old, repeat one only if its state changed (new severity, resolution, escalation, or a material fact added).
- No significance adjectives (banned: historic, significant, major, groundbreaking, "sparking discussion"). No editorializing about what a thing means.
- Quote proper nouns verbatim from the sources: companies, products, codenames, place names. Never paraphrase, respell, or guess a name; if unsure, drop the item.
- If nothing qualifies for a tier, omit that tier; if nothing is new at all, return exactly: none — quiet window.
No markdown headers, no preamble, no trailing commentary.

$corpus
EOF
)"

summary="$(printf '%s' "$prompt" | model_call 4096)"
summary="$(printf '%s' "$summary" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
used="$(last_model_used)"

if [ -n "$summary" ]; then
  {
    printf '# Research brief %s\n' "$DATE"
    printf '_compiled %s | model: %s_\n' "$TS" "$used"
    printf '\n%s\n' "$summary"
  } >"$OUT"
  breadcrumb "$JOB_NAME" "research" "RESEARCH-$DATE.md written via $used"
else
  breadcrumb "$JOB_NAME" "research" "local model produced no brief (fail-closed; archive-only)"
fi

update_dashboard "$JOB_NAME" "$DATE" "$TS"
record_hngh_run "night research digest $DATE $TS"
exit 0
