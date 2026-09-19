# High-level retirement pass — 1024-plan node census (2026-09-19)

Operator directive: high-level pass for eliminating useless nodes.
Direct synthesis from live plan_status (Version 2752): 459 completed,
205 ready, ~200 blocked, 7 failed, gates refused at cap.

## Mechanism note (why elimination = park + re-seed)

No node-removal path exists (verified by eagle: cleanup stops sessions,
resync_plan does not prune). Elimination therefore means: supersede the
plan. Park the 1024 plan permanently (inspectable), seed a fresh
successor plan carrying only the keep-list. The cap binds per plan, so
a fresh plan is unconstrained.

## Ready set (205) — keep vs retire by family

RETIRE (55 nodes, superseded/duplicate/superseded-by-waves):

| Family | Count | Why |
|---|---|---|
| ts-decision-map, ts-sdk-spike | 2 | SDK spike + decision map delivered in-session and by raccoon/bat artifacts |
| unsloth-beat-schedule, -clobber, -models-contexts, -signals | 4 | Superseded by Unsloth-contention wave (hngh-f7j/wc4/sy4 closed with evidence) |
| lanes-ratefit | 1 | lanes family done (roles wave + circulation-mechanics) |
| gastown-roles, ingest-surface | 2 | gastown verified nonexistent (hngh-h84 pattern); ingest covered by beads-gastown-ingest |
| jev-typesafe-verify | 1 | redundant with test-typesafe-wrapper.py 15/15 green |
| tombstone-* ready probes | ~21 | superseded by completed bd-conflict-evidence/-delete-update-resolve/-deleted-rewrite + banked tombstone records (pig/ox/ram/sauropod/owl/mosquito/lobster/ladybug) |
| dup-logs-* | 5 | dup census covered by completed beads-dup-* family |
| bili-cfg-cargo/compose/docker/makefile/packagejson/pyproject/tsconfig | 7 | config-existence probes; family gates passed; repo mapped (~/src/billion-context) |
| enc-creation-scripts, -ext-refs, -policy-refs, -sovereignty-catalog, entropy-scope-decision | 5 | archive-enc family: age/gpg/openssl/pass-env/keyring-seam completed; design recorded |
| gorust-* (6), go-java-scope | 7 | superseded by completed blm-* per-language + ca-* live matrix (koala) |
| perclient-* (5) | 5 | superseded by bili-cert-live-matrix (dove) + lang-matrix (penguin) |

KEEP (~150 nodes, live uncovered surface):

| Family | Count | Why |
|---|---|---|
| drift-links/todo/wip (drift-deps/docs/git completed) | 3 | real drift checks, cheap |
| prop-* (7), denylist-* (5), tmp-* (6) | 18 | uncovered secret/backup propagation surface |
| hermes-* (6) | 6 | hermes lane never audited |
| newspaper-* (4), screenshots, writers-* (5), wr-backup-script, wr-dash-lane, wr-modebits, wr-pub-paths, wr-tmp-use | 17 | artifact/PII sweeps uncovered |
| jcode-runtime, jcode-worker-format, jcode-config-schema-locate, jcode-config-tls-grep | 4 | jcode harness surface |
| gap-fsck/history-grep/pushdest/reflog/remote-refs (5) | 5 | git hygiene, cheap |
| py-certifi/-requests/-ssl-cert-*/-system-store, python-scope, curl-scope/-jobs-*/-lib/-proxy/-system-store/-tests, sysstore-* (5), storedb-* (5) | ~20 | CA/store deep probes beyond the completed matrix |
| failmode-ca-rotation-2, -combined-ca-2, -noproxy-2, -perms-2, -port-2, -proxycase-2, -staleproc-2 | 7 | failure-mode probes uncovered |
| spend-audit, spend-verify, keyfile-vs-value, key-material-flow, route-compare, opencode-go-endpoint, openrouter-endpoint | 7 | routing/budget surface |
| layout-bd-* (5), bd-ish probes (close-claim-next, stale-lease-close, gone-assignee-close, deferred-close, hookwire-* (3), loops-* (3)) | ~10 | beads machinery deep probes |
| rest (json-outputs, junit-xml, coverage, tests-audit, core-dumps, secret-scan-coverage, screenshots, mitm-auth/-errors/-failclosed/-parse, ps-visible, redact-coverage, remote-visibility-check, restore-paths, revoke-* (5), root-logs, spawn-path-trace, history-*, https-rewrites-asymmetry, ignore-hygiene, newspaper-*, hermes-* (6), env-tls-proxy-state, fail-legs-audit, enum-scratch-log-copies, entropy-scope-decision, enc-* overlap-check, truncation-class, updater-* (3), value-policy overlap-check, wr-* overlap, gh-pages/gastown check) | ~35 | genuine uncovered audit surface |

## Blocked set (~200): park, drain family-by-family

Already bead-banked where verified (hngh-2ya/277/292/cf2/n28 secret
families; fnu/twz/dqq plan-drain follow-ups). No retirement — the
families drain into synthesis records as waves reach them.

## Recommendation

1. Stop the current driver.
2. Park the 1024 plan (leave inspectable as the audit-of-record).
3. Seed the successor plan: ~150 keep nodes, deep mode, family gates.
4. Drive; retire verdicts ride the new plan's own gate.