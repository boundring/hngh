# 2026-08-25 — Rung 14: Ed25519 signature-transport hardening

## Scope

Extends the operator pinned-key registry and signature-verification
transport (rung 12) with a closed key-algorithm vocabulary so pins may
name Ed25519 and verification routes to the raw-signature openssl path.
The carrier-bundle envelope, the attestation ports, and the verify
gate are unchanged.

## Decision

1. `hngh.domain` adds `+key-algorithms+` (`:rsa-sha256`, `:ed25519`)
   and the `key-pin` value gains a read-only `algorithm` slot,
   defaulting to `:rsa-sha256`; `make-key-pin` refuses anything outside
   the closed vocabulary.
2. The pins-file grammar gains an optional third column:
   `IDENTIFIER<TAB>ABSOLUTE-KEY-PATH[<TAB>ALGORITHM]`. Unknown,
   extra, or empty algorithm tokens refuse as malformed; omitted
   columns default to `rsa-sha256`. The previous "extra column
   refuses" behavior is preserved for unknown algorithms.
3. Signature verification routes per pin: `:rsa-sha256` keeps the
   single bounded `openssl dgst -sha256 -verify` invocation; `:ed25519`
   uses `openssl pkeyutl -verify -pubin -inkey KEY -rawin
   -sigfile SIG -in PAYLOAD` (Ed25519 signs the message itself; the
   `-in` flag is required by pkeyutl — the positional form was
   discovered and fixed during live verification). One transport call
   per verification, same temp-file lifecycle, no default transport.
4. `list-pins` renders `IDENTIFIER<TAB>PATH<TAB>ALGORITHM` with the
   resolved algorithm per pin.

## Evidence

- Tests written first, red (`+KEY-ALGORITHMS+ not found`), then green:
  `make test` passes 8 reader guards and 2713 checks (+18: domain
  vocabulary/default/refusal, parser columns, argv routing per
  algorithm, list-pins rendering).
- Live end-to-end proof with a real throwaway Ed25519 keypair:
  `verify-attestation` against a raw-signed envelope →
  `attestation status=verified key=ed-key ... state=current` exit 0;
  a tampered payload → `attestation status=refused labels=bad-signature`;
  `list-pins` renders `ed-key<TAB>...<TAB>ed25519`.
- Committed through the self-governed ceremony: `src/packages.lisp`
  exports landed via the chore lane excluded by the dependency guard
  (`545b4bc`); the implementation and tests were proposed (admitted
  10/10 principles), certified against real evidence, and committed as
  `hngh: candidate 21a694ee...` (`2481715`), pushed to origin.
- README, roadmap, changelog, and this record updated; the README
  `Not yet` list drops the Ed25519 clause.

## Remaining unknowns

- Network claim methods behind the federation port remain deferred
  (2026-08-24 decision 5 evidence-first fork).
- Review-fed policy profiles remain the standing policy-profile gap.
