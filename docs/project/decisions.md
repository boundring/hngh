# Decisions — Lightweight Decision Log

**Last updated**: 2026-06-22

This is a lightweight log of day-to-day decisions that don't warrant a full ADR.
Architecture-level decisions live in `docs/design/architecture-decision-record.md`.

---

## 2026-06-22

### D-001: Wipe existing GitHub repo
**Context**: GitHub boundring/hngh had a prior shell/Python implementation with 15 ADRs, working code, AUR packaging, and CI. The new SBCL CL architecture is a fundamental redesign.
**Decision**: Wipe completely, start from scratch. No preservation of prior work.
**Rationale**: The prior work was a different architecture (shell/Python vs. SBCL CL microkernel). Preserving it would create confusion. The prior ADRs, while valuable, are superseded by the new design spec's 11 locked decisions (D1–D11).

### D-002: GitHub as primary, Codeberg as push mirror
**Context**: Dual-remote setup needed. GitHub has better project management (Projects V2, issues, milestones). Codeberg provides a non-corporate mirror.
**Decision**: GitHub is the single source of truth for project management (issues, projects, milestones, PRs). Codeberg is a code mirror only — commits sync, but issues/PRs are GitHub-only.
**Rationale**: No reliable bidirectional issue sync exists between GitHub and Codeberg. Maintaining issues in two places creates drift. GitHub Projects V2 has no Codeberg equivalent.

### D-003: AGPL-3.0 license
**Context**: Need to choose a license for Hngh.
**Decision**: AGPL-3.0-or-later, matching the prior repo's choice (ADR 0004).
**Rationale**: The prior project chose AGPL-3.0 to match Unsloth Studio, which Hngh integrates with. AGPL ensures network-facing services share modifications. Preserving this decision from the prior iteration.

### D-004: Planning docs in docs/project/
**Context**: Need git-visible work state tracking alongside GitHub issues.
**Decision**: Add `next.md` (current work), `done.md` (completed log), `backlog.md` (future queue), `decisions.md` (this file) to `docs/project/`.
**Rationale**: GitHub issues are the canonical tracker, but git-visible planning files give a quick "what's happening" view without opening GitHub. Maintained by hand or by agentic tools during work sessions.