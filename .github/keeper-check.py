#!/usr/bin/env python3
"""CI keeper: assert the workflow contract stays intact.

Regex-based on purpose: no yaml dependency on the runner, and the
contract is a fixed file shape, not arbitrary yaml. Checks:
  1. triggers: push AND pull_request (workflow_dispatch optional)
  2. every job pins timeout-minutes
  3. every action reference is version-pinned (@vN, never @main/@master)
  4. HNGH_CI is exported at workflow level (automation tier gates
     host-only skips on it — see automation/tests/test-hngh-bridge-plugin.py)
  5. the session-store fixture the kernel job seeds actually exists
"""

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
WF = ROOT / ".github" / "workflows" / "ci.yml"

text = WF.read_text(encoding="utf-8")
failures = []

if not re.search(r"^on:", text, re.M):
    failures.append("no `on:` trigger block")
if not re.search(r"^  push:", text, re.M):
    failures.append("missing push trigger")
if not re.search(r"^  pull_request:", text, re.M):
    failures.append("missing pull_request trigger")

jobs_text = re.split(r"^jobs:$", text, flags=re.M)[1]
steps = re.split(r"^  ([a-z][a-z0-9-]*):$", jobs_text, flags=re.M)[1:]
pairs = list(zip(steps[0::2], steps[1::2]))
for job, body in pairs:
    if not re.search(r"^    timeout-minutes: \d+", body, re.M):
        failures.append(f"job {job}: no timeout-minutes")

for ref in re.findall(r"uses:\s*(\S+)", text):
    if "@" not in ref:
        failures.append(f"unpinned action: {ref}")
    elif re.search(r"@(main|master|HEAD)$", ref):
        failures.append(f"floating action ref: {ref}")

if not re.search(r"^  HNGH_CI: ", text, re.M):
    failures.append("workflow-level HNGH_CI not exported")

fixture = ROOT / ".github" / "fixtures" / "ci-store" / "run-1" / "record.lisp"
if not fixture.is_file():
    failures.append(f"missing session-store fixture: {fixture.relative_to(ROOT)}")
if ".github/fixtures/ci-store/run-1" not in text:
    failures.append("workflow never seeds the session-store fixture")

if failures:
    for f in failures:
        print(f"ci-keeper: {f}", file=sys.stderr)
    sys.exit(1)
print("ci-keeper: workflow contract intact "
      f"({len(pairs)} jobs, all pinned + bounded)")
