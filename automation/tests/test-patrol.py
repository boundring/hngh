#!/usr/bin/env python3
"""patrol runner, hermetic (the formal rounds, 2026-09-12): each check's
PASS/FAIL against fixtures -- a fresh healthy ledger is quiet, 3
consecutive failed crumbs fire the stall check, a missing daily digest
fires the paper check, an active blocker at/over the threshold fires
the blocker check; the runner refuses an unknown patrol id (exit 2) and
fails open on a check crash (FAIL check-crash, the walk continues); a
patrol+cause repeating on two consecutive runs auto-queues a
research-subjects entry. No real report-queue, no real ledgers --
sandbox dirs only, wired by PATROL_* env (the beat-watchdog test
convention)."""

import importlib.util
import json
import os
import subprocess
import sys
import tempfile
import time
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SPEC = ROOT / "jobs" / "patrol.py"
REPO = ROOT.parent  # the hngh repo (real routes + quips are copied from here)
NOW = time.mktime(time.strptime("2026-09-12T10:00:00Z",
                                "%Y-%m-%dT%H:%M:%SZ")) - time.timezone


def iso(ago_s):
    return time.strftime("%Y-%m-%dT%H:%M:%SZ",
                         time.gmtime(NOW - ago_s))


GREEN_CRUMB = "%s | overnight-cycle.sh | overnight-done | sessions=1 " \
    "concurrency=1 speed=3 results=ok model=m(env)\n" % iso(30 * 60)


def load_mod():
    spec = importlib.util.spec_from_file_location("patrol_mod", SPEC)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


