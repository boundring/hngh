# Data sovereignty — the Portage

Status: DESIGN — operator-directed 2026-09-07. Hngh should help the
operator leave walled gardens and manage personal data across any mix of
local devices and storage. Nothing here is landed.

Cross-links: [operator-mirror.md](operator-mirror.md) (the model-exposure
policy — governing law), [keyring.md](keyring.md) (handle-only secrets —
governing law), [descent.md](descent.md) (stations and lexicon rules),
[credentials-posture.md](credentials-posture.md) (the 1Password seam),
[../intent.md](../intent.md) (the mesh horizon and the no-daemon
boundary), [../project/backlog.md](../project/backlog.md).

## 1. The problem

An operator's life accumulates inside walled gardens: gmail, calendar,
docs, drive, sheets. Leaving means bulk export, reorganization, and
rehoming across local devices and optional dumb-cloud buckets — long,
multi-step, risky work. That is exactly the shape Hngh's machinery
already governs: a run is bounded, checkpointed, evacuated or closed
([../intent.md](../intent.md)), and every change passes a check and is
recorded. The destination for personal documents already has a design —
the Mirror's local-first corpus ([operator-mirror.md](operator-mirror.md)
§3). What is missing is the transport: getting the data out of the
gardens, normalized, and onto the operator's own storage, with evidence
at each step. The mesh horizon applies — a machine on a shelf, a
hand-held that mostly sleeps, a laptop whose network card is older than
the person using it; each is a boundary the corpus may live behind
([../intent.md](../intent.md)).

## 2. Principles (inherited, not invented)

No new law here; five existing laws, applied to the move:

1. **Local-first storage.** The corpus lives on the operator's machines;
   the cloud, when used at all, is a dumb encrypted container, never a
   system of record ([operator-mirror.md](operator-mirror.md) §4).
2. **The model-exposure policy governs what may leave the machine.** No
   personal item enters a remote prompt without a per-item policy row —
   no row, no exposure ([operator-mirror.md](operator-mirror.md) §4).
3. **Credentials stay handle-only in the Keyring.** Models and records
   see `site:acct-id` handles; secrets are consumed through the manager
   seam at execution time and never enter prompts, transcripts, or
   evidence rows ([keyring.md](keyring.md) §1,
   [credentials-posture.md](credentials-posture.md) §4).
4. **Every transfer is a run.** Bounded, checkpointed, evacuated on
   expiry. A killed half-transfer leaves a verified checkpoint and a
   salvage record, not a mystery ([../intent.md](../intent.md)).
5. **The record is the evidence.** Each phase lands rows naming what
   moved, where it landed, and what verified it — the same
   proposal/check/record path that admits a lattice peer
   ([../intent.md](../intent.md), [descent.md](descent.md)).

## 3. The transfer catalog (design-intent)

Pipeline: export -> normalize -> ingest.

| Stage | Source | Form | Destination | Governing law |
|---|---|---|---|---|
| Export | Google Takeout | gmail mbox, calendar ics, drive files, sheets exports | raw export directory on local disk | run manifest: paths and hashes, no values |
| Normalize | takeout exports | parsed mail and ics, files deduplicated | normalized local corpus tree | one checkpoint per mailbox, calendar, folder |
| Ingest | normalized corpus | named, versioned source | Mirror corpus ([operator-mirror.md](operator-mirror.md) §3) | no unnamed source; per-item exposure rows |

The LobeHub tie-ins (gmail, calendar, sheets, docs, drive through
LobeHub's plugin surface) are the operator-facing live layer Hngh
orchestrates: LobeHub executes, Hngh governs, secrets never reach
models. The division is already written down — browser and app
automation are TRANSPORT, not intelligence
([keyring.md](keyring.md) §2). The 2026-09-07 LobeHub
integration-surface study is landing tonight in [../research/](../research/);
until it exists, every LobeHub claim in this doc is design-intent.

Storage alternatives (design matrix):

| Store | Role | Constraints |
|---|---|---|
| Desktop, deck, NAS, laptop | primary corpus homes | syncthing-managed (§4) |
| Cloud bucket (optional) | dumb, encrypted-at-rest container (age/rclone-crypt class) | never a system of record; keys through the Keyring seam, bucket credentials handle-only |

## 4. Syncthing management (design-intent, first-class)

Hngh manages syncthing across any number of devices through its REST
API. Syncthing itself is operator-installed infrastructure, like the
model server. The no-daemon boundary holds
([../intent.md](../intent.md) — "there is no daemon; every timer is an
operator-installed single tick"), so Hngh speaks the API one-shot per
tick and never runs a watching process.

- **Folders, devices, ignore patterns are ledger rows.** The
  param-ledger discipline of `hngh-automation/cadence-params.tsv`: one
  row per folder-device pair — folder, device, path, state, provenance,
  note. Desired state is data; the tick reconciles one row at a time and
  records what changed.
- **Device admission is a run.** A new device is admitted the only way
  anything is admitted here: a proposal, a check, a record
  ([../intent.md](../intent.md)). The evidence row names the device ID,
  the folders shared, and the introducer.
- **The introducer pattern bootstraps the fleet.** One admitted device
  introduces the rest; Hngh records each introduction as a row, so the
  fleet's shape is citable, not tribal.
- **Pause/resume and bandwidth are Inventory knobs.** Toggles land as
  ledger rows with provenance; a laptop on battery reads its own row.

## 5. The de-google runbook sketch (phase plan)

| Phase | Scope | Writes | Exit evidence |
|---|---|---|---|
| P1 export + ingest | read-only over google | local export and normalized corpus only | manifest rows: per-source paths and hashes; ingest rows naming each corpus item; nothing touched remote |
| P2 rehome | local + syncthing | local filesystem and syncthing REST only | folder-device ledger rows reconciled; per-device hashes matching the P1 manifest |
| P3 account wind-down | operator-performed | none by Hngh | checklist rows per account handle: step, outcome, timestamp; deletions as recorded dispositions |

P1 is read-only against the gardens. P2 writes on local devices only.
P3 is the Keyring's critical-class rule ([keyring.md](keyring.md) §2):
account closure is operator-performed, Hngh is the checklist-runner and
records each step's outcome by handle. Each phase is its own run with
its own certificate; a failed phase evacuates and never half-bleeds
into the next.

## 6. Boundaries and non-goals

- **No cloud as system of record.** Buckets are encrypted dumb storage;
  the truth lives locally ([operator-mirror.md](operator-mirror.md) §4).
- **No credential storage in Hngh.** Accounts authenticate through the
  manager seam at execution time ([keyring.md](keyring.md) §6,
  [credentials-posture.md](credentials-posture.md) §4).
- **No bulk upload to any third party without a per-item policy row.**
  The model-exposure policy covers bytes leaving the machine by any
  door, not just prompts.
- **Deletion is a recorded disposition.** Local or remote, a deletion
  lands as a row citing what was removed and why
  ([operator-mirror.md](operator-mirror.md) §6).
- **No watching daemon.** One-shot API calls on a tick, like every other
  cadence leg ([../intent.md](../intent.md)).

## 7. Lexicon

Flavor names are display-register data; the scope rules are in
[descent.md](descent.md).

| Flavor name | Canonical term | Scope |
|---|---|---|
| the Portage | data-sovereignty layer | design layer; display alias only |

The alias follows the display-register boundary law
([presentation-boundary.md](presentation-boundary.md)): records and APIs
say `data-sovereignty layer`; `the Portage` never enters a record.

---

Back to the [documentation index](../README.md).
