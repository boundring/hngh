#!/usr/bin/env python3
"""imap-poll contract, hermetic (plan step 11, doctrine s4).

(a) conf parsing fail-closed: missing conf / loose mode / missing
    [smtp]|[imap] keys / unresolvable password -> exit 0 no-op with an
    imap-dormant breadcrumb, mailbox client never constructed;
(b) reply -> operator-item conversion through the real bash contract
    (lib/operator-item.sh -> alert_row -> stub report-queue + STATE.md
    crumb), email channel dormant by design;
(c) processed-marking: \\Seen set for every processed message, nothing
    deleted or expunged, per-tick cap respected;
(d) attachments saved under automation/inbox/ with path-only inline,
    plan decisions land as DRAFT files under automation/digest/ (never
    auto-accepted -- accept-plans never scans automation/digest/).

Seams: HNGH_NOTIFY_EMAIL_CONF, HNGH_AUTOMATION_ROOT, HNGH_HOME (a stub
kernel whose scripts/report-queue appends argv to a log). No network,
no real mailbox, no real ledger, no credential access.
"""

import base64
import hashlib
import io
import importlib.util
import os
import shutil
import stat
import subprocess
import sys
import tempfile
import unittest
from email.message import EmailMessage
from pathlib import Path
from unittest import mock

ROOT = Path(__file__).resolve().parent.parent
SCRIPT = ROOT / "scripts" / "imap-poll.py"
sys.path.insert(0, str(SCRIPT.parent))
_spec = importlib.util.spec_from_file_location("imap_poll", SCRIPT)
imap_poll = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(imap_poll)
sys.modules["imap_poll"] = imap_poll


def load_module():
    """Fresh exec of scripts/imap-poll.py so module-level seam
    constants (HNGH_AUTOMATION_ROOT / HNGH_HOME) re-read the env."""
    spec = importlib.util.spec_from_file_location("imap_poll", SCRIPT)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    sys.modules["imap_poll"] = mod
    return mod


class StubClient:
    """The injectable IMAP seam: returns crafted messages, records
    \\Seen stores. delete/expunge calls (should never happen) are
    recorded, not executed."""

    def __init__(self, messages):
        self.messages = messages          # list[bytes], oldest first
        self.seen = []                    # nums passed to mark_seen
        self.deleted = []
        self.expunged = 0

    def unseen(self):
        return [str(i + 1).encode() for i in range(len(self.messages))]

    def fetch(self, num):
        idx = int(num) - 1
        return self.messages[idx] if 0 <= idx < len(self.messages) else None

    def mark_seen(self, num):
        self.seen.append(num)

    # tripwires: any delete/expunge path is a contract break
    def store(self, num, cmd, flags):
        if "deleted" in flags.lower():
            self.deleted.append(num)

    def expunge(self):
        self.expunged += 1


def make_conf(tmp, smtp=True, imap=True, mode=0o600, smtp_pass="",
              pass_cmd=""):
    path = tmp / "notify-email.conf"
    lines = []
    if smtp:
        lines += ["[smtp]", "host = smtp.example.com", "port = 587",
                  "user = hngh@example.com", "from = hngh@example.com",
                  "to = operator@example.com"]
        if smtp_pass:
            lines.append("pass = %s" % smtp_pass)
    if imap:
        lines += ["[imap]", "host = imap.example.com", "port = 993",
                  "user = hngh@example.com"]
        if pass_cmd:
            lines.append("pass_cmd = %s" % pass_cmd)
    path.write_text("\n".join(lines) + "\n")
    path.chmod(mode)
    return path


def make_message(subject, body, from_="Operator <op@example.com>",
                 attachment=None):
    msg = EmailMessage()
    msg["From"] = from_
    msg["Subject"] = subject
    msg["Message-ID"] = "<%s@example.com>" % hashlib.sha256(
        (subject + body).encode()).hexdigest()[:12]
    msg.set_content(body)
    if attachment:
        name, payload = attachment
        msg.add_attachment(payload, maintype="application",
                           subtype="pdf", filename=name)
    return msg.as_bytes()


