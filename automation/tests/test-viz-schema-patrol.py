#!/usr/bin/env python3
"""viz-schema patrol payload acceptance tests (node schema-tests-patrol).

The patrol/1 payload envelope {'schema': 'patrol/1', 'findings': [...]}
with entries {id, date, surface, cause, detail, supportive} is the viz
synthesis input derived from what jobs/patrol.py already writes
(findings_md two-pass sections, the stdout PASS/FAIL machine contract,
report-queue alert identities). Source docs: the tracked design pair
docs/design/ui-evolve/patrol-payload-schema.md (field rules, fail-cause
vocabulary) and docs/design/ui-evolve/patrol-report-samples.md (the real
2026-09-14 run the fixtures mirror: patrol:handoffs bad-execution,
patrol:automation-gate gate-red).

Validation law (fail closed, same discipline as the graph feed's
malformed-session handling):

  - malformed JSON fails closed (never a partial accept)
  - envelope: schema tag missing/wrong, findings missing/not-an-array,
    any unknown envelope key -> fail closed
  - findings: unknown key, missing required field, wrong type (id not a
    patrol:<id> string, supportive not a real bool, date not a real
    YYYY-MM-DD day, surface/cause/detail not non-empty strings) ->
    fail closed
  - duplicate finding ids -> fail closed (ids are the renderer's keys)

One additive lane: an unknown cause value is a WARN, not a rejection --
the cause vocabulary grows (journal rounds file unclaimed-err by design;
patrol.py:1042-1049), so new causes are data the schema must accept.
WARNs come back from validate_payload() as strings; acceptance is the
absence of a PayloadError.

Producer drift cross-check: one finding is derived from a live hermetic
patrol run (seeded handoffs ledger, 3 dead/cancelled rows -> FAIL) and
its schema id must equal the producer's alert identity `patrol:<id>`
(captured through a stub report-queue argv, patrol.py:1432-1436), and
must match the identity literal the samples doc records. If patrol.py
ever changes the identity format, or the schema drifts from it, these
tests go red.

Hermetic: everything runs in a tempfile sandbox (PATROL_* env wired to
sandbox paths, stub report-queue binary, no real ledgers, no real
report-queue, no ~/.hngh, no network). No production file is touched;
the validator lives in this file until the emitter lands behind the
hngh.patrol.v1 tag and promotes it.
"""

import copy
import datetime
import importlib.util
import json
import os
import re
import tempfile
import time
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
REPO = ROOT.parent  # the hngh repo (samples doc + patrol routes read-only)
SPEC = ROOT / "jobs" / "patrol.py"
SAMPLES_DOC = REPO / "docs" / "design" / "ui-evolve" / "patrol-report-samples.md"

NOW = time.mktime(time.strptime("2026-09-12T10:00:00Z",
                                "%Y-%m-%dT%H:%M:%SZ")) - time.timezone
RUN_DATE = time.strftime("%Y-%m-%d", time.gmtime(NOW))

# ---------------------------------------------------------------------------
# patrol/1 validation (schema spec: patrol-payload-schema.md; fail-cause
# vocabulary from its section 3 -- observed patrol.py causes, used only for
# the WARN lane, never for rejection: an unknown cause must stay acceptable)
# ---------------------------------------------------------------------------

SCHEMA_TAG = "patrol/1"
ENVELOPE_KEYS = frozenset(("schema", "findings"))
FINDING_KEYS = frozenset(
    ("id", "date", "surface", "cause", "detail", "supportive"))
FAIL_CAUSES = frozenset((
    "feed-missing", "feed-stale", "blocker-escalated", "ledger-unreadable",
    "bad-execution", "gate-stale", "gate-red", "gate-cure-refused",
    "digest-missing", "digest-empty", "deck-a-empty", "service-down",
    "disk-full", "stalled-line", "budget", "check-crash", "unknown-check",
    "processed-missing", "feedback-flood", "manga-stale",
    "components-pending", "send-failed", "ghost-row",
    "transient-left-running", "adopted-no-followon", "timer-dead",
    "transient-escalation", "unit-not-practiced", "restart-guard",
    "restart-failed", "propose", "alert", "unclaimed-err", "config-bug",
    "journal-unreadable"))