class Patrol(unittest.TestCase):
    def setUp(self):
        self._td = tempfile.TemporaryDirectory()
        self.sb = Path(self._td.name)
        self.auto = self.sb / "automation"
        self.kernel = self.sb / "kernel"
        for d in ("dashboard", "digest", "logs", "state", "config", "lib"):
            (self.auto / d).mkdir(parents=True, exist_ok=True)
        (self.kernel / "tests" / "scripts").mkdir(parents=True)
        # healthy fixture: everything green and fresh
        (self.auto / "cadence-params.tsv").write_text(
            "beat-stall-n\t3\tx\nblocker-escalate-n\t2\tx\n"
            "sessions-day-max\t200\tx\n")
        (self.auto / "STATE.md").write_text(
            GREEN_CRUMB +
            "%s | 03-gate-check.sh | gate-green | hngh-automation: "
            "make test green (200 checks passed)\n" % iso(3600))
        (self.auto / "agent-handoffs.md").write_text(
            "overnight-lead | %s | plan-a|run-1 | rc=0 committed step=1 ok\n"
            % iso(60 * 60))
        (self.auto / "state" / "beat-blockers.tsv").write_text(
            "blk-1\tplan-b\tunknown\t%s\t1\tactive\t%s\n" % (iso(7200), iso(7200)))
        (self.auto / "research-lines.tsv").write_text(
            "some-line\tplanned\t%s\tnote\n" % iso(3600))
        (self.auto / "logs" / "budget.md").write_text("")
        (self.auto / "research-subjects.txt").write_text("")
        for name in ("plans.json", "operator-items.json", "sessions.json"):
            (self.auto / "dashboard" / name).write_text("{}")
        (self.auto / "digest" / "2026-09-12.md").write_text(
            "## 0100 2026-09-12\n- NOTABLE: test item (https://e.com)\n")
        (self.auto / "config" / "hngh-services.tsv").write_text("")
        (self.auto / "dashboard" / "feedback" / "processed").mkdir(
            parents=True, exist_ok=True)
        (self.auto / "config" / "hngh-packages.tsv").write_text(
            "package\tupstream\trole\tinstall-path\tconfig\tupdate\tfeed\t"
            "disposition\nomp\tu\tr\t/usr/bin/env\tc\tu\tf\tin-use\n")
        manga = self.sb / "docs" / "media" / "manga" / "sample"
        manga.mkdir(parents=True)
        (manga / "sample-draft.json").write_text("{}")
        (self.auto / "logs" / "notify-email.log").write_text("")
        (self.auto / "research-dispositions.tsv").write_text(
            "line\taction\tverdict\treviewer\tevidence\tdate\n"
            "some-line\tadopted\tadopted -- fine\tm\te\t%s\n" % iso(3600))
        (self.auto / "config" / "patrol-routes.tsv").write_text(
            (REPO / "automation" / "config" / "patrol-routes.tsv").read_text())
        (self.auto / "lib" / "quips.py").write_text(
            (REPO / "automation" / "lib" / "quips.py").read_text())
        (self.kernel / "tests" / "scripts"
         / "test-loop-history-guard.py").write_text(
            "print('loop-history guard: 93 commits, 0 violations')\n")
        (self.sb / "rq-stub.sh").write_text(
            "#!/usr/bin/env bash\nprintf '%s\\n' \"$*\" >>\"$PATROL_ALERTS\"\n")
        (self.sb / "rq-stub.sh").chmod(0o755)
        (self.sb / "alerts.tsv").write_text("")
        # hermetic systemd: stub ctl backed by a per-unit state table
        (self.sb / "systemctl-stub.sh").write_text(
            "#!/usr/bin/env bash\n"
            "unit=\"$3\"; [ -n \"$unit\" ] || exit 2\n"
            "case \"$2\" in is-enabled) f=enabled ;; is-active) f=active ;; "
            "*) exit 2 ;; esac\n"
            "val=$(awk -F'\\t' -v u=\"$unit\" -v f=\"$f\" "
            "'$1==u && $2==f {print $3}' \"$SYSTEMD_STUB_STATE\")\n"
            "if [ \"$val\" = ok ]; then echo \"$f\"; exit 0; "
            "else echo bad; exit 1; fi\n")
        (self.sb / "systemctl-stub.sh").chmod(0o755)
        (self.sb / "systemd-state.tsv").write_text(
            "".join("%s\t%s\tok\n" % (u, f)
                    for u in ("hngh-automation.timer",
                              "hngh-cadence-1m.timer",
                              "hngh-cadence-5m.timer",
                              "hngh-overnight.timer")
                    for f in ("enabled", "active")))
        for k, v in [("PATROL_ROOT", str(self.auto)),
                     ("HNGH_HOME_DIR", str(self.sb / "home")),
                     ("PATROL_DIGEST_DIR", str(self.auto / "digest")),
                     ("PATROL_KERNEL", str(self.kernel)),
                     ("PATROL_ROUTES", str(self.auto / "config" / "patrol-routes.tsv")),
                     ("PATROL_SUBJECTS", str(self.auto / "research-subjects.txt")),
                     ("PATROL_NOW_EPOCH", str(NOW)),
                     ("REPORT_QUEUE_BIN", str(self.sb / "rq-stub.sh")),
                     ("PATROL_REPORT_ROOT", str(self.sb)),
                     ("PATROL_ALERTS", str(self.sb / "alerts.tsv"))]:
            os.environ[k] = v
        os.environ["PATROL_SYSTEMCTL"] = str(self.sb / "systemctl-stub.sh")
        os.environ["SYSTEMD_STUB_STATE"] = str(self.sb / "systemd-state.tsv")
        # hermetic public-CI patrol: the check polls this file:// fixture,
        # not the real api.github.com (the systemd-stub convention)
        self._ci_runs("completed", "success")
        self._mod = load_mod()

    def tearDown(self):
        self._td.cleanup()

    def run_py(self, *argv):
        return subprocess.run([sys.executable, str(SPEC), *argv],
                              capture_output=True, text=True)

    def run_walk(self):
        """Subprocess walk -> (rc, stdout, alert argv lines)."""
        r = self.run_py("--tier", "30m")
        self.assertEqual(r.returncode, 0, r.stderr)
        return r, (self.sb / "alerts.tsv").read_text().splitlines()

    def _ci_runs(self, status, conclusion=None):
        runs = {"workflow_runs": [{
            "status": status, "conclusion": conclusion,
            "head_sha": "9faf25a" + "0" * 33, "name": "CI",
            "html_url": "https://github.com/boundring/hngh/actions/runs/1",
        }]}
        path = self.sb / "ci-runs.json"
        path.write_text(json.dumps(runs))
        os.environ["HNGH_GH_CI_RUNS_URL"] = "file://" + str(path)

    def _red_guard(self, subjects):
        """A kernel guard fixture that reports violations and exits 1,
        carrying a KNOWN_EXEMPTIONS table the cure can append to."""
        lines = ["#!/usr/bin/env python3",
                 "KNOWN_EXEMPTIONS = {",
                 "    \"seed123\": {",
                 "        \"reason\": \"seed\",",
                 "        \"patch-id\": \"%s\","
                 % ("0" * 40),
                 "    },",
                 "}",
                 "print('loop-history guard: %d violation(s):')"
                 % len(subjects)]
        for s in subjects:
            lines.append("print('  %s')" % s)
        lines.append("raise SystemExit(1)")
        (self.kernel / "tests" / "scripts"
         / "test-loop-history-guard.py").write_text("\n".join(lines) + "\n")

    # --- (1) a fresh healthy ledger is quiet ---
    def test_healthy_ledger_is_quiet(self):
        r, alerts = self.run_walk()
        self.assertEqual([ln for ln in r.stdout.splitlines()
                          if ln.startswith("FAIL")], [])
        self.assertEqual(alerts, [])
        # feeds emits 3 PASSes (one per feed), the other 7 routes one each
        # (gate-cure's green-gate PASS included); systemd-units adds 1
        # systemd-units emits one PASS per unit (4), not one per route;
        # github-ci adds 1 (the latest-run verdict)
        self.assertEqual(r.stdout.count("\nPASS "), 15)

    # --- (2) a stale feed fires the feeds check + files an alert ---
    def test_stale_feed_fails_and_files_alert(self):
        p = self.auto / "dashboard" / "sessions.json"
        os.utime(p, (NOW - 7000, NOW - 7000))
        r, alerts = self.run_walk()
        self.assertIn("FAIL feeds/dashboard/sessions.json feed-stale "
                      "age=7000s > 600s", r.stdout)
        self.assertTrue(any("patrol feeds:" in a for a in alerts))

    # --- (3) 3 consecutive failed crumbs fire the stall check ---
    def test_three_failed_crumbs_fire_stall(self):
        state = self.auto / "STATE.md"
        state.write_text("\n".join(
            "%s | overnight-cycle.sh | overnight-done | sessions=1 "
            "concurrency=1 speed=3 results=failed model=m(env)" % iso(ago)
            for ago in (50 * 60, 7 * 3600, 11 * 3600)) + "\n")
        r, _ = self.run_walk()
        self.assertIn("FAIL stall/overnight bad-execution "
                      "trailing failed crumbs=3 >= 3", r.stdout)

    # --- (4) a missing daily digest fires the paper check ---
    def test_missing_digest_fires_paper(self):
        (self.auto / "digest" / "2026-09-12.md").unlink()
        r = self.run_py("--tier", "day")
        self.assertEqual(r.returncode, 0)
        self.assertIn("FAIL paper/2026-09-12.md digest-missing", r.stdout)

    # --- (5) an active blocker at/over the threshold fires the ledger check ---
    def test_escalated_blocker_fails(self):
        (self.auto / "state" / "beat-blockers.tsv").write_text(
            "blk-1\tplan-c\tunknown\t%s\t2\tactive\t%s\n"
            % (iso(7200), iso(7200)))
        r, _ = self.run_walk()
        self.assertIn("FAIL blockers/plan-c blocker-escalated "
                      "attempts=2 >= 2, not yet parked", r.stdout)

    # --- (6) an unknown patrol id is a usage error (exit 2) ---
    def test_unknown_patrol_id_exits_two(self):
        r = self.run_py("--patrol", "no-such-patrol")
        self.assertEqual(r.returncode, 2)
        self.assertIn("unknown patrol id", r.stderr)

    # --- (7) fail-open on a check crash: FAIL check-crash, walk continues ---
    def test_check_crash_fails_open(self):
        def boom(_ctx):
            raise RuntimeError("boom")
        self._mod.CHECKS["feed-freshness"] = boom
        results, rc = self._mod.run(tier="30m", now_s=NOW)
        self.assertEqual(rc, 0)
        res = results[0]
        self.assertEqual(res["fails"],
                         [("dashboard-feeds", "check-crash",
                           repr(RuntimeError("boom")))])
        self.assertEqual(len(results), 11)  # the walk continued

    # --- gate-cure: a green gate is quiet, no ceremony is driven ---
    def test_gate_cure_green_quiet(self):
        r = self._mod.check_gate_cure({"kernel": str(self.kernel),
                                       "date": "2026-09-12"})
        self.assertEqual(r["fails"], [])
        self.assertEqual(r["passes"], [("gate-cure", "gate green")])

    # --- gate-cure: a red gate declares and drives the ceremony ---
    def test_gate_red_fires_ceremony(self):
        self._red_guard(["ba6b390 fixture",
                         "d2d8f51 Revert \"fixture\""])
        (self.kernel / "docs" / "project").mkdir(parents=True)
        (self.kernel / "docs" / "project" / "decisions.md").write_text(
            "# Decisions\n")
        log = self.sb / "cure-log.tsv"
        stub = self.sb / "cure-stub.sh"
        stub.write_text("#!/usr/bin/env bash\n"
                        "printf '%%s\\n' \"$*\" >>\"%s\"\n"
                        % (log))
        stub.chmod(0o755)
        os.environ["PATROL_CEREMONY_BIN"] = str(stub)
        self.addCleanup(os.environ.pop, "PATROL_CEREMONY_BIN", None)
        self._mod.patch_id = lambda kernel, sha: "p" * 40
        self._mod.commit_subject = lambda kernel, sha: "fixture"
        r = self._mod.check_gate_cure({"kernel": str(self.kernel),
                                       "date": "2026-09-12"})
        self.assertEqual(r["fails"], [])
        self.assertTrue(r["passes"][0][1].startswith("declared ba6b390"))
        # the guard table carries both declared entries + patch-id
        guard = (self.kernel / "tests" / "scripts"
                 / "test-loop-history-guard.py").read_text()
        self.assertIn('"ba6b390"', guard)
        self.assertIn('"d2d8f51"', guard)
        self.assertIn("p" * 40, guard)
        self.assertIn("declared miss, gate-cure patrol", guard)
        # decisions.md carries the dated auto-entry
        dec = (self.kernel / "docs" / "project" / "decisions.md").read_text()
        self.assertIn("## 2026-09-12 — Kernel-gate red declared post-hoc",
                      dec)
        # the ceremony was driven once with objective + both files
        args = log.read_text().splitlines()
        self.assertEqual(len(args), 1)
        self.assertIn("declare kernel-gate violations post-hoc", args[0])
        self.assertIn("test-loop-history-guard.py", args[0])
        self.assertIn("decisions.md", args[0])

    # --- gate-cure: a ceremony refusal parks (the LARGE boundary) ---
    def test_cure_refusal_fails(self):
        self._red_guard(["ba6b390 fixture"])
        (self.kernel / "docs" / "project").mkdir(parents=True)
        (self.kernel / "docs" / "project" / "decisions.md").write_text(
            "# Decisions\n")
        stub = self.sb / "cure-stub.sh"
        stub.write_text("#!/usr/bin/env bash\n"
                        "echo 'refused: LARGE-surface content'\n"
                        "exit 1\n")
        stub.chmod(0o755)
        os.environ["PATROL_CEREMONY_BIN"] = str(stub)
        self.addCleanup(os.environ.pop, "PATROL_CEREMONY_BIN", None)
        self._mod.patch_id = lambda kernel, sha: "p" * 40
        self._mod.commit_subject = lambda kernel, sha: "fixture"
        r = self._mod.check_gate_cure({"kernel": str(self.kernel),
                                       "date": "2026-09-12"})
        self.assertEqual(r["passes"], [])
        self.assertEqual(r["fails"],
                         [("kernel", "gate-cure-refused",
                           "ceremony-drive rc=1: "
                           "refused: LARGE-surface content")])

    # --- (8) a runner crash files one alert and exits 0 ---
    def test_runner_crash_suppressed_exit_zero(self):
        os.environ["PATROL_ROUTES"] = "/no-such/patrol-routes.tsv"
        r = self.run_py("--all")
        self.assertEqual(r.returncode, 0)
        alerts = (self.sb / "alerts.tsv").read_text()
        self.assertIn("patrol runner crashed", alerts)

    # --- (9) same patrol+cause on two consecutive runs queues a subject ---
    def test_repeat_cause_queues_research_subject(self):
        prev = ("## %s run\n\n### Adversarial pass\n\n"
                "- FAIL feeds/dashboard/sessions.json: feed-stale -- "
                "age=7000s > 600s\n")
        (self.auto / "digest" / "PATROL-2026-09-11.md").write_text(
            prev % iso(3600).replace("2026-09-12", "2026-09-11"))
        p = self.auto / "dashboard" / "sessions.json"
        os.utime(p, (NOW - 7000, NOW - 7000))
        r = self.run_py("--tier", "30m")
        self.assertEqual(r.returncode, 0)
        rid = "patrol-20260912-feeds-feed-stale"
        self.assertIn(rid, r.stdout)
        subjects = self.auto / "research-subjects.txt"
        first = subjects.read_text().splitlines()
        self.assertEqual(len(first), 1)
        self.assertTrue(first[0].startswith(rid + "\t"))
        # re-run: the rid is already queued, never duplicated
        self.run_py("--tier", "30m")
        self.assertEqual(len(subjects.read_text().splitlines()), 1)

    # --- (10) a >20 unprocessed feedback backlog fires the flood check ---
    def test_feedback_flood_fails(self):
        fb = self.auto / "dashboard" / "feedback"
        for i in range(21):
            (fb / ("fb-%d.json" % i)).write_text("{}")
        r, _ = self.run_walk()
        self.assertIn("FAIL feedback/feedback feedback-flood "
                      "21 unprocessed > 20", r.stdout)

    # --- (11) a missing processed/ sink fires the feedback check ---
    def test_feedback_processed_missing_fails(self):
        (self.auto / "dashboard" / "feedback" / "processed").rmdir()
        r, _ = self.run_walk()
        self.assertIn("FAIL feedback/feedback/processed processed-missing",
                      r.stdout)

    # --- (12) a stale manga draft fires the manga check ---
    def test_manga_stale_fails(self):
        p = (self.sb / "docs" / "media" / "manga" / "sample"
             / "sample-draft.json")
        os.utime(p, (NOW - 49 * 3600, NOW - 49 * 3600))
        r = self.run_py("--patrol", "manga")
        self.assertIn("FAIL manga/manga manga-stale newest draft 49h old",
                      r.stdout)

    # --- (13) component prompts with no render fire components-pending ---
    def test_manga_components_pending_fails(self):
        d = (self.sb / "docs" / "media" / "manga" / "sample")
        (d / "components").mkdir()
        (d / "components" / "env.json").write_text("{}")
        r = self.run_py("--patrol", "manga")
        self.assertIn("FAIL manga/sample components-pending "
                      "1 component prompt(s), 0 renders", r.stdout)

    # --- (14) email: only failures since the LAST patrol run fire ---
    def test_email_failed_send_fails(self):
        log = self.auto / "logs" / "notify-email.log"
        log.write_text("%s | send failed rc=2: historical\n" % iso(7200))
        r, _ = self.run_walk()
        # the first walk baselines the watermark: old failures stay old
        self.assertNotIn("FAIL email/notify-email.log", r.stdout)
        # a failure written after the watermark is a finding
        with open(log, "a") as fh:
            fh.write("%s | send ok rc=0: hi\n" % iso(300))
            fh.write("%s | send failed rc=2: fresh\n" % iso(60))
        r, _ = self.run_walk()
        self.assertIn("FAIL email/notify-email.log send-failed "
                      "1 failed send(s) since last patrol", r.stdout)
        # the same failure does not re-fire on the next run
        r, _ = self.run_walk()
        self.assertNotIn("FAIL email/notify-email.log", r.stdout)

    # --- (15) an in-use package whose install-path rots is a ghost row ---
    def test_package_ghost_row_fails(self):
        (self.auto / "config" / "hngh-packages.tsv").write_text(
            "package\tupstream\trole\tinstall-path\tconfig\tupdate\tfeed\t"
            "disposition\nomp\tu\tr\t/no/such/bin\tc\tu\tf\tin-use\n")
        r = self.run_py("--patrol", "packages")
        self.assertEqual(r.returncode, 0)
        self.assertIn("FAIL packages/omp ghost-row in-use install-path "
                      "does not resolve: /no/such/bin", r.stdout)

    # --- (16) a transient managed child left running is a leak ---
    def test_transient_child_left_running_fails(self):
        proc = subprocess.Popen(
            [sys.executable, "-c", "import time; time.sleep(60)",
             "--port", "8188"])
        try:
            (self.auto / "config" / "hngh-services.tsv").write_text(
                "service\trole\tmethod\tpath\tstart\thealth\tmanaged\t"
                "disposition\ncomfyui\tr\tvenv\t/opt/comfyui\t"
                "cd /opt/comfyui && python main.py --listen --port 8188\t"
                "http://x\tautomation/lib/comfyui.sh\tin-use\n")
            r = self.run_py("--patrol", "service-children")
            self.assertEqual(r.returncode, 0)
            self.assertIn("FAIL service-children/comfyui "
                          "transient-left-running", r.stdout)
        finally:
            proc.kill()
            proc.wait()

    # --- (17) an adopted disposition with no follow-on is a finding ---
    def test_adopted_no_followon_fails(self):
        (self.auto / "research-dispositions.tsv").write_text(
            "line\taction\tverdict\treviewer\tevidence\tdate\n"
            "orphan-line\tadopted\tadopted -- fine\tm\te\t%s\n" % iso(3600))
        r = self.run_py("--patrol", "research-dispositions")
        self.assertIn("FAIL research-dispositions/orphan-line "
                      "adopted-no-followon", r.stdout)

    # --- (19) a disabled/dead critical timer is a finding + alert ---
    def test_dead_timer_fails_and_files_alert(self):
        state = self.sb / "systemd-state.tsv"
        state.write_text(
            "".join("%s\t%s\tok\n" % (u, f)
                    for u in ("hngh-automation.timer",
                              "hngh-cadence-1m.timer",
                              "hngh-cadence-5m.timer")
                    for f in ("enabled", "active"))
            + "hngh-overnight.timer\tenabled\tdisabled\n"
              "hngh-overnight.timer\tactive\tinactive\n")
        r, alerts = self.run_walk()
        self.assertIn("FAIL systemd-units/hngh-overnight.timer timer-dead "
                      "enabled=bad active=bad", r.stdout)
        self.assertTrue(any("patrol systemd-units:" in a for a in alerts))

    # --- (github-ci) the public CI settlement patrol ---
    def test_ci_latest_success_is_quiet(self):
        r, _ = self.run_walk()
        self.assertIn("PASS github-ci/github-actions-latest "
                      "9faf25a success", r.stdout)
        self.assertEqual([ln for ln in r.stdout.splitlines()
                          if ln.startswith("FAIL")], [])

    def test_ci_latest_failure_fires_alert(self):
        self._ci_runs("completed", "failure")
        r, alerts = self.run_walk()
        self.assertIn("FAIL github-ci/github-actions-latest bad-execution "
                      "latest run 9faf25a concluded failure", r.stdout)
        self.assertTrue(any("patrol github-ci:" in a for a in alerts))

    def test_ci_pending_run_is_quiet(self):
        self._ci_runs("in_progress")
        r, _ = self.run_walk()
        self.assertIn("PASS github-ci/github-actions-latest 9faf25a "
                      "status=in_progress", r.stdout)

    def test_ci_unreachable_fails_closed(self):
        os.environ["HNGH_GH_CI_RUNS_URL"] = "file:///nonexistent/ci-runs.json"
        r, _ = self.run_walk()
        self.assertIn("FAIL github-ci/github-actions-latest service-down",
                      r.stdout)

    # --- (20) enabled-but-not-running still fails ---
    def test_enabled_but_inactive_timer_fails(self):
        state = self.sb / "systemd-state.tsv"
        state.write_text(
            "".join("%s\t%s\tok\n" % (u, f)
                    for u in ("hngh-automation.timer", "hngh-cadence-1m.timer",
                              "hngh-cadence-5m.timer", "hngh-overnight.timer")
                    for f in ("enabled", "active"))
            + "hngh-cadence-1m.timer\tactive\tinactive\n")
        r = self.run_py("--patrol", "systemd-units")
        self.assertIn("FAIL systemd-units/hngh-cadence-1m.timer timer-dead",
                      r.stdout)

    # --- (18) --morning: digest section with counts, causes, top-3 ---
    def test_morning_report_appends_rounds_section(self):
        # two patrol runs with fails land in the findings doc
        os.utime(self.auto / "dashboard" / "sessions.json",
                 (NOW - 7000, NOW - 7000))
        self.run_py("--all")
        (self.auto / "logs" / "notify-email.log").write_text(
            "2026-09-12T01:00:00Z | send failed rc=2: no password\n")
        self.run_py("--all")
        # today's daily digest exists (the append-only target)
        r = self.run_py("--morning")
        self.assertEqual(r.returncode, 0)
        digest = (self.auto / "digest" / "2026-09-12.md").read_text()
        self.assertIn("## The rounds", digest)
        self.assertRegex(digest,
                         r"PASS \d+, FAIL \d+ \(feed-stale x2, "
                         r"deck-a-empty x2, send-failed x1\)")
        self.assertIn("Top items for operator attention:", digest)
        self.assertIn("1. feeds", digest)
        self.assertIn("3. email", digest)
        # idempotent append: a second --morning adds one more section
        self.run_py("--morning")
        self.assertEqual(
            digest.count("## The rounds") + 1,
            (self.auto / "digest" / "2026-09-12.md").read_text()
            .count("## The rounds"))
if __name__ == "__main__":
    unittest.main(verbosity=1)


