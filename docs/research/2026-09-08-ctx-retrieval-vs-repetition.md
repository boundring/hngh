# At equal task quality, when do orientation pointers (retrieval) beat inlined content (repetition) for session input cost, and how does the 1500-byte pack cap trade off?

Status: crystallized 2026-09-08 from research line `ctx-retrieval-vs-repetition`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-ctx-retrieval-vs-repetition.md.

I'll explore the repository structure and the hngh kernel to ground my findings. Let me start by understanding what's available.

<tool_call>
<function=Bash>
<parameter=command>
pwd && echo "---CWD---" && ls -la && echo "===HNNG===" && ls -la /home/bricker/Projects/etc/hngh 2>/dev/null || echo "===HNNG NOT FOUND at that path==="
</parameter>
<parameter=description>
Show current directory and check hnng kernel existence
</parameter>
</function>
</tool_call>
