# Multi-project design — Hngh as a development machine for more than itself

Status: designed 2026-09-08. Cistern (an external emacs roguelike at
`~/Projects/etc/20260830/cistern`, ~17K LOC elisp) becomes the second
project Hngh serves, after Hngh itself. This doc fixes the shape of
that relationship before machinery accretes: what generalizes, what
stays per-project, and where the boundary sits.

## 1. The relationship in one sentence

Hngh provides research, review, disposition, and context for its
projects; each project's own build/test/commit cycle remains its own.
Hngh is the machine's governance and orientation tier, not a second
build system. Cistern already proved the method independently — its
4-phase rewrite + UX cycle ran the roguelike loop with its own ledger,
retro, and runner (hngh
docs/project/roguelike-agentic-field-report.md). Multi-project makes
that support standing machinery instead of a one-off overlap.

## 2. The project registry

One registry, one row per project — the tsv Hngh reads when routing
work or generating packs:

```tsv
# project<TAB>repo<TAB>test-command<TAB>context-pack-role<TAB>key-files
hngh	$HOME/Projects/etc/hngh	make -C automation test	hngh	automation/lib/, docs/
cistern	$HOME/Projects/etc/20260830/cistern	emacs -Q --batch -l tests/run.el -f cistern-run-all-tests	cistern	src/cistern-domain.el src/cistern-game.el src/cistern-view.el
```

Today the cistern row lives inline in `automation/lib/context-pack.sh`
(`context_project_block`); the registry becomes a file when a second
consumer needs it — a spec in a design doc is not yet a second reader,
and no file is added before one exists (YAGNI, the Compass's own rule
against a second pack builder applies to registries too).

## 3. What generalizes

- **context_pack** (`automation/lib/context-pack.sh`) already takes
  ROLE SLUG; a role that names a project dispatches through
  `context_project_block` for repo path, architecture map, key files,
  test command, dirty-file status, and wiki lesson pointers — the same
  <=1500-byte cap, the same single generator, no second pack builder.
  Both launch paths (lib/launch-session.sh, jobs/agent-respawn.sh)
  consume it unchanged.
- **Research subjects** (`automation/research-subjects.txt`) take a
  project-scoped slug prefix (`cistern-*`, as `govbench-*` and `ctx-*`
  already do) so a research beat can generate project-specific lines
  and the Delve station routes them; each still lands with a named
  consumer.
- **The disposition spine** (verdict → report-queue → ledgers) handles
  findings from any project — a finding is a finding; the identity
  keying already namespaces by source.
- **Cadence parameters** (`automation/cadence-params.tsv`) carry
  per-project tunables as new rows with a project prefix in the key
  when a project needs one; nothing else changes.

## 4. What does NOT generalize

- **The kernel ceremony** (hngh docs/design/ — Keyring, Mirror,
  Lexicon, propose/issue-cert/mutation-check) is Hngh-specific
  governance of Hngh's own mutations. It never reaches into another
  repo; Cistern has its own discipline (red/green pairs, failure
  ledger, PROCESS-RETRO P1–P6) and it is not Hngh's to replace.
- **The automation tier's gate** (`make -C automation test`,
  bash -n + the suite) proves Hngh's automation only. Each project
  runs its own gate; Hngh sessions working on Cistern run the Cistern
  runner, never a Hngh make target, and vice versa.
- **Commit authority.** Hngh commits Hngh repos with explicit-path
  staging. In a project with its own active session (Cistern, 2026-09:
  the operator's other omp session owns the working tree), Hngh
  observes — packs may report dirty-file status, Hngh never edits,
  stages, or commits those files.

## 5. The boundary (the whole doc in four lines)

| Hngh does | The project does |
|---|---|
| context packs, orientation, wiki lessons | its own build, test, commit |
| research subjects + beats routed at it | its own architecture decisions |
| review/disposition of findings about it | its own ledger and ceremony |
| dirty-file *status* (read-only git probes) | its own working tree |

## 6. Cross-links

- [context-manager.md](context-manager.md) — the Compass; the context
  pack pattern that generalizes per project via
  `context_project_block`.
- [operator-mirror.md](operator-mirror.md) — the corpus; a second
  project widens what the Mirror observes and must stay derived data
  for both.
- hngh docs/project/roguelike-agentic-field-report.md — the field
  evidence that the method already runs on a second repo.
