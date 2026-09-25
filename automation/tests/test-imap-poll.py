#!/usr/bin/env python3
"""imap-poll contract, hermetic (plan step 11, doctrine s4).

(a) conf parsing fail-closed: missing conf / loose mode / missing
    [smtp]|[imap] keys / unresolvable password -> exit 0 no-op with an
    imap-dormant breadcrumb, mailbox client never constructed;
(b) reply -> operator-item conversion through the real bash contract
    (lib/operator-item.sh -> alert_row -> stub report-queue + journal
    crumb), email channel dormant by design;
(c) processed-marking: \\Seen set for every processed message, nothing
    deleted or expunged, per-tick cap respected;
(d) attachments saved under automation/inbox/ with path-only inline,
    plan decisions land as DRAFT files under automation/digest/ (never
    auto-accepted -- accept-plans never scans automation/digest/);
(e) report links: subject [hngh <report-id>] annotates the report's
    body sidecar (docs/project/report-bodies/<ts>-<kind>-<id>.md,
    created if absent) and applies the approve:/deny:/note: directive
    grammar to matching open operator-items (approve -> handled,
    deny -> dismissed, note/unknown/missing -> annotation only);
    no-match replies keep (a)-(d) behavior unchanged, and the linked
    path never touches the ledger, never auto-accepts plans, never
    deletes anything.

Seams: HNGH_NOTIFY_EMAIL_CONF, HNGH_AUTOMATION_ROOT, HNGH_HOME (a stub
kernel whose scripts/report-queue appends argv to a log). No network,
no real mailbox, no real ledger, no credential access.
"""

import base64
import hashlib
import io
import importlib.util
import json
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


