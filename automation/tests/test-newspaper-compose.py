#!/usr/bin/env python3
"""Hermetic tests for newspaper-compose.py (front-page data layer).

Fixture db + fixture dashboard feeds in a temp sandbox (no network, no
~/.hngh): masthead assembly (weather/system/queues), the article schema
(exact key set), operator decision cards (endpoint literals + real ids),
span rules with the one-span-3 cap, editions grouping (7 dates, 40 cap),
fail-open on missing inputs, and the committed sample fixture. The
rebalance cases pin the hngh-internal majority
and <=40% of the page, sessions/opportunities capped, the consolidated
system desk (one embedded article) and the crumbs activity digest above
the fold. The 2026-09-29 card contract: fire (default-verb example),
narrative {"place", "line"}, and the parked-desk digest.
"""
import datetime
import json
import os
import re
import sqlite3
import subprocess
import sys
import tempfile
import unittest

AUTO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
COMPOSE = os.path.join(AUTO, "scripts", "newspaper-compose.py")
FIXTURE = os.path.join(AUTO, "tests", "fixtures", "newspaper.sample.json")

SCHEMA_TOP = {"generated", "edition", "queues", "articles", "editions"}
SCHEMA_EDITION = {"date", "number", "slot", "weather", "system"}
SCHEMA_ART = {"id", "category", "headline", "deck", "body", "span",
              "score", "ts", "sources", "choices"}
SCHEMA_ART_OP = {"narrative", "occurrences", "guidance", "fire",
                 "embed", "parked"}  # optional desk fields
ENDPOINTS = {"/operator-item/handle", "/operator-item/dismiss",
             "/operator-item/park", "/operator-item/expire",
             "/operator-item/suppress", "/operator-item/acknowledge"}

NOW = datetime.datetime.now(datetime.timezone.utc)


def z(dt):
    return dt.strftime("%Y-%m-%dT%H:%M:%SZ")


def days_ago(n, hour=12):
    d = NOW - datetime.timedelta(days=n)
    return z(d.replace(hour=hour, minute=0, second=0, microsecond=0))


class Base(unittest.TestCase):
    def setUp(self):
        self.sb = tempfile.mkdtemp()
        self.dash = os.path.join(self.sb, "dash")
        self.dbhome = os.path.join(self.sb, "db")
        os.makedirs(self.dash)
        os.makedirs(self.dbhome)
        # settled digest reads the real handoff ledger by default;
        # tests get an absent sandbox stub unless they write one
        os.environ["HNGH_HANDOFFS"] = os.path.join(
            self.sb, "absent-handoffs.md")
        self.addCleanup(os.environ.pop, "HNGH_HANDOFFS", None)
        self._feed_files()
        self.crumbs = os.path.join(self.sb, "crumbs.db")
        self._seed_crumbs()

    def _write(self, rel, obj):
        with open(os.path.join(self.dash, rel), "w") as fh:
            json.dump(obj, fh)

    def _feed_files(self):
        self._write("readout.json", {
            "generated": z(NOW), "verdict": "nominal",
            "queue": [{"id": "a", "status": "queued"},
                      {"id": "b", "status": "queued"},
                      {"id": "c", "status": "done"},
                      {"id": "d", "status": "done"},
                      {"id": "e", "status": "done"}]})
        self._write("operator-items.json", {"generated_at": z(NOW), "items": [
            {"id": "6cb1737b", "text": "feedback-ingest | alert | idea",
             "status": "open", "first_seen": z(NOW),
             "last_seen": z(NOW)},
            {"id": "deadbeef", "text": "already acked",
             "status": "acked", "first_seen": z(NOW),
             "last_seen": z(NOW)}]})
        self._write("sessions.json", {"generated": z(NOW), "sessions": [
            {"id": "run-1", "state": "active", "mission": "bench the model",
             "age": 120.0},
            {"id": "run-2", "state": "active", "mission": "patrol the queue",
             "age": 30.0}]})
        self._write("research-routes.json", {
            "schema": "routes/1", "generated": z(NOW), "routes": [
                {"id": "fail-1", "title": "FOLLOWON: retry policy",
                 "status": "crystallized",
                 "terminus": {"action": "open", "date": "2026-09-20"}}]})
        self._write("fleet.json", {"nodes": [
            {"name": "brickertop", "ip": "x", "online": True, "os": "linux"},
            {"name": "brickus", "ip": "y", "online": False,
             "os": "android"}]})
        with open(os.path.join(self.dbhome, "weather-state.json"),
                  "w") as fh:
            json.dump({"temp_c": 14.3, "summary": "rain",
                       "source": "open-meteo", "fetched": z(NOW)}, fh)
        with open(os.path.join(self.dbhome, "system-resources.json"),
                  "w") as fh:
            json.dump({"generated": z(NOW),
                       "memory": {"total_mb": 64000.0, "avail_mb": 32000.0,
                                  "used_pct": 50.0},
                       "load": {"load1": 1.23, "load5": 0.45,
                                "load15": 0.67},
                       "uptime_s": 987654.0, "cpu_threads": 32,
                       "disks": [
                           {"path": "/srv/hngh",
                            "used_pct": 42.3, "total_gb": 931.0,
                            "free_gb": 537.0},
                           {"path": "/srv/hngh/dbhome",
                            "used_pct": 61.1, "total_gb": 465.0,
                            "free_gb": 180.6}]}, fh)

    def _seed_crumbs(self):
        conn = sqlite3.connect(self.crumbs)
        conn.execute("CREATE TABLE crumbs (ts TEXT, job TEXT, event TEXT,"
                     " detail TEXT, writer TEXT)")
        recent = z(NOW - datetime.timedelta(minutes=20))
        rows = [("progress", "33-research-beat.sh"),
                ("progress", "33-research-beat.sh"),
                ("progress", "23-bctx-canary.sh"),
                ("alert", "news-screen")]
        conn.executemany(
            "INSERT INTO crumbs VALUES (?,?,?,?,?)",
            [(recent, job, ev, "seed row", "test") for ev, job in rows])
        conn.commit()
        conn.close()

    def run_compose(self):
        out = os.path.join(self.sb, "out", "newspaper.json")
        env = dict(os.environ, HNGH_CRUMBS_DB=self.crumbs,
                   HNGH_REPORT_IDENTITIES=os.path.join(
                       self.sb, "report-identities.json"),
                   HNGH_REPORT_ROOT=getattr(self, "report_root", self.sb))
        env["HNGH_XIAOMI_CMD"] = "exit 7"
        r = subprocess.run(
            [sys.executable, COMPOSE, "--out", out,
             "--dashboard", self.dash, "--home-db", self.dbhome],
            capture_output=True, text=True, timeout=120,
            env=env)
        return r, out


