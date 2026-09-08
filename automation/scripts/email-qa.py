#!/usr/bin/env python3
"""email-qa — daily adversarial QA of the operator digest (procedural,
no LLM). Scores yesterday's digest (logs/email-digest-<yesterday>.md,
env/arg seam --digest for tests) against a fixed rubric:

  1. TL;DR head present: a "status: OK|ATTENTION..." line near the top.
  2. No section that is present but empty.
  3. Headline/alerts consistency: ATTENTION with N>0 must not coexist
     with "none — quiet window", and listed alerts must not coexist
     with a plain "status: OK".
  4. Total length < 120 lines.
  5. Redaction duty (credentials-posture.md §4): no value matching the
     conf's smtp `pass` field anywhere in the digest (compare-and-redact
     check — the secret is never printed by this scorer either).
  6. Voice check (display register): CRITICAL/NOTABLE items repeated in
     3+ hour blocks (chatter) or banned significance adjectives.

Prints ONE verdict line; exit 0 always (findings are data, not failure).
The cadence drop-in (cadence/day/13-email-qa.sh) files findings as one
optimization report row per day (identity-deduped) and appends the
verdict to logs/email-qa.log — the digest's self-improving loop.

usage: email-qa.py [--digest PATH]   (default: yesterday's digest)
"""
import argparse
import configparser
import os
import re
import sys
from datetime import datetime, timedelta, timezone

AUTOMATION = os.environ.get(
    "HNGH_AUTOMATION_ROOT",
    os.path.dirname(os.path.dirname(os.path.abspath(__file__))))


def conf_password():
    """The conf smtp pass value for the redaction check, or None.
    Never printed, logged, or embedded in findings."""
    conf = os.environ.get(
        "HNGH_NOTIFY_EMAIL_CONF",
        os.path.expanduser("~/.hngh-automation/notify-email.conf"))
    try:
        cp = configparser.ConfigParser()
        cp.read(conf)
        return cp.get("smtp", "pass", fallback=None)
    except Exception:
        return None


def sections(text):
    """[(title, body_lines)] from the digest markdown."""
    out, title, body = [], None, []
    for ln in text.splitlines():
        if ln.startswith("## "):
            if title is not None:
                out.append((title, body))
            title, body = ln[3:].strip(), []
        elif title is not None:
            body.append(ln)
    if title is not None:
        out.append((title, body))
    return out


def findings(text, secret, hourly=None):
    if not text.strip():
        return ["digest file missing or empty"]
    f = []
    lines = text.splitlines()
    if len(lines) >= 120:
        f.append("digest too long: %d lines (target <120)" % len(lines))
    if not re.search(r"^status: (OK|ATTENTION)", text, re.M):
        f.append("no TL;DR head (missing 'status:' line near the top)")
    for title, body in sections(text):
        content = [b for b in body if b.strip()
                   and not b.startswith("Section summary")]
        if not content:
            f.append("section present but empty: %s" % title)
    att = re.search(r"^status: ATTENTION: (\d+)", text, re.M)
    quiet = "none — quiet window" in text
    alerts_body = next((b for t, b in sections(text)
                        if t.startswith("Alerts")), [])
    listed = [b for b in alerts_body
              if b.strip() and b.strip() != "none — quiet window"]
    if att and int(att.group(1)) > 0 and quiet:
        f.append("headline reports %s alert(s) but the alerts section is quiet"
                 % att.group(1))
    if not att and listed and "status: OK" in text:
        f.append("alerts listed but the headline says OK")
    if (not att and not listed and quiet and re.search(r"^status: ", text, re.M)
            and "status: OK" not in text):
        f.append("alerts section quiet but the headline is not OK")
    if secret and len(secret) >= 4 and secret in text:
        f.append("SECRET LEAK: digest contains the conf password value")
    f.extend(voice_findings(text, hourly))
    return f


def voice_findings(text, digest_path=None):
    """Chatter check: an item repeated in 3+ hour blocks of today's
    digest, or a banned significance adjective used more than twice.
    Non-blocking data. Skipped when no hourly digest path is given
    (keeps tests hermetic; the CLI supplies the default path)."""
    f = []
    path = digest_path or os.environ.get("HNGH_QA_HOURLY_DIGEST")
    if not path:
        return f
    try:
        with open(path, encoding="utf-8", errors="replace") as fh:
            digest = fh.read()
    except OSError:
        return f
    # blocks split on "## <time>" headers; count items per block.
    blocks = re.split(r"^## ", digest, flags=re.M)[1:]
    seen = {}
    for blk in blocks:
        items = {re.sub(r"\s+", " ", re.sub(
                     r"^(CRITICAL|NOTABLE):\s*", "", ln)).strip().lower()
                 for ln in blk.splitlines() if ln[:9].rstrip(":") in ("CRITICAL", "NOTABLE")}
        for it in items:
            seen[it] = seen.get(it, 0) + 1
    for it, n in sorted(seen.items()):
        if n >= 3 and it[:60]:
            f.append("chatter: '%s' repeated %d times" % (it[:60], n))
    adj = re.findall(r"\b(historic|significant|groundbreaking|major)\b",
                     digest, re.I)
    if len(adj) > 2:
        f.append("significance adjectives x%d: %s" % (len(adj), adj[0]))
    return f


def main():
    ap = argparse.ArgumentParser(prog="email-qa")
    ap.add_argument("--digest", default=None,
                    help="digest path (default: yesterday's)")
    ap.add_argument("--hourly", default=None,
                    help="hourly digest path for the chatter check "
                         "(default: today's)")
    a = ap.parse_args()
    today = datetime.now(timezone.utc).strftime("%Y-%m-%d")
    yesterday = (datetime.now(timezone.utc)
                 - timedelta(days=1)).strftime("%Y-%m-%d")
    path = a.digest or os.path.join(
        AUTOMATION, "logs", "email-digest-%s.md" % yesterday)
    try:
        with open(path, encoding="utf-8", errors="replace") as fh:
            text = fh.read()
    except OSError:
        text = ""
    f = findings(text, conf_password(),
                 hourly=a.hourly or os.path.join(AUTOMATION, "digest",
                                                 today + ".md"))
    if f:
        print("email-qa %s: FINDINGS %d: %s"
              % (yesterday, len(f), "; ".join(f)))
    else:
        print("email-qa %s: PASS" % yesterday)
    return 0


if __name__ == "__main__":
    sys.exit(main())