ID_RE = re.compile(r"patrol:[\w-]+\Z")
DATE_RE = re.compile(r"\d{4}-\d{2}-\d{2}\Z")


class PayloadError(ValueError):
    """A patrol/1 fail-closed violation: the payload is not patrol/1."""


def validate_payload(payload):
    """Strict patrol/1 validation.

    Fail closed: raises PayloadError on any structural violation
    (envelope shape, schema tag, unknown keys, missing fields, wrong
    types, duplicate ids). Additive: unknown cause values do not raise;
    they come back as WARN strings -- the cause vocabulary grows and
    new causes are data, not schema errors.
    """
    if not isinstance(payload, dict):
        raise PayloadError("envelope must be a JSON object")
    unknown = sorted(set(payload) - ENVELOPE_KEYS)
    if unknown:
        raise PayloadError(
            "envelope: unknown key(s): %s" % ", ".join(unknown))
    if "schema" not in payload:
        raise PayloadError("envelope: missing schema tag")
    if payload["schema"] != SCHEMA_TAG:
        raise PayloadError("envelope: schema must be %r, got %r"
                           % (SCHEMA_TAG, payload["schema"]))
    if "findings" not in payload:
        raise PayloadError("envelope: missing findings")
    findings = payload["findings"]
    if not isinstance(findings, list):
        raise PayloadError("findings must be an array")
    warns, seen = [], set()
    for i, f in enumerate(findings):
        if not isinstance(f, dict):
            raise PayloadError("finding %d: must be an object" % i)
        unknown = sorted(set(f) - FINDING_KEYS)
        if unknown:
            raise PayloadError("finding %d: unknown key(s): %s"
                               % (i, ", ".join(unknown)))
        missing = sorted(FINDING_KEYS - set(f))
        if missing:
            raise PayloadError("finding %d: missing field(s): %s"
                               % (i, ", ".join(missing)))
        fid = f["id"]
        if not isinstance(fid, str) or not ID_RE.match(fid):
            raise PayloadError(
                "finding %d: id must be a \"patrol:<id>\" string, got %r"
                % (i, fid))
        if fid in seen:
            raise PayloadError("finding %d: duplicate id %s" % (i, fid))
        seen.add(fid)
        date = f["date"]
        if not isinstance(date, str) or not DATE_RE.match(date):
            raise PayloadError(
                "finding %d: date must be YYYY-MM-DD, got %r" % (i, date))
        try:
            datetime.date(int(date[:4]), int(date[5:7]), int(date[8:10]))
        except ValueError:
            raise PayloadError(
                "finding %d: date is not a real calendar day: %r"
                % (i, date))
        for key in ("surface", "cause", "detail"):
            if not isinstance(f[key], str) or not f[key]:
                raise PayloadError(
                    "finding %d: %s must be a non-empty string" % (i, key))
        if not isinstance(f["supportive"], bool):
            raise PayloadError(
                "finding %d: supportive must be a boolean, got %r"
                % (i, f["supportive"]))
        if f["cause"] not in FAIL_CAUSES:
            warns.append(
                "WARN finding %d: unknown cause %r (accepted; the cause "
                "vocabulary grows additively)" % (i, f["cause"]))
    return warns


def parse_payload(text):
    """JSON text -> validated payload (JSONDecodeError propagates)."""
    return validate_payload(json.loads(text))


def alert_identity(patrol_id):
    """The report-queue identity for a patrol id -- the producer's
    format (patrol.py report_alert: `"patrol:" + pid`)."""
    return "patrol:" + patrol_id


