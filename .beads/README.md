# Beads - AI-Native Issue Tracking

Welcome to Beads! This repository uses **Beads** for issue tracking - a modern, AI-native tool designed to live directly in your codebase alongside your code.

## What is Beads?

Beads is issue tracking that lives in your repo, making it perfect for AI coding agents and developers who want their issues close to their code. No web UI required - everything works through the CLI and integrates seamlessly with git.

**Learn more:** [github.com/steveyegge/beads](https://github.com/steveyegge/beads)

## Quick Start

### Essential Commands

```bash
# Create new issues
bd create "Add user authentication"

# View all issues
bd list

# View issue details
bd show <issue-id>

# Update issue status
bd update <issue-id> --claim
bd update <issue-id> --status done

# Sync with Dolt remote
bd dolt push
```

### Working with Issues

Issues in Beads are:
- **Git-native**: Stored in Dolt database with version control and branching
- **AI-friendly**: CLI-first design works perfectly with AI coding agents
- **Branch-aware**: Issues can follow your branch workflow
- **Sync-ready**: Uses Dolt remotes for backup and team sharing

## Close-with-Evidence Convention (project rule)

Every close must carry verifiable evidence. Never close with an empty
or vague reason.

1. **Close reason with hashes/files/validation** (required):
   ```bash
   bd close <id> --reason "Fixed <what>. Commit abc1234. Files: path/to/file.py:42. Validation: make test passed."
   ```
   The reason must name: what changed, the commit hash, touched
   files (with line refs where useful), and the validation run
   (test/lint command plus result).
2. **Comment linkage**: for non-trivial work, add a `bd comment <id>`
   linking the evidence (commit hash, PR, test output) so the audit
   trail survives even if the close reason is terse.
3. **Acceptance criteria on open beads**: when creating or updating an
   open bead, record acceptance criteria explicitly
   (`bd create --acceptance "..."` / `bd update <id> --acceptance "..."`),
   so the close reason can be checked against them.

Rationale: closes without evidence are unauditable. Hashes let anyone
re-verify the change, file refs locate it, validation proves it works,
and AC on open beads defines "done" before work starts.

## Why Beads?

✨ **AI-Native Design**
- Built specifically for AI-assisted development workflows
- CLI-first interface works seamlessly with AI coding agents
- No context switching to web UIs

🚀 **Developer Focused**
- Issues live in your repo, right next to your code
- Works offline, syncs when you push
- Fast, lightweight, and stays out of your way

🔧 **Git Integration**
- Dolt-native sync via bd dolt push / bd dolt pull
- Branch-aware issue tracking
- Dolt-native three-way merge resolution

## Get Started with Beads

Try Beads in your own projects:

```bash
# Install Beads
curl -sSL https://raw.githubusercontent.com/steveyegge/beads/main/scripts/install.sh | bash

# Initialize in your repo
bd init

# Create your first issue
bd create "Try out Beads"
```

## Learn More

- **Documentation**: [github.com/steveyegge/beads/docs](https://github.com/steveyegge/beads/tree/main/docs)
- **Quick Start Guide**: Run `bd quickstart`
- **Examples**: [github.com/steveyegge/beads/examples](https://github.com/steveyegge/beads/tree/main/examples)

---

*Beads: Issue tracking that moves at the speed of thought* ⚡
