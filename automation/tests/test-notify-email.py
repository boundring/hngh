#!/usr/bin/env python3
"""notify-email + email-digest contract, hermetic.

SMTP is stubbed by patching smtplib.SMTP in-process — no socket, no
real server, no credentials. The digest composer runs against fixture
dirs via env seams (HNGH_DIGEST_*): never real git, never telemetry.
Contracts: missing/loose config exits 2 with one stderr line; a good
config composes correct From/To/Subject/body; DRY_RUN prints instead
of sending; the digest renders every section from fixture data.
"""

import contextlib
import io
import json
import os
import re
import smtplib
import subprocess
import sys
import tempfile
import unittest
from datetime import datetime, timezone
from pathlib import Path
from unittest import mock

ROOT = Path(__file__).resolve().parent.parent
NOTIFY = ROOT / "scripts" / "notify-email.py"
DIGEST = ROOT / "scripts" / "email-digest.py"
SETUP = ROOT / "scripts" / "setup-notify-email.sh"

sys.path.insert(0, str(NOTIFY.parent))
import importlib.util
_spec = importlib.util.spec_from_file_location("notify_email", NOTIFY)
notify_email = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(notify_email)

CONF = """[smtp]
host = smtp.example.test
port = 587
user = bot@example.com
pass = sekrit
from = bot@example.com
to = operator@example.com

[flags]
subject-prefix = [hngh]
"""

CONF_OP = """[smtp]
host = smtp.example.test
port = 587
user = bot@example.com
from = bot@example.com
to = operator@example.com

[1password]
item = op://vault/hngh-notify-email/password
"""


def write_conf(root, mode=0o600, text=CONF):
    p = root / "notify-email.conf"
    p.write_text(text)
    p.chmod(mode)
    return p


class StubSMTP:
    instances = []

    def __init__(self, host, port, timeout=None):
        self.host, self.port = host, port
        self.sent = []
        self.logins = []
        self.starttls_called = False
        StubSMTP.instances.append(self)

    def __enter__(self):
        return self

    def __exit__(self, *exc):
        return False

    def starttls(self):
        self.starttls_called = True

    def login(self, user, pw):
        self.logins.append((user, pw))

    def send_message(self, msg):
        self.sent.append(msg)


class NotifyEmail(unittest.TestCase):
    def setUp(self):
        self.root = Path(tempfile.mkdtemp())
        self.conf = write_conf(self.root)
        os.environ["HNGH_NOTIFY_EMAIL_CONF"] = str(self.conf)
        StubSMTP.instances = []
        self._patcher = mock_patch()
        self._patcher.start()

    def tearDown(self):
        os.environ.pop("HNGH_NOTIFY_EMAIL_CONF", None)
        os.environ.pop("DRY_RUN", None)
        self._patcher.stop()

    def run_main(self, args, dry_run=False):
        if dry_run:
            os.environ["DRY_RUN"] = "1"
        out, err = io.StringIO(), io.StringIO()
        code = 0
        with contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
            try:
                code = notify_email.main(["notify-email.py"] + args)
            except SystemExit as e:
                code = e.code
        return code, out.getvalue(), err.getvalue()

    def test_send_composes_message(self):
        code, _, err = self.run_main(
            ["send", "--subject", "test alert", "--body-text", "line one\nline two"])
        self.assertEqual(code, 0)
        self.assertEqual(len(StubSMTP.instances), 1)
        s = StubSMTP.instances[0]
        self.assertEqual((s.host, s.port), ("smtp.example.test", 587))
        self.assertTrue(s.starttls_called)
        self.assertEqual(s.logins, [("bot@example.com", "sekrit")])
        self.assertEqual(len(s.sent), 1)
        msg = s.sent[0]
        self.assertEqual(msg["From"], "bot@example.com")
        self.assertEqual(msg["To"], "operator@example.com")
        self.assertEqual(msg["Subject"], "[hngh] test alert")
        self.assertIn("line two", msg.get_payload(decode=True).decode())

    def test_missing_config_exits_2(self):
        os.environ["HNGH_NOTIFY_EMAIL_CONF"] = str(self.root / "absent.conf")
        code, _, err = self.run_main(["send", "--subject", "s", "--body-text", "b"])
        self.assertEqual(code, 2)
        self.assertIn("dormant", err)
        self.assertEqual(StubSMTP.instances, [])

    def test_loose_config_refused(self):
        write_conf(self.root, mode=0o644)
        code, _, err = self.run_main(["send", "--subject", "s", "--body-text", "b"])
        self.assertEqual(code, 2)
        self.assertIn("chmod 600", err)
        self.assertEqual(StubSMTP.instances, [])

    def test_dry_run_prints_without_smtp(self):
        code, out, _ = self.run_main(
            ["send", "--subject", "dry", "--body-text", "body"], dry_run=True)
        self.assertEqual(code, 0)
        self.assertEqual(StubSMTP.instances, [])
        self.assertIn("Subject: [hngh] dry", out)
        self.assertIn("Ym9keQ==", out)

    def test_body_file(self):
        f = self.root / "body.txt"
        f.write_text("from file")
        code, _, _ = self.run_main(
            ["send", "--subject", "s", "--body-file", str(f)])
        self.assertEqual(code, 0)
        self.assertIn("from file", StubSMTP.instances[0].sent[0].get_payload(decode=True).decode())

    def test_html_file_composes_alternative(self):
        plain = self.root / "body.txt"
        plain.write_text("plain body")
        html = self.root / "body.html"
        html.write_text("<form>feedback form</form>")
        code, _, _ = self.run_main(
            ["send", "--subject", "s", "--body-file", str(plain),
             "--html-file", str(html)])
        self.assertEqual(code, 0)
        msg = StubSMTP.instances[0].sent[0]
        self.assertEqual(msg.get_content_type(), "multipart/alternative")
        parts = msg.get_payload()
        self.assertEqual(parts[0].get_content_type(), "text/plain")
        self.assertIn("plain body", parts[0].get_payload(decode=True).decode())
        self.assertEqual(parts[1].get_content_type(), "text/html")
        self.assertIn("feedback form", parts[1].get_payload(decode=True).decode())


