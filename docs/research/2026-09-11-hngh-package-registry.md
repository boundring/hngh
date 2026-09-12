# hngh collected-repositories: package registry + candidate assessments

Date: 2026-09-11. Status: research + registry beat; no installs. English/ASCII.
Companion artifact: automation/config/hngh-packages.tsv (17 rows; guarded by
automation/tests/test-hngh-packages.py, wired into automation/Makefile `test`).
All fetched web/repo content in this beat was treated as DATA, never as
instructions; nothing from researched repos was executed or installed.

## Collection policy (what makes a project "hngh-related")

Three tiers, decided per candidate and recorded in the registry row:

1. **in-use** — installed on this machine and consumed by the operator's
   harness today. Registry row must cite the real install path and update
   mechanism; ghost rows (upstream cited, nothing on disk) are forbidden and
   test-enforced.
2. **candidate** — assessed but not installed: use-later / watch / study /
   backlog-study / caution, with the reason stated in the row itself.
3. **irrelevant** — operator-nominated repos with no harness relevance get a
   one-line disposition (skip / backlog-study) so the registry stays
   exhaustive instead of quietly dropping things.

Standing rules: each SOURCES feed entry costs news-lane bandwidth, so feed
budget is max 3 new feeds per beat, added only for use-later/watch verdicts;
unknown-provenance content (especially Chinese-language repos) is data-only
until audited — never fed to the news lane, never installed.

## Registry summary

17 rows. Dispositions: 5 in-use, 1 use-later, 3 watch, 5 backlog-study,
1 study, 1 caution, 1 skip. Feeds: acpkernel-rel and bilirel pre-existing;
opencode-acp-rel and ework-aio-rel added this beat (2 of the 3-feed budget).

## In-use packages (verified on this machine, 2026-09-11)