class Seamed(unittest.TestCase):
    """Reload the module with HNGH_AUTOMATION_ROOT / HNGH_HOME pointed
    into a tmp sandbox (inbox/, digest/, STATE.md live there; the stub
    kernel provides scripts/report-queue)."""

    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp(prefix="imap-poll-test-"))
        self.addCleanup(shutil.rmtree, self.tmp, True)
        self.auto = self.tmp / "automation"
        self.kernel = self.tmp / "kernel"
        (self.auto / "logs").mkdir(parents=True)
        (self.kernel / "scripts").mkdir(parents=True)
        rq = self.kernel / "scripts" / "report-queue"
        # alert_row runs the queue as `python3 "$KERNEL/scripts/report-queue"`
        # (lib/notify-email.sh), so the stub must be python: a bash stub is
        # a SyntaxError under python3 and the seam silently never fires.
        rq.write_text(
            "#!/usr/bin/env python3\n"
            "import os, sys\n"
            "with open(os.environ['HNGH_RQ_LOG'], 'a') as f:\n"
            "    f.write(' '.join(sys.argv[1:]) + '\\n')\n")
        rq.chmod(rq.stat().st_mode | stat.S_IEXEC)
        self.rq_log = self.tmp / "report-queue.log"
        self.old = (os.environ.get("HNGH_AUTOMATION_ROOT"),
                    os.environ.get("HNGH_HOME"))
        os.environ["HNGH_AUTOMATION_ROOT"] = str(self.auto)
        os.environ["HNGH_HOME"] = str(self.kernel)
        self.addCleanup(self._restore)
        globals()["imap_poll"] = load_module()

    def _restore(self):
        for key, val in zip(("HNGH_AUTOMATION_ROOT", "HNGH_HOME"), self.old):
            if val is None:
                os.environ.pop(key, None)
            else:
                os.environ[key] = val
        os.environ.pop("HNGH_NOTIFY_EMAIL_CONF", None)
        globals()["imap_poll"] = load_module()

    def run_main(self, *argv):
        env = dict(os.environ, HNGH_RQ_LOG=str(self.rq_log))
        out, err = io.StringIO(), io.StringIO()
        with mock.patch.dict(os.environ, env, clear=False), \
                mock.patch.object(sys, "stdout", out), \
                mock.patch.object(sys, "stderr", err):
            rc = imap_poll.main(list(argv))
        return rc, err.getvalue()


class ConfFailClosed(Seamed):
    """(a) missing/unreadable IMAP config -> exit 0 no-op + breadcrumb,
    no client ever constructed, nothing mutated."""

    def no_client(self):
        return mock.patch.object(
            imap_poll, "ImapClient",
            side_effect=AssertionError("client must not be constructed"))

    def assert_dormant(self, rc, err, why):
        self.assertEqual(rc, 0)
        self.assertIn("no-op", err)
        self.assertIn(why, err)
        state = self.auto / "STATE.md"
        self.assertTrue(state.exists())
        self.assertIn("imap-dormant", state.read_text())

    def test_missing_conf(self):
        os.environ["HNGH_NOTIFY_EMAIL_CONF"] = str(self.tmp / "absent.conf")
        with self.no_client():
            rc, err = self.run_main("--dry-run")
        self.assert_dormant(rc, err, "no config")

    def test_missing_imap_section(self):
        conf = make_conf(self.tmp, imap=False)
        os.environ["HNGH_NOTIFY_EMAIL_CONF"] = str(conf)
        with self.no_client():
            rc, err = self.run_main("--dry-run")
        self.assert_dormant(rc, err, "missing [smtp]/[imap]")

    def test_missing_imap_keys(self):
        conf = make_conf(self.tmp)
        conf.write_text("[smtp]\nhost = s\nport = 1\nuser = u\n"
                        "from = f\nto = t\n[imap]\nhost = imap.example.com\n")
        conf.chmod(0o600)
        os.environ["HNGH_NOTIFY_EMAIL_CONF"] = str(conf)
        with self.no_client():
            rc, err = self.run_main("--dry-run")
        self.assert_dormant(rc, err, "missing [imap] port")

    def test_loose_mode(self):
        conf = make_conf(self.tmp, smtp_pass="pw")
        conf.chmod(0o644)
        os.environ["HNGH_NOTIFY_EMAIL_CONF"] = str(conf)
        with self.no_client():
            rc, err = self.run_main("--dry-run")
        self.assert_dormant(rc, err, "chmod 600")

    def test_no_password(self):
        conf = make_conf(self.tmp)
        os.environ["HNGH_NOTIFY_EMAIL_CONF"] = str(conf)
        with self.no_client():
            rc, err = self.run_main("--dry-run")
        self.assert_dormant(rc, err, "no IMAP password")


