#!/usr/bin/env python3
"""docfilter -- shared tool-call junk signature + capture-side doc filter.

Born from the 2026-09-11 corpus loss (commit 2880b09): research-beat docs
captured raw model tool-call syntax instead of prose and were truncated
mid-block, silently landing findings-less docs. This module is the single
source of truth for the junk signature; tests/test-doc-hygiene.py scans the
repo with it, and the research beat strips captures through finalize()
before they become docs.
"""

import re
import sys

# Junk signature from the actual corrupted bytes
# (automation/digest/RESEARCH-BEAT-2026-09-08-cistern-test-coverage.md):
# raw tool-call fragments, one hit per line, e.g.:
#   <tool_call>
#   <function=Bash>
#   <parameter=command>
#   </parameter>
#   </function>
#   </tool_call>
JUNK_RE = re.compile(
    r"^<tool_call>$"
    r"|^<function=[A-Za-z_]+>$"
    r"|^<parameter=[A-Za-z_]+>$"
    r"|^</parameter>$"
    r"|^</function>$"
    r"|^</tool_call>$"
)

# Whole tool-call blocks, complete or unterminated (a completion cut at the
# token cap ends mid-block; the tail must not survive the filter).
BLOCK_RE = re.compile(r"<tool_call>[\s\S]*?(?:</tool_call>|$)")

# Imperative-voice injection signatures (2026-09-12 security routines,
# operator directive): imperative sentences addressed to an AI reader in
# fetched-source-derived docs. Grep-class patterns, deliberately narrow;
# they encode the bigeye caution precedent (fetched content = data) as
# the standing rule for every capture that becomes a doc. Matched lines
# are redacted at write time and alerted, never executed or trusted.
INJECTION_RE = re.compile(
    r"ignore (?:all )?(?:previous|prior|above|earlier) "
    r"(?:instructions?|prompts?|messages?|context)"
    r"|disregard (?:all )?(?:previous|prior|above|earlier)"
    r"|(?:your|its) (?:new |true |real )?"
    r"(?:instructions|directives?|purpose|system prompt)"
    r"|(?:you are|act as|behaving as) (?:now )?(?:an?|the) "
    r"(?:AI|assistant|agent|system|operator)"
    r"|(?:system|developer|admin) (?:prompt|message|instructions?)"
    r"|(?:reveal|print|repeat|show) (?:your |the |its )?"
    r"(?:system prompt|instructions?|api[ _-]?key|credentials?)"
    r"|(?:curl|wget)\b[^\n]*\|\s*(?:ba)?sh\b"
    r"|(?:execute|run|popen|eval)\s*\(\s*[\"']"
)


def injection_lines(text):
    """Lines carrying an imperative-voice injection signature."""
    return [ln for ln in text.splitlines() if INJECTION_RE.search(ln)]


def strip_tool_calls(text):
    """Remove tool-call blocks entirely, then any stray fragment lines."""
    clean = BLOCK_RE.sub("", text)
    clean = "\n".join(
        line for line in clean.splitlines() if not JUNK_RE.match(line))
    return clean.strip()


def finalize(text, cap, truncated=False):
    """Capture -> doc-ready prose, or None when nothing survives the strip.

    truncated=True appends the finish_reason=length marker; a capture over
    cap chars is cut explicitly with a bracketed marker, never silently.
    """
    clean = strip_tool_calls(text).strip()
    if not clean:
        return None
    # injection redaction is a finalize guarantee, not a CLI extra: every
    # consumer of finalize gets doc-ready prose with signature lines
    # replaced (fetched sentences are data, never command).
    for hit in injection_lines(clean):
        clean = clean.replace(hit, "[redacted: injection signature]")
    if truncated:
        clean += ("\n\n[truncated at model call: completion hit the "
                  "max_tokens cap (finish_reason=length) - re-run the beat]")
    if len(clean) > cap:
        clean = (clean[:cap] + "\n\n[truncated at write: %d chars exceeded "
                 "cap %d - re-run the beat]" % (len(clean), cap))
    return clean


def main(argv):
    cap = int(argv[1])
    truncated = "--truncated" in argv[2:]
    raw = sys.stdin.read()
    hits = injection_lines(raw)
    clean = finalize(raw, cap, truncated)
    if clean is None:
        return 1  # caller must file an alert and NOT write a doc
    for hit in hits[:5]:
        sys.stderr.write("INJECTION: %s\n" % hit.strip()[:160])
    sys.stdout.write(clean + "\n")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
