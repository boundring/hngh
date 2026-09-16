# 2026-09-16 — token-file reads gated to exactly 0600 across the four
# remaining readers

## Problem

`f809a05f` (probe-model-route token-mode check) closed one reader of the
class, but three more surfaces read a token/key file and put its value
on the wire with no permission check, while the kimi/ocgo/zai readers
in `automation/lib/model.sh` had always stat-checked mode 600:

- `scripts/grade-interface` read `conf["token-file"]` bare
  (e1-curl-argv-sweep had recorded it OK with an explicit
  missing-600-check note);
- `automation/jobs/manga-vision.py` `open(TOKEN_FILE)` unguarded (same
  note);
- `automation/lib/model.sh` `remote_chat` read `REMOTE_TOKEN_FILE` with
  no gate — the one asymmetry in the file it lives in;
- `automation/jobs/credential-health.sh` `probe_token` read
  `TOKEN_FILE` unguarded while its own kimi/ocgo probes gated.

A loose-perm token file (0644 group/world read) was silently trusted
and its secret sent in an Authorization header.

## What landed

One class, one shape, four sites — every refusal is fail-closed BEFORE
the value is read or sent, names the path and the required 0600, and
never logs the value:

- `scripts/grade-interface`: new `read_token(kv)` helper —
  `stat.S_IMODE != 0o600` -> `fail("...: token file too open (mode
  NNNN); chmod 0600 required", 1)`; the read itself moved into a
  `with`-block inside the helper and main() now calls it (the value
  travels as `bearer`). The helper-LHS naming also keeps
  verify-candidate's CREDENTIAL_PATTERN quiet (a bare `token =` line
  with an 8+-char identifier on the right reads credential-shaped).
- `automation/jobs/manga-vision.py`: new `TokenFileModeError` +
  `_bearer_header()` — mode check first (`os.stat ... & 0o777 != 0o600`
  raises, naming path and 0600), then the with-block read; the old
  swallow-OSError-and-send-headerless fallback is gone (headerless is
  the probe-measures-itself bug class, 2026-09-10 lesson).
- `automation/lib/model.sh` `remote_chat`: existence first (absent ->
  "no key file -> next backend", the dormant contract, now explicit),
  then `stat -c %a != 600` -> breadcrumb "key file too open (chmod 600
  required) -> next backend" and return 1 — byte-shape identical to
  the kimi leg's gate.
- `automation/jobs/credential-health.sh` `probe_token`: `stat -c %a`
  gate above the read returning the literal code `too-open` (flows
  through the job's `ok()` classification like any non-2xx/3xx code,
  so the unsloth section alerts without a new alert class), curl never
  spawned for a too-open file.

## Tests (red first, each mirroring `ProbeTokenMode` from f809a05f)

- `tests/scripts/test-grade-interface-token-mode.py` (kernel suite):
  0644 refusal (exit 1, path + 0600 on stderr), 0600 control returns
  the value, missing file stays a loud FileNotFoundError.
- `automation/tests/test-manga-vision-token-mode.py`: 0644 raises
  `TokenFileModeError` with the guard proving the file was never
  opened; 0600 control rides `Bearer <value>` into the stubbed urlopen.
- `automation/tests/test-model-remote-token-mode.sh`: 0644 -> empty
  stdout + the too-open breadcrumb + zero POSTs against a live stub
  (the red run of this suite POSTed the 0644 key to the stub — the
  hole, reproduced); 0600 -> exactly one POST, stub answer on stdout;
  absent -> dormant contract pinned.
- `automation/tests/test-probe-token-mode.sh`: 0644 -> literal
  `too-open`, fake curl never spawned, value never read or sent;
  0600 -> one authenticated probe; missing -> `missing` pinned.

## Gate

- automation slice: `cd automation && make test` green before its
  commit.
- kernel slice (`scripts/grade-interface`, its test, root `Makefile`
  registration, this record): full `make test` green before the
  ceremony commit.

## Ceremony

The kernel files landed through `scripts/omp-bridge --ceremony`
(certificate-gated `hngh: candidate <hash>` commit); the automation
files are the free-commit lane behind the green automation gate. The
credential-health.sh delta was sequenced after the concurrent
bearer-stdin slice (g3) landed its `-K -` conversions in the same
function — one writer per file per slice, coordinated by DM.
