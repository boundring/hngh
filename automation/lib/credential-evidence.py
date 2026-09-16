#!/usr/bin/env python3
"""credential-evidence.py — key-rotation-freshness evidence rows (hermetic).

Machine-checkable facts for perishable credential metadata: each row pins
the last rotation epoch and the SHA-256 of an evidence file (fail-closed
when the file moves). Ledger is TSV:

  credential <TAB> rotate_epoch <TAB> scan_epoch <TAB> evidence_sha256 <TAB> evidence_path

CLI:
  record NAME EVIDENCE_PATH LEDGER [--now EPOCH]  -> append/replace a row
  check LEDGER OLA_S [--now EPOCH]                -> print findings; each
      finding is `finding-class: credential detail`. A clean ledger prints
      `ok` lines. Classes: ledger-missing / stale / hash-mismatch /
      evidence-missing / malformed-row / ok.

Fail-closed: anything unparseable, unhashable, or older than the OLA is a
finding, never a silent pass. Ledger is created mode 600. No secrets in
rows — only digests and paths.
"""

import hashlib
import os
import sys
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


def check(ledger, ola_s, now):
    """Yield finding lines; fail-closed on every unverifiable fact."""
    rows = _read(ledger)
    if rows is None:
        yield f"ledger-missing: {ledger}"
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
            yield f"evidence-missing: {name} {evpath}"
            continue
        current = _digest(evpath)
        if current is None or not (digest and digest == current):
            yield f"hash-mismatch: {name} (evidence {evpath})"
            continue
        yield f"ok: {name} (rotate epoch {rotate_epoch})"


def main(argv):
    if argv and argv[0] == "record" and len(argv) >= 4:
        now = int(argv[5]) if len(argv) > 5 and argv[4] == "--now" else 0
        return record(argv[1], argv[2], argv[3], now)
    if argv and argv[0] == "check" and len(argv) >= 3:
        ola = int(argv[2])
        now = int(argv[4]) if len(argv) > 4 and argv[3] == "--now" else os.time()
        for line in check(argv[1], ola, now):
            print(line)
        return 0
    Path(__file__).name
    print(__doc__.strip())
    return 2


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
