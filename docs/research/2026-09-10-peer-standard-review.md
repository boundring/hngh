# Peer-standard review - hngh against Pi, omp, billion-context

Adversarial review, 2026-09-10. Standard: the tools hngh interops
with daily (omp/bili: one-command install, published docs, MCP
surface; billion-context: a README that explains itself in one
screen; Pi: agent config that a stranger can read). No victory laps;
the mirror only.

## Method

Read the repo as a stranger would: README, install path, docs
navigation, then grep the failure classes from 2026-09-09/10 across
automation/ (159 shell/python files, 36-entry root, 149 plan files,
85 records). Each finding cites files; severity: blocks-peers /
major / minor.

## Findings (ranked)

### 1. blocks-peers: no stranger can install hngh

omp installs with `bun install` and runs; bili is an npm global.
hngh's real install is: clone, `make test` (needs SBCL - documented),
then assemble an operator environment that exists nowhere in the
repo: 24 KEY/TOKEN vars sourced by
~/.config/plasma-workspace/env/env_vars.sh (outside the repo, Plasma
session-only), 1Password service-account rotation
(docs/records/2026-09-09-1password-service-account-interface.md),
`systemctl --user import-environment ONEPASSWORD_SERVICE_KEY` at
login (env_vars.sh:30), npm-global `bili`, bun `omp`, a tailnet
address baked as defaults (automation/cadence/day/06-remote-posture.sh:21
DECK_IP=100.79.162.3), and an automation/systemd/ unit set whose
install is `make enable` in a Makefile that also owns smoke tests.
The kernel is a library and installs fine; the machine that makes it
"hng" exists only on this desktop. 18 hardcoded user-home-style
paths in job code (excluding comments and config.env) confirm it.
Fix direction: an `automation/bootstrap` that declares its env
contract (key names, not values), a machine-profile file for the
tailnet/deck defaults, and a README "run it live" section that
admits what today requires a human with this exact desktop.

### 2. major: CI tests the kernel, not the machine

.github/workflows/ci.yml (16 lines) installs SBCL and runs the
kernel's `make test` - 2855 checks. The automation tier (40 test
files, the code that actually did today's damage) runs only on this
machine, by this operator, often only when a cadence tick trips it.
The two-layer gate story told everywhere (docs/core/test-boundary.md)
is half-true in CI. Fix direction: a second CI job installing bash
+ python and running `automation/ make test` (hermetic by design;
the suite already is - test-remote-push.sh, test-quota-routing.sh,
test-model-demote.sh all run in sandboxes).

### 3. major: the probe-measures-itself class is fixed in
credential-health.sh but the CLASS has no systematic guard. Two
probes in one file measured their own missing headers/wrong shapes
for five days (kimi 401, lobehub 404 - commits 8db143a, b367b0c) and
both were caught by hand, not by tests. The remaining probe
(deck /health at credential-health.sh:88) is a bare GET that no
credential can authenticate - benign today, same shape as the bug.
Fix direction: one rule - every credential probe must exercise the
authenticated path its real caller uses - plus a lint-style test
that greps credential-health for headerless curls against
key-gated endpoints.

### 4. major: single-writer state files with fixed paths. The
gate-rerun log clobber (2026-09-10: fixture evidence mv'd into
automation/logs as kernel-gate evidence, commit d214e591) was one
instance of a pattern: automation/lib/model.sh's
tmp-modelused.txt (fixed path, concurrent model_call writers),
per-tier /tmp locks that assume one operator host, failfirst state
in /tmp/hngh-failfirst (resets on reboot - the ladder forgets its
own degradations every boot, which is why speed-3 persisted
'through' reboots only by luck of no reboot). model-demote.tsv got
it right (automation/state/, durable). Fix direction: an audit pass
that moves behavioral state to automation/state/ (failfirst first)
and leaves only true serialization locks in /tmp.

### 5. major: automation/ sprawl with the abstractions the
inventory already flagged. 149 plan files (8 overnight-continuity
templates, 15 files carrying the same Autonomy rule paragraph,
per-step `make test green` boilerplate x50+) and one selector that
three separate mechanisms have grown into (slot ordering, priority
key, class tags landing in cost-tiering). A stranger's ten-minute
read concludes: one person's working bench, not a tool. The
inventory already prescribed the fixes
(docs/research/2026-09-09-queue-dependency-inventory.md: verification
contract, one autonomy reference, parameterized continuity plan,
routed-stub template); none have landed. Fix direction: execute the
simplification candidates as the plan that already exists rather
than writing another.

### 6. major: the MCP surface is designed but empty.
docs/project/plans/2026-09-09-omp-hngh-integration.plan.md step 1
(read-only MCP stdio server) sits at 0 steps checked; LobeHub's
adoption path now NEEDS that server (LobeHub connects TO agents via
MCP; docs/research/2026-09-10-lobehub-api-research.md maps the three
integration RFCs). omp and Pi speak MCP natively today; hngh's
interop story is still prose. Fix direction: the MCP server is the
single highest-leverage rung for peer standing - it is also the
cheapest (read-only verbs already exist as CLI commands).

### 7. minor: README is genuinely good prose (the furnace/ledger
framing is better than billion-context's README) but it sells
philosophy where a stranger wants a running example: no
create-run-to-close-run transcript, no `scripts/hngh` example
output, no screenshot of the dashboard it praises. docs/README.md's
read-order is solid; examples are the gap. Fix direction: one
worked example page (kernel cycle transcript + automation beat
walkthrough).

### 8. minor: pre-GitHub-quality debts documented but not burned
down: 0 git tags, no release story, CHANGELOG says "nothing has been
released yet", 149 plan files with no archive/retention rule, and a
docs corpus (39 design + 85 records) that now outruns any new
contributor's ability to know what is current. STATE-OF-PROJECT.md
is fresh (updated 2026-09-10) - that discipline is real. Fix
direction: a "current vs historical" split in docs/README.md and a
first tagged release with the kernel API declared stable.

## The gap to Pi / omp / billion-context

1. **Install path** (finding 1): they install in one command; hngh
   needs a personal desktop. An `automation/bootstrap.sh` + env
   contract would close most of it.
2. **CI for the live tier** (finding 2): omp/bili test in CI; hngh's
   most failure-prone code is tested only where it breaks.
3. **A machine-readable surface** (finding 5 + the adoption design):
   omp has skills/plugins; hngh has CLI verbs and a designed-but-
   unbuilt MCP server. Until automation/mcp/ exists, hngh cannot be
   consumed by its peers.
4. **Docs navigation with examples** (finding 7): the read-order is
   excellent; the missing piece is "do this in five minutes", which
   is what a stranger actually reads.
5. **Boundary honesty is real, not claimed** (finding 4's flip
   side): the kernel is genuinely pure (mutation adapter executes
   only certificate-bound git verbs, src/adapter/mutation.lisp:9),
   the certificate loop is real, and 75ce22c2/b367b0c show failures
   becoming tests. The gap is not the kernel; it is everything the
   kernel depends on living in one operator's home directory.
