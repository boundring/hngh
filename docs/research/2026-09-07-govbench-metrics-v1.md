# Which metrics make tamper-evidence, approved=executed, reconstruction-from-record, and refusal-accounting measurable?

Status: crystallized 2026-09-07 from research line `govbench-metrics-v1`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-govbench-metrics-v1.md.

I'll start by exploring the repository structure to ground my findings in what actually exists.

<tool_call>
<function=Bash>
<parameter=command>
pwd && echo "===CWD===" && ls -la && echo "===HNHG KERNEL===" && ls -la /home/bricker/Projects/etc/hngh 2>&1 | head -80
</parameter>
<parameter=description>
Inspect current directory and hngh kernel repo
</parameter>
</function>
</tool_call>
