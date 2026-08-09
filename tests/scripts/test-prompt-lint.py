"""CLI regression tests for ``hngh prompt-lint`` (card 103).

These tests drive the built Hngh executable with temporary prompt/config
fixtures. The guard is procedural: no model, network, or external service.
"""

import json
import os
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
BINARY = ROOT / "bin" / "hngh"


def run_lint(tmp_path, prompt, config="model: gpt-5.6-luna\n"):
    prompt_path = tmp_path / "request.md"
    config_path = tmp_path / "config.yaml"
    prompt_path.write_text(prompt)
    config_path.write_text(config)
    env = os.environ.copy()
    env["HNGH_PROMPT_LINT_CONFIG"] = str(config_path)
    result = subprocess.run(
        [str(BINARY), "prompt-lint", str(prompt_path)],
        capture_output=True,
        text=True,
        env=env,
    )
    return result


def report(result):
    return json.loads(result.stdout)


def test_valid_request_passes_without_findings(tmp_path):
    result = run_lint(
        tmp_path,
        """STATE: ready\nSTEER: inspect /etc/hosts\nANSWER: verified\n\n"
        "Acceptance: make test; evidence: verified 956/956.\n"
        "Model: gpt-5.6-luna.\n""",
    )
    assert result.returncode == 0
    assert report(result)["findings"] == []


def test_unknown_model_id_is_error_with_suggestion(tmp_path):
    result = run_lint(
        tmp_path,
        "STATE: ready\nSTEER: launch -m gpt-5.6-luna-max\nANSWER: pending\n",
    )
    data = report(result)
    assert result.returncode == 1
    finding = next(f for f in data["findings"] if f["category"] == "model-id")
    assert finding["level"] == "error"
    assert "gpt-5.6-luna" in finding["suggested-fix"]


def test_nonexistent_path_is_error(tmp_path):
    result = run_lint(
        tmp_path,
        "STATE: ready\nSTEER: read /definitely/missing/card-103.txt\nANSWER: pending\n",
    )
    data = report(result)
    assert result.returncode == 1
    assert any(f["category"] == "path" for f in data["findings"])


def test_dangerous_action_requires_human_gate(tmp_path):
    result = run_lint(
        tmp_path,
        "STATE: ready\nSTEER: run rm -rf /tmp/target\nANSWER: blocked\n",
    )
    data = report(result)
    assert result.returncode == 1
    finding = next(f for f in data["findings"] if f["category"] == "dangerous-action")
    assert finding["level"] == "error"
    assert finding["human-gate-ref"] == "operation-gate"


def test_missing_steer_is_warning(tmp_path):
    result = run_lint(tmp_path, "STATE: ready\nANSWER: pending\n")
    data = report(result)
    assert result.returncode == 0
    assert any(
        f["category"] == "structure" and "STEER:" in f["fragment"]
        for f in data["findings"]
    )


def test_unverified_assumption_is_warning(tmp_path):
    result = run_lint(tmp_path, "STATE: ready\nSTEER: card 103 lands\nANSWER: pending\n")
    data = report(result)
    assert result.returncode == 0
    assert any(f["category"] == "assumption" for f in data["findings"])


def test_every_finding_has_attribution(tmp_path):
    result = run_lint(tmp_path, "STATE: ready\nANSWER: pending\n")
    for finding in report(result)["findings"]:
        assert set(finding["producer"]) == {"agent", "model", "harness"}


def test_missing_file_is_error(tmp_path):
    config = tmp_path / "config.yaml"
    config.write_text("model: gpt-5.6-luna\n")
    env = os.environ.copy()
    env["HNGH_PROMPT_LINT_CONFIG"] = str(config)
    result = subprocess.run(
        [str(BINARY), "prompt-lint", str(tmp_path / "absent.md")],
        capture_output=True,
        text=True,
        env=env,
    )
    assert result.returncode == 1
    assert json.loads(result.stdout)["findings"][0]["category"] == "input"
