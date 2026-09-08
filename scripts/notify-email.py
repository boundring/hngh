#!/usr/bin/env python3
"""notify-email — procedural email reports to the operator (stdlib only).

Config: the operator places an INI at ~/.hngh-automation/notify-email.conf
(env seam HNGH_NOTIFY_EMAIL_CONF for tests); this script NEVER creates or
edits it. Format:

    [smtp]
    host / port / user / pass / from / to
    [1password]
    ; optional — preferred credential source; pass becomes the fallback
    item = op://<vault>/<item>/<field>
    [flags]
    ; optional
    subject-prefix = [hngh]

Password precedence at send time: with [1password] item present and a live
`op` session (HNGH_OP_BIN seam, 45s cap) the password comes from `op read`
and the raw value never touches disk; on any op failure the conf `pass`
field is the fallback; with neither, fail closed (exit 2). Without the
[1password] section behavior is unchanged and `pass` is required.

Fail-closed: missing config or mode looser than 600 -> one stderr line,
exit 2, nothing sent; send failure -> exit 1. DRY_RUN=1 prints the
composed message instead of sending.

Importance rubric (classify_alert): alert rows ALWAYS land in the
report-queue and the daily digest; only IMMEDIATE-class rows also email
right away. Ranked, first match wins; default = digest-only so noise
never spams the inbox:
  IMMEDIATE: park/critical-class; service-ctl actions; unsloth serving
    down/recovered; agent-stall; git-push-fail; credential/config
    touches; ceremony/verdict failures; kernel tree-skew; budget cap
    exceeded.
  DEFER-TO-DIGEST: routine gate flaps; ui-audit nits; repeat-crumbs;
    feed-validity one-steppers.
Set HNGH_NOTIFY_IMMEDIATE=0 to force everything to digest-only
(tests/override).

usage: notify-email.py send --subject S (--body-file F | --body-text T)
       notify-email.py classify --text T   # prints immediate|digest
"""
import configparser
import os
import smtplib
import subprocess
import sys
from email.mime.text import MIMEText
from email.utils import formatdate

DEFAULT_CONF = os.path.expanduser("~/.hngh-automation/notify-email.conf")
OP_TIMEOUT = 45


def fail(msg, code):
    sys.stderr.write("notify-email: %s\n" % msg)
    sys.exit(code)


def conf_path():
    return os.environ.get("HNGH_NOTIFY_EMAIL_CONF") or DEFAULT_CONF


def load_conf():
    path = conf_path()
    if not os.path.isfile(path):
        fail("no config at %s — email channel dormant (operator setup item)" % path, 2)
    if os.stat(path).st_mode & 0o077:
        fail("config %s must be chmod 600" % path, 2)
    cp = configparser.ConfigParser()
    cp.read(path)
    if not cp.has_section("smtp"):
        fail("config missing [smtp] section", 2)
    has_item = cp.has_section("1password") and cp.has_option("1password", "item")
    required = ("host", "port", "user", "from", "to")
    if not has_item:
        required += ("pass",)  # item present -> pass is the fallback only
    for key in required:
        if not cp.has_option("smtp", key):
            fail("config missing [smtp] %s" % key, 2)
    return cp


def op_run(*args):
    try:
        return subprocess.run(
            [os.environ.get("HNGH_OP_BIN", "op")] + list(args),
            capture_output=True, timeout=OP_TIMEOUT)
    except (OSError, subprocess.SubprocessError):
        return None


def op_password(item):
    """Secret from `op read`, or None on any failure. Never logged."""
    ready = op_run("whoami")
    if ready is None or ready.returncode != 0:
        return None
    got = op_run("read", item)
    if got is None or got.returncode != 0:
        return None
    return got.stdout.decode("utf-8", "replace").strip()


def resolve_password(cp):
    item = (cp.get("1password", "item")
            if cp.has_section("1password") and cp.has_option("1password", "item")
            else None)
    if item:
        pw = op_password(item)
        if pw:
            return pw
        sys.stderr.write("notify-email: 1password unavailable — conf pass fallback\n")
    pw = cp.get("smtp", "pass", fallback="").strip()
    if not pw:
        fail("no password available (1password unreadable, conf pass empty) — fail closed", 2)
    return pw


