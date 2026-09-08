# Which structured brief fields measurably cut reorientation tokens after a session death, and which fields are noise?

Status: crystallized 2026-09-08 from research line `ctx-structured-briefs`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-ctx-structured-briefs.md.

<tool_call>... Maybe we are to continue from that? We can run tools now. Need maybe current date is 2026-09-07 but beat says 2026-09-08 (future?) irrelevant.

We need investigate repository: likely current repo? The prompt says "Ground every claim in this repository and the hngh kernel repository (/home/bricker/Projects/etc/hngh)". We need know what "this repository" is. Could be cwd, maybe /home/bricker/Projects/etc/hngh? It says kernel repository at that path. Maybe current repo is some research process repo? Need find research-lines.tsv. The prior tool call would locate it. We can run commands.

Need be careful: cite concrete file paths only where confident they exist. We can verify via tools. Need maybe not overclaim. Need final structured summary with findings, recommendations, open threads. Since contracting/crystallize line, likely no more experiments? But we need ground claims in repo. We need inspect files related to structured brief fields, reorientation tokens after session death. Maybe there are logs, metrics, scripts. Need identify which fields measurably cut reorientation tokens and which are noise. Could be from data in repository: maybe "briefs", "reorient", "session", "tokens". Need search.

Let's start with broad exploration. Use Bash to list /home/bricker/Projects/etc/hngh, pwd, find research-lines.tsv. Also maybe current repo is not that path? The prompt says kernel repository at /home/bricker/Projects/etc/hngh. We can inspect both.

Need likely use multiple tool calls. Let's do initial exploration.


<tool_call>
<function=Bash>
<parameter=command>
echo "=== KERNEL REPO ==="; ls -la /home/bricker/Projects/etc/hngh 2>&1 | head -100; echo; echo "=== PWD ==="; pwd; echo; echo "=== FIND research-lines.tsv ==="; find / -name "research-lines.tsv" 2>/dev/null | head
</parameter>
<parameter=description>
Check kernel repo, cwd, and locate line state file
</parameter>
</function>
</tool_call>
