#!/usr/bin/env python3
"""quips -- deterministic, evidence-first caption bank for the digest
editions (operator feedback 2026-09-12: "witty-but-dry quips").

Law (docs/design/display-register-spec.md s2/s7):
  - exactly one caption per section; the quip IS the caption, it never
    doubles a rendered fact line;
  - evidence-first: every quip embeds the numbers it captions;
  - the safe comedy lane is the MACHINE's own metrics only -- quips
    never target real people, outlets, or events;
  - deterministic: the day+section key picks the line, never the clock.

usage: quips.quip("ledger", date, spend=1.25, calls=195, quiet=22) -> str | None
"""
import hashlib

# One bank per section. Every template is a format string over the facts
# passed in; a missing fact must never crash the paper (all formats are
# fed complete dicts by the renderers below).
BANKS = {
    "ledger": [
        "The meters never once looked away: ${spend:.2f} across {calls} calls.",
        "{quiet} hours of dead air and ${spend:.2f} of metered thought, all of it.",
        "The hall billed ${spend:.2f} in {calls} breaths; the ledger absolves no one.",
        "${spend:.2f}, {calls} calls, {quiet} hushed hours -- arithmetic with a pulse.",
        # Distillation register (policy clause f, revised): each line is
        # an original distillation inspired by the collection's register;
        # the source is the study, not the line.
        "Death took the day off: ${spend:.2f} metered, {calls} calls, "
        "{quiet} quiet hours. The ledger can wait.",
        "{calls} calls, ${spend:.2f}. The silence moved first; "
        "the meters followed it down the hall.",
    ],
    "deck_a": [
        "{blocks} dispatch blocks, {criticals} alarms; the outside world "
        "remains unrunnable.",
        "{quiet_wins} quiet windows; even the wire sleeps on schedule.",
        "{criticals} red stamps across {blocks} blocks. The wires hummed; "
        "the paper counted.",
    ],
    "deck_b": [
        "The megastructure answered in {tokens} tokens; the walls held.",
        "{tokens} tokens in, grounded to the last line. The building "
        "keeps its books.",
        # Distillation register (policy clause f, revised).
        "{tokens} tokens. The corridors stayed silent; the work did "
        "not.",
    ],
    "comic": [
        "Everything above this panel was measured; this one is allowed "
        "to be a drawing.",
        "Filed under fiction. The only panel here that will not page anyone.",
        # Distillation register (policy clause f, revised).
        "He said the hole would close. It is still open. So, for the "
        "record, is this panel.",
    ],
    "machine_hall": [
        "The machine hall, rendered in the only medium it respects: text.",
        "Twenty-four columns of spent attention; the floor never blinks.",
        "The builders finished long ago. The hall still runs itself; "
        "nobody has asked it to stop.",
        # Distillation register (policy clause f, revised).
        "The mechanic never spoke a word. The hall does the talking for him.",
        "It is not broken in here. It is finished. That is worse.",
    ],
    "patrol": [
        "{surfaces} surfaces walked, {passes} green crumbs, {fails} red "
        "marks for the ledger; the rounds continue.",
        "The rounds ran on schedule: {passes} doors open, {fails} doors "
        "that need a key.",
        "{fails} red marks across {surfaces} surfaces. The rounds walked; "
        "the paper counted.",
        "{passes} green doors, {fails} doors a key alone will open. The "
        "corridors were quiet. The corridors are always quiet.",
        "{surfaces} surfaces, {fails} marks. Somewhere above, a stair "
        "went down a level the map does not keep.",
        # Distillation register (policy clause f, revised).
        "{surfaces} surfaces walked; {fails} of them only move when "
        "nobody is watching, which the rounds do not mention.",
        "{passes} doors open, {fails} things pretending to be doors. "
        "The watch logged both the same way.",
    ],
}


def _pick(section, date, bank):
    key = hashlib.sha1(("%s|%s" % (date, section)).encode()).hexdigest()
    return bank[int(key, 16) % len(bank)]


def quip(section, date, **facts):
    """One caption for <section> on <date>, or None when the bank has
    nothing for that section. Facts ride inside the line (register law)."""
    bank = BANKS.get(section)
    if not bank:
        return None
    return _pick(section, date, bank).format(**facts)
