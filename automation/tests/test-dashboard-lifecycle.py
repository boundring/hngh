#!/usr/bin/env python3
"""Stage-2 exit gate: the operator-item lifecycle endpoints.

POST /operator-item/<verb> for verb in {handle, dismiss, park, expire,
suppress, acknowledge} records the open -> handled / dismissed
transitions in their ledgers
(dashboard/operator-approved.json / operator-dismissed.json,
{"approved"|"dismissed": {"<id>": "<UTC ts>"}}, atomic replace) and
each transition files exactly ONE report-queue progress row (identity
operator-item:<id>:<state>). Repeat posts are idempotent: no second
row. A report-queue failure fails the POST closed with the ledger
untouched, so no transition ever lands silently without its row. The
token guard covers both endpoints.

Run: python3 automation/tests/test-dashboard-lifecycle.py
"""
import importlib.util
import json
import os
import shutil
import subprocess
import sys
import tempfile
import threading
import unittest
import urllib.error
import urllib.request
from pathlib import Path

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))  # automation/
DS_PATH = os.path.join(ROOT, "dashboard-server.py")

STUB_RQ = r'''
import os, sys
with open(os.environ["HNGH_STUB_RQ_LOG"], "a") as f:
    f.write(repr(sys.argv[1:]) + "\n")
raise SystemExit(int(os.environ.get("HNGH_STUB_RQ_RC", "0")))
'''

STUB_PRIV = '''#!/usr/bin/env bash
# stand-in for automation/lib/privileged.sh: logs argv, exits on demand
printf '%s\\n' "$*" >> "$HNGH_STUB_PRIV_LOG"
echo "line-one"
echo "stderr-line" >&2
exit "${HNGH_STUB_PRIV_RC:-0}"
'''

STUB_AUR = '''#!/usr/bin/env bash
# stand-in for automation/jobs/aur-build.sh: logs argv, canned output
printf '%s\\n' "$*" >> "$HNGH_STUB_AUR_LOG"
echo "line-one"
echo "aur-build: staged owe-1.0.0-1-any.pkg.tar.zst"
echo "aur-build: follow-up: stub-privileged.sh wicket install-file owe-1.0.0-1-any.pkg.tar.zst"
exit "${HNGH_STUB_AUR_RC:-0}"
'''


def _load():
    spec = importlib.util.spec_from_file_location(
        "ds_lifecycle", os.path.join(ROOT, "dashboard-server.py"))
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


ds = _load()