class Masthead(Base):
    def test_top_level_and_masthead(self):
        r, out = self.run_compose()
        self.assertEqual(r.returncode, 0, r.stderr)
        with open(out) as fh:
            doc = json.load(fh)
        self.assertEqual(set(doc), SCHEMA_TOP)
        ed = doc["edition"]
        self.assertEqual(set(ed), SCHEMA_EDITION)
        self.assertEqual(ed["weather"]["temp_c"], 14.3)
        self.assertEqual(ed["weather"]["summary"], "rain")
        sysm = ed["system"]
        self.assertEqual(sysm["queue_depth"], 2)
        self.assertEqual(sysm["sessions_active"], 2)
        self.assertEqual([n["name"] for n in sysm["fleet"]],
                         ["brickertop", "brickus"])
        self.assertTrue(all(set(n) == {"name", "online", "os"}
                            for n in sysm["fleet"]))
        self.assertEqual(ed["slot"], NOW.hour // 8)

    def test_article_schema_and_order(self):
        r, out = self.run_compose()
        self.assertEqual(r.returncode, 0, r.stderr)
        with open(out) as fh:
            doc = json.load(fh)
        arts = doc["articles"]
        self.assertTrue(arts)
        for a in arts:
            self.assertTrue(SCHEMA_ART <= set(a)
                            <= SCHEMA_ART | SCHEMA_ART_OP, set(a))
            self.assertIn(a["span"], (1, 2, 3))
            self.assertIsInstance(a["body"], list)
        scores = [a["score"] for a in arts]
        self.assertEqual(scores, sorted(scores, reverse=True))
        self.assertEqual(sum(1 for a in arts if a["span"] == 3), 1)
        lead = arts[0]
        self.assertEqual(lead["span"], 3)
        self.assertEqual(lead["category"], "operator")


class OperatorAndQueues(Base):
    def test_operator_choices(self):
        r, out = self.run_compose()
        self.assertEqual(r.returncode, 0, r.stderr)
        with open(out) as fh:
            doc = json.load(fh)
        ops = [a for a in doc["articles"] if a["category"] == "operator"]
        self.assertEqual(len(ops), 1)  # acked item is filtered out
        ops = ops[0]
        self.assertEqual(ops["score"], 0.95)
        # "feedback-ingest | alert | idea" carries no regression /
        # heartbeat / stale / decision keyword -> automation-debt
        # (default class) -> suppress primary, park (land-note) second;
        # Handle and Dismiss always stay available
        self.assertEqual([c["label"] for c in ops["choices"]],
                         ["Suppress", "Park", "Handle", "Dismiss"])
        for c in ops["choices"]:
            self.assertIn(c["action"]["endpoint"], ENDPOINTS)
            self.assertEqual(c["action"]["payload"].get("id"), "6cb1737b")

    def test_queues_counts(self):
        r, out = self.run_compose()
        self.assertEqual(r.returncode, 0, r.stderr)
        with open(out) as fh:
            doc = json.load(fh)
        q = doc["queues"]
        self.assertEqual(q["queued"], 2)
        self.assertEqual(q["done"], 3)
        self.assertEqual(q["operator"], 1)
        self.assertEqual(q["system"], 4)  # 2 sessions + desk(1) + digest
        self.assertEqual(q["opportunities"], 1)


class Editions(Base):
    def test_editions_list_retired_empty(self):
        # the newspaper page retired 2026-10-03: no past-edition
        # accumulation; the field stays for schema compatibility
        r, out = self.run_compose()
        self.assertEqual(r.returncode, 0, r.stderr)
        with open(out) as fh:
            doc = json.load(fh)
        self.assertEqual(doc["editions"], [])
        self.assertEqual(doc["edition"]["number"], 1)


class FailOpen(Base):
    def test_missing_inputs_still_publish(self):
        os.remove(os.path.join(self.dash, "sessions.json"))
        os.remove(os.path.join(self.dash, "fleet.json"))
        os.remove(os.path.join(self.dbhome, "weather-state.json"))
        os.remove(os.path.join(self.dbhome, "system-resources.json"))
        r, out = self.run_compose()
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertIn("sessions", r.stderr)
        self.assertIn("fleet", r.stderr)
        self.assertIn("weather", r.stderr)
        self.assertIn("system resources", r.stderr)
        with open(out) as fh:
            doc = json.load(fh)
        self.assertIsNone(doc["edition"]["weather"])
        self.assertEqual(doc["edition"]["system"]["sessions_active"], 0)
        self.assertEqual(doc["edition"]["system"]["fleet"], [])
        self.assertEqual(doc["edition"]["number"], 1)
        # the stale snapshot triggers a real system-ingest refresh; the
        # desk still lands on this host (load + memory always exist)
        desk = [a for a in doc["articles"] if a["category"] == "system"
                and a["headline"].startswith("System desk:")]
        self.assertTrue(desk)


class Rebalance(Base):
    def test_session_and_research_caps(self):
        self._write("sessions.json", {"generated": z(NOW), "sessions": [
            {"id": "run-%d" % i, "state": "active",
             "mission": "mission %s" % ("ten" if i == 10 else
                                        "nine" if i == 9 else str(i)),
             "age": 10.0 * i} for i in range(1, 11)]})
        self._write("research-routes.json", {
            "schema": "routes/1", "generated": z(NOW), "routes": [
                {"id": "r-%d" % i, "title": "Route research %d" % i,
                 "status": "active",
                 "terminus": {"action": "hold", "date": "2026-09-27"}}
                for i in range(9)]})
        r, out = self.run_compose()
        self.assertEqual(r.returncode, 0, r.stderr)
        with open(out) as fh:
            doc = json.load(fh)
        arts = doc["articles"]
        sess = [a for a in arts if a["headline"].startswith("mission ")]
        self.assertEqual(len(sess), 8)  # SESSION_CAP, freshest kept
        blob = json.dumps(sess)
        self.assertNotIn("mission nine", blob)
        self.assertNotIn("mission ten", blob)
        # masthead reports the true active count, not the page cap
        self.assertEqual(doc["edition"]["system"]["sessions_active"], 10)
        opps = [a for a in arts if a["category"] == "opportunities"]
        cards = [a for a in opps
                 if a["headline"].startswith("Route research")]
        over = [a for a in opps
                if a["headline"].startswith("Opportunities desk:")]
        self.assertEqual(len(cards), 6)  # RESEARCH_CAP
        self.assertEqual(len(over), 1)
        self.assertEqual(over[0]["headline"],
                         "Opportunities desk: 3 more routes on the bench")
        self.assertEqual(doc["queues"]["opportunities"], 7)

    def test_system_desk_front_loaded(self):
        r, out = self.run_compose()
        self.assertEqual(r.returncode, 0, r.stderr)
        with open(out) as fh:
            doc = json.load(fh)
        arts = doc["articles"]
        self.assertEqual([a["category"] for a in arts[:2]],
                         ["operator", "system"])
        desk = [a for a in arts
                if a["headline"].startswith("System desk:")]
        self.assertEqual(len(desk), 1)  # consolidated: exactly one
        desk = desk[0]
        self.assertEqual(desk["headline"],
                         "System desk: live machine readout")
        self.assertEqual(desk["embed"],
                         {"kind": "btop", "src": "/system/btop",
                          "alt": "live btop++ snapshot"})
        # the deck line still comes from system-resources data
        self.assertIn("load 1.23 on 32 threads", desk["deck"])
        self.assertIn("50% memory used", desk["deck"])
        self.assertIn("fleet: 1/2 fleet nodes online", desk["body"])
        self.assertIn("/srv/hngh: 42% used, 537.0 GB free", desk["body"])
        self.assertIn("/srv/hngh/dbhome: 61% used, 180.6 GB free",
                      desk["body"])

    def test_activity_digest(self):
        r, out = self.run_compose()
        self.assertEqual(r.returncode, 0, r.stderr)
        with open(out) as fh:
            doc = json.load(fh)
        dig = [a for a in doc["articles"]
               if a["headline"].startswith("Last hour: ")]
        self.assertEqual(len(dig), 1)
        dig = dig[0]
        self.assertEqual(dig["headline"],
                         "Last hour: 4 machine events, 1 alert")
        self.assertIn("progress: 3", dig["body"])
        self.assertIn("busiest: 33-research-beat.sh (2)", dig["body"])


class SampleFixture(Base):
    def test_fixture_parses_and_matches_schema(self):
        with open(FIXTURE) as fh:
            doc = json.load(fh)
        self.assertEqual(set(doc), SCHEMA_TOP)
        self.assertEqual(set(doc["edition"]), SCHEMA_EDITION)
        for a in doc["articles"]:
            self.assertTrue(SCHEMA_ART <= set(a)
                            <= SCHEMA_ART | SCHEMA_ART_OP, set(a))
        blob = json.dumps(doc)
        for ep in ENDPOINTS:
            self.assertIn(ep, blob)  # view tests grep these literals
        self.assertEqual(sum(1 for a in doc["articles"]
                             if a["span"] == 3), 1)


class Stability(Base):
    def test_ids_stable_across_runs(self):
        r1, out1 = self.run_compose()
        r2, out2 = self.run_compose()
        self.assertEqual(r1.returncode, 0, r1.stderr)
        self.assertEqual(r2.returncode, 0, r2.stderr)
        with open(out1) as fh:
            a = json.load(fh)
        with open(out2) as fh:
            b = json.load(fh)
        self.assertEqual([x["id"] for x in a["articles"]],
                         [x["id"] for x in b["articles"]])


class OperatorCap(Base):
    def test_operator_cap_and_overflow_card(self):
        self._write("operator-items.json", {"generated_at": z(NOW),
            "items": [
                {"id": "acked", "text": "fam-0 | acked | done deal",
                 "first_seen": z(NOW - datetime.timedelta(minutes=60)),
                 "status": "acked",
                 "last_seen": z(NOW - datetime.timedelta(minutes=60))},
            ] + [
                {"id": "op-%02d" % i, "text": "fam-%02d | alert | item %02d"
                 % (i, i),
                 "first_seen": z(NOW - datetime.timedelta(minutes=30 + i)),
                 "status": "open",
                 "last_seen": z(NOW - datetime.timedelta(minutes=30 - i))}
                for i in range(1, 16)]})
        r, out = self.run_compose()
        self.assertEqual(r.returncode, 0, r.stderr)
        with open(out) as fh:
            doc = json.load(fh)
        ops = [a for a in doc["articles"] if a["category"] == "operator"]
        cards = [a for a in ops if a["choices"]]  # decision cards
        over = [a for a in ops
                if a["headline"].startswith("Operator desk:")]
        self.assertEqual(len(cards), 12)  # OPERATOR_CAP, freshest kept
        kept = {c["action"]["payload"]["id"] for c2 in cards
                for c in c2["choices"]
                if c["action"]["endpoint"] == "/operator-item/handle"}
        self.assertEqual(sorted(kept),
                         ["op-%02d" % i for i in range(4, 16)])
        self.assertEqual(len(over), 1)
        self.assertEqual(over[0]["headline"],
                         "Operator desk: 3 more open items on the console")
        blob = json.dumps(doc)
        self.assertNotIn("op-01", blob)
        self.assertNotIn("| acked", blob)  # closed items stay off the page


class ChoiceClasses(Base):
    """Per-class primary choice mapping (judged taxonomy, keyword
    heuristic on the item text -- no LLM call). Handle+Dismiss stay."""

    def _item(self, iid, text):
        return {"id": iid, "text": text, "status": "open",
                "first_seen": z(NOW), "last_seen": z(NOW)}

    def _verbs(self, items):
        self._write("operator-items.json",
                    {"generated_at": z(NOW), "items": items})
        r, out = self.run_compose()
        self.assertEqual(r.returncode, 0, r.stderr)
        with open(out) as fh:
            doc = json.load(fh)
        return {c["action"]["payload"]["id"]:
                [x["action"]["endpoint"] for x in a["choices"]]
                for a in doc["articles"]
                if a["category"] == "operator" and a.get("choices")
                for c in a["choices"]}

    def test_stale_superseded_expires_parks(self):
        verbs = self._verbs([self._item(
            "s1", "beat.sh | stale | superseded by plan 7")])
        self.assertEqual(verbs["s1"][:2],
                         ["/operator-item/expire", "/operator-item/park"])
        self.assertEqual(verbs["s1"][2:],
                         ["/operator-item/handle", "/operator-item/dismiss"])

    def test_operator_decision_parks_acknowledges(self):
        verbs = self._verbs([self._item(
            "d1", "pick.sh | operator decision | choose a provider")])
        self.assertEqual(verbs["d1"][:2],
                         ["/operator-item/park", "/operator-item/acknowledge"])

    def test_transient_heartbeat_expires_suppresses(self):
        verbs = self._verbs([self._item(
            "t1", "pulse.sh | alert | heartbeat flapping retry timeout")])
        self.assertEqual(verbs["t1"][:2],
                         ["/operator-item/expire", "/operator-item/suppress"])

    def test_automation_debt_suppresses(self):
        verbs = self._verbs([self._item(
            "a1", "16-curator-beat.sh | needs | enabling-work edge needs"
                  " staging")])
        self.assertEqual(verbs["a1"][:2],
                         ["/operator-item/suppress", "/operator-item/park"])

    def test_real_regression_acknowledges(self):
        verbs = self._verbs([self._item(
            "r1", "gate.sh | alert | regression: gate failing after"
                  " upgrade")])
        self.assertEqual(verbs["r1"][:2],
                         ["/operator-item/acknowledge", "/operator-item/park"])


class Settlements(Base):
    """The settled digest: recent operator decisions from the handoff
    ledger as one operator-category record article -- newest first,
    capped at 8 rows, guidance note included; fail-open on a missing
    or malformed ledger."""
    LINE = "operator-%s | %s | automation|%s | %s\n"

    def setUp(self):
        super().setUp()
        self.hand = os.path.join(self.sb, "agent-handoffs.md")
        os.environ["HNGH_HANDOFFS"] = self.hand
        self.addCleanup(os.environ.pop, "HNGH_HANDOFFS", None)

    def _settled(self, out):
        with open(out) as fh:
            doc = json.load(fh)
        return [a for a in doc["articles"]
                if a["headline"].startswith("Operator settlements")]

    def test_digest_present(self):
        with open(self.hand, "w") as f:
            f.write(self.LINE % (
                "park", "2026-09-29T13:56:25Z", "faa648fe",
                "parked with guidance: filed as backlog debt; revisit "
                "at the next disposition sweep"))
            f.write(self.LINE % (
                "acknowledge", "2026-09-29T12:34:34Z", "ff2f2a18",
                "acknowledged: leave open for the sweep"))
            f.write("not a handoff line\n")
            f.write("build: something | with | pipes | galore\n")
        r, out = self.run_compose()
        self.assertEqual(r.returncode, 0, r.stderr)
        arts = self._settled(out)
        self.assertEqual(len(arts), 1)
        a = arts[0]
        self.assertEqual(a["category"], "operator")
        self.assertEqual(a["choices"], [])
        self.assertNotIn("guidance", a)
        text = "\n".join(a["body"])
        self.assertIn("park faa648fe", text)
        self.assertIn(
            "parked with guidance: filed as backlog debt", text)
        self.assertIn("acknowledge ff2f2a18", text)
        self.assertEqual(a["ts"], "2026-09-29T13:56:25Z")  # newest

    def test_cap_and_order(self):
        with open(self.hand, "w") as f:
            for i in range(10):
                f.write(self.LINE % (
                    "dismiss", "2026-09-%02dT00:00:00Z" % (20 + i),
                    "id%d" % i, "item dismissed as viewed"))
        r, out = self.run_compose()
        self.assertEqual(r.returncode, 0, r.stderr)
        a = self._settled(out)[0]
        self.assertEqual(len(a["body"]), 8)
        self.assertIn("dismiss id9", a["body"][0])
        self.assertIn("dismiss id2", a["body"][-1])

    def test_fail_open(self):
        os.environ["HNGH_HANDOFFS"] = os.path.join(self.sb, "absent.md")
        r, out = self.run_compose()
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertEqual(self._settled(out), [])


class Guidance(Base):
    """Every operator decision card carries guidance per the shared
    contract: why/note_rules/verbs/docs, verbs mirroring the card's
    own choices 1:1, example notes <=200 chars and pipe-free, and
    docs paths that exist in the repo right now."""
    NOTE_VERBS = ("park", "acknowledge")

    def _op_cards(self, out):
        with open(out) as fh:
            doc = json.load(fh)
        # decision cards only: the settled digest is operator-category
        # but a record, not a card with choices
        return [a for a in doc["articles"]
                if a["category"] == "operator" and a.get("choices")]

    @staticmethod
    def _verb(choice):
        return choice["action"]["endpoint"].rsplit("/", 1)[-1]

    def test_operator_cards_carry_guidance(self):
        r, out = self.run_compose()
        self.assertEqual(r.returncode, 0, r.stderr)
        cards = self._op_cards(out)
        self.assertTrue(cards)
        for card in cards:
            g = card.get("guidance")
            self.assertIsInstance(g, dict)
            self.assertTrue(g.get("why"))
            self.assertIn("200", g.get("note_rules", ""))
            docs = g.get("docs")
            self.assertTrue(docs)
            for d in docs:
                self.assertTrue(d.get("label"))
                path = d["path"]
                self.assertTrue(os.path.exists(
                    os.path.join(AUTO, os.pardir, path)), path)
            verbs = g.get("verbs")
            self.assertEqual(len(verbs), len(card["choices"]))
            for entry, choice in zip(verbs, card["choices"]):
                self.assertEqual(entry["verb"], self._verb(choice))
                self.assertEqual(entry["label"], choice["label"])
                if entry["verb"] in self.NOTE_VERBS:
                    self.assertIn(entry["note"], ("required", "optional"))
                    self.assertTrue(entry["examples"])
                else:
                    self.assertIsNone(entry["note"])
                for ex in entry.get("examples", ()):
                    self.assertLessEqual(len(ex["note"]), 200)
                    self.assertNotIn("|", ex["note"])
                    self.assertTrue(ex["effect"])

    def test_guidance_present_without_note_verb(self):
        # transient-heartbeat items carry expire/suppress/handle/dismiss
        # only -- guidance must still render (fail-open contract).
        self._write("operator-items.json", {"generated_at": z(NOW), "items": [
            {"id": "pulse01", "text": "watchdog | heartbeat | pulse "
             "flapping on lane 3", "status": "open",
             "first_seen": z(NOW), "last_seen": z(NOW)}]})
        r, out = self.run_compose()
        self.assertEqual(r.returncode, 0, r.stderr)
        cards = self._op_cards(out)
        self.assertEqual(len(cards), 1)
        g = cards[0].get("guidance")
        self.assertIsInstance(g, dict)
        self.assertEqual(
            [v["verb"] for v in g["verbs"]],
            [self._verb(c) for c in cards[0]["choices"]])


class DupeCollapse(Base):
    """Repeated headline cards ([w=N] stamp resurrections, or one job's
    many detail tails) collapse into one card carrying an occurrences
    count."""

    def _stamp_item(self, iid, stamp, minutes_ago):
        seen = z(NOW - datetime.timedelta(minutes=minutes_ago))
        return {"id": iid,
                "text": "16-curator-beat.sh | needs | enabling-work edge"
                        " needs staging [w=%s]" % stamp,
                "status": "open", "first_seen": seen, "last_seen": seen}

    def test_stamp_dupes_collapse_to_one_card(self):
        self._write("operator-items.json", {"generated_at": z(NOW), "items": [
            self._stamp_item("d1", 1, 90), self._stamp_item("d2", 2, 30)]})
        r, out = self.run_compose()
        self.assertEqual(r.returncode, 0, r.stderr)
        with open(out) as fh:
            doc = json.load(fh)
        cards = [a for a in doc["articles"]
                 if a["category"] == "operator" and a.get("choices")]
        self.assertEqual(len(cards), 1)
        self.assertEqual(cards[0]["occurrences"], 2)
        # the freshest copy is the representative: its id carries the
        # choices so a decision lands on a live feed row
        ids = {c["action"]["payload"]["id"] for c in cards[0]["choices"]}
        self.assertEqual(ids, {"d2"})

    def test_distinct_items_stay_distinct(self):
        self._write("operator-items.json", {"generated_at": z(NOW), "items": [
            self._stamp_item("k1", 1, 90),
            {"id": "k2", "text": "other.sh | needs | different tail",
             "status": "open", "first_seen": z(NOW), "last_seen": z(NOW)}]})
        r, out = self.run_compose()
        self.assertEqual(r.returncode, 0, r.stderr)
        with open(out) as fh:
            doc = json.load(fh)
        cards = [a for a in doc["articles"]
                 if a["category"] == "operator" and a.get("choices")]
        self.assertEqual(len(cards), 2)
        self.assertEqual(sorted(a["occurrences"] for a in cards), [1, 1])

    def test_same_prefix_detail_tails_collapse(self):
        # the observed 2026-09-27 flood: one job echoing many plan-slug
        # tails, rendered as ~8 identical-looking cards
        tails = ["2026-09-01-overnight-continuity -> 2026-08-31-x",
                 "2026-09-02-overnight-continuity -> 2026-09-01-x",
                 "2026-09-03-capabilities -> 2026-09-03-staging"]
        self._write("operator-items.json", {"generated_at": z(NOW),
            "items": [
                {"id": "p%d" % n,
                 "text": "16-curator-beat.sh | needs | staging edge: "
                         + tail,
                 "status": "open",
                 "first_seen": z(NOW - datetime.timedelta(minutes=30 * n)),
                 "last_seen": z(NOW - datetime.timedelta(minutes=30 * n))}
                for n, tail in enumerate(tails, 1)]})
        r, out = self.run_compose()
        self.assertEqual(r.returncode, 0, r.stderr)
        with open(out) as fh:
            doc = json.load(fh)
        cards = [a for a in doc["articles"]
                 if a["category"] == "operator" and a.get("choices")]
        self.assertEqual(len(cards), 1)
        self.assertEqual(cards[0]["occurrences"], 3)
        ids = {c["action"]["payload"]["id"] for c in cards[0]["choices"]}
        self.assertEqual(ids, {"p1"})  # freshest tail (30 min ago) speaks


class Narrative(Base):
    """Every operator card carries the per-class megastructure
    narrative: {"place", "line"}, ASCII only."""

    def _card(self, items):
        self._write("operator-items.json",
                    {"generated_at": z(NOW), "items": items})
        r, out = self.run_compose()
        self.assertEqual(r.returncode, 0, r.stderr)
        with open(out) as fh:
            doc = json.load(fh)
        return [a for a in doc["articles"]
                if a["category"] == "operator" and a.get("choices")]

    def test_narrative_on_alert_item(self):
        seen = z(NOW - datetime.timedelta(minutes=45))
        cards = self._card([{"id": "n1",
                             "text": "feed.sh | alert | escalation pending",
                             "status": "open", "first_seen": seen,
                             "last_seen": z(NOW)}])
        self.assertEqual(len(cards), 1)
        n = cards[0]["narrative"]
        self.assertEqual(set(n), {"place", "line"})
        self.assertTrue(n["place"] and n["line"])
        self.assertTrue(n["place"].isascii() and n["line"].isascii())
        self.assertEqual(n["place"], "the alarm desk")  # real-regression

    def test_narrative_differs_per_class(self):
        cards = self._card([
            {"id": "n2", "text": "plain.sh | note | ordinary update",
             "status": "open", "first_seen": z(NOW), "last_seen": z(NOW)},
            {"id": "n3", "text": "watchdog | heartbeat | pulse flapping",
             "status": "open", "first_seen": z(NOW), "last_seen": z(NOW)}])
        self.assertEqual(len(cards), 2)
        places = {c["narrative"]["place"] for c in cards}
        self.assertEqual(len(places), 2)  # class-keyed, not boilerplate
        for c in cards:
            n = c["narrative"]
            self.assertEqual(set(n), {"place", "line"})
            self.assertTrue(n["place"].isascii() and n["line"].isascii())


class Fire(Base):
    """Fire strip: the card's DEFAULT verb (first choice whose
    (class, verb) pair has a guidance example) carries that example's
    note + effect; absent when no example verb exists (fail-open)."""

    def _cards(self, out):
        with open(out) as fh:
            doc = json.load(fh)
        return [a for a in doc["articles"]
                if a["category"] == "operator" and a.get("choices")]

    def test_fire_default_verb_note_effect(self):
        r, out = self.run_compose()
        self.assertEqual(r.returncode, 0, r.stderr)
        cards = self._cards(out)
        self.assertEqual(len(cards), 1)
        fire = cards[0].get("fire")
        self.assertIsInstance(fire, dict)
        self.assertEqual(set(fire), {"verb", "endpoint", "note", "effect"})
        # automation-debt card: Suppress first (no example), Park second
        # (example) -> park is the default verb
        self.assertEqual(fire["verb"], "park")
        self.assertEqual(fire["endpoint"], "/operator-item/park")
        self.assertEqual(
            fire["note"],
            "filed as backlog debt; revisit at the next disposition sweep")
        self.assertEqual(
            fire["effect"],
            "Parks the card; the note files the debt with the dismissed-"
            "side row, so the sweep can find the rationale later.")

    def test_fire_absent_without_example_verb(self):
        # transient-heartbeat: expire/suppress/handle/dismiss only, no
        # (class, verb) example pair -> no fire, never a crash
        self._write("operator-items.json", {"generated_at": z(NOW), "items": [
            {"id": "pulse09", "text": "watchdog | heartbeat | pulse "
             "flapping on lane 3", "status": "open",
             "first_seen": z(NOW), "last_seen": z(NOW)}]})
        r, out = self.run_compose()
        self.assertEqual(r.returncode, 0, r.stderr)
        cards = self._cards(out)
        self.assertEqual(len(cards), 1)
        self.assertNotIn("fire", cards[0])
        self.assertIn("guidance", cards[0])


class ParkedDesk(Base):
    """Parked-desk digest: report-queue rows marked parked, newest
    first, capped at 8, with kin (class/keyword-token siblings);
    fail-open when the queue is absent or broken."""

    HEAD = "Parked desk: debt on the shelf, kin noted"

    def _seed_queue(self, rows):
        root = os.path.join(self.sb, "qroot")
        os.makedirs(os.path.join(root, "docs", "project"))
        with open(os.path.join(root, "docs", "project", "reports.md"),
                  "w") as fh:
            fh.write("| timestamp | kind | id | first line | body |\n")
            for ts, kind, rid, first in rows:
                fh.write("| %s | %s | %s | %s | %s |\n"
                         % (ts, kind, rid, first, rid + ".md"))
        self.report_root = root

    def _desk(self, out):
        with open(out) as fh:
            doc = json.load(fh)
        return [a for a in doc["articles"]
                if a["headline"] == self.HEAD]

    def test_digest_cap8_newest_first_with_kin(self):
        rows = [("2026-09-29T%02d:00:00Z" % h, "alert", "hb%d" % h,
                 "watchdog: heartbeat flapping lane %d parked pending"
                 % h) for h in (1, 8, 9, 10)]
        rows += [("2026-09-29T%02d:00:00Z" % h, "alert", "rg%d" % h,
                  "accept-plans: plan %d parked (regression risk)" % h)
                 for h in range(2, 8)]
        rows += [("2026-09-29T09:30:00Z", "optimization", "lz1",
                  "zephyr quixel mordant lonesome parked"),
                 ("2026-09-29T11:00:00Z", "progress", "live1",
                  "backup run: ok 10 files wall=2s"),
                 ("2026-09-29T12:00:00Z", "progress", "live2",
                  "canary: nominal")]
        self._seed_queue(list(reversed(rows)))  # ledger: oldest first
        r, out = self.run_compose()
        self.assertEqual(r.returncode, 0, r.stderr)
        desk = self._desk(out)
        self.assertEqual(len(desk), 1)
        desk = desk[0]
        self.assertEqual(desk["category"], "operator")
        self.assertEqual(desk["choices"], [])
        for absent in ("fire", "guidance", "occurrences"):
            self.assertNotIn(absent, desk)
        parked = desk["parked"]
        self.assertEqual(len(parked), 8)  # 10 parked rows -> cap 8
        self.assertEqual([e["id"] for e in parked],
                         ["hb10", "lz1", "hb9", "hb8",
                          "rg7", "rg6", "rg5", "rg4"])  # newest first
        by = {e["id"]: e for e in parked}
        for e in parked:
            self.assertEqual(set(e) - {"kin"}, {"id", "ts", "why"})
            self.assertTrue(e["why"])
            self.assertTrue(e["ts"].endswith("Z"))
        self.assertEqual(set(by["rg5"]["kin"]), {"rg4", "rg6", "rg7"})
        self.assertNotIn("rg5", by["hb8"].get("kin", []))
        self.assertNotIn("kin", by["lz1"])  # no class/token sibling

    def test_absent_queue_no_article(self):
        self.report_root = os.path.join(self.sb, "never-seeded")
        r, out = self.run_compose()
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertEqual(self._desk(out), [])

    def test_broken_queue_fails_open(self):
        # report-queue crashes when its ledger path is a directory
        root = os.path.join(self.sb, "broken")
        os.makedirs(os.path.join(root, "docs", "project", "reports.md"))
        self.report_root = root
        r, out = self.run_compose()
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertEqual(self._desk(out), [])


class Whitelist(Base):
    """The view whitelist allows exactly the six contract endpoints,
    and every endpoint composition emits is whitelisted."""

    def test_whitelist_covers_emitted_and_contract(self):
        allowed = ENDPOINTS
        r, out = self.run_compose()
        self.assertEqual(r.returncode, 0, r.stderr)
        with open(out) as fh:
            doc = json.load(fh)
        emitted = {c["action"]["endpoint"] for a in doc["articles"]
                   for c in a.get("choices") or []}
        self.assertTrue(emitted)
        self.assertLessEqual(emitted, allowed)


def _load_compose():
    """Module object for direct unit calls (base_article, session_articles)."""
    import importlib.machinery
    import importlib.util
    loader = importlib.machinery.SourceFileLoader(
        "hngh_compose_test", COMPOSE)
    spec = importlib.util.spec_from_loader("hngh_compose_test", loader)
    mod = importlib.util.module_from_spec(spec)
    loader.exec_module(mod)
    return mod


class PresentableText(unittest.TestCase):
    def test_base_article_tildes_paths_and_strips_markup(self):
        mod = _load_compose()
        art = mod.base_article(
            "k", "operator",
            'watch <span class="x">span-id</span> broken',
            "Repo: /home/nyx/Projects/etc/hngh.",
            ["body /home/nyx/x line <div class=\"lcd\">v</div>"],
            "", 0.5, [])
        blob = json.dumps(art)
        self.assertNotIn("/home/", blob)
        self.assertNotIn("<span", blob)
        self.assertNotIn("<div", blob)
        self.assertIn("~/", art["deck"])

    def test_session_articles_skip_delegation_missions(self):
        mod = _load_compose()
        rows = {"sessions": [
            {"id": "a", "state": "active", "age": 12,
             "mission": "Complete assignment thoroughly: "
                        "Survey hngh dashboard CLIENT code."},
            {"id": "b", "state": "active", "age": 5,
             "mission": "bench the model"},
        ], "generated": "2026-10-03T00:00:00Z"}
        arts = mod.session_articles(rows)
        self.assertEqual([a["headline"] for a in arts],
                         ["bench the model"])


if __name__ == "__main__":
    unittest.main()