def mock_patch():
    return mock.patch.object(smtplib, "SMTP", StubSMTP)


class _FakeOp:
    """Standalone `op` for the 1Password precedence tests: whoami/read
    result codes fixed per test; the secret never leaves the stub."""

    def __init__(self, whoami_rc=0, read_rc=0, read_out=b""):
        self.whoami_rc, self.read_rc, self.read_out = whoami_rc, read_rc, read_out
        self.calls = []

    def __call__(self, args, **kw):
        self.calls.append(list(args))

        class R:
            returncode = self.whoami_rc if args[1] == "whoami" else self.read_rc
            stdout = b"" if args[1] == "whoami" else self.read_out

        return R()


class OnePasswordPrecedence(unittest.TestCase):
    """[1password] item -> op read wins; op fails -> conf pass fallback;
    neither -> fail-closed exit 2. SMTP stubbed, op stubbed, hermetic."""

    def setUp(self):
        self.root = Path(tempfile.mkdtemp())
        os.environ["HNGH_NOTIFY_EMAIL_CONF"] = str(self.root / "notify-email.conf")
        StubSMTP.instances = []
        self.smtp_patcher = mock_patch()
        self.smtp_patcher.start()

    def tearDown(self):
        os.environ.pop("HNGH_NOTIFY_EMAIL_CONF", None)
        os.environ.pop("HNGH_OP_BIN", None)
        self.smtp_patcher.stop()

    def run_main(self, text):
        conf = self.root / "notify-email.conf"
        conf.write_text(text)
        conf.chmod(0o600)
        out, err = io.StringIO(), io.StringIO()
        code = 0
        with contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
            try:
                code = notify_email.main(
                    ["notify-email.py", "send", "--subject", "s", "--body-text", "b"])
            except SystemExit as e:
                code = e.code
        return code, err.getvalue()

    def test_op_value_wins_when_session_live(self):
        fake = _FakeOp(read_out=b"op-secret-16ch\n")
        with mock.patch.object(subprocess, "run", fake):
            code, err = self.run_main(CONF_OP)
        self.assertEqual(code, 0, err)
        self.assertEqual(StubSMTP.instances[0].logins,
                         [("bot@example.com", "op-secret-16ch")])

    def test_op_failure_falls_back_to_conf_pass(self):
        conf = CONF_OP.replace("to = operator@example.com",
                               "to = operator@example.com\npass = file-fallback")
        fake = _FakeOp(whoami_rc=1)
        with mock.patch.object(subprocess, "run", fake):
            code, err = self.run_main(conf)
        self.assertEqual(code, 0, err)
        self.assertIn("fallback", err)
        self.assertEqual(StubSMTP.instances[0].logins,
                         [("bot@example.com", "file-fallback")])

    def test_op_failure_without_pass_fails_closed(self):
        fake = _FakeOp(whoami_rc=1)
        with mock.patch.object(subprocess, "run", fake):
            code, err = self.run_main(CONF_OP)
        self.assertEqual(code, 2)
        self.assertIn("fail closed", err)
        self.assertEqual(StubSMTP.instances, [])

    def test_item_absent_behavior_unchanged_no_op_calls(self):
        fake = _FakeOp()
        with mock.patch.object(subprocess, "run", fake):
            code, err = self.run_main(CONF)
        self.assertEqual(code, 0, err)
        self.assertEqual(fake.calls, [])  # op never invoked
        self.assertEqual(StubSMTP.instances[0].logins,
                         [("bot@example.com", "sekrit")])