# ---------------------------------------------------------------------------
# Fixtures (the real 2026-09-14 23:20Z run, samples doc Sample 2)
# ---------------------------------------------------------------------------

def _finding(**over):
    f = {"id": "patrol:handoffs", "date": "2026-09-14",
         "surface": "handoffs-accumulation", "cause": "bad-execution",
         "detail": "7 dead/cancelled in last 10 rows (threshold 3)",
         "supportive": False}
    f.update(over)
    return f


def _envelope(findings=None):
    return {"schema": SCHEMA_TAG,
            "findings": [_finding()] if findings is None else findings}


VALID_ENVELOPE = _envelope([
    _finding(),
    _finding(id="patrol:automation-gate", surface="automation-gate",
             cause="gate-red", detail="make test rc=2"),
])


class VizSchemaPatrolPayload(unittest.TestCase):
    """patrol/1 acceptance: valid fixtures accept; every structural
    violation fails closed; unknown causes warn but accept."""

    def test_valid_fixture_accepts_clean(self):
        self.assertEqual(validate_payload(VALID_ENVELOPE), [])

    def test_empty_findings_accepts(self):
        # an all-green run emits a run section with no findings rows
        self.assertEqual(validate_payload(_envelope([])), [])

    def test_malformed_json_fails_closed(self):
        with self.assertRaises(json.JSONDecodeError):
            parse_payload('{"schema": "patrol/1", "findings": [')
        with self.assertRaises(json.JSONDecodeError):
            parse_payload("not json at all")

    def test_non_object_envelope_fails_closed(self):
        for bad in ([], "patrol/1", 42, None):
            with self.assertRaises(PayloadError):
                validate_payload(bad)

    def test_schema_tag_missing_fails_closed(self):
        env = _envelope()
        del env["schema"]
        with self.assertRaisesRegex(PayloadError, "missing schema"):
            validate_payload(env)

    def test_schema_tag_wrong_fails_closed(self):
        for wrong in ("patrol/2", "hngh.patrol.v1", 42, None):
            with self.assertRaisesRegex(PayloadError, "schema"):
                validate_payload({"schema": wrong, "findings": []})

    def test_envelope_unknown_key_fails_closed(self):
        env = _envelope()
        env["run_ts"] = "2026-09-14T23:20:13Z"  # plausible, still illegal
        with self.assertRaisesRegex(PayloadError, "unknown key"):
            validate_payload(env)

    def test_findings_missing_fails_closed(self):
        env = {"schema": SCHEMA_TAG}
        with self.assertRaisesRegex(PayloadError, "missing findings"):
            validate_payload(env)

    def test_findings_not_array_fails_closed(self):
        for bad in ({"id": "patrol:x"}, "findings", 7):
            with self.assertRaisesRegex(PayloadError, "findings"):
                validate_payload({"schema": SCHEMA_TAG, "findings": bad})

    def test_finding_not_object_fails_closed(self):
        with self.assertRaisesRegex(PayloadError, "must be an object"):
            validate_payload(_envelope(["patrol:handoffs"]))

    def test_finding_unknown_key_fails_closed(self):
        f = _finding(note="a perceptual caption never enters a record")
        with self.assertRaisesRegex(PayloadError, "unknown key"):
            validate_payload(_envelope([f]))

    def test_finding_missing_required_field_fails_closed(self):
        for key in sorted(FINDING_KEYS):
            f = _finding()
            del f[key]
            with self.assertRaisesRegex(PayloadError, key):
                validate_payload(_envelope([f]))

    def test_id_wrong_type_fails_closed(self):
        for bad in (7, None, ["patrol:handoffs"], True):
            with self.assertRaisesRegex(PayloadError, "id"):
                validate_payload(_envelope([_finding(id=bad)]))

    def test_id_wrong_shape_fails_closed(self):
        for bad in ("handoffs",            # missing patrol: prefix
                    "patrol:",             # empty suffix
                    "alert:handoffs",      # wrong identity prefix
                    "patrol:handoffs x"):  # space, not an id
            with self.assertRaisesRegex(PayloadError, "patrol:<id>"):
                validate_payload(_envelope([_finding(id=bad)]))

    def test_date_wrong_format_fails_closed(self):
        for bad in ("2026-9-14", "20260914", "2026/09/14",
                    "14-09-2026", 20260914, None):
            with self.assertRaisesRegex(PayloadError, "YYYY-MM-DD"):
                validate_payload(_envelope([_finding(date=bad)]))

    def test_date_not_real_day_fails_closed(self):
        for bad in ("2026-13-01", "2026-02-30", "2026-00-10"):
            with self.assertRaisesRegex(PayloadError, "calendar day"):
                validate_payload(_envelope([_finding(date=bad)]))

    def test_text_fields_wrong_type_or_empty_fail_closed(self):
        for key in ("surface", "cause", "detail"):
            for bad in (42, None, [], True, ""):
                with self.assertRaisesRegex(PayloadError, key):
                    validate_payload(_envelope([_finding(**{key: bad})]))

    def test_supportive_wrong_type_fails_closed(self):
        # bool is not an int gate: 1/0 and "true" are not booleans
        for bad in (1, 0, "true", "false", None, [], [True]):
            with self.assertRaisesRegex(PayloadError, "supportive"):
                validate_payload(_envelope([_finding(supportive=bad)]))

    def test_duplicate_finding_ids_fail_closed(self):
        dup = _envelope([_finding(), _finding()])
        with self.assertRaisesRegex(PayloadError, "duplicate id"):
            validate_payload(dup)

    def test_unknown_cause_warns_but_accepts(self):
        # the additive lane: journal rounds file novel causes by design
        f = _finding(cause="unclaimed-err-v2")
        warns = validate_payload(_envelope([f]))
        self.assertEqual(len(warns), 1)
        self.assertIn("unclaimed-err-v2", warns[0])
        self.assertTrue(warns[0].startswith("WARN"))

    def test_supportive_pass_row_accepts_and_warns_on_open_cause(self):
        # Sample 1's quiet-rounds pass row: supportive True. The cause
        # vocabulary above is the FAIL bestiary, so a pass-side cause is
        # data outside it -> accepted, with a WARN until it grows in.
        f = _finding(id="patrol:feeds", surface="dashboard-feeds",
                     cause="ok", detail="feed age=1343s", supportive=True)
        warns = validate_payload(_envelope([f]))
        self.assertEqual(len(warns), 1)
        self.assertIn("unknown cause", warns[0])


