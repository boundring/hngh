# Agent guardrails — the prevention leg

This session taught six failure classes by surviving them. Each entry names
the failure class, the concrete reaction that worked, and one line of
provenance. These are procedural pre-empts: the *steering* that got applied
live, now codified so a future agent applies it before the failure, not
after. Delegate this file (or its `local://agent-guardrails.md` twin) into
any task prompt whose work touches the same ground.

## 1. Tool-call failure loops

**Failure class:** a tool call returns a validation error, and the agent
retries the *identical* call blindly, sometimes repeatedly, burning turn
budget and producing nothing.

**Reaction (works):**
- On any validation/parse error from a write-style tool, **fall back to
  `apply_patch` / the edit tool** rather than re-invoking the same broken
  call.
- **Re-read the anchor region** before the next edit — the failure may mean
  the file changed under you; editing against a stale snapshot re-fails.
- Never retry the same broken call with the same arguments expecting a
  different result.

**Provenance:** steering the stuck matrix write — the first write returned a
validation error; blind retry would have looped forever. Fallback to
`apply_patch` + re-read unblocked immediately.

## 2. Token / credential decay (401)

**Failure class:** a session or reviewer token decays mid-session; API calls
start returning 401, and the agent either treats it as an endpoint outage or
stalls trying to mint a new credential itself.

**Reaction (works):**
- Run `hngh-automation/jobs/credential-health.sh` to **self-heal**. The
  script probes every credential and, on a 401-bearing session token,
  rotates it through the flocked refresh in `lib/model.sh` (fail-closed:
  exits 0, files a breadcrumb either way).
- If the probe returns a genuine failure (missing token, decayed refresh
  pair, unreachable reviewer), the script already filed an `alert` row in
  the hngh report ledger — surface it, do not hand-mint a broader
  credential.

**Provenance:** the 401 we rotated live this session — `credential-health`
probed, rotated, re-probed, and breadcrumbed in one run.

## 3. Stale-anchor re-verification

**Failure class:** a tool result is skipped or interrupted (timeout,
subagent stall, dropped result). The agent proceeds to edit the region as if
it had fresh proof of its content.

**Reaction (works):**
- After **ANY** skipped, interrupted, or unverified tool result, **re-read
  the anchor region** before editing it. Never treat an interrupted result
  as "good enough to edit against."

**Provenance:** the EvoUI stall — a subagent's result was cut off and the
edit proceeded against the stale anchor until steering forced a re-read.

## 4. Ceremony-store stomp

**Failure class:** two ceremony runs aimed at the same store, or a store
directory that does not exist yet, causing transport faults and crossed
run records.

**Reaction (works):**
- **Always `mkdir -p` the store path first.**
- **Flock the whole ceremony** (e.g. `flock /tmp/hngh-ceremony.lock
  sbcl --script scripts/ceremony-drive --store=… …`) so two runs cannot
  stomp one store.
- **Wrap the ceremony in a generous timeout** — the loop is many steps
  (create-run, admit, propose, cert, commit, optional push); a short timeout
  hijacks a legitimate in-flight run.

**Provenance:** two transport faults this session, both resolved by
mkdir-first + flock + a generous timeout.

## 5. Untracked sibling changes

**Failure class:** the working tree is shared by parallel lanes; a sibling
has untracked or modified files that are not yours. A blanket `git add -A`
sweeps them into your commit, mixing ownership and silently stealing a
sibling's work.

**Reaction (works):**
- **Stage ONLY the files you own.** Build the manifest explicitly and pass
  it to the ceremony — never `git add -A`.
- Check `git status --short` first so you *know* what exists and is not
  yours before you commit anything.

**Provenance:** multiple parallel lanes committed one tree without
cross-contamination purely by binding narrow explicit manifests.

## 6. State before acting

**Failure class:** a build/test gate passes, the agent loops straight into
its next mutation, and a state flaw (a stale artifact, a breadcrumb written
after the commit it should precede) slips through unobserved.

**Reaction (works):**
- After **each build/test gate**, `peek` at the resulting state /
  `review` your own tick before acting on it: inspect the artifact the gate
  just produced, verify ordering (e.g. breadcrumb before the commit it
  announces, not after).
