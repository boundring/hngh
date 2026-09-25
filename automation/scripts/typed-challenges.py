#!/usr/bin/env python3
"""typed-challenges.py -- typed Jev findings producer for the ceremony.

Usage: typed-challenges.py OBJECTIVE FILE...

Prints findings TSV on stdout (empty = no findings), ALWAYS exit 0.
Wire shape (consumed by scripts/ceremony-drive --findings):

    <principle>\t<text>\t<cite>

one line per finding, <=32 lines, text and cite <=200 chars each.
Findings are recorded DATA: advisory challenges riding the certificate,
never evidence and never principle-satisfying (design doc :57, :144-145).

One batched system_one call (lib/typesafe.py ask_nouls) over the ten
principle-matrix refusal conditions
(docs/design/autonomous-development-control.md :51-62); a question fires
one finding at v >= 0.7 (the steer bar precedent). A second batched call
asks the disconfirming question per principle and emits advisory counter
rows at the same bar (the principle column keeps the matrix name; the
text carries "counter p="). At most 20 rows ever ride out. Fail-open: no
key, any failure, or every v < 0.7 -> empty stdout and the ceremony runs
exactly as before. Citation caveat (recorded): System One returns labels
and probabilities only, so the cite names the judged source set, not
lines; line-level cites remain the chat reviewer's job.
"""
import os
import subprocess
import sys

sys.path.insert(
    0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "lib"))
from typesafe import ask_nouls

FIRE_BAR = 0.7
DIFF_CUT = 8000
FIELD_CUT = 200
ROW_CAP = 20

# The principle matrix (design doc :51-62): wire name -> refusal
# condition. Order is the fixed matrix order.
PRINCIPLES = {
    "closed-authority": "Unknown or implicit capability",
    "least-authority": "Undeclared authority or scope broadening",
    "dependency-direction": "Inward outer or test dependency",
    "fail-closed": "Missing, malformed, conflicting, or stale evidence",
    "evidence-before-claim": "Unsupported claim or model opinion as proof",
    "atomic-mutation": "Any candidate mismatch",
    "reversibility": "External effect without rollback/containment",
    "no-hidden-execution": "Import-time or implicit execution",
    "cost-and-route-discipline": "Unknown/exhausted allowance",
    "source-grounding": "Missing, stale, or conflicting sources",
}


def _repo_root():
    # HNGH_HOME seam (context-pack.sh pattern) over a derived fallback:
    # never a literal home path.
    return os.environ.get("HNGH_HOME") or os.path.dirname(
        os.path.dirname(os.path.dirname(os.path.abspath(__file__))))


def _diff(files):
    try:
        out = subprocess.run(
            ["git", "-C", _repo_root(), "diff", "HEAD", "--"] + files,
            capture_output=True, text=True, errors="replace", timeout=30,
        ).stdout
    except Exception:
        out = ""
    return out[:DIFF_CUT]


def findings(objective, files):
    """-> list of TSV lines; empty = no findings (fail-open)."""
    state = {
        "objective": objective,
        "diff": _diff(files),
        "files": ",".join(files),
    }
    questions = {
        name: "%s. Is there a real risk this candidate trips it?" % cond
        for name, cond in PRINCIPLES.items()
    }
    try:
        values = ask_nouls(state, questions)
        cite = ",".join(files)[:FIELD_CUT]
        out = []
        for name, cond in PRINCIPLES.items():
            v = values.get(name)
            if v is not None and v >= FIRE_BAR:
                text = ("risk p=%.2f: %s" % (v, cond))[:FIELD_CUT]
                out.append("%s\t%s\t%s" % (name, text, cite))
    except Exception:
        return []
    counters = {
        name: ("%s. Is there a plausible disconfirming reading of this "
               "candidate?") % cond
        for name, cond in PRINCIPLES.items()
    }
    try:
        cvalues = ask_nouls(state, counters)
        for name, cond in PRINCIPLES.items():
            v = cvalues.get(name)
            if v is not None and v >= FIRE_BAR:
                text = ("counter p=%.2f: plausible disconfirming reading of %s"
                        % (v, cond))[:FIELD_CUT]
                out.append("%s\t%s\t%s" % (name, text, cite))
    except Exception:
        pass
    return out[:ROW_CAP]


if __name__ == "__main__":
    try:
        argv = sys.argv[1:]
        lines = findings(argv[0], argv[1:]) if len(argv) >= 2 else []
    except Exception:
        lines = []
    if lines:
        sys.stdout.write("\n".join(lines) + "\n")
    sys.exit(0)