class EmailDigest(unittest.TestCase):
    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp())
        # fixture kernel: one fresh research doc + a lesson harvest
        kernel = self.tmp / "kernel"
        (kernel / "docs" / "research").mkdir(parents=True)
        (kernel / "docs" / "research" / "2026-09-01-beat.md").write_text("x")
        (kernel / "docs" / "research" / "2020-01-01-old.md").write_text("x")
        old = kernel / "docs" / "research" / "2020-01-01-old.md"
        os.utime(old, (0, 0))  # stale: excluded by the 24h window
        (kernel / "docs" / "project").mkdir(parents=True)
        (kernel / "docs" / "project" / "lessons-2026-09-01.md").write_text("a\nb\n")
        # fixture plans
        plans = self.tmp / "plans.json"
        plans.write_text(json.dumps({"plans": [
            {"slug": "p-live", "status": "accepted", "risk": "normal",
             "accepted": "-", "steps_total": 4, "steps_done": 2},
            {"slug": "p-done", "status": "executed", "risk": "normal",
             "accepted": "x", "steps_total": 3, "steps_done": 3}]}))
        self.env = dict(os.environ,
                        HNGH_HOME=str(kernel),
                        HNGH_AUTOMATION_ROOT=str(self.tmp),
                        HNGH_NOTIFY_EMAIL_CONF=str(self.tmp / "absent.conf"),
                        HNGH_DIGEST_ALERTS="",
                        HNGH_DIGEST_STORE_DIR=str(self.tmp / "empty-store"),
                        HNGH_DIGEST_KERNEL_COMMITS="abc123 kernel commit",
                        HNGH_DIGEST_AUTO_COMMITS="def456 automation commit",
                        HNGH_DIGEST_RESEARCH="?? docs/notes/new.md",
                        HNGH_DIGEST_PLANS=str(plans),
                        HNGH_DIGEST_TELEMETRY="telemetry fixture text")

    def test_composes_all_sections_from_fixtures(self):
        p = subprocess.run([sys.executable, str(DIGEST)], env=self.env,
                           capture_output=True, text=True, timeout=60)
        self.assertEqual(p.returncode, 0, p.stderr)
        d = p.stdout
        self.assertIn("# hngh daily digest", d)
        self.assertIn("abc123 kernel commit", d)
        self.assertIn("def456 automation commit", d)
        self.assertIn("p-live", d)          # live plan listed
        self.assertNotIn("p-done", d)       # executed plan excluded
        self.assertIn("2/4", d)
        self.assertIn("2026-09-01-beat.md", d)  # fresh doc listed
        self.assertNotIn("2020-01-01-old.md", d)  # stale doc excluded
        self.assertIn("?? docs/notes/new.md", d)
        self.assertIn("lessons-2026-09-01.md (2 lines)", d)
        self.assertIn("telemetry fixture text", d)

    def test_missing_gathers_degrade_to_placeholders(self):
        env = dict(self.env, HNGH_DIGEST_KERNEL_COMMITS="",
                   HNGH_DIGEST_AUTO_COMMITS="", HNGH_DIGEST_RESEARCH="",
                   HNGH_DIGEST_PLANS="/nonexistent.json")
        # telemetry falls through to the real SELECT-only reader
        # (jobs/telemetry-report.py): exits 0 on any store state — no
        # network, no git, no SMTP
        kernel = Path(env["HNGH_HOME"])
        (kernel / "docs" / "project" / "lessons-2026-09-01.md").unlink()
        p = subprocess.run([sys.executable, str(DIGEST)], env=env,
                           capture_output=True, text=True, timeout=60)
        self.assertEqual(p.returncode, 0, p.stderr)
        self.assertIn("(plans.json unreadable)", p.stdout)
        self.assertIn("## Budget (telemetry)", p.stdout)
        self.assertIn("(no lesson harvest found)", p.stdout)

    def test_operator_items_setup_command_when_config_absent(self):
        p = subprocess.run([sys.executable, str(DIGEST)], env=self.env,
                           capture_output=True, text=True, timeout=60)
        self.assertEqual(p.returncode, 0, p.stderr)
        self.assertIn("## Operator items awaiting you", p.stdout)
        self.assertIn("email channel dormant", p.stdout)
        self.assertIn("setup-notify-email.sh", p.stdout)

    def test_operator_items_no_setup_command_when_config_present(self):
        conf = self.tmp / "notify-email.conf"
        conf.write_text("[smtp]\n")
        p = subprocess.run([sys.executable, str(DIGEST)],
                           env=dict(self.env, HNGH_NOTIFY_EMAIL_CONF=str(conf)),
                           capture_output=True, text=True, timeout=60)
        self.assertEqual(p.returncode, 0, p.stderr)
        self.assertNotIn("email channel dormant", p.stdout)

    def test_operator_items_draft_plans_newest_first_with_status(self):
        digest = self.tmp / "digest"
        digest.mkdir()
        (digest / "DRAFT-PLAN-2026-08-30.md").write_text(
            "<!-- plan: status=drafted risk=normal author=machine -->\n")
        (digest / "DRAFT-PLAN-2026-09-02.md").write_text(
            "<!-- plan: status=drafted risk=normal author=machine -->\n")
        (digest / "MORNING-2026-09-02.md").write_text("not a draft\n")
        p = subprocess.run([sys.executable, str(DIGEST)], env=self.env,
                           capture_output=True, text=True, timeout=60)
        self.assertEqual(p.returncode, 0, p.stderr)
        d = p.stdout
        self.assertIn("draft plan 2026-09-02 (status=drafted)", d)
        self.assertIn("draft plan 2026-08-30 (status=drafted)", d)
        self.assertLess(d.index("2026-09-02"), d.index("2026-08-30"))
        self.assertNotIn("MORNING", d)

    def test_operator_items_alert_rows_and_open_runs(self):
        env = dict(self.env, HNGH_DIGEST_ALERTS=
                   "gate red: make test failed\npush failed rc=1\n")
        store = self.tmp / "store"
        (store / "overnight-open-1").mkdir(parents=True)
        (store / "overnight-open-1" / "record.lisp").write_text(
            '(:IDENTIFIER "run-1" :STATE :CREATED :RUN (:MISSION '
            '(:OBJECTIVE "Execute the next step of plan p")))\n')
        (store / "overnight-done-1").mkdir()
        (store / "overnight-done-1" / "record.lisp").write_text(
            '(:IDENTIFIER "run-1" :STATE :CANCELLED)\n')
        env["HNGH_DIGEST_STORE_DIR"] = str(store)
        p = subprocess.run([sys.executable, str(DIGEST)], env=env,
                           capture_output=True, text=True, timeout=60)
        self.assertEqual(p.returncode, 0, p.stderr)
        d = p.stdout
        self.assertIn("alerts (last 7d): 2 row(s)", d)
        self.assertIn("gate red: make test failed", d)
        self.assertIn("overnight runs still open: 1", d)
        self.assertIn("overnight-open-1", d)
        self.assertNotIn("overnight-done-1", d)

    def run_digest(self, **extra):
        p = subprocess.run([sys.executable, str(DIGEST)],
                           env=dict(self.env, **extra),
                           capture_output=True, text=True, timeout=60)
        self.assertEqual(p.returncode, 0, p.stderr)
        return p.stdout

    def test_headline_tldr_first_three_seconds(self):
        d = self.run_digest(HNGH_DIGEST_TELEMETRY=
                            "session cost:\n  session-cost total: $0.42")
        lines = d.splitlines()
        # headline sits directly under the title, before any section
        self.assertTrue(lines[0].startswith("# hngh daily digest "))
        self.assertEqual(lines[2], "status: OK")
        self.assertTrue(lines[3].startswith("changed:"))
        self.assertEqual(
            lines[4], "spend: $0.42 today (vs unknown yesterday; target $10/day)")
        self.assertIn("action needed: yes", lines[5])  # setup item pending
        self.assertLess(d.index("status: "), d.index("## Operator items"))

    def test_section_reading_order(self):
        d = self.run_digest()
        order = ["## Operator items awaiting you",
                 "## Progress (plans + queue, 24h)", "## Research",
                 "## Commits (24h)", "## Alerts (last 24h)",
                 "## Budget (telemetry)"]
        idx = [d.index(h) for h in order]
        self.assertEqual(idx, sorted(idx))

    def test_attention_headline_with_24h_alerts(self):
        d = self.run_digest(HNGH_DIGEST_ALERTS="gate red: make test failed\n")
        self.assertIn("status: ATTENTION: 1 alert(s) in 24h", d)
        alerts = d.split("## Alerts (last 24h)", 1)[1].split("## ", 1)[0]
        self.assertIn("gate red: make test failed", alerts)

    def test_quiet_window_when_no_alerts(self):
        d = self.run_digest(HNGH_DIGEST_ALERTS="")
        alerts = d.split("## Alerts (last 24h)", 1)[1].split("## ", 1)[0]
        self.assertIn("none — quiet window", alerts)

    def test_pace_line_rising_from_prev_digest(self):
        prev = self.tmp / "prev.md"
        prev.write_text("## Progress (plans + queue, 24h)\n"
                        "  p-live                      accepted  steps 1/4\n")
        d = self.run_digest(HNGH_DIGEST_PREV_DIGEST=str(prev))
        self.assertIn("steps 2/4 (+1)", d)
        self.assertIn("pace: rising (+1 steps in 24h)", d)

    def test_plan_list_capped_with_movers_first(self):
        prev = self.tmp / "prev.md"
        prev.write_text("## Progress\n" + "".join(
            "  %-28s accepted  steps 0/1\n" % ("p-idle-%02d" % i)
            for i in range(20))
            + "  p-mover                     accepted  steps 0/9\n")
        plans = [{"slug": "p-idle-%02d" % i, "status": "accepted",
                  "risk": "normal", "steps_total": 1, "steps_done": 0}
                 for i in range(20)]
        plans.append({"slug": "p-mover", "status": "accepted",
                      "risk": "normal", "steps_total": 9, "steps_done": 2})
        pj = self.tmp / "plans.json"
        pj.write_text(json.dumps({"plans": plans}))
        d = self.run_digest(HNGH_DIGEST_PREV_DIGEST=str(prev),
                            HNGH_DIGEST_PLANS=str(pj))
        prog = d.split("## Progress (plans + queue, 24h)", 1)[1].split("## ", 1)[0]
        self.assertIn("p-mover", prog)            # mover listed first
        self.assertLess(prog.index("p-mover"), prog.index("p-idle"))
        self.assertIn("(+6 more live plan(s)", prog)
        # cap: 15 listed lines = the mover + 14 idle plans
        self.assertEqual(prog.count("p-idle-"), 14)

    def test_long_sections_carry_a_summary(self):
        commits = "\n".join("abc%03d0 kernel commit subject number %d"
                            % (i, i) for i in range(7))
        d = self.run_digest(HNGH_DIGEST_KERNEL_COMMITS=commits)
        # caption register: no self-description, the factual line itself,
        # and the pace verdict stated exactly once.
        self.assertIn("7 commit(s) across both repos", d)
        self.assertNotIn("Section summary", d)
        self.assertEqual(len(re.findall(r"^pace: ", d, re.M)), 1)

    def test_top5_with_overflow_pointer(self):
        commits = "\n".join("abc%03d0 kernel commit subject number %d"
                            % (i, i) for i in range(7))
        d = self.run_digest(HNGH_DIGEST_KERNEL_COMMITS=commits)
        body = d.split("## Commits (24h)", 1)[1].split("## ", 1)[0]
        self.assertEqual(body.count("kernel commit subject"), 5)
        self.assertIn("+2 more — full list: logs/email-digest-", body)

    def test_width_cap_78(self):
        d = self.run_digest(HNGH_DIGEST_TELEMETRY=
                            "x" * 200 + " tail words " * 10)
        for ln in d.splitlines():
            self.assertLessEqual(len(ln), 78, ln)

    def test_redaction_strips_conf_password(self):
        conf = self.tmp / "notify-email.conf"
        conf.write_text("[smtp]\npass = sekret-pw-1234\n")
        d = self.run_digest(
            HNGH_NOTIFY_EMAIL_CONF=str(conf),
            HNGH_DIGEST_TELEMETRY="leak attempt sekret-pw-1234 in text")
        self.assertIn("[redacted]", d)
        self.assertNotIn("sekret-pw-1234", d)

    def test_spend_vs_yesterday_from_prev_digest(self):
        prev = self.tmp / "prev.md"
        prev.write_text("spend: $0.31 today (vs unknown yesterday; "
                        "target $10/day) | action needed: no\n")
        d = self.run_digest(
            HNGH_DIGEST_PREV_DIGEST=str(prev),
            HNGH_DIGEST_TELEMETRY="session-cost total: $0.42")
        self.assertIn("spend: $0.42 today (vs $0.31 yesterday; target $10/day)", d)

    def test_plain_digest_has_form_fallback_line(self):
        p = subprocess.run([sys.executable, str(DIGEST)], env=self.env,
                           capture_output=True, text=True, timeout=60)
        self.assertEqual(p.returncode, 0, p.stderr)
        self.assertIn("Form not rendering? Open the dashboard and use its "
                      "feedback pip.", p.stdout)

    def test_html_variant_contains_feedback_form(self):
        p = subprocess.run([sys.executable, str(DIGEST), "--html"], env=self.env,
                           capture_output=True, text=True, timeout=60)
        self.assertEqual(p.returncode, 0, p.stderr)
        h = p.stdout
        self.assertIn('action="http://127.0.0.1:8890/api/feedback"', h)
        self.assertIn('method="POST"', h)
        self.assertIn('name="element"', h)
        self.assertIn('name="text"', h)
        self.assertIn('name="type"', h)
        self.assertIn('maxlength="2000"', h)
        for t in ("css-theme", "data-format", "correction", "idea"):
            self.assertIn("<option>%s</option>" % t, h)
        self.assertIn("Form not rendering?", h)

    def test_form_action_url_respects_env(self):
        p = subprocess.run(
            [sys.executable, str(DIGEST), "--html"],
            env=dict(self.env, DASHBOARD_PORT="8123", DASHBOARD_HOST="192.0.2.9"),
            capture_output=True, text=True, timeout=60)
        self.assertEqual(p.returncode, 0, p.stderr)
        self.assertIn('action="http://192.0.2.9:8123/api/feedback"', p.stdout)

    # ---- newspaper HTML variant (email-safe: inline styles, tables) ----

    def run_html(self, **extra):
        p = subprocess.run([sys.executable, str(DIGEST), "--html"],
                           env=dict(self.env, **extra),
                           capture_output=True, text=True, timeout=60)
        self.assertEqual(p.returncode, 0, p.stderr)
        return p.stdout

    def test_html_masthead_and_ledger_stats(self):
        h = self.run_html(
            HNGH_DIGEST_TELEMETRY="session cost:\n  session-cost total: $0.42",
            HNGH_DIGEST_HOURLY="0.10:100:1,0.30:200:2")
        self.assertIn("THE MACHINE HALL", h)
        self.assertIn("MORNING DISPATCH", h)
        self.assertIn("METERED SPEND", h)
        self.assertIn("$0.42", h)          # from the fixture telemetry text
        self.assertIn("API CALLS", h)
        self.assertIn(">3<", h)            # 1+2 calls from the hourly fixture
        self.assertIn("TOKENS IN", h)
        self.assertIn("300", h)            # 100+200 tokens

    def test_html_unicode_sparkline(self):
        h = self.run_html(HNGH_DIGEST_HOURLY="0:0:0,0.5:10:2,0:0:0,1.0:30:4")
        # esc() emits decimal entities: U+2581 = 9601 (flat base),
        # U+2588 = 9608 (full block peak)
        self.assertIn("&#9601;", h)
        self.assertIn("&#9608;", h)
        self.assertGreaterEqual(h.count("&#96"), 48)  # 2 trends x 24 buckets

    def test_html_sparkline_zero_only_stays_flat(self):
        h = self.run_html(HNGH_DIGEST_HOURLY="0:0:0,0:0:0,0:0:0")
        self.assertNotIn("&#9608;", h)
        self.assertIn("&#9601;", h)

    def test_html_delta_line_from_prev_digest(self):
        prev = self.tmp / "prev.md"
        prev.write_text("status: OK\nspend: $0.31 today (vs unknown yesterday; "
                        "target $10/day)\n")
        h = self.run_html(
            HNGH_DIGEST_PREV_DIGEST=str(prev),
            HNGH_DIGEST_TELEMETRY="session-cost total: $0.42")
        self.assertIn("since yesterday", h)
        self.assertIn("$0.42", h)
        self.assertIn("(was $0.31", h)
        # omitted when yesterday's digest is unreadable
        h2 = self.run_html(HNGH_DIGEST_PREV_DIGEST="/nonexistent-prev.md")
        self.assertNotIn("since yesterday", h2)

    def test_html_all_styles_inline(self):
        h = self.run_html()
        self.assertNotIn("<style", h.lower())
        self.assertNotIn("<script", h.lower())

    def test_html_feedback_form_keeps_hidden_token(self):
        (self.tmp / "dashboard").mkdir(exist_ok=True)
        (self.tmp / "dashboard" / "token.txt").write_text("tok-abc123\n")
        h = self.run_html()
        self.assertIn('name="hngh_token" value="tok-abc123"', h)

    def test_html_table_nesting_depth_bounded(self):
        h = self.run_html()
        depth = mx = 0
        for m in re.finditer(r"</?table\b", h):
            depth += -1 if m.group(0).startswith("</") else 1
            mx = max(mx, depth)
        self.assertGreaterEqual(mx, 1)     # table-built at all
        self.assertLessEqual(mx, 3)        # no deeper than 3 nested tables

    def test_html_news_from_outside_world(self):
        day = datetime.now(timezone.utc).strftime("%Y-%m-%d")
        digest = self.tmp / "digest"
        digest.mkdir(exist_ok=True)
        (digest / ("%s.md" % day)).write_text(
            "## 0917 %s\n_sources: reuters.com | model: gpt-x_\n"
            "Grid pilot expands. https://example.com/grid\n" % day)
        h = self.run_html()
        self.assertIn("NEWS FROM THE OUTSIDE WORLD", h)
        self.assertIn("reuters.com", h)
        self.assertIn('href="https://example.com/grid"', h)

    def test_html_plan_links_to_dashboard_only_when_up(self):
        up = self.run_html(HNGH_DIGEST_DASHBOARD_UP="1")
        self.assertIn('href="http://127.0.0.1:8890/"', up)
        down = self.run_html(HNGH_DIGEST_DASHBOARD_UP="0")
        self.assertNotIn('href="http://127.0.0.1:8890/"', down)

    def test_plain_variant_stays_text(self):
        p = subprocess.run([sys.executable, str(DIGEST)], env=self.env,
                           capture_output=True, text=True, timeout=60)
        self.assertEqual(p.returncode, 0, p.stderr)
        self.assertIn("# hngh daily digest", p.stdout)
        self.assertNotIn("THE MACHINE HALL", p.stdout)


