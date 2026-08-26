#!/usr/bin/env python3
"""dashboard-readout smoke: every renderer + the dance flag run clean."""

import subprocess
import sys
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent.parent


def run(args):
    return subprocess.run([sys.executable, str(ROOT / "scripts" / "dashboard-readout"), *args],
                          capture_output=True, text=True, cwd=ROOT)


def test_linear():
    out = run([])
    assert out.returncode == 0, out.stderr
    assert "timeline rows" in out.stdout


def test_spiral():
    out = run(["--spiral"])
    assert out.returncode == 0, out.stderr
    assert "spiral" in out.stdout and "timeline rows" in out.stdout


def test_circular():
    out = run(["--circular"])
    assert out.returncode == 0, out.stderr
    assert "circular" in out.stdout and "timeline rows" in out.stdout


def test_burst():
    out = run(["--burst"])
    assert out.returncode == 0, out.stderr
    assert "burst" in out.stdout


def test_wave():
    out = run(["--wave"])
    assert out.returncode == 0, out.stderr
    assert "wave" in out.stdout


def test_themes():
    for extra in (["--theme=matrix"], ["--banner", "--theme=ocean"], ["--quiet"]):
        out = run(extra)
        assert out.returncode == 0, out.stderr


def test_tone():
    for style in (["--tone"], ["--tone", "--circular"], ["--tone", "--wave"]):
        out = run(style)
        assert out.returncode == 0, out.stderr


def test_dance():
    for style in ([], ["--spiral"], ["--circular"]):
        out = run([*style, "--dance", "5"])
        assert out.returncode == 0, out.stderr
        out = run([*style, "--dance", "auto"])
        assert out.returncode == 0, out.stderr


def load_readout():
    import importlib.machinery
    import importlib.util
    loader = importlib.machinery.SourceFileLoader(
        "dashboard_readout_under_test", str(ROOT / "scripts" / "dashboard-readout"))
    spec = importlib.util.spec_from_loader("dashboard_readout_under_test", loader)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def test_json_carries_roster_key():
    out = run(["--json"])
    assert out.returncode == 0, out.stderr
    doc = json.loads(out.stdout)
    assert "roster" in doc
    assert isinstance(doc["roster"], list)


def test_roster_fails_closed_on_missing_store():
    mod = load_readout()
    # a store root that cannot exist yields an empty roster, never a crash
    mod._roster_sources = lambda: (("automation", [ROOT / "no-such-store"]),)
    mod._roster_cache.update(at=0.0, rows=None)
    assert mod.roster_rows() == []


if __name__ == "__main__":
    test_linear()
    test_spiral()
    test_circular()
    test_burst()
    test_wave()
    test_tone()
    test_dance()
    test_json_carries_roster_key()
    test_roster_fails_closed_on_missing_store()
    print("dashboard-readout smoke OK (linear+spiral+circular+burst+wave+tone+theme+banner+quiet+dance+roster)")
