# Unit tests for lib/harness/registry.py (plan: 2026-09-13-dev-os-harness-cross-platform-patterns).
# Hermetic: no real desktop environment is needed; adapters are exercised via probe/execute.
import os
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))

from lib.harness.adapters import TargetAdapter
from lib.harness.adapters.gnome import GNOMEAdapter
from lib.harness.adapters.kde import KDEAdapter
from lib.harness.registry import resolve_adapter


class TestRegistry(unittest.TestCase):
    def setUp(self):
        self._saved = os.environ.pop("HNGH_DE", None)

    def tearDown(self):
        if self._saved is None:
            os.environ.pop("HNGH_DE", None)
        else:
            os.environ["HNGH_DE"] = self._saved

    def test_kde_resolves(self):
        os.environ["HNGH_DE"] = "kde"
        adapter = resolve_adapter()
        self.assertIsInstance(adapter, KDEAdapter)
        self.assertIsInstance(adapter, TargetAdapter)

    def test_gnome_resolves(self):
        os.environ["HNGH_DE"] = "gnome"
        adapter = resolve_adapter()
        self.assertIsInstance(adapter, GNOMEAdapter)
        self.assertIsInstance(adapter, TargetAdapter)

    def test_case_and_space_tolerant(self):
        os.environ["HNGH_DE"] = " KDE "
        self.assertIsInstance(resolve_adapter(), KDEAdapter)

    def test_unknown_value_raises(self):
        os.environ["HNGH_DE"] = "wmaker"
        with self.assertRaises(ValueError):
            resolve_adapter()

    def test_unset_raises(self):
        with self.assertRaises(ValueError):
            resolve_adapter()


class TestAdapters(unittest.TestCase):
    def test_probe_kde(self):
        self.assertEqual(KDEAdapter().probe()["de"], "kde")

    def test_probe_gnome(self):
        self.assertEqual(GNOMEAdapter().probe()["de"], "gnome")

    def test_execute_kde(self):
        result = KDEAdapter().execute({"x": 1})
        self.assertEqual(result, {"ok": True, "de": "kde", "action": {"x": 1}})

    def test_execute_gnome(self):
        result = GNOMEAdapter().execute({"x": 1})
        self.assertEqual(result, {"ok": True, "de": "gnome", "action": {"x": 1}})

    def test_execute_rejects_non_dict(self):
        for adapter in (KDEAdapter(), GNOMEAdapter()):
            with self.assertRaises(ValueError):
                adapter.execute("x")


if __name__ == "__main__":
    unittest.main(verbosity=2)