class ClassifyAlert(unittest.TestCase):
    """classify_alert rubric — first match wins, default digest-only."""

    def test_immediate_classes(self):
        for t in (
            "critical-class plan p parked for the operator",
            "service-ctl restart unsloth-studio.service",
            "unsloth serving down on :8888 — check journal",
            "serving recovered on :8888",
            "agent-stall: no heartbeat for 30m",
            "git push failed: main rc=1",
            "credential rotated for notify-email.conf",
            "verdict rejected — ceremony failed",
            "tree-skew detected on kernel working tree",
            "budget cap exceeded: $12.40 > $10/day",
        ):
            self.assertEqual(notify_email.classify_alert(t), "immediate", t)

    def test_digest_classes_and_default(self):
        for t in (
            "gate red: make test failed",
            "ui-audit: contrast nit on the deploy button",
            "repeat-crumb: stale day stamp swept",
            "feed-validity one-step refresh done",
            "something entirely novel",  # default: digest-only
        ):
            self.assertEqual(notify_email.classify_alert(t), "digest", t)

    def test_immediate_beats_digest_on_overlap(self):
        self.assertEqual(
            notify_email.classify_alert(
                "gate red: service-ctl could not recover the unit"),
            "immediate")

    def test_kill_switch_forces_digest(self):
        with mock.patch.dict(os.environ, {"HNGH_NOTIFY_IMMEDIATE": "0"}):
            self.assertEqual(
                notify_email.classify_alert("critical-class plan parked"),
                "digest")

    def test_cli_verb(self):
        p = subprocess.run(
            [sys.executable, str(NOTIFY), "classify", "--text",
             "park: critical plan"],
            capture_output=True, text=True, timeout=30)
        self.assertEqual(p.returncode, 0, p.stderr)
        self.assertEqual(p.stdout.strip(), "immediate")


