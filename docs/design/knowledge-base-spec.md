# Knowledge base

The vault is canon; every reader is a lens over it, never a second vault.

Status: DESIGN — vault canon, viewer QoL, publisher options, flexibility
rule, from the operator's third-evening intake (session-notes §9),
2026-08-27.

Source: `../../docs/project/session-notes-2026-08-27.md` §9; the llm-wiki
vault (Obsidian-compatible markdown); the dashboard KB tab.

Cross-links: [ledger-and-records-spec.md](ledger-and-records-spec.md),
[display-register-spec.md](display-register-spec.md),
[../../docs/project/roadmap.md](../project/roadmap.md),
[../architecture-index.md](../architecture-index.md).

## 1. Canon

The markdown vault is the single source of truth: git-able, greppable,
engine-portable, LLM-writable. Conventions are the contract — frontmatter
(`id`, `type`, `created`, `source`, `status`, `tags`), wikilinks, atomic
notes, immutable source packets. Hngh's duty is to be a good vault
citizen: it never writes engine-specific markup, so every engine below
stays swappable and the store outlives all of them.

## 2. Viewer (KB tab QoL)

The tab's failure is presentation, not storage: a wiki-grade vault
deserves a wiki-grade reader. Prebuild a client-side index at kb-feed
time (MiniSearch-class — no server, no dependency): full-text search,
backlinks pane, tag/type facets, per-page table of contents, graph pane.
The index is a generated artifact; a missing or stale index degrades to
the current file list, never to silence.
The index stays bounded: rebuilt per kb-feed run over the current vault,
size-capped and regenerated on demand — a view artifact, gated behind
capture, never a second store.

## 3. Flexibility rule

The knowledge base is a directory plus conventions plus thin adapters.
Auto-detect at read time: an Obsidian vault registered on the host →
deep-link out (`obsidian://`); `mkdocs`/`quartz` installed → an optional
publish step appears; otherwise the internal viewer serves. Nothing in
the canon may require a specific engine — Hngh must be flexible enough
to use whatever the operator's system has available.

## 4. Publishers (long-term publications)

Candidates for the story-of-Hngh publication layer, all reading the same
vault: MkDocs Material (static site, search, versioning), Quartz
(Obsidian-native static), Wiki.js (live wiki, git-backed). The decision
is deliberately deferred to the first real publication; because the canon
is plain files, the choice is reversible at any time without migration.

## 5. Story of creation

Hngh documents its own development through the means that already exist
and only need curation: auto-captured trajectory and retro packets,
session notes, ADR-numbered records. Taxonomy: Sources / Decisions /
Sessions / Cases — the curation surface is the viewer (§2), never a
second store.

## 6. Non-goals

No wiki engine vendored in-tree; no daemon; no lock-in; no rewrite of
the vault to suit a viewer.
