# 2026-09-18 — 1Password item metadata completeness backfill (P0 plan step 5)

Plan: docs/project/plans/2026-09-18-backlog-p0-security-fixes.plan.md
step 5, backlog item rot-gap-1password-item-metadata. Scope: read-only
probing plus this doc; no 1Password item mutation, no provider or
credential configuration changes (plan boundary).

## Enumeration method

The automation service token (`ONEPASSWORD_SERVICE_KEY` mapped to
`OP_SERVICE_ACCOUNT_TOKEN`; seam defined in automation/lib/credentials.sh
lines 26-27) was used read-only for `op account list`, `op vault list`,
and `op item list --format json` across the 7 service-account-scoped
vaults. All automation-referenced items cited by records
(docs/records/2026-09-09-1password-service-account-interface.md,
docs/design/credentials-posture.md,
automation/scripts/setup-notify-email.sh, automation/README.md) were
matched against the vault inventory by title.

## Items found and metadata completeness

- hngh-notify-email (id jeorhe5wrpa37vm6tqbyvq56li, vault `etc.`,
  vault id 3lv4v3jxzjh6yllhwmqxrhoaua, category LOGIN, version 1).
  This is the only item automation records actually cite: the
  migration path in docs/records/2026-09-09-1password-service-account-interface.md
  and the `--from-1password` seam in automation/scripts/setup-notify-email.sh
  both point at `op://<vault-id>/hngh-notify-email/password`.
  - title: present ("hngh-notify-email").
  - URL field: NOT RETRIEVABLE this session — item-ID-level reads
    (`op item get <id> --format json`) failed repeatedly with
    "authorization prompt dismissed" or 60s+ timeouts; field-scoped
    reads (`op read .../username`, `op read .../website`) also timed
    out or returned empty. Metadata annotated as INCOMPLETE-PENDING;
    the completed provenance requires a re-probe after the desktop-app
    auth overlay issue clears (parked, see Open gaps).
- GOG - HNGH (id c65pyr3mg7dujtnmy5zoziskjq, vault Hobbies
  rhxj2lp3o5bmwt5a7vvxqtfi6u, LOGIN). This item surfaced in the vault
  inventory scan because its title contains "HNGH", but NO automation
  record cites it — it is operator-personal data that lives in scope
  only because the vault-shared token happens to reach it. Metadata
  (title, tags, created 2025-11-07T23:00:06Z, updated
  2025-11-08T18:56:07Z, URL https://login.gog.com) is already complete
  in the 1Password record; no backfill needed and none recorded here.

## Provenance recorded

- Account: my.1password.com, operator boundring@gmail.com, user id
  XP4NFUS5ERH35CSHTV2HZEX2CY (service account, least-privilege);
  determines the authoritative item-ID source of truth for any future
  `op://` reference hardening.
- Vault scope confirmed: 7 vaults; Private and Shared deliberately
  excluded by the token's ACL (matches the 2026-09-09 interface record).
- No item metadata was mutated by automation; the only authoritative
  metadata source for these two items is 1Password itself, recorded
  here for citation by future automation changes (e.g. hardening the
  `op://<vault-id>/hngh-notify-email/password` placeholder into a
  pinned item-ID form once the desktop auth overlay clears).

## Blocked / deferred

- Item-ID-level metadata (URL creation date, last-updated date field,
  full field inventory) for hngh-notify-email: blocked by intermittent
  "authorization prompt dismissed" failures on `op item get` with the
  service token (retried 8+ times across 3 minutes). Parked; the block
  is an environment/authifier issue, not a records-gap issue, and the
  operator should decide whether to re-probe under a desktop-app
  auth session or refresh the service token scope.

Related: docs/records/2026-09-09-1password-service-account-interface.md,
docs/design/credentials-posture.md,
automation/scripts/setup-notify-email.sh.