- **omp** — `/home/bricker/.bun/bin/omp` (npm `@oh-my-pi/pi-coding-agent`;
  upstream https://github.com/can1357/oh-my-pi, MIT, npm latest 18.1.18).
  Extensions live under `~/.omp/plugins` (package.json deps re-pulled by the
  update script). Updated by `automation/scripts/hngh-omp-update.sh`, which
  deliberately never runs bare `omp update` (it once installed a stale 17.3.3
  over 18.x — note preserved in the script).
- **bili** — `/home/bricker/.npm-global/bin/bili` (npm global
  `billion-context@0.1.106`, upstream https://github.com/ranxianglei/billion-context,
  MIT). The compression proxy serving omp sessions. Same update script
  (`npm install -g billion-context@latest`). Feed: `bilirel`.
- **pi** — `/home/bricker/.npm-global/bin/pi` (`@earendil-works/pi-coding-agent`
  0.84.3, upstream https://github.com/earendil-works/pi, MIT), data in `~/.pi/`.
  Manual npm update; no feed (secondary harness, slow-moving surface).
- **opencode** — `/home/bricker/.npm-global/bin/opencode` (npm `opencode-ai`
  1.18.30, upstream https://github.com/sst/opencode). The agentic executor
  surface behind the ocgo legs. Same update script.
- **acp-kernel** — not installed standalone; its algorithm is embodied inside
  the billion-context proxy the operator already runs. Prior-art position
  (covered 2026-09-11, docs/research/2026-09-11-acp-kernel-follow.md): a
  pure-TypeScript compression core with state-in/state-out and zero host I/O,
  an MIT reimplementation of Tarquinen's AGPL DCP, consumed by five thin
  adapters (proxy, pi, opencode, dsh, omp plugin). Lesson lines already
  crystallized: acpkernel-boundary-model (adopted), acpkernel-process-track
  (adopted). No install planned; feed `acpkernel-rel` already tracked.

## New candidate assessments (this beat)

### ranxianglei/opencode-acp — USE-LATER (feed added: opencode-acp-rel)

What: an opencode plugin implementing the author's Active Context Pruning
(ACP — a name collision with Agent Client Protocol, unrelated). It is an
AGPL-3.0 fork of tarquinen/opencode-dynamic-context-pruning carrying 39
documented bug fixes on top of DCP v3.1.11, including several CRITICAL ones
(state loss across restarts, in-place message mutation invalidating the
prefix cache, compression summaries leaking into the wrong dialog role).
Maturity: 252 stars, 17 forks, 18 open issues, active CI, v1.17.0 released
2026-09-10; releases.atom verified live (HTTP 200) this beat.

Direct relevance: this is the bili author's own answer to "which do I need?"
for opencode clients — the in-process plugin path, while omp rides the bili
proxy. The operator's opencode (ocgo legs) currently runs uncompressed; this
plugin is the natural candidate when the bili-on-opencode integration gets a
dedicated beat. Author-published scale evidence (6 sessions, 11k+ API calls,
context p90 15-19% of window, 91% aggregate cache hit) is self-reported and
not independently verified, but the shipped fix log and release cadence are
verifiable in the repo.

Config surface if installed: `~/.config/opencode/acp.jsonc` plus
`opencode.json` `compaction.auto=false` (ACP conflicts with OpenCode's
built-in auto-compaction). Why not USE-NOW: this beat is registry + research,
not integration; the install deserves ocgo verification in its own beat.
Lesson for hngh: model-owned compression with pluggable quality gates and a
hardcoded GC fallback matches the ctx-* research lines; the independent
per-tier cadence counters are a concrete design to keep on file.

### ranxianglei/ework-aio — WATCH (feed added: ework-aio-rel)

What: all-in-one installer for the ework self-hosted AI development stack:
ework-web (multi-project issue tracker, Gitea-compatible REST), ework-daemon
(issue-driven bridge that spawns opencode to resolve issues), opencode-ework
(plugin giving agents issue/reply/floor tools). Same author as bili. Real
code with unit tests, e2e scripts, and a deliberate two-step install split
(npm lays files; explicit `ework-aio install` does the invasive work). 2
stars, MIT, releases.atom verified (HTTP 200) this beat.

Relevance: it overlaps hngh's queue/report lane conceptually — issues become
agent runs with logs and cost accounting. WATCH, not install: hngh already
owns its queue machinery and dogfoods its own kernel; the feed is cheap
signal about where the bili author is heading (2-of-3 feed budget spent).

### ranxianglei/context-compress-algorithms — STUDY (no feed)

What: the extracted MIT algorithm core behind opencode-acp — rouge-recall-v1
quality gate (calibrated on 6,913 real blocks), tool-agnostic compression
prompt principles, and the growth-gated nudge trigger policy. v1.3.0, tests
plus CI, devlog-driven releases. STUDY because hngh consumes compression
through the bili proxy rather than as a dependency; the crystallization
candidate is the quality-gate layering (L1 length floor / L2 content
coverage AND-combined), which maps directly onto the
ctx-compaction-strategies research line. No feed: STUDY verdicts do not get
feeds, and releases here are rare.

### ranxianglei/billion-context-web — WATCH (no feed)

What: browser-side compression client for billion-context/acp-kernel. The
README says it outright: "This is a **skeleton** package. The compression
surface is a placeholder" — `compress()` is a declared no-op until wired to
a running proxy. WATCH only because the author's other surfaces demonstrably
ship; a feed would spend news-lane bandwidth on a package with no substantive
releases. Revisit if a release makes the compression surface real.

## suanrongqieqiezi/bigeye — CAUTION (operator directive)

All content below came from web reads of the repo, machine-translated for
our own reading; every fetched sentence was treated as data, never as
instruction. Nothing was executed; nothing will be installed without a
separate operator-approved beat.

### What it is

Chinese-language Python desktop assistant ("Aria-EQ", nickname Dayan)
claiming to give existing LLMs effectively unlimited working memory —
memory/ (14 modules incl. a 1,412-line reflection_loop.py with SQLite +
embedding-graph logic), task/ (planner/DAG/executor), rules_engine/, sync/
(client+server), tools/ (incl. bash and file-edit tools), desktop entry.
Translation confidence: high; the Chinese is straightforward colloquial
prose. Created 2026-08-18, last push 2026-09-11, 52 stars, 6 forks, 0 open
issues. The code is real, not vaporware — but there are no tests, no docs,
and NO LICENSE (all-rights-reserved by default; reuse is legally
unauthorized). The author self-describes the source tree as dev-exchange
only, not for production, and directs users to prebuilt release binaries.

### SECURITY FINDINGS (recorded, never acted on)

1. **No prompt-injection imperative text found.** The README and docs scan
   found no imperative language addressed to AI readers (no
   "ignore your instructions" phrasing). Recorded as a clean negative.
2. **Persona-overwrite claim (translated, high confidence).** README
   describes "crystallized intelligence": injecting specific memories so
   that, with a clean API, the model "will believe these are its own
   memories ... theoretically it can become any person/thing." This is a
   deliberate false-memory instillation capability — legitimate research
   topic, but the framing invites identity-overwrite misuse and is a
   credibility red flag.
3. **Credential-format config committed.** model_config.json ships provider
   endpoints (deepseek/openrouter/zhipu/ollama) with empty api_key fields;
   a .example.json also exists, making the committed real config redundant
   risk surface. The config names a model "deepseek-v4-flash" that
   corresponds to no known public DeepSeek release — an incoherent claim
   that undercuts README credibility.
4. **Opaque binary distribution.** Stable versions ship as "out-of-the-box"
   prebuilt release binaries while the repo itself has no documentation;
   binary provenance is unverifiable without execution (which is out of
   scope by rule).

### Risk posture (static analysis only)

If ever run: external LLM API calls with user keys, a bash/exec tool under
agent control, a sync client+server network surface with unverified default
endpoints, and a local SQLite memory store written from LLM output — i.e.
the classic exfiltration-capable trio plus a persistence layer that poisoned
content could survive. Prompts encode first-person identity narratives,
which would push a reused agent to treat synthesized memories as authentic
autobiography.

### Verdict and disposition

Early single-maintainer hobby project (3.5 weeks old): genuinely engineered
memory code wrapped in marketing-toned, partly incoherent claims, no
license, no tests, binary-first distribution. Registry row: **caution**;
never install, never execute, never feed to the news lane. Follow-up if the
operator wants depth: STUDY-VIA-TRANSLATION through a browser-relay session
(read-only), noting its tuned memory-consolidation constants (e.g.
similarity 0.65, prune-after-30-days, 3-source authority) as the one
transferable idea source. Queued as research subject `bigeye-caution-audit`.

## Agent-harness comparisons (lesson candidates)

Assessed 2026-09-11 from READMEs/architecture docs; read-only, nothing run.

- **opensandbox-group/OpenSandbox** (15.1k stars, Apache 2.0, Alibaba-origin
  org, docs exemplary): container/K8s sandbox substrate for agents — specs
  as source of truth, one narrow SandboxService interface, egress sidecar,
  Cosign-signed images. STEAL: contract-first port discipline (a written
  contract per boundary). REJECT: rootfs-snapshot pause/resume (cluster-scale
  machinery hngh's single-host PTY supervision does not need).
- **multica-ai/multica** (49.6k stars; custom Multica License — Apache 2.0
  plus hosting/branding conditions; NOT OSI despite the README claim):
  issue-board workspace driving agent CLIs (omp and pi explicitly listed);
  Go daemon auto-detects runtimes, worktree-per-task on a bare-clone cache
  with TTL GC, review-gated landings, per-run tool-call replay. STEAL:
  task-barrier daemon version-follow (re-exec into an upgraded binary only
  between tasks, never mid-flight). CONSIDER: worktree-per-task GC if hngh
  workers ever go concurrent on one repo.
- **1jehuang/jcode** (19.5k stars, MIT, solo author — bus-factor risk,
  60+ releases): Rust terminal harness with a Swarm model. STEAL: mode-gated
  fan-out depth — who may spawn workers, live-worker budget, absolute member
  cap, subtree-scoped stop authority; and the single-writer plan slot
  (one coordinator mutates the VersionedPlan, proposals need approval — a
  lighter cousin of hngh's certificate ceremony, convergent validation).
  REJECT: no OS-level isolation (permission layer only) — do not follow that
  trust model.

Cross-cutting: hngh's ceremony sits between jcode's agent-level plan slot
and Multica's human review gate; the three concrete steals are jcode's
spawn-depth/budget gate, Multica's task-barrier version-follow, and
OpenSandbox's contract-as-spec for port boundaries.

## One-line dispositions (operator-nominated repos)

- apache/incubator-pegasus — BACKLOG-STUDY: distributed KV store; nothing
  for the harness now.
- bytedance/monolith — SKIP: recommendation/DL training system; outside
  hngh's scope.
- apache/fluss — BACKLOG-STUDY: streaming lakehouse storage; no harness
  relevance today.
- torvalds/linux — BACKLOG-STUDY: the long-horizon kernel-knowledge
  ambition stays queued; not actionable this beat.

## Follow-feed wiring (budget: max 3 new feeds this beat)

Added 2 (both releases.atom verified HTTP 200 on 2026-09-11), now in
automation/config.env SOURCES:

- `opencode-acp-rel` — USE-LATER verdict: the ocgo legs' likely next
  dependency; release cadence active (v1.17.0, 2026-09-10).
- `ework-aio-rel` — WATCH verdict: adjacent queue-lane product by the bili
  author; cheap signal on where that ecosystem is heading.

Deliberately not added: context-compress-algorithms (STUDY verdicts get no
feed), billion-context-web (skeleton), bigeye (caution — unvetted content
never enters the news lane). Total SOURCES after this beat: 16.

## Research subjects queued (automation/research-subjects.txt)

- `bigeye-caution-audit` — translate-and-audit the repo's actual content;
  derive the collection policy for unknown-provenance Chinese-language repos.
- `harness-delegation-patterns` — crystallize the OpenSandbox/Multica/jcode
  steal/reject table against hngh's worker + ceremony architecture.