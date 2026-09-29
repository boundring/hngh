#!/usr/bin/env python3
"""Structural pins for the Omarchy plugin (automation/omarchy-plugin/
boundring.hngh): manifest contract, entry files, endpoint allowlist.
QML behavior itself is live-unexercised here (no omarchy-shell on the
dev host); on a target box run `omarchy plugin validate`."""

import json
import re
import unittest
from pathlib import Path

PLUGIN = Path(__file__).resolve().parents[1] / "omarchy-plugin" / "boundring.hngh"

ALLOWED_ENDPOINTS = {
    "/newspaper.json",
    "/operator-item/handle",
    "/operator-item/park",
    "/operator-item/dismiss",
    "/operator-item/expire",
    "/operator-item/suppress",
    "/operator-item/acknowledge",
}


def read(name):
    return (PLUGIN / name).read_text(encoding="utf-8")


class Manifest(unittest.TestCase):
    def setUp(self):
        self.manifest = json.loads(read("manifest.json"))

    def test_schema_and_identity(self):
        self.assertEqual(self.manifest["schemaVersion"], 1)
        self.assertEqual(self.manifest["id"], "boundring.hngh")
        self.assertFalse(self.manifest["id"].startswith("omarchy."))
        self.assertEqual(self.manifest["kinds"], ["bar-widget"])

    def test_required_fields_nonempty(self):
        for field in ("name", "version", "author", "license", "description"):
            self.assertTrue(str(self.manifest[field]).strip(), field)
        bw = self.manifest["barWidget"]
        self.assertTrue(bw["displayName"])
        self.assertIs(bw["allowMultiple"], False)
        self.assertIn(bw["defaultSection"], ("left", "center", "right"))

    def test_entry_points_exist(self):
        for kind, rel in self.manifest["entryPoints"].items():
            self.assertFalse(Path(rel).is_absolute(), rel)
            self.assertTrue((PLUGIN / rel).is_file(), rel)

    def test_no_symlinks(self):
        for p in PLUGIN.rglob("*"):
            self.assertFalse(p.is_symlink(), p)


class QmlContract(unittest.TestCase):
    def test_barwidget_loads_panel_and_polls_dashboard(self):
        text = read("BarWidget.qml")
        self.assertIn('moduleName: "boundring.hngh"', text)
        self.assertIn('source: Qt.resolvedUrl("Panel.qml")', text)
        self.assertIn('"http://127.0.0.1:8890/newspaper.json"', text)
        # queue count comes from queues.operator; -1 = unreachable
        self.assertIn("d.queues && d.queues.operator", text)
        self.assertIn("root.operatorQueue = -1", text)

    def test_panel_uses_panel_kit(self):
        text = read("Panel.qml")
        self.assertIn("KeyboardPanel {", text)
        self.assertIn("PanelKeyCatcher {", text)
        self.assertIn('moduleName: "boundring.hngh"', text)


class Security(unittest.TestCase):
    def test_urls_local_only(self):
        for name in ("BarWidget.qml", "Panel.qml"):
            for url in re.findall(r'"(https?://[^"]+)"', read(name)):
                # the property is "no external hosts"; endpoint paths
                # are pinned separately by test_endpoints_allowlisted
                self.assertTrue(
                    url.startswith("http://127.0.0.1:8890"),
                    "%s: %s" % (name, url))

    def test_endpoints_allowlisted(self):
        seen = set()
        for name in ("BarWidget.qml", "Panel.qml"):
            seen |= set(re.findall(
                r'"(/(?:operator-item|newspaper)[^"]*)"', read(name)))
        self.assertIn("/operator-item/handle", seen)
        self.assertIn("/operator-item/park", seen)
        self.assertEqual(seen, seen & ALLOWED_ENDPOINTS)

    def test_park_requires_note(self):
        text = read("Panel.qml")
        self.assertIn("enabled: parkNote.text.length > 0", text)
        self.assertIn(
            "{ id: card.modelData.id, note: parkNote.text }", text)


class Docs(unittest.TestCase):
    def test_readme_documents_install_and_validation(self):
        text = read("README.md")
        self.assertIn("rescanPlugins", text)
        self.assertIn("omarchy plugin validate", text)
        self.assertIn("127.0.0.1:8890", text)


if __name__ == "__main__":
    unittest.main(verbosity=2)
