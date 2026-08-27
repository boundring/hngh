#!/usr/bin/env python3
"""dashboard-readout smoke: every renderer + the dance flag run clean."""

import subprocess
import sys
import json
import tempfile
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


def test_verdict_truth_table():
    """The S1 single verdict (mirrors hngh.main:match): all-clear exactly
    when the digest is healthy AND no run's headroom is failing."""
    mod = load_readout()
    # healthy digest + a progressing run -> all clear
    state, reasons = mod.verdict({"roster": [{"id": "r1", "state": "running"}]})
    assert state == "all-clear" and not reasons
    # a died run flips to attention naming the run
    state, reasons = mod.verdict({"roster": [{"id": "r1", "state": "dead"}]})
    assert state == "attention" and any("r1" in r for r in reasons)
    # an unreadable run fails closed to attention, never a crash
    state, _ = mod.verdict({"roster": [{"id": "r9", "state": "unknown"}]})
    assert state == "attention"


def test_verdict_digest_fault_is_attention():
    mod = load_readout()
    # a faulting spine cannot claim all-clear even with a clean roster
    mod.source_digest = lambda: (False, "queue unreadable")
    state, reasons = mod.verdict({"roster": []})
    assert state == "attention" and "queue unreadable" in reasons
    # restored digest returns to all clear
    mod.source_digest = lambda: (True, "")
    state, reasons = mod.verdict({"roster": []})
    assert state == "all-clear" and not reasons


def test_honest_depends_on_rename():
    """ETA displays rename to 'Depends on' (underlying keys untouched)."""
    out = run([])
    assert out.returncode == 0, out.stderr
    assert "depends-on window" in out.stdout
    assert "ETA" not in out.stdout, "stale ETA label leaked into the readout"
    with tempfile.TemporaryDirectory() as td:
        target = Path(td) / "d.html"
        out = run([f"--export-html={target}"])
        assert out.returncode == 0, out.stderr
        html = target.read_text()
        assert "<th>depends on</th>" in html
        assert "<th>eta</th>" not in html


def test_reorder_by_usefulness_is_stable():
    """Running/active rows float first; the rest keeps existing queue/Next
    order; stable, so nothing is dropped or re-sequenced."""
    mod = load_readout()
    items = [("b", "queued"), ("a", "active"), ("c", "queued"), ("d", "done")]
    assert mod.order_queue(items) == [
        ("a", "active"), ("b", "queued"), ("c", "queued"), ("d", "done")]
    # already-active-first input is untouched (stable identity)
    first = [("a", "active"), ("b", "queued")]
    assert mod.order_queue(first) == first
    # nothing is added or dropped
    ordered = mod.order_queue(items)
    assert len(ordered) == len(items)
    assert {i for i, _ in ordered} == {i for i, _ in items}


def test_json_carries_verdict_key():
    out = run(["--json"])
    assert out.returncode == 0, out.stderr
    doc = json.loads(out.stdout)
    assert doc["verdict"]["state"] in ("all-clear", "attention")
    assert isinstance(doc["verdict"]["reasons"], list)


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
    test_verdict_truth_table()
    test_verdict_digest_fault_is_attention()
    test_honest_depends_on_rename()
    test_reorder_by_usefulness_is_stable()
    test_json_carries_verdict_key()
    print("dashboard-readout smoke OK (linear+spiral+circular+burst+wave+tone+theme+banner+quiet+dance+roster)")
