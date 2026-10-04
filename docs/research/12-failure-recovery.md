---
category: failure/recovery
persona: The Coroner
status: seed
anchored: 2026-10-03
note: automation anchors predate the 2026-10-04 control-room cut (broadsheet/ghost/wire surfaces retired)
---

# Failure & Recovery — what hngh runs today

hngh's failure doctrine is fail-closed with named dispositions and recoverable storage. **Row-then-write** is the atomicity pattern for every dashboard lifecycle transition: `_report_row` files ONE report-queue progress row (stable identity `operator-item:<id>:<state>`) BEFORE the ledger write, and "a refusal leaves every ledger untouched so nothing lands silently without its row" — the identical order at dismiss/handle (:1435-1439,1500-1503), `_report_row` itself (:1557-1575), and desk approval (:1628-1643) (automation/dashboard-server.py). Idempotent retries ride the stable identity (report-queue dedups within its window).

The kernel classifies failure into **eight closed categories** (`+failure-categories+`, src/domain/governance.lisp:27-31) mapped to dispositions — :propagate-to-test-gate, :typed-domain-refusal, :normalize-to-conflict-without-retry, :refuse, :needs-escalation, :stop-and-record-evidence — resolved by pure policy `evaluate-failure-disposition` (:47-72). Death is a first-class record: `src/domain/outcome.lisp` has receipts (:9-18), score-records (delivery/cost/headroom/turnaround/lesson-reuse; :30-38), and afterlife-records (terminal-cause, observed-facts, salvage-labels, rejected-hypotheses, lesson-candidate; :49-53). Run lifecycle encodes the recovery taxonomy: `:created :armed :running :checkpointed :cancelled :evacuated :dead :afterlife :scored :archived` with a legal-successor table (src/domain/run.lisp:3-12); omp-bridge enforces disposition honesty (a bridge run never enters :running, so `cancelled` is the legal close from :created; scripts/omp-bridge:22-25). Even storage reads fail closed: the filesystem store's probe-then-read race "must fail closed as a transport fault, never a raw error" (src/adapter/filesystem.lisp:81-84).

**Physical recovery**: the installer lays GPT + LUKS2 + btrfs with exactly two keyslots — keyfile slot 0 + recovery passphrase slot, verified `luksDump` shows exactly 2 ENABLED (automation/iso/profile/airootfs/root/install-hngh-os.sh:464-496) — and prints a RECOVERY CARD (LUKS uuid, recovery passphrase, passwords, key-only ssh, ufw default-deny; :684-701). A lockout guard refuses key-only sshd when the live env has no authorized_keys (:580-583); a stale `/mnt` means a previous run died mid-flight and the installer dies rather than stack mounts (:384-385). Btrfs time-travel is deliberately bounded: the sudoers grant admits `btrfs subvolume snapshot|list` only — "restore is snapshot-over, deletes stay operator-run" (automation/config/hngh-automation.sudoers.example:29-32; docs/records/2026-09-12-privilege-model.md:96-102,148-155) — with an `@factory` subvolume on the Omarchy SSD as the reset baseline. The alert ledger itself needs real recurrence to re-fire (`--evidence` token; scripts/report-queue:388-399).

## Open questions for web research

1. Snapshot-over vs delete discipline in btrfs recovery; factory-reset subvolume layouts (`@factory` class) — Snapper/openSUSE and image-based reset precedents.
2. Row-then-write ordering vs transactional-outbox patterns for file-backed ledgers.
3. Failure taxonomy + disposition tables in autonomous systems — comparable closed vocabularies.
4. FDE recovery UX: keyfile + recovery-passphrase slot rotation and keyslot management practice (systemd-cryptenroll et al.).
5. Afterlife/post-mortem record modeling (terminal cause, salvage, rejected hypotheses) — incident-review schema precedents.

## Candidate external systems to survey

- Snapper (btrfs snapshot timelines)
- ZFS snapshot/rollback tooling
- systemd-cryptenroll (LUKS2 keyslot management)
- Timeshift
- OSTree / Android factory-reset subvolume designs
