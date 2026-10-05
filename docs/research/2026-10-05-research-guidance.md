# 2026-10-05 -- research guidance: standing read and five seeded lines

Evidence note for the research feed. Every claim cites the file it was
read from. No verdict rows were written to
automation/research-dispositions.tsv; the re-disposition section is
proposals only.

## Standing read

automation/research-lines.tsv held 322 rows at this read (327 after
this seed). Only six of the 322 serve the any-Linux-system harness goal
(docs/records/2026-09-11-operating-system-harness-vision.md:10-17):

- os-harness-distro-packaging (research-lines.tsv:45) -- PARKED with a
  truncated crystallization: "truncated mid-first-finding; needs beat
  re-run to cover deb/rpm and Nix sections"
  (automation/research-dispositions.tsv:58); the record itself ends
  "[truncated at model call: completion hit the max_tokens cap
  (finish_reason=length) - re-run the beat]" inside its first
  PKGBUILD/AUR section (docs/research/2026-09-12-os-harness-distro-packaging.md:23,41).
- os-harness-systemd-integration (research-lines.tsv:46) -- ADOPTED
  (automation/research-dispositions.tsv:59).
- os-harness-cross-platform-patterns (research-lines.tsv:47) -- ADOPTED
  (automation/research-dispositions.tsv:57).
- transaction-certificate-system-mutations (research-lines.tsv:59) --
  PARKED on safety grounds: findings disconfirmed (environmental drift,
  atomicity) (automation/research-dispositions.tsv:123).
- arc-20260925-os-adapters (research-lines.tsv:267) -- parked on a bare
  typed verdict (automation/research-dispositions.tsv:380, confidence
  0.92), blocking OT1: probe plans were emitted but "none returned
  observable output into the record" and probe results "never enter the
  record" (docs/research/2026-09-26-arc-20260925-os-adapters.md:15,31,38).
- arc-20260925-os-package-pairing (research-lines.tsv:268) -- parked on
  a bare typed verdict (automation/research-dispositions.tsv:381,
  confidence 0.86); its central artifact is unverified in its own
  record: hngh-packages.tsv, "existence asserted by line convention,
  exact path within the repo tree [unverified]"
  (docs/research/2026-09-26-arc-20260925-os-package-pairing.md:57).
  Checked on disk: automation/config/hngh-packages.tsv exists but is
  the 2026-09-11 collected-repositories registry (its own header), not
  a pins file, and the pairing check this line asked for landed
  2026-09-27 as automation/jobs/pins-drift.py over a separate
  automation/config/hngh-pins.tsv (pure comparator, pacman -Q/-Qq only,
  never actuates).

## The five seeded lines (automation/research-lines.tsv rows 323-327)

- env-contract-checkable (:323) -- declarative environment-contract
  schema checkable on a live host: ladder rung 2 of the vision ladder
  (docs/records/2026-09-11-operating-system-harness-vision.md:50-60);
  validates the CachyOS workstation and the Omarchy node; feeds
  docs/design/harness-data-plane.md / system-harness Rung D
  (docs/project/system-harness-roadmap.md:50-59) and the config-manager
  backlog row (docs/project/backlog.md:322).
- os-harness-distro-packaging-2 (:324) -- complete the truncated
  crystallization of research-lines.tsv:45 (deb/rpm and
  Nix/system-manager never covered); feeds the stalled packaging
  research backlog row (docs/project/backlog.md:1105) and ladder rung 3.
- os-package-drift-comparator (:325) -- land hngh-packages.tsv intended
  pins plus a pure read-only pins-vs-local-package-db checker (exit
  0/1/2, no actuation) and a first drift report; feeds the governed
  package operations backlog row (docs/project/backlog.md:865).
- os-probe-tier-manifest (:326) -- closed-vocabulary read-only probe
  manifest plus first captured probe output from the Omarchy node
  (systemctl status, list-timers, read-only journal) -- the probe tier
  its own record prescribes (read-only, closed-vocabulary
  [docs/research/2026-09-26-arc-20260925-os-adapters.md:27,32]);
  unblocks OT1 of research-lines.tsv:267, where no probe output has
  ever been captured.
- installer-mesh-key-provisioning (:327) -- node mesh-key provisioning
  through the documented 1Password service-account pattern
  (OP_SERVICE_ACCOUNT_TOKEN headless seam,
  docs/design/hngh-installer.md:202-204), fail-closed, no interactive
  prompts; closes installer GAP-I2, the remaining mesh admission seam
  (docs/design/hngh-installer.md:319-320,
  docs/project/system-harness-roadmap.md:106-107); feeds the
  keyring/secrets backlog row (docs/project/backlog.md:981).

## Re-disposition candidates (proposals only; no verdict rows written)

- research-lines.tsv:59 (transaction-certificate-system-mutations) --
  deserves a look again now that the package upgrade rode the
  certificate loop with invariants: all ten invariants verified under
  standing guards and patrols, "the stage-4 exit (governed package
  upgrade) rode the certificate loop"
  (docs/project/roadmap.md:228-232), and the backlog row now specifies
  upgrades as proposal -> verdict -> executor in a declared window with
  rollback evidence (docs/project/backlog.md:872-876) -- the exact
  machinery the parked findings judged unsafe.
- research-lines.tsv:267 (arc-20260925-os-adapters) -- superseded-by
  candidate of os-probe-tier-manifest (research-lines.tsv:326).
- research-lines.tsv:268 (arc-20260925-os-package-pairing) --
  superseded-by candidate of os-package-drift-comparator
  (research-lines.tsv:325); the artifact-naming drift recorded above
  (hngh-packages.tsv vs hngh-pins.tsv) is residue the successor line
  should settle.
- research-lines.tsv:45 (os-harness-distro-packaging) -- successor is
  os-harness-distro-packaging-2 (research-lines.tsv:324).

## Weak-reviewer observation

Many verdicts in the 2026-09-26..2026-10-04 window are bare "typed
verdict parked (confidence N)" rows with no prose: 19 of the 39 rows in
automation/research-dispositions.tsv:380-418 carry a confidence token
and nothing else, and the pattern continues through 2026-10-04
(automation/research-dispositions.tsv:426,428,430,439). A confidence
number with no rationale cannot guide the re-dispositions above.
