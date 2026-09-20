#!/usr/bin/env python3
"""Test-first coverage for the dashboard source-IP allowlist (2026-09-20
operator mitigation: localhost + explicit allowlist, deny otherwise).

Run: python3 automation/tests/test-dashboard-allowlist.py
"""

import importlib.util
import ipaddress
import os
import sys
import tempfile
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
MODULE_PATH = REPO / "automation" / "dashboard-server.py"


def load_module():
    spec = importlib.util.spec_from_file_location(
        "dashboard_server", MODULE_PATH)
    mod = importlib.util.module_from_spec(spec)
    sys.modules["dashboard_server"] = mod
    spec.loader.exec_module(mod)
    return mod


class ClientAllowedTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.mod = load_module()

    def test_loopback_ipv4_allowed_by_default(self):
        self.assertTrue(
            self.mod.client_allowed("127.0.0.1", None))

    def test_loopback_ipv6_allowed_by_default(self):
        self.assertTrue(
            self.mod.client_allowed("::1", None))

    def test_tailnet_range_allowed_by_default(self):
        # 100.64.0.0/10 is the tailnet CGNAT range; only tailnet members
        # can source from it.
        self.assertTrue(
            self.mod.client_allowed("100.83.36.27", None))

    def test_lan_denied_by_default(self):
        # The 2026-09-20 mitigation: LAN hosts must be denied.
        self.assertFalse(
            self.mod.client_allowed("192.168.0.42", None))

    def test_public_denied(self):
        self.assertFalse(
            self.mod.client_allowed("203.0.113.7", None))

    def test_env_entries_honored(self):
        env = "10.0.0.0/8,192.168.1.5"
        self.assertTrue(self.mod.client_allowed("10.1.2.3", env))
        self.assertTrue(self.mod.client_allowed("192.168.1.5", env))
        self.assertFalse(self.mod.client_allowed("192.168.1.6", env))

    def test_malformed_entry_ignored_others_still_work(self):
        env = "not-an-ip,10.0.0.0/8"
        self.assertTrue(self.mod.client_allowed("10.2.3.4", env))
        self.assertFalse(self.mod.client_allowed("203.0.113.9", env))

    def test_unparseable_client_ip_denied(self):
        self.assertFalse(self.mod.client_allowed("garbage", None))

    def test_empty_allowlist_string_denies_all(self):
        self.assertFalse(self.mod.client_allowed("127.0.0.1", ""))

    def test_ipv6_tailnet_style_denied_unless_listed(self):
        self.assertFalse(self.mod.client_allowed("fd7a:115c:a1e0::1", None))


if __name__ == "__main__":
    unittest.main(verbosity=2)
