# The Keyring — the credential-rotation harness

Status: DESIGN — operator-directed 2026-09-07. Hngh should help users run
long, complex security processes — rotating hundreds to thousands of account
passwords, paired with password-manager entry updates. Nothing here is landed.

Cross-links: [credentials-posture.md](credentials-posture.md) (the 1Password
seam), the browser-relay lines [2026-09-04-browser-relay-architecture.md](../research/2026-09-04-browser-relay-architecture.md)
and [2026-09-03-browser-messaging-automation.md](../research/2026-09-03-browser-messaging-automation.md),
[bestiary.md](bestiary.md), [descent.md](descent.md), [autonomous-development-control.md](autonomous-development-control.md),
[gate-inventory.md](gate-inventory.md), [../project/backlog.md](../project/backlog.md).

## 1. The trust boundary law

The password manager is the ONLY component that holds secrets. First
choice is 1Password via its CLI (`op`), per
[credentials-posture.md](credentials-posture.md) §2 and §6 (CLI first, SDK
later — the ladder: already-installed dependency over a new runtime).
Known blocker, recorded in
[../research/2026-09-04-operator-interface-landscape.md](../research/2026-09-04-operator-interface-landscape.md)
§3: on Linux the SDKs and the CLI share the same desktop-app integration
socket, so an SDK inherits the CLI's failure mode and bypasses nothing;
the documented bypasses are CLI-only `op account add` or a Service
Account. The standing leads there (a stale `op-daemon.sock`; restart after
the operator's reboot window as the cheap first test) are the integration
prerequisite — until `op whoami` succeeds at execution time, the harness
parks with the exact operator step quoted, per credentials-posture §5. It
never retries in a loop.

Consequences: models never see a password or any secret — not in prompts,
transcripts, or evidence rows. Plans and certificates reference accounts
by **handle** (`site:acct-id`), never by secret value. Secrets are consumed
only through `cred_get`-shaped seams ([credentials-posture.md](credentials-posture.md)
§2) at execution time; that doc's §4 redaction rules apply verbatim — no
secret values in logs, breadcrumbs, report rows, or digests.

## 2. The flow

1. **Account inventory.** Exported handles only — site, username, item
   reference, policy class. A plan manifest (paths, roles, hashes; no
   values) in the sense of
   [autonomous-development-control.md](autonomous-development-control.md).
2. **Per-account rotation proposals.** Batched, operator-approved per
   policy class. Class 1 (unattended): no 2FA, no anti-automation, low
   blast radius. Class 2 (attended): 2FA, TOTP, or anti-automation
   defenses. Class 3 (critical): email roots and recovery accounts —
   operator-performed, Hngh as checklist-runner (§4).
3. **Execution.** Browser relay or site API where available. The two
   crystallized browser-relay research lines are the transport — Route A
   (Playwright isolated profile, ADMIT) and Route B (extension relay,
   operator-authorized). Browser automation is TRANSPORT, not intelligence
   (2026-09-03 line §3) — a rotation step is a script shape, not a model.
4. **Manager update, same atomic step.** A rotation is not done until the
   password-manager entry matches. A half-rotation is a failed rotation:
   the account rolls back — the old value re-applied from the manager's
   own version history before the entry was updated; Hngh stores nothing.
   The failure parks with cause per the Bestiary ([bestiary.md](bestiary.md)).
5. **Verification evidence.** A login check with the NEW secret, fetched
   via the manager at execution time, never logged or persisted — the
   evidence row records the outcome and timestamp, not the secret.
6. **Per-account certificate.** One per rotation, action-scoped,
   expiry-bound, rechecked at the moment of action
   ([autonomous-development-control.md](autonomous-development-control.md)).

## 3. 2FA/TOTP reality

Sites with TOTP/2FA or anti-automation defenses route to the operator
packet class — `missing-authority` in the Bestiary and the gate inventory:
one report-ledger row naming the exact action, target, and grant needed.
The loop waits; it never self-grants and never bypasses. A TOTP code is an
operator step by definition — it exists to prove a human is present.

## 4. Safety properties

- **Rate limiting per site.** A per-site cap and spacing, ledger rows in
  the `hngh-automation/cadence-params.tsv` pattern, so a batch cannot
  trip a site's lockout into an account-recovery cascade.
- **Break-glass ordering.** Never rotate an account that is the sole
  recovery path for another account before its dependent is rotated.
  Batch order is a topological sort over the recovery edges (design-intent).
- **Dry-run is the default.** The first pass of every batch runs the full
  flow minus the mutation: proposals, classes, ordering, evidence shape —
  no password changes. Wet runs are named, approved runs.
- **It is a run, not a daemon.** Bounded, checkpoints, evacuation — the
  roguelike lifecycle ([../intent.md](../intent.md);
  [descent.md](descent.md)). A campaign out of time ends dead or evacuated;
  the next run starts from the ledger, not from memory.

## 5. Scale story

Hundreds to thousands of accounts are the same ledger machinery, batched:
one inventory, N classed proposals, one operator approval per class, one
daily packet — the digest row naming accounts rotated, parked, and failed,
handles only. Nothing per-account is operator-facing unless the account parked.

## 6. Non-goals

- **No credential storage in Hngh itself.** The manager is the store;
  "no plaintext secrets in any repo" (credentials-posture §4) is absolute.
- **No scraping secrets out of the manager into files.** Secrets cross
  the seam at execution time only, into the consuming process, never to disk.
- **No auto-rotating anything in the critical class.** Email roots and
  recovery accounts are operator-performed, Hngh as checklist-runner.
- **No browser-session laundering.** The relay transport inherits the
  standing credentials rules of the browser research line §6 — session
  credentials redact to paths, never values.

## 7. Lexicon

| Flavor name | Canonical term | Scope |
|---|---|---|
| the Keyring | credential-rotation harness | design layer; display alias only |

The alias follows the display-register boundary law
([presentation-boundary.md](presentation-boundary.md)): records and APIs say
`credential-rotation harness`; the alias never enters a record.

---

Back to the [documentation index](../README.md).
