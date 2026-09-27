#!/usr/bin/env python3
"""Hermetic tests for newspaper-compose.py (broadsheet data layer).

Fixture db + fixture dashboard feeds in a temp sandbox (no network, no
~/.hngh): masthead assembly (weather/system/queues), the article schema
(exact key set), operator decision cards (endpoint literals + real ids),
span rules with the one-span-3 cap, editions grouping (7 dates, 40 cap),
fail-open on missing inputs, and the committed sample fixture.
"""
import datetime
import json
import os
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
ENDPOINTS = {"/operator-item/handle", "/operator-item/dismiss"}

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
        self.db = os.path.join(self.sb, "news.db")
        self._feed_files()

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
            {"id": "run-2", "state": "active", "mission": "patrol",
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
        with open(os.path.join(self.dbhome, "onthisday.json"), "w") as fh:
            json.dump({"day": NOW.strftime("%Y-%m-%d"), "fetched": z(NOW),
                       "events": [{"year": 2014, "text": "Ontake erupted.",
                                   "url": "https://en.wikipedia.org/"}]}, fh)

    def _seed_db(self):
        conn = sqlite3.connect(self.db)
        conn.execute("DROP TABLE IF EXISTS items")
        conn.execute("CREATE TABLE items (id TEXT PRIMARY KEY, feed TEXT,"
                     " category TEXT, title TEXT, link TEXT, summary TEXT,"
                     " published TEXT, fetched TEXT)")
        rows = [
            ("w1", "bbc-world", "world", "Wire: storm moves east",
             "https://example.com/1", "A low tracks east. Gales expected.",
             days_ago(0, 4), z(NOW)),
            ("w2", "phoronix", "linux", "Scheduler tuned for hybrid",
             "https://example.com/2", "Placement tuning landed.",
             days_ago(2, 9), z(NOW)),
        ]
        # d=4..11: every age >72h for any current wall clock (max skew
        # 11h keeps 4d-11h=85h); 8 dates -> 7 kept, oldest dropped
        for d in range(4, 12):
            rows.append(("old%d" % d, "hn-frontpage", "technology",
                         "Old story %d" % d, "https://example.com/o%d" % d,
                         "Old body %d." % d, days_ago(d, 15), z(NOW)))
        for i in range(41):  # one date exceeds the 40-article cap
            rows.append(("cap%02d" % i, "hn-frontpage", "technology",
                         "Cap story %02d" % i, "https://example.com/c%d" % i,
                         "Cap body %d." % i, days_ago(4, 3), z(NOW)))
        conn.executemany("INSERT INTO items VALUES (?,?,?,?,?,?,?,?)", rows)
        conn.commit()
        conn.close()

    def run_compose(self):
        self._seed_db()
        out = os.path.join(self.sb, "out", "newspaper.json")
        r = subprocess.run(
            [sys.executable, COMPOSE, "--db", self.db, "--out", out,
             "--dashboard", self.dash, "--home-db", self.dbhome],
            capture_output=True, text=True, timeout=60)
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
            self.assertEqual(set(a), SCHEMA_ART)
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
        self.assertEqual([c["label"] for c in ops["choices"]],
                         ["Handle", "Dismiss"])
        for c in ops["choices"]:
            self.assertIn(c["action"]["endpoint"], ENDPOINTS)
            self.assertEqual(c["action"]["payload"], {"id": "6cb1737b"})

    def test_queues_counts(self):
        r, out = self.run_compose()
        self.assertEqual(r.returncode, 0, r.stderr)
        with open(out) as fh:
            doc = json.load(fh)
        q = doc["queues"]
        self.assertEqual(q["queued"], 2)
        self.assertEqual(q["done"], 3)
        self.assertEqual(q["world"], 2)  # wire + on-this-day column
        self.assertEqual(q["linux"], 1)
        self.assertEqual(q.get("technology", 0), 0)  # old items uncounted
        self.assertEqual(q["operator"], 1)
        self.assertEqual(q["system"], 2)
        self.assertEqual(q["opportunities"], 1)


class Editions(Base):
    def test_grouping_and_caps(self):
        r, out = self.run_compose()
        self.assertEqual(r.returncode, 0, r.stderr)
        with open(out) as fh:
            doc = json.load(fh)
        eds = doc["editions"]
        self.assertEqual(len(eds), 7)  # 8 past dates -> 7 most recent
        dates = [e["date"] for e in eds]
        self.assertEqual(dates, sorted(dates, reverse=True))
        self.assertNotIn((NOW - datetime.timedelta(days=11)).strftime(
            "%Y-%m-%d"), dates)  # oldest dropped
        for e in eds:
            self.assertLessEqual(len(e["articles"]), 40)
            for a in e["articles"]:
                self.assertEqual(set(a), SCHEMA_ART)
                self.assertEqual(a["span"], 1)  # editions never lead
        self.assertEqual(doc["edition"]["number"], 8)
        # fresh <=72h never leaks into past editions
        for e in eds:
            for a in e["articles"]:
                self.assertNotIn("storm moves east", a["headline"])


class FailOpen(Base):
    def test_missing_inputs_still_publish(self):
        os.remove(os.path.join(self.dash, "sessions.json"))
        os.remove(os.path.join(self.dash, "fleet.json"))
        os.remove(os.path.join(self.dbhome, "weather-state.json"))
        r, out = self.run_compose()
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertIn("sessions", r.stderr)
        self.assertIn("fleet", r.stderr)
        self.assertIn("weather", r.stderr)
        with open(out) as fh:
            doc = json.load(fh)
        self.assertIsNone(doc["edition"]["weather"])
        self.assertEqual(doc["edition"]["system"]["sessions_active"], 0)
        self.assertEqual(doc["edition"]["system"]["fleet"], [])
        self.assertEqual(doc["edition"]["number"], 8)


class SampleFixture(Base):
    def test_fixture_parses_and_matches_schema(self):
        with open(FIXTURE) as fh:
            doc = json.load(fh)
        self.assertEqual(set(doc), SCHEMA_TOP)
        self.assertEqual(set(doc["edition"]), SCHEMA_EDITION)
        for a in doc["articles"]:
            self.assertEqual(set(a), SCHEMA_ART)
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


if __name__ == "__main__":
    unittest.main()