class ProducerIdentityCrossCheck(unittest.TestCase):
    """The schema id cannot silently drift from the producer: a live
    hermetic patrol run must (a) file its alert under identity
    patrol:<id> exactly, and (b) yield a finding that validates clean
    under patrol/1 with that id."""

    def setUp(self):
        self._saved = {}
        self.sb = tempfile.TemporaryDirectory()
        self.addCleanup(self.sb.cleanup)
        sb = Path(self.sb.name)
        # minimal routes: only the handoffs row (columns per
        # config/patrol-routes.tsv)
        (sb / "patrol-routes.tsv").write_text(
            "patrol-id\tsurface\tcheck\tfreq-tier\tfinding-class\n"
            "handoffs\thandoffs-accumulation\thandoff-deaths\t30m\t"
            "bad-execution\n")
        # handoffs ledger: 3 dead/cancelled among the last rows --
        # at/over the threshold (3), so handoff-deaths FAILs
        (sb / "agent-handoffs.md").write_text(
            "overnight-lead | 2026-09-12T08:00:00Z | plan-alpha|run-1 | "
            "rc=1 dead cause=provider-429\n"
            "overnight-lead | 2026-09-12T08:30:00Z | plan-beta|run-2 | "
            "rc=0 ok\n"
            "overnight-lead | 2026-09-12T09:00:00Z | plan-gamma|run-3 | "
            "rc=1 dead cause=provider-429\n"
            "overnight-lead | 2026-09-12T09:20:00Z | plan-delta|run-4 | "
            "rc=1 cancelled cause=operator-stop\n"
            "overnight-lead | 2026-09-12T09:40:00Z | plan-eps|run-5 | "
            "rc=0 ok\n")
        # stub report-queue: captures argv, touches nothing real
        (sb / "rq-stub.sh").write_text(
            "#!/usr/bin/env bash\n"
            "printf '%s\\n' \"$*\" >> \"$RQ_LOG\"\n")
        (sb / "rq-stub.sh").chmod(0o755)
        (sb / "digest").mkdir()
        (sb / "lib").mkdir()  # no quips module -> quip line stays empty
        for k, v in [("PATROL_ROOT", str(sb)),
                     ("PATROL_KERNEL", str(sb)),
                     ("PATROL_ROUTES", str(sb / "patrol-routes.tsv")),
                     ("PATROL_HANDOFFS", str(sb / "agent-handoffs.md")),
                     ("PATROL_DIGEST_DIR", str(sb / "digest")),
                     ("PATROL_SUBJECTS", str(sb / "research-subjects.txt")),
                     ("PATROL_REPORT_ROOT", str(sb)),
                     ("REPORT_QUEUE_BIN", str(sb / "rq-stub.sh")),
                     ("RQ_LOG", str(sb / "rq.log")),
                     ("PATROL_NOW_EPOCH", str(NOW))]:
            self._saved[k] = os.environ.get(k)
            os.environ[k] = v
        self.addCleanup(self._restore_env)
        spec = importlib.util.spec_from_file_location("patrol_mod", SPEC)
        self.patrol = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(self.patrol)

    def _restore_env(self):
        for k, v in self._saved.items():
            if v is None:
                os.environ.pop(k, None)
            else:
                os.environ[k] = v

    def test_run_fails_as_expected(self):
        results, rc = self.patrol.run(patrol_id="handoffs", now_s=NOW)
        self.assertEqual(rc, 0)
        self.assertEqual(len(results), 1)
        r = results[0]
        self.assertEqual(r["id"], "handoffs")
        self.assertEqual(r["surface"], "handoffs-accumulation")
        self.assertEqual(r["passes"], [])
        self.assertEqual(r["fails"], [
            ("agent-handoffs.md", "bad-execution",
             "3 dead/cancelled in last 5 rows")])

    def test_alert_identity_matches_schema_id(self):
        # end-to-end through main(): the FAIL files a report-queue alert
        # whose --identity must be exactly "patrol:" + the route id --
        # the format the schema's `id` field encodes
        rc = self.patrol.main(["--patrol", "handoffs"])
        self.assertEqual(rc, 0)
        log = (Path(self.sb.name) / "rq.log").read_text()
        self.assertIn("--identity patrol:handoffs", log)
        rid = "handoffs"
        self.assertEqual(alert_identity(rid), "patrol:handoffs")
        # the producer-shaped finding validates clean under patrol/1
        finding = {"id": alert_identity(rid), "date": RUN_DATE,
                   "surface": "handoffs-accumulation",
                   "cause": "bad-execution",
                   "detail": "3 dead/cancelled in last 5 rows",
                   "supportive": False}
        self.assertEqual(
            validate_payload({"schema": SCHEMA_TAG, "findings": [finding]}),
            [])
        # and the identity literal the samples doc records stays the
        # same format (drift triangle: producer <-> schema <-> samples)
        if SAMPLES_DOC.is_file():
            self.assertIn("patrol:handoffs", SAMPLES_DOC.read_text(
                encoding="utf-8", errors="replace"))
        else:
            self.skipTest("samples doc not present")


if __name__ == "__main__":
    unittest.main()
