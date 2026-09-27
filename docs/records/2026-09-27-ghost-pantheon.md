# 2026-09-27 — Ghost pantheon expansion (course-correction slice 4)

## What landed

- `automation/config/ghost-voices.tsv` — the pantheon roster: 4 columns
  (ghost-name TAB era TAB register TAB convictions), `#`-comment header.
  Rows 1–17 are a documentary distillation of the tao-confucian-canon
  `voices/pantheon.json` (canon is read-only evidence; import copies
  register + first two convictions, nothing else). Rows 18–39 are 22
  natively authored ghosts: Kafka, Nietzsche, Voltaire, C. S. Lewis,
  García Márquez, Faulkner, McCarthy, van Vogt, Lem, Norton, Brunner,
  Bradbury, Ellison, Mann, Joyce, Kerouac, Fitzgerald, Campbell, Jung,
  Card, Lee, Wittgenstein. 39 rows, all 4-column, no duplicate names.
- `automation/lib/ghost-voices.py` — `ghost_counsel()` for the digest
  editorial slot that slice 2's `email-digest.py ghost_editorial()`
  importlib seam has been waiting on. Deterministic daily blend
  (`sha1(date-8h-slot)` seeded sample of 3 distinct ghosts), one Xiaomi
  MiMo one-shot through `lib/model.sh xiaomi_chat` (the slice-5 pacer
  will bound this leg; counsel adds at most 6 calls/24h of its own via
  stamp files in `<home>/db/ghost-state/`). Every failure path returns
  None — decoration, not data. Env seams: `HNGH_GHOST_TSV`,
  `HNGH_GHOST_STATE`, `HNGH_GHOST_STUB` (canned answer, tests),
  `HNGH_XIAOMI_CMD` (bridge override). The bridge injects
  `AUTOMATION_ROOT` like the `jobs/news-articles.py` precedent —
  `lib/model.sh` sources `lib/` relative to it. Counsel output is
  collapsed to one line and refused if it mentions stale/expired/
  unverified: the ghosts have no machine view and must not invent one.
- `automation/tests/test-ghost-voices.py` — 6 hermetic cases (roster
  completeness, deterministic distinct pick, cap blocks at 6 fresh
  stamps, old stamps ignored, bridge failure fail-closed, empty answer
  fail-closed). Registered in `automation/Makefile test`.

## Key facts

- Xiaomi credential: 1Password item "Xiaomi AI" (Hngh Secrets vault,
  id `hxw2g6xkg25pktnhxvw2z3wm2m`, single password field) materialized
  to `~/.config/hngh/xiaomi-key` mode 600 — the exact seam
  `xiaomi_chat` resolves (`${XIAOMI_KEY_FILE:-$HOME/.config/hngh/xiaomi-key}`).
- Live verdict at landing: endpoint/model/key all resolve (chain
  reached the HTTP stage), but the token-plan SGP gateway
  `token-plan-sgp.xiaomimimo.com` resets connections instantly from
  this host (curl HTTP 000 in ~5 ms; DNS resolves to the Alibaba SG
  ALB). `xiaomi_chat` fails closed with breadcrumb
  `HTTP 000 -> next backend` and counsel returns None. The live leg
  heals when the network path is restored; nothing to fix in code.

## Principle

The ghost pantheon advises, never certifies (same doctrine as Typesafe
Jev): a counsel line is an editorial decoration in the digest, generated
fail-closed, capped, and never read by any gate. The canon import is
documentary-only per the canon's governance.
