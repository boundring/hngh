# Secret Scan Report — Hngh repository

**Date:** 2026-08-24
**Branch scanned:** `main` (HEAD `dafce3e`), `wip-public-readiness`, all other refs, reflogs, and unreachable objects
**Total commits scanned (all refs):** 457 — `git log --all` (89 of these are `refs/omp-undo-redo/history/*` evidence-only snapshots)
**Extra scans:** reflog-walk (`git log -g --all`, 861 entries), 115 unreachable commits (`git fsck` + `--no-walk` per commit), 63 loose trees, 45 loose blobs, current working tree (`git ls-files` only; untracked `.omp/` excluded per scan contract)
**Tooling:** pattern-based scanner (gawk engine over `git log -p -U0`), 12 pattern classes. No gitleaks/trufflehog installed; this is the closest available equivalent. No entropy detection.

## Verdict: NO PLAUSIBLE REAL FINDINGS

All 64 unique findings are **test fixtures**, **detector-rule literals**, or **false positives** (keyword adjacency, model names, documentation). **Zero** API keys, private keys, passwords, AWS/Slack/Stripe/GitHub tokens, JWTs, or embedded-credential URLs were found anywhere in reachable history, reflogs, unreachable commits, loose objects, or the working tree. **No history rewrite is required.**

## Method (per launch-checklist contract)

1. `git log --all -p -U0` → pattern engine over every patch line (adds and deletes).
2. `git log -g --all -p -U0` (reflog walk) → finds nothing the first pass missed (all reflog hits are duplicates of pass 1 findings — see Gate honesty).
3. `git fsck` equivalents: 115 unreachable commits, each scanned individually via `git log --no-walk <id> -p -U0`; 45 loose blobs + 63 loose trees scanned with the same engine → **0 hits**.
4. Working tree: `git grep` of HEAD tree and tracked working-tree files → **0 hits**.

## Bucket counts (unique findings, deduplicated)

| Bucket | Pattern essence | Unique hits | Result |
|---|---|---|---|
| P1 | `(api[_-]?key|secret|token|password|credential|auth)[:=]` + value | 34 | all keyword-prose / fake fixture values |
| P2 | `BEGIN (RSA|OPENSSH|EC|DSA|PGP) PRIVATE KEY` | 2 | 1 string literal in detector self-test (seen at 2 commits) |
| P3 | AWS `AKIA…` | 0 | — |
| P4 | `ghp_` / github 30+ token formats | 2 | 1 literal placeholder-string in sentry self-test |
| P4b | `gho_/ghu_/ghs_/ghr_` formats | 2 | 1 regex *rule* in retired detector code |
| P5 | Slack `xox[baprs]-` | 0 | — |
| P6 | Stripe `sk_live_` | 0 | — |
| P7 | `-----BEGIN CERTIFICATE` | 0 | — |
| P8a/b | provider name (openai/anthropic/kimi/xai/gemini) + `sk-`/32-char run | 0/22 | all false positives (model names, prose, type names) |
| P9 | URL embedded creds `https://user:pass@` | 0 | — |
| P10 | DB connection URLs | 0 | — |
| P11 | JWT `eyJ…` | 0 | — |
| P12 | `Authorization:` headers | 2 | 1 test string `Bearer open-key` |

Total unique finding lines: **64** across **12 commits** (2026-06-22 → 2026-08-11). No finding predates 2026-06-22 (repo creation, `9dd7c1384d12`).

## Anchored findings by classification

Masking rule: `first4…` for any value that could be a credential; fixture values that are unambiguous fake data are shown verbatim for operator judgment.

### FIXTURES — deliberate fake values in test code (safe, retained for review)

| Commit | Date | Path:line | Content (masked where needed) | Bucket |
|---|---|---|---|---|
| `f45c5c7d1370` | 2026-06-23 | `tests/unit/test-secrets-manager.lisp` (later retired) | `set-secret :protected-key "shhhh"`, `:accessed-key "ok-value"`, `:pre-lock-key "pre-lock-val"`, `:overwrite-key "v1"/"v2"`, `:valuable-secret "SUPER-SECRET-VALUE-123"`; plugin names `evil-plugin`, `good-plugin`, `safe-plugin`, `updater` — all synthetic | P1 (8 lines) |
| `905ea2fd4b50` | 2026-06-24 | `tests/unit/test-ai-tool-hub.lisp:289` | string literal `"Authorization: Bearer open-key"` — test assertion for the tool hub | P12 |
| `1a54dbd15470` | 2026-08-09 | `tests/scripts/test-seat-dashboard.sh:307` | sample seed payload `api_key: UNSLOTH_API_KEY` (unsloth is a free-tier notebook provider; sample variable, not a credential) | P1 |
| `e7d6a7cfb89e` | 2026-07-31 | `sessions/2026-07-31-night-run.md` | `:local-openai-api` rebound to local ollama :11434 — session notes, no credential | P8w |

