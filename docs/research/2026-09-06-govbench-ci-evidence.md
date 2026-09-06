# What CI/CD systems publish machine-checkable evidence of change governance, and what do their artifacts cover?

Status: crystallized 2026-09-06 from research line `govbench-ci-evidence`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-govbench-ci-evidence.md.

I'll research this by examining both repositories. Let me start with the current repo and the hngh kernel repository structure.

<tool_call>
<function=bash>
<parameter=command>
echo "=== Current directory ===" && pwd && echo "" && echo "=== Top-level of current repo ===" && ls -la 2>/dev/null | head -60
</parameter>
<parameter=description>
Inspect current repository top level
</parameter>
</function>
</tool_call>
<tool_call>
<function=bash>
<parameter=command>
echo "=== hngh kernel repo top-level ===" && ls -la /home/bricker/Projects/etc/hngh 2>/dev/null | head -80
</parameter>
<parameter=description>
Inspect hngh kernel repository top level
</parameter>
</function>
</tool_call>
