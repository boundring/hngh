#!/usr/bin/env python3
"""feedback-ingest — standardize dashboard feedback into operator-items.

Scans automation/dashboard/feedback/*.json (written by the dashboard's
POST /api/feedback), dedupes by moving each file to feedback/processed/,
and files each item through the existing operator-item contract
(lib/operator-item.sh -> alert_row + breadcrumb) so the item lands on
the dashboard's operator-items feed like any other alert.

Standardized row: `[feedback:<type>][quick] <element>: <text>` where
[quick] is present only for css-theme|data-format (operator wants
simple specifics applied fast; the applying workstream keys on it).
Text is post-processed: common shorthand expanded via a fixed mapping
table (no magic), whitespace collapsed, trimmed.
"""
import os
import re
import subprocess
import sys
import time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
HNGH = os.environ.get("HNGH_REPO",
                      os.path.dirname(ROOT))
FEEDBACK = os.path.join(ROOT, "dashboard", "feedback")
PROCESSED = os.path.join(FEEDBACK, "processed")
AUTOMATION_ROOT = ROOT
KERNEL = HNGH
REPORT_ROOT = HNGH  # the ledger seam (report-queue ROOT); HNGH_HOME is
                    # NOT seamed — alert_row needs the real script path.

SHORTHAND = [
    (r"\bfont\+", "increase base font size"),
    (r"\bfont-", "decrease base font size"),
    (r"\bmargin\+", "increase margins"),
    (r"\bmargin-", "decrease margins"),
    (r"\bgap\+", "increase panel gap"),
    (r"\bgap-", "decrease panel gap"),
    (r"\bspacing\+", "increase spacing"),
    (r"\bspacing-", "decrease spacing"),
]

QUICK_TYPES = ("css-theme", "data-format")


def expand(text):
    """Expand fixed shorthand, trim, collapse whitespace. Plain-text only."""
    out = str(text)
    for pat, phrase in SHORTHAND:
        out = re.sub(pat, phrase, out)
    return re.sub(r"\s+", " ", out).strip()


def standardize(rec):
    """One feedback record -> the standardized operator-item text."""
    text = expand(rec.get("text", ""))
    tag = "[quick]" if rec.get("type") in QUICK_TYPES else ""
    element = re.sub(r"\s+", " ", str(rec.get("element") or "")).strip()
    head = ("[feedback:%s]%s %s: " % (rec.get("type"), tag, element)
            if element else "[feedback:%s]%s " % (rec.get("type"), tag))
    return (head + text).strip()


def file_item(identity, text):
    """File via the existing operator-item contract (hermetic env seams,
    dormant email channel — same discipline as the cap-block test)."""
    env = dict(os.environ)
    env.setdefault("HOME", AUTOMATION_ROOT)  # notify-email.sh set -u needs HOME
    env.update({
        "AUTOMATION_ROOT": AUTOMATION_ROOT,
        "STATE_FILE": os.path.join(AUTOMATION_ROOT, "STATE.md"),
        "HNGH_REPORT_ROOT": REPORT_ROOT,
        "HNGH_HOME": HNGH,  # lib/notify-email.sh KERNEL resolution
        "HNGH_NOTIFY_EMAIL_CONF":
            "/dev/null/notify-email.conf",  # dormant by design
        "JOB_NAME": "feedback-ingest",
        "ITEM_IDENTITY": identity,
        "ITEM_TEXT": text,
    })
    script = ('. "%s/lib/breadcrumbs.sh"\n'
              '. "%s/lib/notify-email.sh"\n'
              '. "%s/lib/operator-item.sh"\n'
              'operator_item "$ITEM_IDENTITY" "$ITEM_TEXT"\n'
              % (ROOT, ROOT, ROOT))
    return subprocess.run(["bash", "-c", script], env=env,
                          capture_output=True, text=True, timeout=60)


def main(argv):
    os.makedirs(PROCESSED, exist_ok=True)
    n = 0
    for name in sorted(os.listdir(FEEDBACK)):
        if not name.endswith(".json"):
            continue
        src = os.path.join(FEEDBACK, name)
        if os.path.isdir(src):
            continue
        try:
            import json
            with open(src, encoding="utf-8") as f:
                rec = json.load(f)
        except (OSError, ValueError) as exc:
            print("feedback-ingest: skip %s: %s" % (name, exc),
                  file=sys.stderr)
            continue
        text = standardize(rec)
        import hashlib
        identity = "feedback-" + hashlib.sha256(
            text.encode("utf-8")).hexdigest()[:8]
        r = file_item(identity, text)
        if r.returncode != 0:
            print("feedback-ingest: file rc=%d for %s: %s"
                  % (r.returncode, name, (r.stderr or "").strip()),
                  file=sys.stderr)
            continue
        os.replace(src, os.path.join(PROCESSED, name))  # dedupe marker
        n += 1
    if n:
        print("feedback-ingest: filed %d item(s)" % n)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))