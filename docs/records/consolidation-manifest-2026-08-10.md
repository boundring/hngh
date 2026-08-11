# Consolidation manifest — 2026-08-10

**Transaction:** pre-consolidation project documentation archive
**Authority:** operator-directed cleanup
**Method:** `git mv` for legacy tracked material; an empty new `.hermes/plans/` is the future planning scratch area. Content files were not textually edited during the move.

## Recovery

- `git status` identifies the staged rename map.
- `git restore --staged <path>` and `git restore <path>` recover a mistaken move before commit.
- Git history remains the authoritative path/history recovery mechanism after commit.
- Compatibility aliases preserve the former documented paths while the archive is the physical storage location.

## Archive receipts

The digest is a SHA-256 over the sorted multiset of SHA-256 content digests for each group. It is independent of file names and archive paths.

| Source | Archive location | Files | Content-set SHA-256 | Replacement / status |
|---|---|---:|---|---|
| `docs/design/` | `legacy-docs/design/` | 67 | `f1a186b0d5ac24e0931ecf42de8648e201e45a8cee9c60c5edd6d30476a4bb98` | `docs/core/`; compatibility alias |
| `docs/project/` | `legacy-docs/project/` | 7 | `9d42ee1cfec5b28061a9a7692c77e829e54f52bbdb2e739d9a9933fe99c07f1b` | `docs/core/delivery.md`, `docs/records/`; compatibility alias |
| `docs/journal/` | `legacy-docs/journal/` | 14 | `61be2f0d24b5518b4a2507fbce2aaed278862d2bdf851406c8ae605bb293ab58` | dated `docs/records/`; compatibility alias |
| `docs/research/` | `legacy-docs/research/` | 4 | `e6cadc24fd8f42b0a10364a2673eeed3669a0419d724e02c34e54deea149cd1a` | task-scoped archive source; compatibility alias |
| `docs/guides/` | `legacy-docs/guides/` | 2 | `c760a88071fd243fe80f12e12f6cac71ed71e620aecc96b2e966a990d4e84bec` | core/documentation index; compatibility alias |
| `docs/prompts/` | `legacy-docs/prompts/` | 1 | `aa5d843c21d8030ad8e4dfd4893232739eeb924786712bcc89dc1a214115f2de` | task-scoped archive source; compatibility alias |
| `docs/review/` | `legacy-docs/review/` | 1 | `bb71d2595eb02d718dc9e3df37a0b31a32052521ae6c9b25e55cc31a8b894cfd` | current hold index; compatibility alias |
| `sessions/` | `legacy-sessions/` | 13 | `eb8101114f913a1b92af45ffeee2836a85a72f0ac66520089668a5aeb40bd3a9` | historical; root compatibility alias |
| `journal/` | `legacy-journal/` | 15 | `9929bf8f2afbb7304df077dfa9505710ce6e3e4835eed5edad3b598c4719ba08` | historical; root compatibility alias |
| `.hermes/plans/` | `legacy-plans/` | 6 | `a66703c38ecd8fb10e135b89debd10e43d74491921c342dfacad0a8a44bac8a5` | future plans use new empty `.hermes/plans/` |

**Total moved content files:** 130. Git records 129 tracked files as `R100` moves. The remaining file, `2026-08-10_214507-hngh-documentation-reorientation.md`, was already untracked; its archived content-set receipt is included in the `plans` row.

## Compatibility aliases

| Former path | Resolves to |
|---|---|
| `docs/design` | `docs/archive/2026-08-10-pre-consolidation/legacy-docs/design` |
| `docs/project` | `docs/archive/2026-08-10-pre-consolidation/legacy-docs/project` |
| `docs/journal`, `docs/research`, `docs/guides`, `docs/prompts`, `docs/review` | corresponding `legacy-docs/` directory |
| `sessions` | `docs/archive/2026-08-10-pre-consolidation/legacy-sessions` |
| `journal` | `docs/archive/2026-08-10-pre-consolidation/legacy-journal` |

These aliases are compatibility infrastructure. Fresh documentation and fresh agent context use only `docs/core/` and `docs/records/`.

## Exclusions

No runtime/workbench data under `~/.hngh/`, no source/configuration, no test artifact, and no external backup tree was moved. The existing dirty planner-fixture test remains an independent review boundary.
