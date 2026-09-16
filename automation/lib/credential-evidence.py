#!/usr/bin/env python3
"""credential-evidence.py — key-rotation-freshness evidence rows (hermetic).

Machine-checkable facts for perishable credential metadata: each row pins
the last rotation epoch and the SHA-256 of an evidence file (fail-closed
when the file moves). Ledger is TSV:

  credential <TAB> rotate_epoch <TAB> scan_epoch <TAB> evidence_sha256 <TAB> evidence_path

CLI:
  record NAME EVIDENCE_PATH LEDGER [EPOCH | --now EPOCH]
      -> append/replace a row pinned at EPOCH. The positional epoch is the
      production call shape (jobs/credential-health.sh); --now EPOCH is the
      test shape. No epoch given = live clock. Fail-closed: a non-integer
      epoch is a malformed-argv refusal, never a silent 0.
  check LEDGER OLA_S [--now EPOCH]                -> print findings; each
      finding is `finding-class: credential detail`. A clean ledger prints
      `ok` lines. Classes: ledger-missing / stale / hash-mismatch /
      evidence-missing / malformed-row / malformed-argv. No --now = live
      clock (never a silent 0).

Fail-closed: anything unparseable, unhashable, or older than the OLA is a
finding, never a silent pass. Ledger is created mode 600 and re-chmodded
600 on every write (O_TRUNC alone would keep an existing wider mode). No
secrets in rows — only digests and paths.

Steady state (credential-health wiring): the first healthy unsloth probe
seeds the ledger (bootstrap); afterwards only the tracked 401-rotate path
re-records. So `stale` means no tracked rotation within the OLA (the
evidence chain stopped being exercised) and `hash-mismatch` means the
token changed outside the tracked path. Operators tune the bound with the
cadence-params `credential-fresh-ola` row.
"""

import hashlib
import os
import sys
import time
from pathlib import Path


def _digest(path):
    h = hashlib.sha256()
    try:
        with open(path, "rb") as fh:
            for chunk in iter(lambda: fh.read(65536), b""):
                h.update(chunk)
    except OSError:
        return None
    return h.hexdigest()


def record(name, evidence_path, ledger, now):
    """Append (replacing a prior row for NAME) a freshness-evidence row."""
    digest = _digest(evidence_path)
    if digest is None:
        raise SystemExit(f"evidence-missing: {name} {evidence_path}")
    rows = _read(ledger) or []
    rows = [(n, row) for (n, row) in rows if n != name]
    rows.append((name, [name, str(now), str(now), digest, str(Path(evidence_path))]))
    os.makedirs(os.path.dirname(ledger) or ".", exist_ok=True)
    fd = os.open(ledger, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    os.fchmod(fd, 0o600)  # O_TRUNC keeps an existing file's (wider) mode
    with os.fdopen(fd, "w") as fh:
        for _, row in rows:
            fh.write("\t".join(row) + "\n")
    return 0


def _read(ledger):
    """Load (name, [fields]) rows; each line is one row."""
    p = Path(ledger)
    if not p.is_file():
        return None
    out = []
    for line in p.read_text().splitlines():
        if not line.strip():
            continue
        fields = line.split("\t")
        out.append((fields[0], fields))
    return out


def redact(path):
    """Tilde-redact a path for public output: $HOME -> ~.

    Findings are piped into alert rows that land in the git-tracked,
    publicly pushed report ledger; absolute home paths must never reach
    it verbatim (username disclosure). Private output keeps full paths:
    the ledger rows themselves stay absolute.
    """
    s = str(path)
    home = str(Path.home())
    if home != "/" and s.startswith(home):
        s = "~" + s[len(home):]
    return s


def check(ledger, ola_s, now):
    """Yield finding lines; fail-closed on every unverifiable fact.

    Findings are public-bound (alert ledger): every interpolated path is
    redacted via redact()."""
    rows = _read(ledger)
    if rows is None:
        yield f"ledger-missing: {redact(ledger)}"
        return
    for name, fields in rows:
        if len(fields) != 5 or fields[0] != name:
            yield f"malformed-row: {name}"
            continue
        rotate_epoch, _scan_epoch, digest, evpath = (
            fields[1], fields[2], fields[3], fields[4],
        )
        try:
            rotate_epoch = int(rotate_epoch)
        except ValueError:
            yield f"malformed-row: {name} (rotate epoch)"
            continue
        if now - rotate_epoch > ola_s:
            yield f"stale: {name} (rotate epoch {rotate_epoch} older than OLA)"
            continue
        if not os.path.isfile(evpath):
            yield f"evidence-missing: {name} {redact(evpath)}"
            continue
        current = _digest(evpath)
        if current is None or not (digest and digest == current):
            yield f"hash-mismatch: {name} (evidence {redact(evpath)})"
            continue
        yield f"ok: {name} (rotate epoch {rotate_epoch})"


def _epoch(tok, what):
    """Parse an integer epoch/OLA; refuse anything else (fail-closed)."""
    try:
        return int(tok)
    except ValueError:
        raise SystemExit(f"malformed-argv: {what} {tok!r} is not an integer")


def main(argv):
    if argv and argv[0] == "record" and len(argv) >= 4:
        rest = argv[4:]
        if not rest:  # live clock
            now = int(time.time())
        elif rest[0] == "--now" and len(rest) == 2:
            now = _epoch(rest[1], "record epoch")
        elif len(rest) == 1 and rest[0] != "--now":  # production shape
            now = _epoch(rest[0], "record epoch")
        else:
            raise SystemExit(
                "malformed-argv: record NAME EVIDENCE LEDGER [EPOCH | --now EPOCH]")
        return record(argv[1], argv[2], argv[3], now)
    if argv and argv[0] == "check" and len(argv) >= 3:
        rest = argv[3:]
        if not rest:  # live clock (os.time() does not exist on Python 3)
            now = int(time.time())
        elif rest[0] == "--now" and len(rest) == 2:
            now = _epoch(rest[1], "check epoch")
        else:
            raise SystemExit("malformed-argv: check LEDGER OLA_S [--now EPOCH]")
        ola = _epoch(argv[2], "OLA")
        if ola < 0:
            raise SystemExit(f"malformed-argv: OLA {ola} is negative")
        for line in check(argv[1], ola, now):
            print(line)
        return 0
    print(__doc__.strip())
    return 2


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
