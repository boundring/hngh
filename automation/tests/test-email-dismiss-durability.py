#!/usr/bin/env python3
"""Email-driven operator-item dismissals survive the feed rebuild.

Red-first regression for the dismiss-clobber defect: imap-poll's deny:
directive used to transition dashboard/operator-items.json only, so the
next jobs/operator-items-feed.py rebuild (cadence/subhour/05-operator-items.sh)
reset the item to open and the operator's emailed decision evaporated.

Contract after the fix:
  - scripts/imap-poll.py apply_directive records every deny: target id in
    dashboard/operator-dismissed.json under the SAME schema the
    dashboard-server.py POST /operator-item/dismiss path writes
    ({"dismissed": {"<id>": "<UTC ts>"}}, atomic replace), merging with
    ids already dismissed from the UI; approve:/note: never touch the
    ledger.
  - jobs/operator-items-feed.py honors ledger ids with dismissed-status
    semantics consistent with the display contract: the dashboard hides
    every id in the dismissal ledger, so the feed must not report them
    open (and must not mark them recurring); a later RESOLVED crumb
    still outranks the ledger (handled wins).

Seams: HNGH_AUTOMATION_ROOT / HNGH_HOME point imap-poll at a tmp
sandbox; the feed module's DATA/STATE/OUT/DISMISSED constants are
patched to the same sandbox. No network, no real mailbox, no server.
"""

import importlib.util
import json
import os
import shutil
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
IMAP_POLL = ROOT / "scripts" / "imap-poll.py"
FEED = ROOT / "jobs" / "operator-items-feed.py"

REPORT_ID = "f7fd5d5b"
NOW = "2026-09-14T14:00:00Z"
ITEM_TEXT = "imap-poll | alert | deck pull fails (%s)" % REPORT_ID

_feed_seq = 0


def load_imap_poll():
    """Fresh exec so module-level seam constants re-read the env."""
    spec = importlib.util.spec_from_file_location("imap_poll", IMAP_POLL)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def load_feed(tmp):
    """Feed module with every filesystem touchpoint seamed into tmp."""
    global _feed_seq
    _feed_seq += 1
    spec = importlib.util.spec_from_file_location(
        "operator_items_feed_%d" % _feed_seq, FEED)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    dash = tmp / "dashboard"
    mod.DATA = str(dash / "data.json")
    mod.STATE = str(tmp / "STATE.md")
    mod.OUT = str(dash / "operator-items.json")
    mod.DISMISSED = str(dash / "operator-dismissed.json")
    mod.APPROVED = str(dash / "operator-approved.json")
    return mod


