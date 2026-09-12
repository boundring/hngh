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
        "{quiet} hours of dead air and ${spend:.2f} of metered thought.",
        "The hall billed ${spend:.2f} in {calls} breaths; the ledger absolves no one.",
        "${spend:.2f}, {calls} calls, {quiet} hushed hours -- arithmetic with a pulse.",
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
    ],
    "comic": [
        "Everything above this panel was measured; this one is allowed "
        "to be a drawing.",
        "Filed under fiction. The only panel here that will not page anyone.",
    ],
    "machine_hall": [
        "The machine hall, rendered in the only medium it respects: text.",
        "Twenty-four columns of spent attention; the floor never blinks.",
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