def crumbs_text(db):
    """The journal's derived 4-field lines (the read seam)."""
    return subprocess.run(
        ["python3", str(ROOT / "lib" / "crumbs-db.py"), "export", "--db", str(db)],
        capture_output=True, text=True, check=True).stdout


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
    into a tmp sandbox (inbox/, digest/, the crumbs journal live there; the stub
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
                    os.environ.get("HNGH_HOME"),
                    os.environ.get("HNGH_CRUMBS_DB"))
        os.environ["HNGH_AUTOMATION_ROOT"] = str(self.auto)
        os.environ["HNGH_HOME"] = str(self.kernel)
        os.environ["HNGH_CRUMBS_DB"] = str(self.auto / "state" / "crumbs.db")
        self.addCleanup(self._restore)
        globals()["imap_poll"] = load_module()

    def _restore(self):
        for key, val in zip(("HNGH_AUTOMATION_ROOT", "HNGH_HOME",
                             "HNGH_CRUMBS_DB"), self.old):
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
        state = crumbs_text(self.auto / "state" / "crumbs.db")
        self.assertTrue(state)                       # a crumb was written
        self.assertIn("imap-dormant", state)

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
    a sandbox journal; email channel dormant by design."""

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
        state = crumbs_text(self.auto / "state" / "crumbs.db")
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
        self.assertEqual(env["HNGH_CRUMBS_DB"],
                         str(self.auto / "state" / "crumbs.db"))
        self.assertEqual(env["JOB_NAME"], "imap-poll")
        self.assertRegex(env["ITEM_IDENTITY"], r"^imap-reply-[0-9a-f]{8}$")
        self.assertIn("[imap-reply] Re: subject line", env["ITEM_TEXT"])
        self.assertIn("from Operator <op@example.com>", env["ITEM_TEXT"])
        self.assertIn("body words", env["ITEM_TEXT"])

    def test_dry_run_files_nothing(self):
        self.poll_conf()
        client = StubClient([make_message("Re: hi", "hello")])
        imap_poll.poll(client, dry=True)
        self.assertEqual(crumbs_text(self.auto / "state" / "crumbs.db"), "")
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


REPORT_ID = "f7fd5d5b"
TS = "2026-09-14T13:12:26Z"


class ReportLinks(ReplyConversion):
    """(e) reply subjects carrying `[hngh <report-id>]` link to the
    kernel report row with that 8-hex id: the report's body sidecar
    (docs/project/report-bodies/<ts>-<kind>-<id>.md, created if absent)
    gets an appended annotation block with the reply date/from/body;
    directive lines in the reply body transition matching operator-items:
    approve -> handled, deny -> dismissed, note -> annotation only
    (unknown/missing directives default to note). No-match replies keep
    the (a)-(d) behavior byte-for-byte; malformed replies never delete
    anything and never auto-accept plans."""

    def seed_report(self, rid=REPORT_ID, ts=TS, kind="alert"):
        """A real-shaped report row + sidecar in the stub kernel."""
        (self.kernel / "docs" / "project" / "report-bodies").mkdir(
            parents=True)
        body = self.kernel / ("docs/project/report-bodies/%s-%s-%s.md"
                              % (ts, kind, rid))
        body.write_text(
            "# %s — %s\n\n"
            "- **timestamp:** %s\n"
            "- **kind:** %s\n"
            "- **first line:** deck pull fails\n"
            "- **identity:** deck-unreachable\n\n"
            "deck pull fails\n"
            "- %s occurrence\n" % (kind, rid, ts, kind, ts))
        ledger = self.kernel / "docs" / "project" / "reports.md"
        ledger.write_text(
            "# Report ledger\n\n"
            "| timestamp | kind | id | first line | body |\n"
            "|---|---|---|---|---|\n"
            "| %s | %s | %s | deck pull fails | %s-%s-%s.md |\n"
            % (ts, kind, rid, ts, kind, rid))
        return body

    def seed_item(self, iid, status="open", ref=True):
        """One item in the operator-items feed + a matching journal alert
        crumb (the item's provenance, as the feed itself builds it).
        ref=True: the item text references the linked report id, which
        is what makes directive transitions apply to it."""
        dash = self.auto / "dashboard"
        dash.mkdir(exist_ok=True)
        now = "2026-09-14T14:00:00Z"
        with open(dash / "operator-items.json", "w") as f:
            json.dump({"generated_at": now, "items": [
                {"id": iid,
                 "text": "imap-poll | alert | deck pull fails (%s)"
                         % (REPORT_ID if ref else iid),
                 "first_seen": now, "last_seen": now, "status": status,
                 "evidence": ""}]}, f)
        # the provenance crumb rides the journal: load the fixture STATE
        # line through the import seam (fixture-format coverage kept)
        fixture = self.tmp / "seeded-STATE.md"
        with open(fixture, "a") as f:
            f.write("%s | imap-poll | alert | deck pull fails (%s)\n"
                    % (now, iid))
        subprocess.run(
            ["python3", str(ROOT / "lib" / "crumbs-db.py"), "sync",
             "--state", str(fixture),
             "--db", str(self.auto / "state" / "crumbs.db")],
            check=True, capture_output=True)
        return dash / "operator-items.json"

    def poll_one(self, subject, body_txt):
        """Run one hermetic poll pass over a single crafted reply."""
        self.poll_conf()
        client = StubClient([make_message(subject, body_txt)])
        with mock.patch.object(imap_poll, "file_item", return_value=R()):
            imap_poll.poll(client)
        return client

    def sidecars(self):
        return list((self.kernel / "docs" / "project" / "report-bodies")
                    .glob("*.md"))

    def test_linked_reply_annotates_sidecar(self):
        body = self.seed_report()
        self.poll_one("Re: [hngh %s] deck pull fails" % REPORT_ID,
                      "saw this, looking into it today.")
        txt = body.read_text()
        self.assertIn("## operator reply", txt)
        self.assertIn("from:** Operator <op@example.com>", txt)
        self.assertIn("date:**", txt)
        self.assertIn("looking into it today", txt)
        # existing content preserved, nothing rewritten
        self.assertIn("deck pull fails\n", txt)
        self.assertIn("- %s occurrence\n" % TS, txt)

    def test_link_creates_absent_sidecar(self):
        # id in the ledger, body file missing (pruned/rotated away)
        body = self.seed_report()
        body.unlink()
        self.poll_one("Re: [hngh %s] deck" % REPORT_ID, "on it")
        self.assertEqual(len(self.sidecars()), 1)
        self.assertIn("## operator reply", body.read_text())

    def test_approve_directive_transitions_to_handled(self):
        self.seed_report()
        feed = self.seed_item("aabbccdd")
        self.poll_one("Re: [hngh %s]" % REPORT_ID,
                      "approve: yes, the deck fix looks right.")
        it = json.load(open(feed))["items"][0]
        self.assertEqual(it["status"], "handled")

    def test_approve_directive_persists_approval_ledger(self):
        """Red-first rebuild-clobber fix: approve: must persist durably
        to dashboard/operator-approved.json (same schema as the
        dismissal ledger) so the 1m feed rebuild keeps handled."""
        self.seed_report()
        self.seed_item("aabbccdd")
        self.poll_one("Re: [hngh %s]" % REPORT_ID,
                      "approve: yes, the deck fix looks right.")
        led = json.load(open(self.auto / "dashboard"
                             / "operator-approved.json"))
        self.assertEqual(set(led.keys()), {"approved"})
        ts = led["approved"]["aabbccdd"]
        self.assertRegex(ts, r"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$")

    def test_note_directive_never_touches_approval_ledger(self):
        self.seed_report()
        self.seed_item("deadbeef")
        self.poll_one("Re: [hngh %s]" % REPORT_ID,
                      "note: watching this one, no action yet.")
        self.assertFalse((self.auto / "dashboard"
                          / "operator-approved.json").exists())

    def test_deny_directive_transitions_to_dismissed(self):
        self.seed_report()
        feed = self.seed_item("11223344")
        self.poll_one("Re: [hngh %s]" % REPORT_ID,
                      "deny: this is a known false positive.")
        it = json.load(open(feed))["items"][0]
        self.assertEqual(it["status"], "dismissed")

    def test_note_directive_annotates_only(self):
        self.seed_report()
        feed = self.seed_item("deadbeef")
        self.poll_one("Re: [hngh %s]" % REPORT_ID,
                      "note: watching this one, no action yet.")
        it = json.load(open(feed))["items"][0]
        self.assertEqual(it["status"], "open")  # untouched
        body = (self.kernel / "docs/project/report-bodies").glob("*.md")
        self.assertIn("note: watching this one",
                      list(body)[0].read_text())

    def test_missing_directive_defaults_to_note(self):
        self.seed_report()
        feed = self.seed_item("00112233")
        self.poll_one("Re: [hngh %s]" % REPORT_ID, "still broken here?")
        it = json.load(open(feed))["items"][0]
        self.assertEqual(it["status"], "open")

    def test_unknown_directive_defaults_to_note(self):
        self.seed_report()
        feed = self.seed_item("44556677")
        self.poll_one("Re: [hngh %s]" % REPORT_ID,
                      "maybe: some other word\nand more prose")
        it = json.load(open(feed))["items"][0]
        self.assertEqual(it["status"], "open")

    def test_directive_without_matching_item_annotates_only(self):
        self.seed_report()
        feed = self.seed_item("aabbccdd", ref=False)  # no report-id ref
        before = feed.read_text()
        self.poll_one("Re: [hngh %s]" % REPORT_ID, "approve: fine")
        self.assertEqual(feed.read_text(), before)  # only id-matching items

    def test_no_match_keeps_behavior_unchanged(self):
        body = self.seed_report()
        feed = self.seed_item("99887766")
        before = (body.read_text(), feed.read_text())
        self.poll_one("Re: unrelated question", "plain prose reply")
        self.assertEqual(body.read_text(), before[0])  # sidecar untouched
        self.assertEqual(feed.read_text(), before[1])  # feed untouched
        # kernel docs are never written by the no-match path
        rq = self.kernel / "docs" / "project" / "reports.md"
        self.assertIn("f7fd5d5b", rq.read_text())  # ledger intact

    def test_malformed_body_still_records_safely(self):
        self.seed_report()
        feed = self.seed_item("1357acef")
        client = self.poll_one(
            "Re: [hngh %s]" % REPORT_ID,
            "\x00\x01\x02 approve:\ndeny\nnote:\nnonsense: \xff lines")
        it = json.load(open(feed))["items"][0]
        self.assertEqual(it["status"], "open")  # malformed -> note default
        self.assertEqual(len(client.seen), 1)   # processed once, \Seen
        self.assertEqual(client.deleted, [])    # never deleted
        txt = self.sidecars()[0].read_text()
        self.assertIn("## operator reply", txt)  # annotation still landed

    def test_plain_bad_id_never_annotates(self):
        # `f7fd5d5` (7 chars) and `f7fd5d5g` (non-hex) are not report ids
        self.seed_report()
        for subj in ("Re: [hngh f7fd5d5]", "Re: [hngh f7fd5d5g]"):
            self.poll_one(subj, "approve: x")
        self.assertEqual(len(self.sidecars()), 1)  # only the seeded one

    def test_annotation_never_touches_ledger_or_drafts(self):
        """A linked reply adds no report row, no plan draft, ever."""
        self.seed_report()
        ledger_before = (self.kernel / "docs" / "project"
                         / "reports.md").read_text()
        self.poll_one("Re: [hngh %s] decision: accept" % REPORT_ID,
                      "approve: go ahead")
        self.assertEqual(
            (self.kernel / "docs" / "project" / "reports.md").read_text(),
            ledger_before)
        self.assertFalse((self.auto / "digest").exists())


if __name__ == "__main__":
    unittest.main()
