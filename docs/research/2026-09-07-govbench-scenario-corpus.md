# What scenario corpus (benign, adversarial, partial-failure changes) exercises a governance benchmark honestly?

Status: crystallized 2026-09-07 from research line `govbench-scenario-corpus`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-govbench-scenario-corpus.md.

I'll research this by exploring both repositories, grounding every claim in concrete file paths. Let me start by understanding the structure of both.

<tool_call>
<function=Bash>
<parameter=command>
pwd && echo "=== TOP LEVEL ===" && ls -la
</parameter>
<parameter=description>
Show current directory and contents
</parameter>
</function>
</tool_call>
<tool_call>
<function=Bash>
<parameter=command>
echo "=== hngh kernel top level ===" && ls -la /home/bricker/Projects/etc/hngh 2>&1 | head -80
</parameter>
<parameter=description>
List hngh kernel repository contents
</parameter>
</function>
</tool_call>