class ReplyConversion(Seamed):
    """(b) UNSEEN reply -> operator-item through the REAL bash contract
    (lib/operator-item.sh), ledger seamed to the stub report-queue and
    a sandbox STATE.md; email channel dormant by design."""

    def poll_conf(self):
        conf = make_conf(self.tmp, smtp_pass="pw")
        os.environ["HNGH_NOTIFY_EMAIL_CONF"] = str(conf)
        os.environ["HNGH_RQ_LOG"] = str(self.rq_log)
        self.addCleanup(os.environ.pop, "HNGH_RQ_LOG", None)

    def test_reply_files_operator_item(self):
        self.poll_conf()
        raw = make_message(
            "Re: [hngh] parked plan question",
            "Yes, go ahead with the slower cadence.\nThanks.")
        client = StubClient([raw])
        imap_poll.poll(client)
        state = (self.auto / "STATE.md").read_text()
        self.assertIn("| imap-poll | alert | ", state)
        text = "[imap-reply] Re: [hngh] parked plan question"
        self.assertIn(text, state)
        self.assertIn("from Operator <op@example.com>", state)
        self.assertIn("slower cadence", state)
        # identity is the msgid hash, dedupeable across ticks
        self.assertRegex(self.rq_log.read_text(), r"imap-reply-[0-9a-f]{8}")
        # the alert row reached the report-queue seam (the feed contract)
        rq = self.rq_log.read_text()
        self.assertIn("--identity imap-reply-", rq)
        self.assertIn("--window 604800", rq)

    def test_bash_contract_env(self):
        """The bash contract receives the right identity/text and the
        dormant conf seam (feedback-ingest file_item discipline)."""
        self.poll_conf()
        raw = make_message("Re: subject line", "body words")
        captured = {}

        class R:
            returncode = 0
            stdout = ""
            stderr = ""

        def fake_run(argv, env=None, **kw):
            captured["argv"], captured["env"], captured["script"] = \
                argv, env, argv[2]
            return R()

        with mock.patch.object(imap_poll.subprocess, "run", fake_run):
            imap_poll.poll(StubClient([raw]))
        self.assertEqual(captured["argv"][:2], ["bash", "-c"])
        self.assertIn("operator_item", captured["script"])
        self.assertIn("operator-item.sh", captured["script"])
        env = captured["env"]
        self.assertEqual(env["HNGH_NOTIFY_EMAIL_CONF"],
                         "/dev/null/notify-email.conf")  # dormant by design
        self.assertEqual(env["JOB_NAME"], "imap-poll")
        self.assertRegex(env["ITEM_IDENTITY"], r"^imap-reply-[0-9a-f]{8}$")
        self.assertIn("[imap-reply] Re: subject line", env["ITEM_TEXT"])
        self.assertIn("from Operator <op@example.com>", env["ITEM_TEXT"])
        self.assertIn("body words", env["ITEM_TEXT"])

    def test_dry_run_files_nothing(self):
        self.poll_conf()
        client = StubClient([make_message("Re: hi", "hello")])
        imap_poll.poll(client, dry=True)
        self.assertFalse((self.auto / "STATE.md").exists())
        self.assertFalse(self.rq_log.exists())
        self.assertEqual(client.seen, [])  # nothing marked in a dry run


class R:
    returncode = 0
    stdout = ""
    stderr = ""


class ProcessedMarking(Seamed):
    """(c) \\Seen for every successfully filed message; nothing deleted
    or expunged; per-tick cap respected; filing failure stays UNSEEN."""

    def test_processed_marked_seen(self):
        client = StubClient([
            make_message("Re: a", "one"), make_message("Re: b", "two")])
        with mock.patch.object(imap_poll, "file_item", return_value=R()):
            n = imap_poll.poll(client)
        self.assertEqual(n, 2)
        self.assertEqual(client.seen, [b"1", b"2"])
        self.assertEqual(client.deleted, [])
        self.assertEqual(client.expunged, 0)

    def test_failed_filing_stays_unseen(self):
        client = StubClient([make_message("Re: x", "body")])
        bad = R()
        bad.returncode = 1
        with mock.patch.object(imap_poll, "file_item", return_value=bad):
            n = imap_poll.poll(client)
        self.assertEqual(n, 0)
        self.assertEqual(client.seen, [])  # retry next tick

    def test_tick_cap(self):
        client = StubClient([make_message("Re: %d" % i, "b%d" % i)
                             for i in range(25)])
        with mock.patch.object(imap_poll, "file_item", return_value=R()):
            n = imap_poll.poll(client)
        self.assertEqual(n, imap_poll.MAX_PER_TICK)
        self.assertEqual(len(client.seen), imap_poll.MAX_PER_TICK)
        self.assertNotIn(b"25", client.seen)  # backlog waits for next tick

    def test_client_surface_cannot_delete(self):
        for verb in ("expunge", "delete"):
            self.assertFalse(hasattr(imap_poll.ImapClient, verb),
                             "ImapClient must not expose %s" % verb)


