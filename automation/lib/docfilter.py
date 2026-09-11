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
    clean = finalize(sys.stdin.read(), cap, truncated)
    if clean is None:
        return 1  # caller must file an alert and NOT write a doc
    sys.stdout.write(clean + "\n")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
