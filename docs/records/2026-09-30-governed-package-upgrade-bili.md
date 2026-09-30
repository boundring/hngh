# 2026-09-30 Governed package upgrade -- bili through the certificate loop (Slice D)

Filed by the governed-fleet slice D landing (plan
`governed-fleet-consolidation`, 2026-09-30 execution). Design surface:
docs/design/governed-fleet.md section 6 slice D ("the ceremony is the
exercise; kernel src untouched") and section 4 row 8 (invariant: one
governed package upgrade start-to-finish through the certificate loop
on this host; evidence is the certificate + the `hngh: candidate`
commit in git log). This record cites evidence; it does not restate
the design.

## What was upgraded

- Package: bili (npm `billion-context`), the context-compression
  proxy in front of the agent launch lanes (the bili rows in
  automation/config/hngh-packages.tsv and
  automation/config/hngh-services.tsv).
- Installed version after the 2026-09-29/30 update pass: 0.1.174
  (package.json; dist mtime 2026-09-30T01:31Z, minutes after the
  0.1.174 npm publish 2026-09-30T01:29:40Z). The preceding live
  version visible in the ACP status trail was 0.1.172
  (automation/dashboard/sessions.json).
- Registry drift being governed: the hngh-packages.tsv bili row (and
  the acp-kernel embodiment note) still carried the `0.1.141` pin
  from 2026-09-23 while the host had moved on. The governed act of
  this slice is the certificate-bound reconciliation of the registry
  to the verified host state plus this decision record -- not a
  fresh download: the upgrade itself was already performed through
  the maintained updater (`automation/scripts/hngh-omp-update.sh`,
  `npm install -g billion-context@latest`, the row's own declared
  update mechanism) before this session started.

## Why the upgrade is safe to admit

- Upstream 0.1.174 (release PR 1717, commit 228bd05) is a version
  bump; the one functional change since 0.1.173 (PR 1714, fix 1706)
  retires the BILI_STREAM_STALL_MS stall guard: upstream silence is
  bounded solely by the always-on BILI_UPSTREAM_TIMEOUT_MS idle
  budget, and stale exports are ignored with a startup warning.
  hngh carries no BILI_STREAM_STALL_MS export (no occurrence in
  config.env, cadence-params.tsv, lib, or jobs) and no bili config
  override of the idle budget (~/.config/billion-context/
  billion-context.json holds only the compress block and the mitm
  domain list), so the retirement is behavior-neutral for hngh and
  removes a truncation hazard for the local-model legs
  (thinking-phase silence runs minutes, not seconds).
- Rollback: `npm install -g billion-context@0.1.173` (npm cache),
  containment local; the registry row reverts as a one-line edit.
- Guard surface re-verified: automation/tests/test-hngh-packages.py
  (registry shape + in-use path resolution) and
  automation/tests/test-bctx-canary.sh (updater lane; the deprecated
  billion-context-omp/-pi installs stay retired) ride the automation
  suite; the certificate's gate evidence is the full kernel
  `make test` (fast-test marker, rc=0).

## The certificate exercise (the point of the slice)

- Pre-flight: the loop was rehearsed with `scripts/ceremony-drive
  --dry-run` against a disposable /tmp fixture built from the real
  kernel sources with a mocked gate -- dream stop after propose with
  all ten principles passed. The rehearsal surfaced both refusal
  classes before any real mutation: a candidate lacking a .md
  conclusion link refuses source-grounding, and a run created
  without HNGH_LOADOUT facts refuses cost-and-route-discipline.
- The real drive: ONE `scripts/ceremony-drive` call against a fresh
  /tmp store, candidates = this record, the flipped plan step, the
  bumped registry rows, and the CHANGELOG entry; objective in plain
  words (tool-arg-hostility lesson). The drive ran create-run ->
  admit-transport model/repository -> propose (deterministic
  ten-principle verdict over real per-principle evidence facts) ->
  mutation-check prepare-candidate -> commit -> the
  certificate-gated push leg (a commit certificate never authorizes
  a push; the push proposes under class=push-request into its own
  fresh verdict). The commit message is the certificate's content
  hash (`hngh: candidate <hash>`); mint-time receipts land in
  cert-receipts.tsv under the automation home.
- kernel `make test` green is the candidate's fast-test evidence
  (the ceremony runs the gate itself and caches per candidate hash;
  the pre-existing unrelated dirty paths are outside the candidate
  manifest and stay untouched).

## Advisory review findings

Three advisory findings rode the certificate (reviewers advise,
never decide): the cost-and-route note that the upgrade ran
pre-verified (the certificate binds the upgrade decision, not a
runtime reinstall), the evidence-before-claim pointer to the
registry rows as the claim surface, and the reversibility pointer to
the documented npm rollback.

## What this does NOT claim

- The System-view upgrade trigger (governed-fleet.md section 6 slice
  D prose) is free-commit automation surface and stays open; this
  slice's invariant is the certificate exercise, now witnessed. The
  trigger lane is filed in the queue ledger as follow-through, not
  as a slice-D gate.
- The running bili proxy instance continues on its loaded binary
  until its own exit; the next bili launch (per-launch child, never
  a daemon) serves 0.1.174. That is the documented per-launch update
  semantics -- machine sessions do not restart operator services.
