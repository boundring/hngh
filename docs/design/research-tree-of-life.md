# Research tree-of-life

The research corpus grows as a flat intake (`research-subjects.txt`) into a
flat ledger (`research-lines.tsv`, headerless 4-col contract owned by
`jobs/research-routes.py:148-167` — untouched by design). What the corpus
lacks is shape: which line serves which stage of the roadmap, and where the
next question should branch. The tree-of-life is that shape, stored beside
the ledger instead of inside it.

## Model

- **Trunk** — one root node, `tree-root`: the project purpose (a
  side-effect-free governance kernel plus an automation surface that spends
  its time on expansive, productive work).
- **Branches** — one node per active roadmap stage (stages 0, 1, 2, 3, 5, 6,
  7; stage 4 is retired and never renumbered).
- **Leaves** — research lines (`research-lines.tsv` ids) and candidate
  seeds (`research-subjects.txt` ids) that hang under the stage they serve.
- **Question matrices** — Jev fan-out question graphs (fractal fan-out over
  the typesafe KB) do not live in the TSV; they are `question-node` kind
  rows in the knowledge DB (`~/.hngh/db/hngh-knowledge.db`, schema landed
  with the 2026-09-27 typesafe knowledge graph). The tree references them
  by id when one becomes a research line.

## Storage

`automation/research-tree.tsv`, three TAB columns:

    node	parent	line-id

`#` header documents the columns. `line-id` is the `research-lines.tsv` id
when the node is (or became) a line, else empty. Consumers (graph-data,
research-routes, a dashboard tree view) are wired by the follow-on lane
`arc-20260926-tree-of-life-wiring`.

## Long-horizon view

The tree's eventual visualization is a Nihei-esque megastructure map on the
newspaper front page: the trunk as the spine, stages as inhabited decks,
active lines as lit corridors. Seeds record: 2026-09-26 course-correction
seeds.
