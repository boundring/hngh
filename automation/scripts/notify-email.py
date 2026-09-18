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
import importlib.util
import os
import smtplib
import subprocess
import sys
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText
from email.utils import formatdate

DEFAULT_CONF = os.path.expanduser("~/.hngh-automation/notify-email.conf")
OP_TIMEOUT = 45


def fail(msg, code):
    sys.stderr.write("notify-email: %s\n" % msg)
    sys.exit(code)


_SCRUB_PY = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                         os.pardir, "lib", "scrub.py")


def fail_closed():
    """True iff the outbound scrub guard loaded (or loads now). The
    send path is an outbound channel independent of the report-queue
    row (ts-angle3-email-outbound-scrub, 2026-09-17): subjects and
    bodies pass through the machine-local path-token family
    (automation/lib/scrub.py) before any SMTP compose. Ordinary prose
    and source URLs survive verbatim except credential userinfo;
    redaction, not dropping."""
    global _OUTBOUND_SCRUB
    if _OUTBOUND_SCRUB is not None:
        return _OUTBOUND_SCRUB
    try:
        spec = importlib.util.spec_from_file_location(
            "notify_email_scrub", _SCRUB_PY)
        mod = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(mod)
        _OUTBOUND_SCRUB = lambda text: mod.scrub_paths(str(text or ""))
    except Exception:
        _OUTBOUND_SCRUB = False
    return _OUTBOUND_SCRUB


_OUTBOUND_SCRUB = None


def scrub_outbound(text):
    """Fail-closed outbound scrub: unreadable module grades harder than
    a leak, so a broken guard refuses the send (never leaks)."""
    fn = fail_closed()
    if fn is False:
        fail("outbound scrub module unavailable at %s - fail closed"
             % _SCRUB_PY, 2)
    return fn(text)


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
    # Map the operator's service key onto op's service-account env FIRST
    # (mirrors lib/credentials.sh; Python callers don't source it). The
    # CLI falls back to the desktop-app integration — and its interactive
    # password prompt — when only ONEPASSWORD_SERVICE_KEY is set.
    if not os.environ.get("OP_SERVICE_ACCOUNT_TOKEN"):
        _key = os.environ.get("ONEPASSWORD_SERVICE_KEY")
        if _key:
            os.environ["OP_SERVICE_ACCOUNT_TOKEN"] = _key
    # Service-account-only (2026-09-13): `op` is invoked ONLY when a
    # service token exists (mapped here from ONEPASSWORD_SERVICE_KEY —
    # this script may run without lib/credentials.sh, e.g. via notify.sh).
    # No token -> fail soft to the conf pass fallback; never reach the
    # desktop-app integration, which can demand an interactive prompt.
    if not (os.environ.get("OP_SERVICE_ACCOUNT_TOKEN")
            or os.environ.get("ONEPASSWORD_SERVICE_KEY")):
        return None
    try:
        return subprocess.run(
            [os.environ.get("HNGH_OP_BIN", "op")] + list(args),
            capture_output=True, timeout=OP_TIMEOUT)
    except (OSError, subprocess.SubprocessError):
        return None


def op_password(item):
    """Secret from `op read`, or None on any failure. Never logged."""
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


def compose(cp, subject, body, html_body=None):
    if html_body:
        msg = MIMEMultipart("alternative")
        msg.attach(MIMEText(body, "plain", "utf-8"))
        msg.attach(MIMEText(html_body, "html", "utf-8"))
    else:
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
    subject = body = html_body = None
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
        elif a == "--html-file" and i + 1 < len(argv):
            try:
                with open(argv[i + 1], encoding="utf-8", errors="replace") as fh:
                    html_body = fh.read()
            except OSError as exc:
                fail("cannot read html file: %s" % exc, 2)
            i += 2
        else:
            fail("usage: notify-email.py send --subject S "
                 "(--body-file F|--body-text T) [--html-file H]", 2)
    if subject is None or body is None:
        fail("--subject and one of --body-file/--body-text required", 2)
    return subject, body, html_body


def main(argv):
    if len(argv) >= 2 and argv[1] == "classify":
        if "--text" not in argv[2:] or argv.index("--text") + 1 >= len(argv):
            fail("usage: notify-email.py classify --text T", 2)
        sys.stdout.write(classify_alert(argv[argv.index("--text") + 1]) + "\n")
        return 0
    if len(argv) < 2 or argv[1] != "send":
        fail("usage: notify-email.py send --subject S (--body-file F|--body-text T)\n"
             "       notify-email.py classify --text T", 2)
    subject, body, html_body = parse_args(argv[2:])
    # Outbound scrub (ts-angle3-email-outbound-scrub 2026-09-17): the
    # send path is an outbound channel INDEPENDENT of the report-queue
    # row's sink-side redact_boundary; subject and body carry the
    # machine-local token family here, at the last boundary before
    # SMTP compose. classify stays vocabulary-only (the rubric).
    subject = scrub_outbound(subject)
    body = scrub_outbound(body)
    cp = load_conf()
    msg = compose(cp, subject, body, html_body)
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
