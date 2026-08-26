# 2026-08-25 — Rung 12: pinned-key registry and signature-verification transport

## Scope

Lands the roadmap "Next" revocation-policy refinement: the operator's
pinned-key registry as a pure domain value, the strict pins-file parser and
real signature-verification transport in the federation adapter, and the
operator surface that admits a pins file on `verify-attestation` plus the
new `list-pins` command. This closes the gap between the rung-11
attestation ports (injection-only, fixture-verified) and a real
operator-pinned trust anchor verified by a real openssl invocation.

## Decision

1. The registry is pure kernel: `key-pin` (plain bounded identifier plus
   absolute key path — option-like path components and relative paths
   refuse) and the immutable `key-pin-registry` (duplicate identifiers
   refuse with `duplicate pin: <id>`, defensive list copies, `lookup-key-pin`
   returning the stored pin or NIL). No I/O, no clock, no key bytes.
2. The adapter owns everything touching operator text and processes:
   `parse-pinned-keys` is a strict `IDENTIFIER<TAB>ABSOLUTE-KEY-PATH` line
   parser (`#` comments and blank lines skipped; wrong field count, empty
   identifier, relative or option-like paths refuse); `hex-decode` is the
   pure lowercase-hex codec; `make-pinned-attestation-ports` resolves keys
   from the registry and verifies one envelope signature through a single
   bounded `openssl dgst -sha256 -verify` invocation on the injected
   process transport. Temp files are always removed; a malformed hex
   signature or missing pin refuses before any process call.
3. The pins file is the trust anchor at the operator surface: when
   `verify-attestation ... pins=PATH` is present, the parsed registry plus
   the installed read-only process transport replace any injected
   attestation ports; a missing file refuses `cannot read pins file` and a
   malformed file refuses `malformed pins file` (both exit 2, before any
   run or transport work). `list-pins PATH` renders the registry through
   the new `render-pin-list` (one `IDENTIFIER<TAB>PATH` line per pin).
4. `src/packages.lisp` symbol exports land as a direct chore commit — the
   file structurally defines adapter packages, so the candidate dependency
   guard excludes it from certificate manifests (rung-10 precedent,
   commit `29aa3ab`).

## Evidence

- `make test` green after each stage: 8 reader guards and 2,663 checks
  (baseline 2,616 + 6 domain + 27 adapter + 14 operator-surface checks).
- Three self-governed commits through the dogfood governance loop, pushed to
  `origin/main`: `7186333` (domain slice, candidate `48eea853...`),
  `1916bee` (adapter slice, candidate `b1ce3eea...`), and this slice's
  governance commit; plus the two `chore:` export commits (`b773651`,
  `5851273`).
- Live end-to-end proof (not a test — real subprocess, real key), run
  from the repository root against a scratch store with a throwaway
  2048-bit RSA keypair and `openssl dgst -sha256 -sign`:

  ```
  $ scripts/hngh --store=/tmp/hngh-live-store verify-attestation run-1 \
      /tmp/hngh-envelope.json pins=/tmp/hngh-pins.txt
  attestation status=verified key=live-key-1 fact=evidence kind=remote-attestation \
    fingerprint=machine-live|live-key-1|7fbccad4390b81deb0a642bd02f7a52e7b335de2da46b66b8b524185887e54ff state=current
  exit=0

  $ ... verify-attestation run-1 /tmp/hngh-envelope-tampered.json pins=...
  attestation status=refused labels=bad-signature      (exit=1)

  $ ... verify-attestation run-1 /tmp/hngh-envelope-unknown.json pins=...
  attestation status=refused labels=unknown-peer-key   (exit=1)

  $ scripts/hngh list-pins /tmp/hngh-pins.txt
  live-key-1	/tmp/hngh-pin-test.pub                    (exit=0)
  ```

  The tampered case reuses the valid signature over a modified payload;
  the unknown case reuses the valid payload under an unpinned key
  identifier. OpenSSL 3.6.3.

## Remaining unknowns

- Ed25519 keys cannot ride the fixed `dgst -sha256` pairing on this
  OpenSSL ("Explicit digest not allowed with EdDSA operations"); the
  adapter command is digest-signature-key shaped (RSA/ECDSA/DSA). An
  Ed25519-capable `pkeyutl -rawin` command variant is future hardening,
  recorded in the roadmap Next.
- Pin expiry and rotation (a pin valid until a date, superseded pins)
  remain open — the registry is a closed list and revocation is
  file-editing, per the 2026-08-24 design decision 1 (immediate refusal
  on rotation).
- The verified fact feeds the evidence ledger like any other fact; no
  policy requirement kind yet consumes `:remote-attestation` fingerprints
  in a shipped policy profile.