class Lifecycle(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        base = Path(self.tmp.name)
        dash = base / "dashboard"
        dash.mkdir()
        (dash / "index.html").write_text(
            "<html><head><title>t</title></head><body></body></html>")
        for name in ("operator-items.json", "operator-dismissed.json",
                     "readout.json"):
            (dash / name).write_text("{}")
        self.approved = dash / "operator-approved.json"
        self.dismissed = dash / "operator-dismissed.json"
        self.handoffs = base / "agent-handoffs.md"
        self.rq_log = base / "rq.log"
        stub = base / "stub-report-queue"
        stub.write_text(STUB_RQ)
        stub.chmod(0o755)
        ds.TOKEN_FILE = str(base / "token.txt")
        ds.HANDOFFS = str(self.handoffs)
        ds.DISMISSED = str(self.dismissed)
        ds.APPROVED = str(self.approved)
        ds.REPORT_QUEUE = str(stub)
        ds.EVENT_WATCH = tuple(str(dash / n) for n in (
            "operator-items.json", "operator-dismissed.json",
            "operator-approved.json", "readout.json"))
        self.old_env = {k: os.environ.get(k)
                        for k in ("HNGH_STUB_RQ_LOG", "HNGH_STUB_RQ_RC")}
        os.environ["HNGH_STUB_RQ_LOG"] = str(self.rq_log)
        os.environ.pop("HNGH_STUB_RQ_RC", None)
        self.token = ds.load_token()
        self.httpd = ds.ThreadingHTTPServer(("127.0.0.1", 0), ds.Handler)
        self.port = self.httpd.server_address[1]
        threading.Thread(target=self.httpd.serve_forever,
                         daemon=True).start()
        self.addCleanup(self._teardown)

    def _teardown(self):
        self.httpd.shutdown()
        self.httpd.server_close()
        for key, val in self.old_env.items():
            if val is None:
                os.environ.pop(key, None)
            else:
                os.environ[key] = val
        self.tmp.cleanup()

    def post(self, route, obj, token=True):
        req = urllib.request.Request(
            "http://127.0.0.1:%d/%s" % (self.port, route),
            data=json.dumps(obj).encode(),
            headers={"Content-Type": "application/json"})
        if token:
            req.add_header("X-Hngh-Token", self.token)
        try:
            with urllib.request.urlopen(req, timeout=5) as r:
                return r.status, json.loads(r.read() or b"{}")
        except urllib.error.HTTPError as e:
            return e.code, json.loads(e.read() or b"{}")

    def rows(self):
        if not self.rq_log.exists():
            return []
        return [line for line in self.rq_log.read_text().splitlines() if line]

    # ---- open -> handled -------------------------------------------------
    def test_handle_files_row_and_approved_ledger(self):
        code, body = self.post("operator-item/handle", {"id": "deadbeef"})
        self.assertEqual((code, body.get("ok")), (201, True))
        approved = json.loads(self.approved.read_text())["approved"]
        self.assertIn("deadbeef", approved)
        rows = self.rows()
        self.assertEqual(len(rows), 1)
        self.assertIn("'progress'", rows[0])
        self.assertIn("'operator-item:deadbeef:handled'", rows[0])
        self.assertIn("operator-handle | ", self.handoffs.read_text())
        self.assertIn("automation|deadbeef | item marked handled",
                      self.handoffs.read_text())

    def test_handle_repeat_is_idempotent(self):
        self.post("operator-item/handle", {"id": "deadbeef"})
        code, body = self.post("operator-item/handle", {"id": "deadbeef"})
        self.assertEqual((code, body.get("ok")), (201, True))
        self.assertEqual(len(self.rows()), 1)
        approved = json.loads(self.approved.read_text())["approved"]
        self.assertEqual(list(approved), ["deadbeef"])

    # ---- open -> dismissed -----------------------------------------------
    def test_dismiss_files_row_and_merges_ledger(self):
        self.dismissed.write_text(
            json.dumps({"dismissed": {"00112233": "2026-01-01T00:00:00Z"}}))
        code, body = self.post("operator-item/dismiss", {"id": "deadbeef"})
        self.assertEqual((code, body.get("ok")), (201, True))
        dismissed = json.loads(self.dismissed.read_text())["dismissed"]
        self.assertEqual(set(dismissed), {"00112233", "deadbeef"})
        self.assertEqual(dismissed["00112233"], "2026-01-01T00:00:00Z")
        rows = self.rows()
        self.assertEqual(len(rows), 1)
        self.assertIn("'operator-item:deadbeef:dismissed'", rows[0])
        # idempotent: the second post keeps its handoffs line but files
        # no second row and never re-stamps the ledger entry
        code, _ = self.post("operator-item/dismiss", {"id": "deadbeef"})
        self.assertEqual(code, 201)
        self.assertEqual(len(self.rows()), 1)

    # ---- fail closed / guards --------------------------------------------
    def test_row_failure_leaves_ledger_untouched(self):
        os.environ["HNGH_STUB_RQ_RC"] = "1"
        code, body = self.post("operator-item/handle", {"id": "deadbeef"})
        self.assertEqual(code, 500)
        self.assertFalse(body.get("ok"))
        self.assertFalse(self.approved.exists())
        self.assertFalse(self.handoffs.exists())
        code, _ = self.post("operator-item/dismiss", {"id": "deadbeef"})
        self.assertEqual(code, 500)
        self.assertEqual(json.loads(self.dismissed.read_text()), {})

    def test_bad_id_rejected(self):
        for route in ("operator-item/handle", "operator-item/dismiss"):
            code, _ = self.post(route, {"id": "bad id!"})
            self.assertEqual(code, 400)
        self.assertEqual(self.rows(), [])

    def test_token_required(self):
        code, _ = self.post("operator-item/handle", {"id": "deadbeef"},
                            token=False)
        self.assertEqual(code, 403)
        self.assertFalse(self.approved.exists())
        self.assertEqual(self.rows(), [])


class UiWiring(unittest.TestCase):
    """app.js must actually drive the transitions it renders."""

    def test_handle_affordance_posts_both_endpoints(self):
        a = Path(ROOT, "dashboard", "app.js").read_text()
        self.assertIn("postJson('/operator-item/handle', { id: id })", a)
        self.assertIn("postJson('/operator-item/dismiss', { id: id })", a)
        self.assertIn('data-handle-yes="', a)
        self.assertIn("it.status = 'handled'", a)


class OperatorVerbs(Lifecycle):
    """park/expire/suppress/acknowledge ride the SAME seams as
    handle/dismiss: one report-queue row (identity
    operator-item:<id>:<verb>) then the matching durable ledger.
    park requires a non-blank note (4xx otherwise, nothing written)."""

    def test_park_requires_note(self):
        code, body = self.post("operator-item/park", {"id": "deadbeef"})
        self.assertEqual(code, 400)
        self.assertEqual(body.get("ok"), False)
        self.assertEqual(self.rows(), [])
        self.assertEqual(json.loads(self.dismissed.read_text()), {})
        code, _ = self.post("operator-item/park", {"id": "deadbeef",
                                                   "note": "   "})
        self.assertEqual(code, 400)
        self.assertEqual(self.rows(), [])

    def test_park_with_note_dismisses_ledger(self):
        code, body = self.post("operator-item/park",
                               {"id": "deadbeef", "note": "watch after 7"})
        self.assertEqual((code, body.get("ok")), (201, True))
        self.assertIn("deadbeef",
                      json.loads(self.dismissed.read_text())["dismissed"])
        rows = self.rows()
        self.assertEqual(len(rows), 1)
        self.assertIn("'operator-item:deadbeef:parked'", rows[0])
        self.assertIn("watch after 7", rows[0])
        self.assertIn("operator-park | ", self.handoffs.read_text())

    def test_expire_and_suppress_dismiss_ledger(self):
        for verb in ("expire", "suppress"):
            code, body = self.post("operator-item/" + verb,
                                   {"id": "deadbee" + verb[0]})
            self.assertEqual((code, body.get("ok")), (201, True))
        led = json.loads(self.dismissed.read_text())["dismissed"]
        self.assertIn("deadbeee", led)
        self.assertIn("deadbees", led)
        rows = self.rows()
        self.assertEqual(len(rows), 2)
        self.assertIn("'operator-item:deadbeee:expired'", rows[0])
        self.assertIn("'operator-item:deadbees:suppressed'", rows[1])
        self.assertIn("operator-expire | ", self.handoffs.read_text())
        self.assertIn("operator-suppress | ", self.handoffs.read_text())

    def test_acknowledge_optional_note_approved_ledger(self):
        code, body = self.post("operator-item/acknowledge",
                               {"id": "deadbeef"})
        self.assertEqual((code, body.get("ok")), (201, True))
        self.assertIn("deadbeef",
                      json.loads(self.approved.read_text())["approved"])
        rows = self.rows()
        self.assertEqual(len(rows), 1)
        self.assertIn("'operator-item:deadbeef:acknowledged'", rows[0])
        code, body = self.post("operator-item/acknowledge",
                               {"id": "cafebabe", "note": "seen"})
        self.assertEqual((code, body.get("ok")), (201, True))
        self.assertIn("seen", self.rows()[1])

    def test_new_verb_fails_closed_without_row(self):
        os.environ["HNGH_STUB_RQ_RC"] = "1"
        code, body = self.post("operator-item/expire", {"id": "deadbeef"})
        self.assertEqual((code, body.get("ok")), (500, False))
        self.assertEqual(json.loads(self.dismissed.read_text()), {})
        self.assertNotIn("operator-expire",
                         self.handoffs.read_text()
                         if self.handoffs.exists() else "")


class DunderGuard(Lifecycle):
    """Dunder ids ('__...' sentinels) are refused 400 on EVERY
    /operator-item/* verb (INT-28) and never touch rows or ledgers."""

    def test_dunder_refused_on_all_six(self):
        verbs = ("handle", "dismiss", "park", "expire", "suppress",
                 "acknowledge")
        for verb in verbs:
            payload = {"id": "__smoke__"}
            if verb == "park":
                payload["note"] = "x"
            code, body = self.post("operator-item/" + verb, payload)
            self.assertEqual((code, body.get("ok")), (400, False), verb)
            self.assertEqual(code, 400, verb)
        self.assertEqual(self.rows(), [])
        self.assertEqual(json.loads(self.dismissed.read_text()), {})
        self.assertEqual(json.loads(self.approved.read_text())
                         if self.approved.exists() else {}, {})
        self.assertEqual(self.handoffs.read_text()
                         if self.handoffs.exists() else "", "")





class Desk(Lifecycle):
    """The Installation Desk: /desk-state.json assembly (stubbed probes,
    fail closed), /desk/stage-authz filing, and the gated
    /desk/run-phase-1 chain. The privileged channel is a stub script;
    no test ever installs a package or runs sudo for real."""

    MANIFEST_TEXT = (
        "# test manifest\n"
        "hyprland\n"
        "foot # aur\n"
        "grim\n")

    def setUp(self):
        super().setUp()
        base = Path(self.tmp.name)
        self.probe_calls = []
        self.installed = set()
        self.clone = base / "omarchy-upstream"
        (self.clone / ".git").mkdir(parents=True)
        self.manifest = base / "omarchy-base.packages"
        self.manifest.write_text(self.MANIFEST_TEXT)
        self.priv_log = base / "priv.log"
        priv = base / "stub-privileged.sh"
        priv.write_text(STUB_PRIV)
        priv.chmod(0o755)
        self.old_attrs = {}
        for name, val in (("OMARCHY_UPSTREAM", str(self.clone)),
                          ("MANIFEST", str(self.manifest)),
                          ("PRIVILEGED_SH", str(priv)),
                          ("DRIFT_JOB", str(base / "absent-drift.py")),
                          ("WICKET_SUDOERS_EXAMPLE",
                           str(base / "absent-sudoers.example")),
                          ("DASHBOARD", str(base / "dashboard"))):
            self.old_attrs[name] = getattr(ds, name)
            setattr(ds, name, val)
        self.old_run_ro = ds._run_ro
        self.old_probe_wicket = ds._desk_probe_wicket
        ds._run_ro = self._fake_run
        self.wicket_armed = (False, "sudo: a password is required")
        ds._desk_probe_wicket = lambda: self.wicket_armed
        self._old_priv_env = {k: os.environ.get(k) for k in
                              ("HNGH_STUB_PRIV_LOG", "HNGH_STUB_PRIV_RC")}
        os.environ["HNGH_STUB_PRIV_LOG"] = str(self.priv_log)
        os.environ.pop("HNGH_STUB_PRIV_RC", None)
        self.addCleanup(self._desk_teardown)

    def _desk_teardown(self):
        ds._run_ro = self.old_run_ro
        ds._desk_probe_wicket = self.old_probe_wicket
        for name, val in self.old_attrs.items():
            setattr(ds, name, val)
        for key, val in self._old_priv_env.items():
            if val is None:
                os.environ.pop(key, None)
            else:
                os.environ[key] = val

    def _fake_run(self, argv, timeout=15):
        self.probe_calls.append(list(argv))
        exe = argv[0]
        if exe == "git":
            return _Result(0, "abc1234\n", "")
        if exe == "pacman":
            return _Result(0 if argv[2] in self.installed else 1, "", "")
        if exe == "sudo":
            return _Result(1, "", "sudo: a password is required\n")
        if exe == "python3":
            return _Result(0, '{"drift": [], "ok": true}', "")
        return _Result(1, "", "unexpected probe %r" % (argv,))

    def reset_cache(self):
        ds._desk_cache = (0.0, None)

    def get(self, route):
        try:
            with urllib.request.urlopen(
                    "http://127.0.0.1:%d/%s" % (self.port, route),
                    timeout=5) as r:
                return r.status, r.read().decode()
        except urllib.error.HTTPError as e:
            return e.code, e.read().decode()

    def get_json(self, route):
        code, text = self.get(route)
        return code, json.loads(text)

    def approve(self):
        self.approved.write_text(json.dumps(
            {"approved": {"desk-authz:phase-1": "2026-09-27T00:00:00Z"}}))

    def priv_calls(self):
        if not self.priv_log.exists():
            return []
        return [ln for ln in self.priv_log.read_text().splitlines() if ln]

    # ---- desk page ---------------------------------------------------------
    def test_desk_page_served_with_token_meta(self):
        shutil.copy2(os.path.join(ROOT, "dashboard", "desk.html"),
                     Path(self.tmp.name) / "dashboard" / "desk.html")
        code, text = self.get("desk.html")
        self.assertEqual(code, 200)
        self.assertIn('meta name="hngh-token"', text)
        self.assertIn("THE INSTALLATION", text)

    # ---- desk-state assembly -----------------------------------------------
    def test_desk_state_shape_and_fail_closed_defaults(self):
        self.reset_cache()
        code, st = self.get_json("desk-state.json")
        self.assertEqual(code, 200)
        self.assertEqual(st["clone"], {"present": True, "ref": "abc1234"})
        self.assertTrue(st["manifest"]["present"])
        self.assertEqual(st["manifest"]["count"], 3)
        self.assertEqual(st["manifest"]["aur_count"], 1)
        self.assertEqual(st["manifest"]["pkgs"],
                         [{"name": "hyprland", "installed": False},
                          {"name": "foot", "installed": False},
                          {"name": "grim", "installed": False}])
        self.assertFalse(st["wicket"]["armed"])
        self.assertEqual(st["wicket"]["reason"],
                         "sudo: a password is required")
        self.assertIsNone(st["drift"])
        self.assertEqual(st["approvals"], {"desk-authz:phase-1": False})
        self.assertFalse(st["phase1_ready"])
        self.assertRegex(st["generated"], r"^\d{4}-\d{2}-\d{2}T")

    def test_desk_state_installed_mapping_and_ready(self):
        self.installed.update(("hyprland", "grim"))
        self.approve()
        self.reset_cache()
        code, st = self.get_json("desk-state.json")
        self.assertEqual(code, 200)
        self.assertEqual([p["installed"] for p in st["manifest"]["pkgs"]],
                         [True, False, True])
        self.assertTrue(st["phase1_ready"])
        self.assertEqual(st["approvals"], {"desk-authz:phase-1": True})

    def test_desk_state_cached_within_window(self):
        self.reset_cache()
        _, first = self.get_json("desk-state.json")
        self.installed.add("hyprland")  # cache must hide the flip
        _, second = self.get_json("desk-state.json")
        self.assertEqual(first["generated"], second["generated"])
        self.assertEqual(second["manifest"]["pkgs"][0]["installed"], False)

    def test_desk_state_drift_passthrough(self):
        drift_job = Path(self.tmp.name) / "drift.py"
        drift_job.write_text("# stub")
        ds.DRIFT_JOB = str(drift_job)
        old = ds._run_ro

        def drift_run(argv, timeout=15):
            if any("drift.py" in a for a in argv):
                return _Result(0, '{"drift": [{"n": 1}, {"n": 2}],'
                                  ' "ok": false}', "")
            return self._fake_run(argv, timeout=timeout)

        ds._run_ro = drift_run
        self.reset_cache()
        try:
            _, st = self.get_json("desk-state.json")
        finally:
            ds._run_ro = old
        self.assertEqual(st["drift"], {"ok": False, "count": 2})

    # ---- stage-authz ---------------------------------------------------------
    def test_stage_authz_files_row_and_handoff(self):
        code, body = self.post("desk/stage-authz", {"phase": "1"})
        self.assertEqual((code, body.get("ok")), (201, True))
        self.assertEqual(body.get("identity"), "desk-authz:phase-1")
        rows = self.rows()
        self.assertEqual(len(rows), 1)
        self.assertIn("'alert'", rows[0])
        self.assertIn("'desk-authz:phase-1'", rows[0])
        self.assertIn("'--window'", rows[0])
        self.assertIn("desk-stage-authz | ", self.handoffs.read_text())

    def test_stage_authz_refuses_other_phases(self):
        code, body = self.post("desk/stage-authz", {"phase": "2"})
        self.assertEqual((code, body.get("ok")), (400, False))
        self.assertEqual(self.rows(), [])

    def test_stage_authz_fails_closed_on_rq_refusal(self):
        os.environ["HNGH_STUB_RQ_RC"] = "1"
        code, body = self.post("desk/stage-authz", {"phase": "1"})
        self.assertEqual((code, body.get("ok")), (500, False))
        self.assertFalse(self.handoffs.exists())

    # ---- run-phase-1 gate chain -----------------------------------------------
    def test_run_phase1_unapproved_409(self):
        code, body = self.post("desk/run-phase-1", {})
        self.assertEqual((code, body.get("ok")), (409, False))
        self.assertIn("Stage authorization", body["remediation"])
        self.assertIn("desk-authz:phase-1", body["remediation"])
        self.assertEqual(self.probe_calls, [])
        self.assertEqual(self.priv_calls(), [])

    def test_run_phase1_approved_but_unarmed_409(self):
        self.approve()
        code, body = self.post("desk/run-phase-1", {})
        self.assertEqual((code, body.get("ok")), (409, False))
        self.assertIn("wicket not armed", body["error"])
        self.assertIn("sudo install", body["remediation"])
        self.assertEqual(self.priv_calls(), [])

    def test_run_phase1_missing_clone_409(self):
        self.approve()
        self.wicket_armed = (True, "")
        ghost = Path(self.tmp.name) / "not-a-clone"
        ds.OMARCHY_UPSTREAM = str(ghost)
        code, body = self.post("desk/run-phase-1", {})
        self.assertEqual((code, body.get("ok")), (409, False))
        self.assertIn(str(ghost), body["remediation"])

    def test_run_phase1_missing_manifest_409(self):
        self.approve()
        self.wicket_armed = (True, "")
        ds.MANIFEST = str(Path(self.tmp.name) / "absent.packages")
        code, body = self.post("desk/run-phase-1", {})
        self.assertEqual(code, 409)
        self.assertIn("absent.packages", body["remediation"])

    def test_run_phase1_happy_path_runs_stub(self):
        self.approve()
        self.wicket_armed = (True, "")
        code, body = self.post("desk/run-phase-1", {})
        self.assertEqual((code, body.get("rc")), (201, 0))
        self.assertTrue(body.get("ok"))
        self.assertEqual(self.priv_calls(), ["wicket install-base"])
        self.assertIn("line-one", body["tail"])
        self.assertIn("desk-phase-1 | ", self.handoffs.read_text())

    def test_run_phase1_stub_failure_502(self):
        self.approve()
        self.wicket_armed = (True, "")
        os.environ["HNGH_STUB_PRIV_RC"] = "2"
        code, body = self.post("desk/run-phase-1", {})
        self.assertEqual((code, body.get("ok"), body.get("rc")),
                         (502, False, 2))
        self.assertIn("stderr-line", body["tail"])

    def test_desk_posts_need_token(self):
        for route in ("desk/stage-authz", "desk/run-phase-1"):
            code, _ = self.post(route, {"phase": "1"}, token=False)
            self.assertEqual(code, 403, route)
        self.assertEqual(self.rows(), [])
        self.assertEqual(self.priv_calls(), [])


class DeskAur(Desk):
    """POST /desk/run-aur: the gated user-session AUR lane. The job is
    a stub script; no test builds a package, touches the network, or
    runs pacman for real."""

    AUR_NAMES = ("foot",)

    def setUp(self):
        super().setUp()
        self.aur_log = Path(self.tmp.name) / "aur.log"
        stub = Path(self.tmp.name) / "stub-aur-build.sh"
        stub.write_text(STUB_AUR)
        stub.chmod(0o755)
        self.old_attrs["AUR_BUILD_SH"] = ds.AUR_BUILD_SH
        ds.AUR_BUILD_SH = str(stub)
        # AUR_PKGS parsed from the stubbed manifest by the same helper
        # the server uses at import (env OMARCHY_MANIFEST-or-default).
        self.old_attrs["AUR_PKGS"] = ds.AUR_PKGS
        ds.AUR_PKGS = frozenset(ds._aur_manifest_names(str(self.manifest)))
        self._old_aur_env = {k: os.environ.get(k) for k in
                             ("HNGH_STUB_AUR_LOG", "HNGH_STUB_AUR_RC")}
        os.environ["HNGH_STUB_AUR_LOG"] = str(self.aur_log)
        os.environ.pop("HNGH_STUB_AUR_RC", None)
        self.addCleanup(self._aur_teardown)

    def _aur_teardown(self):
        ds._aur_running = False
        for key, val in self._old_aur_env.items():
            if val is None:
                os.environ.pop(key, None)
            else:
                os.environ[key] = val

    def aur_calls(self):
        if not self.aur_log.exists():
            return []
        return [ln for ln in self.aur_log.read_text().splitlines() if ln]

    def arm(self):
        self.approve()
        self.wicket_armed = (True, "")

    # ---- manifest parse -------------------------------------------------
    def test_aur_names_parsed_from_real_manifest(self):
        real = os.path.join(ROOT, "config", "omarchy-base.packages")
        self.assertEqual(ds._aur_manifest_names(real),
                         [])

    def test_aur_pkgs_env_override(self):
        mf = Path(self.tmp.name) / "override.packages"
        mf.write_text("# lead\nbare\nfoo # aur\n# nope # aur\n")
        code = ("import importlib.util, json"
                ";spec = importlib.util.spec_from_file_location('m', %r)"
                ";m = importlib.util.module_from_spec(spec)"
                ";spec.loader.exec_module(m)"
                ";print(json.dumps(sorted(m.AUR_PKGS)))" % DS_PATH)
        p = subprocess.run([sys.executable, "-B", "-c", code],
                           env=dict(os.environ, OMARCHY_MANIFEST=str(mf)),
                           capture_output=True, text=True, timeout=30)
        self.assertEqual(p.returncode, 0, p.stderr)
        self.assertEqual(json.loads(p.stdout), ["foo"])

    # ---- desk-state -----------------------------------------------------
    def test_desk_state_lists_aur_pkgs_and_running(self):
        self.reset_cache()
        _, st = self.get_json("desk-state.json")
        self.assertEqual(st["aur"], {"pkgs": ["foot"], "running": False})
        ds._aur_running = True
        try:
            self.reset_cache()
            _, st = self.get_json("desk-state.json")
        finally:
            ds._aur_running = False
        self.assertTrue(st["aur"]["running"])

    # ---- run-aur gate chain ----------------------------------------------
    def test_run_aur_needs_token(self):
        code, _ = self.post("desk/run-aur", {"pkg": "foot"}, token=False)
        self.assertEqual(code, 403)
        self.assertEqual(self.aur_calls(), [])

    def test_run_aur_bad_body_400(self):
        for body in ({}, {"pkg": ""}, {"pkg": 5}, ["foot"]):
            code, out = self.post("desk/run-aur", body)
            self.assertEqual(code, 400, body)
            self.assertFalse(out.get("ok"), body)
        self.assertEqual(self.aur_calls(), [])

    def test_run_aur_unknown_pkg_400_known_list(self):
        code, body = self.post("desk/run-aur", {"pkg": "not-in-manifest"})
        self.assertEqual(code, 400)
        self.assertEqual(body.get("error"), "unknown aur package")
        self.assertEqual(body.get("known"), list(self.AUR_NAMES))
        self.assertEqual(self.aur_calls(), [])

    def test_run_aur_unapproved_409(self):
        code, body = self.post("desk/run-aur", {"pkg": "foot"})
        self.assertEqual((code, body.get("ok")), (409, False))
        self.assertEqual(body.get("error"), "phase 1 not authorized")
        self.assertIn("Stage authorization", body["remediation"])
        self.assertIn("desk-authz:phase-1", body["remediation"])
        self.assertEqual(self.aur_calls(), [])

    def test_run_aur_unarmed_409(self):
        self.approve()
        code, body = self.post("desk/run-aur", {"pkg": "foot"})
        self.assertEqual((code, body.get("ok")), (409, False))
        self.assertIn("wicket not armed", body["error"])
        self.assertIn("sudo install", body["remediation"])
        self.assertEqual(self.aur_calls(), [])

    def test_run_aur_happy_201_follow_up_extracted(self):
        self.arm()
        code, body = self.post("desk/run-aur", {"pkg": "foot"})
        self.assertEqual(code, 201)
        self.assertTrue(body.get("ok"))
        self.assertEqual(body.get("pkg"), "foot")
        self.assertIn("line-one", body["tail"])
        self.assertEqual(body.get("follow_up"),
                         "aur-build: follow-up: stub-privileged.sh wicket"
                         " install-file owe-1.0.0-1-any.pkg.tar.zst")
        self.assertEqual(self.aur_calls(), ["foot"])
        self.assertFalse(ds._aur_running)

    def test_run_aur_stub_failure_502(self):
        self.arm()
        os.environ["HNGH_STUB_AUR_RC"] = "4"
        code, body = self.post("desk/run-aur", {"pkg": "foot"})
        self.assertEqual((code, body.get("ok"), body.get("rc")),
                         (502, False, 4))
        self.assertIn("line-one", body["tail"])
        self.assertIsNone(body.get("follow_up"))
        self.assertFalse(ds._aur_running)

    def test_run_aur_in_flight_409(self):
        self.arm()
        ds._aur_running = True
        try:
            code, body = self.post("desk/run-aur", {"pkg": "foot"})
        finally:
            ds._aur_running = False
        self.assertEqual((code, body.get("ok")), (409, False))
        self.assertEqual(self.aur_calls(), [])

    # ---- regression: the phase-1 lanes behave unchanged ------------------
    def test_phase1_and_stage_authz_unchanged_alongside_aur(self):
        code, body = self.post("desk/stage-authz", {"phase": "1"})
        self.assertEqual((code, body.get("ok")), (201, True))
        self.assertEqual(body.get("identity"), "desk-authz:phase-1")
        self.arm()
        code, body = self.post("desk/run-phase-1", {})
        self.assertEqual((code, body.get("rc")), (201, 0))
        self.assertEqual(self.priv_calls(), ["wicket install-base"])
        self.assertEqual(self.aur_calls(), [])


class _Result:
    """Stand-in for a CompletedProcess (no subprocess in the probes)."""

    def __init__(self, returncode, stdout, stderr):
        self.returncode = returncode
        self.stdout = stdout
        self.stderr = stderr


if __name__ == "__main__":
    unittest.main(verbosity=2)