class FetchNeverSetsSeen(Seamed):
    """fetch() must use BODY.PEEK (RFC 3501 s6.4.5): no implicit
    \\Seen, so a dry run against a real server flips no unread mail
    to read."""

    def test_fetch_uses_peek(self):
        rec = {}

        class FakeImap:
            def login(self, *a):
                pass

            def select(self, box, readonly=False):
                rec["readonly"] = readonly
                return ("OK", [b"1"])

            def search(self, charset, criterion):
                return ("OK", [b"1"])

            def fetch(self, num, spec):
                rec["spec"] = spec
                return ("OK", [(b"1", make_message("Re: hi", "hello"))])

        with mock.patch("imaplib.IMAP4_SSL", lambda *a, **kw: FakeImap()):
            client = imap_poll.ImapClient("h", 993, "u", "p")
            msg = client.fetch(b"1")
        self.assertIn("BODY.PEEK", rec["spec"])
        self.assertIsNotNone(msg)


SLUG = "2026-09-09-stall-recovery-and-operator-surfaces"


class AttachmentsAndDrafts(Seamed):
    """(d) attachments saved under automation/inbox/ with PATH-only
    inline; plan decisions land as DRAFT files under automation/digest/
    (never into kernel plans/, never auto-accepted)."""

    def poll_capture(self, raw):
        items = []

        class EnvR:
            returncode = 0
            stdout = ""
            stderr = ""

        def fake(identity, text):
            items.append((identity, text))
            return EnvR()

        with mock.patch.object(imap_poll, "file_item", fake):
            imap_poll.poll(StubClient([raw]))
        return items

    def test_attachment_saved_path_only(self):
        payload = b"%PDF-1.7 secret-attachment-bytes-XYZ"
        raw = make_message("Re: see attached", "here is the scan",
                           attachment=("scan.pdf", payload))
        items = self.poll_capture(raw)
        self.assertEqual(len(items), 1)
        inbox = self.auto / "inbox"
        saved = list(inbox.iterdir())
        self.assertEqual(len(saved), 1)
        self.assertEqual(saved[0].read_bytes(), payload)
        self.assertRegex(saved[0].name, r"^[0-9a-f]{8}-scan\.pdf$")
        identity, text = items[0]
        self.assertIn(str(saved[0]), text)       # the PATH is in the item
        self.assertNotIn(b"secret-attachment-bytes"
                         .decode(), text)         # never the content

    def test_decision_writes_draft(self):
        raw = make_message(
            "Re: parked plan",
            "decision: accept\n"
            "please re-surface %s.plan.md" % SLUG)
        items = self.poll_capture(raw)
        self.assertEqual(len(items), 1)
        drafts = list((self.auto / "digest").glob(
            "DRAFT-PLAN-*-imap-%s.md" % SLUG))
        self.assertEqual(len(drafts), 1)
        draft = drafts[0].read_text()
        self.assertIn("DRAFT", draft)
        self.assertIn("accept", draft)
        self.assertIn(SLUG, draft)
        self.assertIn("op@example.com", draft)
        # never in the kernel plans feed: drafts are operator-promoted
        kernel_plans = self.kernel / "docs"
        self.assertFalse(kernel_plans.exists())

    def test_no_decision_no_draft(self):
        raw = make_message("Re: parked plan",
                           "thinking about %s.plan.md, more later" % SLUG)
        items = self.poll_capture(raw)
        self.assertEqual(len(items), 1)
        self.assertFalse((self.auto / "digest").exists())

    def test_subject_only_decision(self):
        raw = make_message("decision: reject %s.plan.md" % SLUG, "no.")
        self.poll_capture(raw)
        drafts = list((self.auto / "digest").glob(
            "DRAFT-PLAN-*-imap-%s.md" % SLUG))
        self.assertEqual(len(drafts), 1)
        self.assertIn("reject", drafts[0].read_text())


if __name__ == "__main__":
    unittest.main()