class Durability(unittest.TestCase):
    """directive -> rebuild -> status survives."""

    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp(prefix="dismiss-durability-"))
        self.addCleanup(shutil.rmtree, self.tmp, True)
        self.auto = self.tmp / "automation"
        (self.auto / "dashboard").mkdir(parents=True)
        (self.auto / "logs").mkdir()
        self.kernel = self.tmp / "kernel"
        (self.kernel / "scripts").mkdir(parents=True)
        self.old = (os.environ.get("HNGH_AUTOMATION_ROOT"),
                    os.environ.get("HNGH_HOME"))
        os.environ["HNGH_AUTOMATION_ROOT"] = str(self.auto)
        os.environ["HNGH_HOME"] = str(self.kernel)
        self.addCleanup(self._restore)
        self.imap_poll = load_imap_poll()
        self.feed = load_feed(self.auto)
        self.dash = self.auto / "dashboard"
        self.out = self.dash / "operator-items.json"
        self.ledger = self.dash / "operator-dismissed.json"

    def _restore(self):
        for key, val in zip(("HNGH_AUTOMATION_ROOT", "HNGH_HOME"), self.old):
            if val is None:
                os.environ.pop(key, None)
            else:
                os.environ[key] = val

    def seed(self, ledger=None):
        """One open operator-item whose id the feed rebuild reproduces:
        the STATE.md alert crumb's joined text is exactly ITEM_TEXT, so
        item_id(ITEM_TEXT) is stable across the rebuild."""
        iid = self.feed.item_id(ITEM_TEXT)
        with open(self.out, "w") as f:
            json.dump({"generated_at": NOW, "items": [
                {"id": iid, "text": ITEM_TEXT, "first_seen": NOW,
                 "last_seen": NOW, "status": "open", "evidence": ""}]}, f)
        with open(self.auto / "STATE.md", "a") as f:
            f.write("%s | imap-poll | alert | deck pull fails (%s)\n"
                    % (NOW, REPORT_ID))
        (self.dash / "data.json").write_text(
            json.dumps({"generated_at": NOW, "digest": ""}))
        if ledger is not None:
            with open(self.ledger, "w") as f:
                json.dump(ledger, f)
        return iid

    def live(self):
        return json.load(open(self.out))

    def items(self):
        return self.live()["items"][0]

    # -- the red-first regression -------------------------------------

    def test_directive_then_rebuild_status_survives(self):
        iid = self.seed()
        # deny: via email -> live feed dismissed (pre-existing behavior)
        rc = self.imap_poll.apply_directive(
            REPORT_ID, "deny: this is a known false positive.")
        self.assertEqual(rc, str(self.out))
        self.assertEqual(self.items()["status"], "dismissed")
        # ...and the next 1m feed rebuild must NOT resurrect it
        self.feed.main()
        it = self.items()
        self.assertEqual(it["id"], iid)      # same item re-emitted
        self.assertEqual(it["status"], "dismissed")  # decision survives

    def test_deny_records_dismissal_ledger_with_server_schema(self):
        iid = self.seed()
        self.imap_poll.apply_directive(REPORT_ID, "deny: known false hit.")
        led = json.load(open(self.ledger))
        self.assertEqual(set(led.keys()), {"dismissed"})
        ts = led["dismissed"][iid]
        self.assertRegex(ts, r"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$")

    def test_approve_records_approval_ledger(self):
        """Red-first rebuild-clobber fix: approve: must persist durably
        to dashboard/operator-approved.json (same schema), merged with
        existing approvals."""
        iid = self.seed()
        with open(self.dash / "operator-approved.json", "w") as f:
            json.dump({"approved": {"cafe0001": NOW}}, f)
        rc = self.imap_poll.apply_directive(
            REPORT_ID, "approve: yes, the deck fix looks right.")
        self.assertEqual(rc, str(self.out))
        self.assertEqual(self.items()["status"], "handled")
        led = json.load(open(self.dash / "operator-approved.json"))["approved"]
        self.assertEqual(led["cafe0001"], NOW)  # merged, not clobbered
        self.assertRegex(led[iid], r"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$")

    def test_approve_then_rebuild_status_survives(self):
        """The original defect: approve: transitions only the live feed,
        the next 1m rebuild resets to open. After the fix the approval
        ledger keeps handled across rebuilds."""
        iid = self.seed()
        self.imap_poll.apply_directive(
            REPORT_ID, "approve: yes, the deck fix looks right.")
        self.assertEqual(self.items()["status"], "handled")
        self.feed.main()  # 1m rebuild
        it = self.items()
        self.assertEqual(it["id"], iid)
        self.assertEqual(it["status"], "handled")  # decision survives

    def test_ledger_merge_preserves_ui_dismissals(self):
        """deny: merges into the ledger; UI-dismissed ids are never lost."""
        iid = self.seed(ledger={"dismissed": {
            "cafe0001": "2026-09-14T00:00:00Z"}})
        self.imap_poll.apply_directive(REPORT_ID, "deny: nope.")
        led = json.load(open(self.ledger))["dismissed"]
        self.assertEqual(led["cafe0001"], "2026-09-14T00:00:00Z")
        self.assertIn(iid, led)

    def test_approve_and_note_never_touch_the_dismissal_ledger(self):
        self.seed()
        self.imap_poll.apply_directive(
            REPORT_ID, "approve: yes, the deck fix looks right.")
        self.assertFalse(self.ledger.exists())
        self.imap_poll.apply_directive(REPORT_ID, "note: watching this.")
        self.assertFalse(self.ledger.exists())

    def test_corrupt_ledger_fails_closed_not_fatal(self):
        """Unparsable ledger: the directive still lands (annotation +
        live transition) and the ledger is rebuilt fresh, never fatal."""
        iid = self.seed()
        self.ledger.write_text("{not json")
        rc = self.imap_poll.apply_directive(REPORT_ID, "deny: bad json ok.")
        self.assertEqual(rc, str(self.out))
        self.assertEqual(self.items()["status"], "dismissed")
        self.assertEqual(self.items()["status"], "dismissed")
        led = json.load(open(self.ledger))["dismissed"]
        self.assertRegex(led[iid], r"^\d{4}-")  # rebuilt fresh, valid ts

    def test_multi_match_records_every_id(self):
        """Two matching open items -> both ids land in the ledger."""
        iid = self.seed()
        extra = dict(json.load(open(self.out))["items"][0])
        extra = {"id": "beef0001",
                 "text": "imap-poll | alert | deck pull fails again (%s)"
                         % REPORT_ID,
                 "first_seen": NOW, "last_seen": NOW,
                 "status": "open", "evidence": ""}
        data = json.load(open(self.out))
        data["items"].append(extra)
        with open(self.out, "w") as f:
            json.dump(data, f)
        self.imap_poll.apply_directive(REPORT_ID, "deny: both.")
        led = json.load(open(self.ledger))["dismissed"]
        self.assertIn(iid, led)
        self.assertIn("beef0001", led)

    # -- feed-side semantics -------------------------------------------

    def test_feed_marks_ledger_ids_dismissed_without_resolution(self):
        iid = self.seed()
        self.feed.main()  # no ledger yet -> open
        self.assertEqual(self.items()["status"], "open")
        with open(self.ledger, "w") as f:
            json.dump({"dismissed": {iid: NOW}}, f)
        self.feed.main()
        it = self.items()
        self.assertEqual(it["status"], "dismissed")
        self.assertNotIn("recurring", it)  # dismissed is not recurring

    def test_feed_honors_approval_ledger(self):
        """Red-first: ids in operator-approved.json keep handled across
        the rebuild; a later RESOLVED crumb evidence still shows."""
        iid = self.seed()
        self.feed.main()  # no approval yet -> open
        self.assertEqual(self.items()["status"], "open")
        with open(self.dash / "operator-approved.json", "w") as f:
            json.dump({"approved": {iid: NOW}}, f)
        self.feed.main()
        it = self.items()
        self.assertEqual(it["status"], "handled")  # not reset to open

    def test_feed_resolution_scan_outranks_the_ledger(self):
        """A later RESOLVED crumb still promotes to handled (display
        contract: handled renders the green check when not hidden)."""
        iid = self.seed()
        with open(self.ledger, "w") as f:
            json.dump({"dismissed": {iid: NOW}}, f)
        with open(self.auto / "STATE.md", "a") as f:
            f.write("2026-09-14T15:00:00Z | deck-refresh | done | "
                    "deck pull fails no more — resolved and closed\n")
        self.feed.main()
        it = self.items()
        self.assertEqual(it["status"], "handled")
        self.assertIn("resolved", it["evidence"])

    def test_feed_without_ledger_stays_open(self):
        self.seed()
        self.feed.main()
        it = self.items()
        self.assertEqual(it["status"], "open")
        self.assertNotIn("recurring", it)

if __name__ == "__main__":
    unittest.main()