class SetupNotifyEmail(unittest.TestCase):
    """scripts/setup-notify-email.sh — config-writer contract only (the
    interactive prompts and the test email are excluded by design)."""

    def run_bash(self, script_body, conf, force=False):
        cmd = "source %s; %s" % (SETUP, script_body)
        env = dict(os.environ, HNGH_NOTIFY_EMAIL_CONF=str(conf),
                   FORCE="1" if force else "0")
        return subprocess.run(["bash", "-c", cmd], env=env,
                              capture_output=True, text=True, timeout=60)

    def test_write_conf_writes_chmod_600_ini(self):
        conf = Path(tempfile.mkdtemp()) / "notify-email.conf"
        p = self.run_bash('write_conf h 587 u s f t', conf)
        self.assertEqual(p.returncode, 0, p.stderr)
        self.assertEqual(oct(os.stat(conf).st_mode & 0o777), "0o600")
        text = conf.read_text()
        for key in ("host = h", "port = 587", "user = u", "pass = s",
                    "from = f", "to = t"):
            self.assertIn(key, text)

    def test_write_conf_refuses_existing_config_without_force(self):
        conf = Path(tempfile.mkdtemp()) / "notify-email.conf"
        conf.write_text("[smtp]\nhost = keepme\n")
        p = self.run_bash('write_conf h 587 u s f t', conf, force=False)
        self.assertEqual(p.returncode, 1)
        self.assertIn("--force", p.stderr)
        self.assertEqual(conf.read_text(), "[smtp]\nhost = keepme\n")

    def test_write_conf_force_overwrites_existing_config(self):
        conf = Path(tempfile.mkdtemp()) / "notify-email.conf"
        conf.write_text("[smtp]\nhost = old\n")
        p = self.run_bash('write_conf h 587 u s f t', conf, force=True)
        self.assertEqual(p.returncode, 0, p.stderr)
        self.assertIn("host = h", conf.read_text())

    def test_write_conf_opref_section_no_pass_on_disk(self):
        conf = Path(tempfile.mkdtemp()) / "notify-email.conf"
        p = self.run_bash('write_conf h 587 u "" f t op://v/i/password', conf)
        self.assertEqual(p.returncode, 0, p.stderr)
        self.assertEqual(oct(os.stat(conf).st_mode & 0o777), "0o600")
        text = conf.read_text()
        self.assertIn("[1password]\nitem = op://v/i/password", text)
        self.assertNotIn("pass =", text)  # password never touches disk

    def _from_1password(self, ref, conf, stub):
        stub_path = Path(tempfile.mkdtemp()) / "op-stub"
        stub_path.write_text(stub)
        stub_path.chmod(0o755)
        env = dict(os.environ, HNGH_NOTIFY_EMAIL_CONF=str(conf),
                   HNGH_OP_BIN=str(stub_path))
        return subprocess.run(["bash", str(SETUP), "--from-1password", ref], env=env,
                              capture_output=True, text=True, timeout=60)

    def _from_1password_argv(self, conf, stub, *argv):
        stub_path = Path(tempfile.mkdtemp()) / "op-stub"
        stub_path.write_text(stub)
        stub_path.chmod(0o755)
        env = dict(os.environ, HNGH_NOTIFY_EMAIL_CONF=str(conf),
                   HNGH_OP_BIN=str(stub_path))
        return subprocess.run(["bash", str(SETUP), *argv], env=env,
                              capture_output=True, text=True, timeout=60)

    def test_from_1password_force_flag_in_any_position(self):
        conf = Path(tempfile.mkdtemp()) / "notify-email.conf"
        conf.write_text("[smtp]\nhost = keepme\n")
        p = self._from_1password_argv(conf, "#!/usr/bin/env bash\nexit 1\n",
                                      "--from-1password", "op://v/i/password",
                                      "--force")
        # with the flag honored, the run must NOT refuse for the existing
        # conf; it proceeds to the vault gate (stub exits 1)
        self.assertNotIn("already exists", p.stderr)
        self.assertIn("unlock the 1Password desktop app", p.stderr)

    def test_from_1password_refuses_locked_vault(self):
        conf = Path(tempfile.mkdtemp()) / "notify-email.conf"
        p = self._from_1password("op://v/i/password", conf,
                                 "#!/usr/bin/env bash\nexit 1\n")
        self.assertEqual(p.returncode, 1)
        self.assertIn("unlock the 1Password desktop app", p.stderr)
        self.assertFalse(conf.exists())

    def test_from_1password_refuses_item_without_username(self):
        conf = Path(tempfile.mkdtemp()) / "notify-email.conf"
        p = self._from_1password("op://v/i/password", conf,
                                 "#!/usr/bin/env bash\n"
                                 '[ "$1" = account ] && exit 0\nexit 1\n')
        self.assertEqual(p.returncode, 1)
        self.assertIn("username", p.stderr)
        self.assertFalse(conf.exists())

    def test_from_1password_refuses_malformed_ref(self):
        conf = Path(tempfile.mkdtemp()) / "notify-email.conf"
        p = self._from_1password("op://v/i", conf,
                                 "#!/usr/bin/env bash\nexit 0\n")
        self.assertEqual(p.returncode, 2)
        self.assertIn("op://<vault>/<item>/<field>", p.stderr)
        self.assertFalse(conf.exists())


if __name__ == "__main__":
    unittest.main()
