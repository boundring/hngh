#!/usr/bin/env python3
"""dashboard-server /fleet.json resource-pool feed, hermetic.

Contract proven here (rung B of docs/project/system-harness-roadmap.md —
queue item pooled-hardware / resource-pool-view):
  - The feed shells out to the kernel fleet-manager in --json mode
    (read-only discovery, one invocation: no daemon, no ambient
    collector — the rung B boundary).
  - TTL cache: the second call within TELEMETRY_TTL_S does NOT re-run
    fleet-manager.
  - Pass-through: fleet-manager's payload (nodes/facts/generated) is
    served as-is — the server never filters node kinds.
  - Fail-soft: when fleet-manager fails mid-flight (nonzero exit,
    timeout, unparsable JSON), the endpoint serves the last good
    payload; a cold-start failure fails closed (raises) instead of
    inventing an empty pool.

The fleet-manager path is seamed (module var FLEET_MANAGER), so no real
tailscale binary is touched: the stub is a shell script in a temp dir
that prints a canned payload.
"""
import importlib.util
import json
import shutil
import stat
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent  # automation/


def _load(name, rel):
    spec = importlib.util.spec_from_file_location(name, str(ROOT / rel))
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


ds = _load("dashboard_server_fleet", "dashboard-server.py")

PAYLOAD = {
    "nodes": [{"name": "deck", "ip": "100.1.2.3",
               "online": True, "os": "linux"}],
    "facts": {"audio": 0, "tailscale": "up", "dbus": "up"},
    "generated": "2026-09-16T03:00:00+00:00"}


class PoolFeedTest(unittest.TestCase):
    """fleet_pool_json against a seamed fleet-manager stub script."""

    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp())
        self.stub = self.tmp / "fleet-manager"
        self.absent = self.tmp / "absent-fleet-manager"
        ds._fleet_cache = (0.0, None)  # cold, per-test
        self.prev_fleet = ds.FLEET_MANAGER

    def tearDown(self):
        ds.FLEET_MANAGER = self.prev_fleet
        shutil.rmtree(self.tmp, ignore_errors=True)

    def stub_printing(self, body, exit_code=0):
        """A stub fleet-manager: prints BODY, exits EXIT_CODE. The body
        is nested: line 1 is the invocation log payload (the stub
        re-reads $FLEET_LOG), the rest is the printed JSON."""
        self.stub.write_text(
            "#!/bin/sh\n"
            f'if [ -n "$FLEET_LOG" ]; then printf "run\\n" >> "$FLEET_LOG"; fi\n'
            f"cat <<'EOF'\n{body}\nEOF\n"
            f"exit {exit_code}\n")
        self.stub.chmod(stat.S_IRWXU)
        return self.tmp / "invoked.log"

    def test_passes_payload_through_unmodified(self):
        log = self.stub_printing(json.dumps(PAYLOAD))
        ds.FLEET_MANAGER = str(self.stub)
        osvar = __import__("os").environ
        osvar["FLEET_LOG"] = str(log)
        try:
            out = ds.fleet_pool_json()
        finally:
            osvar.pop("FLEET_LOG", None)
        self.assertEqual(out["nodes"], PAYLOAD["nodes"])
        self.assertEqual(out["facts"], PAYLOAD["facts"])
        self.assertEqual(out["generated"], PAYLOAD["generated"])
        self.assertEqual(log.read_text(), "run\n")

    def test_cold_start_failure_fails_closed(self):
        self.stub_printing("not json", exit_code=1)
        ds.FLEET_MANAGER = str(self.stub)
        with self.assertRaises(Exception):
            ds.fleet_pool_json()

    def test_mid_flight_failure_serves_last_good_payload(self):
        log = self.stub_printing(json.dumps(PAYLOAD))
        ds.FLEET_MANAGER = str(self.stub)
        osvar = __import__("os").environ
        osvar["FLEET_LOG"] = str(log)
        try:
            good = ds.fleet_pool_json()
        finally:
            osvar.pop("FLEET_LOG", None)
        self.assertEqual(good["generated"], PAYLOAD["generated"])
        # expire the cache, then make the script vanish (mid-flight fail)
        ds._fleet_cache = (ds._fleet_cache[0] - ds.TELEMETRY_TTL_S - 1.0,
                           ds._fleet_cache[1])
        ds.FLEET_MANAGER = str(self.absent)
        out = ds.fleet_pool_json()
        self.assertEqual(out["generated"], PAYLOAD["generated"])
        self.assertEqual(log.read_text(), "run\n")

    def test_ttl_cache_skips_second_run(self):
        log = self.stub_printing(json.dumps(PAYLOAD))
        ds.FLEET_MANAGER = str(self.stub)
        osvar = __import__("os").environ
        osvar["FLEET_LOG"] = str(log)
        try:
            ds.fleet_pool_json()
            ds.fleet_pool_json()
        finally:
            osvar.pop("FLEET_LOG", None)
        self.assertEqual(log.read_text(), "run\n")

    def test_ttl_value_is_30s(self):
        self.assertEqual(ds.TELEMETRY_TTL_S, 30.0)


if __name__ == "__main__":
    unittest.main(verbosity=2)
