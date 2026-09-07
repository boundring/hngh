# What prior art exists for procedural voting on changes (sign-offs, LGTM counts, quorum rules) and how is it scored?

Status: crystallized 2026-09-07 from research line `govbench-voting-prior-art`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-govbench-voting-prior-art.md.

I'll research this by exploring the hngh kernel repository to find prior art for procedural voting mechanisms. Let me start by understanding the repository structure.

<tool_call>
<function=Bash>
<parameter=command>
ls -la /home/bricker/Projects/etc/hngh 2>/dev/null && echo "---GITLOG---" && cd /home/bricker/Projects/etc/hngh && git log --oneline -10 2>/dev/null
</parameter>
<parameter=description>
List hngh repo root and recent commits
</parameter>
</function>
</tool_call>