- Review-then-act is cheap and catches ordering/recency flaws the gate's
  exit code cannot see.

**Provenance:** the agent caught the breadcrumb-after-commit flaw — a gate
passed, but the breadcrumb watchdog declared the commit before it was
committed; state review caught the ordering, not the exit code.
## 7) Repeated-expensive-identical-work (loops) — prevent, else interrupt at start

- **Class:** the same expensive operation re-runs on identical inputs
  (ceremony drove verify-candidate ~5×, each re-running `make test`
  ~33s on the same tree).
- **Prevent:** cache deterministic full-gate results keyed on
  (base-revision | candidate-hash | normalized-porcelain) — the
  first run pays, repeats are ~0s, fail closed on any marker problem
  (provenance: verify-candidate fasttest cache, 31.58s→0.1s).
- **Recognize as it starts:** 3+ byte-identical same-job breadcrumbs in
  30 min, or 3+ same-key /tmp/hngh-fasttest markers in 5 min →
  oversight fires `loop-signal` alert; the agentic steer leg is
  instructed to interrupt-and-redirect with a concrete next action
  (provenance: loop-recognition probe + fixture).
- **Never** silence the alert to make the loop quiet; fix the loop.

## 8) Wired-state lens (every refactor, not a failure class)

- **Class:** a refactor that works in isolation but regresses the
  now-live observation/cadence/security/governance surfaces.
- **Reaction (works):** before touching any slice, read
  `docs/project/wired-state-lens.md` and check the 9 lenses
  (observability, cadence fit, cost/loops, self-healing, governance,
  fleet shape, operator surfaces, index continuity, simplicity).
  A change that a watcher cannot see is a wiring regression even green.
- **Provenance:** 2026-08-26 — ceremony was 111s invisible until
  per-phase timing; the fix only landed after self-observation.
  Codified as the standing refactor checklist.

## 9) Rendered-but-inert surfaces (serves but doesn't function)

- **Class:** a delivered surface (webapp, dashboard, UI) returns 200 /
  looks present but its interactions are dead — panels don't expand,
  controls don't click, a chart doesn't render. HTTP-200 + assets =
  NOT proof of function.
- **Reaction (works):** drive the actual rendered surface (browser
  relay / interactive probe) and CLICK the widgets, assert DOM
  state changes (data-open flip, body display, chart nodes), never
  trust a fetch status alone. Watch for contract mismatches between
  the HTML/CSS/JS layers (class vs data-attribute toggles, one
  mechanism per layer).
- **Provenance:** 2026-08-26 — the webapp served fine (200 on all
  assets) but app.js toggled a `.open` class while HTML+CSS used
  `[data-open]`; nothing expanded; the operator (not the machine)
  reported it. The watchdog should have caught it via a rendered-
  surface probe.

## 10) Trust self-reported evidence as claims, not facts

- **Class:** a subagent's final report contains hashes, counts, or
  "verified" claims that are corrupted/mangled/unverifiable (SysAware's
  sha256 transcription broke mid-report: "wait use e0bc3b..."). A
  report is a claim; the tree/disk is the fact.
- **Reaction (works):** re-verify any self-reported identifier against
  the actual artifact on disk (the file's real hash, the real ledger
  line, the real commit) before accepting it; when a report mangles an
  identifier, read the file directly instead of trusting it.
- **Provenance:** 2026-08-26 — SysAware reported unreliable hashes; the
  on-disk `system.json` was the ground truth.

## 11) A periodic heartbeat is not a loop

- **Class:** loop-detectors flag healthy periodicity as a loop — 756
  identical `mode=timer` crumbs tripped the 3x-identical rule on the
  oversight tick's own heartbeat (a false positive the watchdog caught
  catching itself).
- **Reaction (works):** an identical periodic crumb with no alert/error/
  fail signal is healthy cadence, not a loop; require a NON-periodic
  signal (alert/error/loop/fail keyword) inside the repeated crumb, and
  mind the split between "repeats by design" and "repeats without
  progress."
- **Provenance:** 2026-08-26 — the loop-signal fired on the watchdog's
  own house; fixed by requiring an alert/error/loop marker in the
  repeated body.