These live in `tests/`/session notes only, contain zero real values, and were all removed in the clean-slate kernel (see below).

### FUNCTIONAL LITERALS — detector rules / harness mask formats, not credentials

| Commit | File | Content | Note |
|---|---|---|---|
| `0030153c9f29` | `src/plugins/sentry.lisp:23` (retired) | `("github-oauth" . "gho_[A-Za-z0-9]{36}")` | regex **pattern** for the retired sentry detector — the rule, not a token. Retired with the daemon. |
| `0030153c9f29` | `tests/unit/test-sentry.lisp:28` | `-----BEGIN RSA PRIVATE KEY----- and more` | self-test string proving the detector fires on the literal |
| `0030153c9f29` | `tests/unit/test-sentry.lisp:34` | `token ghp_abcdefghijklmnopqrstuvwxyz0123456789 here` | the harness's own credential-mask placeholder format; the value is a placeholder token, not a real masked secret |

### DOCUMENTATION / FALSE POSITIVES — keyword adjacency in prose and code

| File | Content | Why FP |
|---|---|---|
| `docs/design/integrations.md:312,700` (and `docs/archive/*` copies) | `:secrets (:anthropic-api-key :google-api-key :openai-api-key)` | config key **names** in design docs |
| `src/packages.lisp` docstring | model route table: `openai-api`, `kimi-k3`, `deepseek-v4-flash`, prices | model names, not tokens |
| `emacs/README.md` + `emacs/hngh-mc.el` | `opencode (kimi-k3)` | model name comments |
| `docs/design/coordination-patterns-research.md` | OpenAI SDK guardrails, `OutputGuardrailTripwireTriggered` | prose + long CamelCase type-name tripping the 32-char-run rule |
| `docs/project/work-sessions.md` | `:local-openai-api` tool member | symbol name, no secret |
| `sessions/*.md`, `docs/archive/**` | night-run session logs | local-model experimentation notes |

All P8-family hits (provider-key class, 22 lines total) are the above model names/tool symbols, never values adjacent to a provider key.

## Retired-era plugin inventory (for the record)

The old daemon system (`src/plugins/*`) was retired on 2026-08-11 by commit `86aee764675d` ("refactor!: establish clean-slate kernel"). Its file content scanned produced exactly the one regex literal and two test strings above — no real secrets. Full 36-file list at `136738e05729`: acp-client, acp-transport, agents-md, ai-orchestrator, ai-tool-hub, backup-manager, beans, config-watcher, dashboard-tui, dbus-bridge, emacs-daemon, file-watcher, fragment-journal, hngh-coord/, hngh-planner, hngh-up, hnghbeats, knowledge-base, llm-threat-detector, maintenance-coordinator, mission-control, model-routes, model-runtime, package-manager, prompt-lint, quota-spreader, secrets-manager, sentry, signals, situation-casebase/-detectors/-judge/-scoring, squad-dispatch, squad-resources, system-config.

## Gate honesty

- **Pattern coverage limit:** no entropy detection (short/high-entropy custom tokens can escape); the expanded P1 keyword class compensates for names like `protected-key`. Binary blobs can't be read as text; the 45 loose blobs all failed to match when checked with the same patterns.
- **Reflog coverage:** a reflog stores only commit IDs + rationale, not diffs, so "pattern applied across reflogs" is impossible in the literal sense. Equivalent coverage was achieved by walking every reflog entry with `git log -g --all -p` plus scanning all 115 unreachable objects — the only content reachable solely via reflogs. **No content exists solely in reflog-addressed commits that was not scanned.**
- **omp-undo-redo refs (89):** omp's own turn-boundary snapshots (`omp-undo-redo: before turn`), stored as local refs, never pushed, each a root commit mirroring the full tree; scanned in every pass — zero hits.

## Conclusion

Repository is **public-ready for secrets** as of 2026-08-24 (`main` @ `dafce3e`): no real credentials in any reachable/unreachable/loose object, working tree, or reflog. The 12 flagged commits are all test fixtures or documentation/prose. Optional hardening: install `gitleaks` for pre-commit CI, covering entropy detection this manual pass cannot.