def compose(cp, subject, body):
    msg = MIMEText(body, "plain", "utf-8")
    prefix = cp.get("flags", "subject-prefix") if cp.has_option("flags", "subject-prefix") else ""
    msg["Subject"] = ("%s %s" % (prefix, subject)) if prefix else subject
    msg["From"] = cp.get("smtp", "from")
    msg["To"] = cp.get("smtp", "to")
    msg["Date"] = formatdate(localtime=False)
    return msg


def send(msg, cp, password):
    with smtplib.SMTP(cp.get("smtp", "host"), cp.getint("smtp", "port"),
                      timeout=30) as s:
        try:
            s.starttls()
        except smtplib.SMTPException:
            pass  # plain- local relay: no STARTTLS offered
        s.login(cp.get("smtp", "user"), password)
        s.send_message(msg)


IMMEDIATE_PATTERNS = (  # ranked; first match wins
    ("park/critical-class", ("park", "critical")),
    ("service-ctl actions", ("service-ctl", "service ctl")),
    ("serving down/recovered", ("serving down", "serving recovered",
                                "unsloth")),
    ("agent-stall", ("agent-stall", "stall")),
    ("git-push-fail", ("git-push", "push failed", "push-fail")),
    ("credential/config touches", ("credential", "config")),
    ("ceremony/verdict failures", ("ceremony", "verdict")),
    ("tree-skew on kernel", ("tree-skew", "tree skew")),
    ("budget-cap exceeded", ("budget-cap", "budget cap")),
)
DIGEST_PATTERNS = (
    ("routine gate flaps", ("gate",)),
    ("ui-audit nits", ("ui-audit",)),
    ("repeat-crumbs", ("repeat-crumb",)),
    ("feed-validity one-steppers", ("feed-validity",)),
)


def classify_alert(text):
    """immediate | digest — see the rubric in the module docstring."""
    if os.environ.get("HNGH_NOTIFY_IMMEDIATE") == "0":
        return "digest"
    low = (text or "").lower()
    for _name, pats in IMMEDIATE_PATTERNS:
        if any(p in low for p in pats):
            return "immediate"
    for _name, pats in DIGEST_PATTERNS:
        if any(p in low for p in pats):
            return "digest"
    return "digest"  # default: noise never spams the inbox


def parse_args(argv):
    subject = body = None
    i = 0
    while i < len(argv):
        a = argv[i]
        if a == "--subject" and i + 1 < len(argv):
            subject = argv[i + 1]; i += 2
        elif a == "--body-file" and i + 1 < len(argv):
            try:
                with open(argv[i + 1], encoding="utf-8", errors="replace") as fh:
                    body = fh.read()
            except OSError as exc:
                fail("cannot read body file: %s" % exc, 2)
            i += 2
        elif a == "--body-text" and i + 1 < len(argv):
            body = argv[i + 1]; i += 2
        else:
            fail("usage: notify-email.py send --subject S (--body-file F|--body-text T)", 2)
    if subject is None or body is None:
        fail("--subject and one of --body-file/--body-text required", 2)
    return subject, body


def main(argv):
    if len(argv) >= 2 and argv[1] == "classify":
        if "--text" not in argv[2:] or argv.index("--text") + 1 >= len(argv):
            fail("usage: notify-email.py classify --text T", 2)
        sys.stdout.write(classify_alert(argv[argv.index("--text") + 1]) + "\n")
        return 0
    if len(argv) < 2 or argv[1] != "send":
        fail("usage: notify-email.py send --subject S (--body-file F|--body-text T)\n"
             "       notify-email.py classify --text T", 2)
    subject, body = parse_args(argv[2:])
    cp = load_conf()
    msg = compose(cp, subject, body)
    if os.environ.get("DRY_RUN") == "1":
        sys.stdout.write(msg.as_string())
        return 0
    password = resolve_password(cp)
    try:
        send(msg, cp, password)
    except Exception as exc:
        fail("send failed: %s" % exc, 1)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
