# Does the `hngh-automation` repository contain an `install.sh` or Makefile target that explicitly writes to `/etc/systemd/system/`, and if so, what unit names does it emit?

Status: crystallized 2026-09-17 from research line `fail-20260917-Does-the-hngh-automation-repository-cont`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-fail-20260917-Does-the-hngh-automation-repository-cont.md.

# Research Line Contraction — `hngh-automation` systemd install surface

**Line:** Does the `hngh-automation` repository contain an `install.sh` or Makefile target that explicitly writes to `/etc/systemd/system/`, and if so, what unit names does it emit?
**Lifecycle:** contracting → **closed (unresolved)**
**Date:** 2026-09-17

---

## Findings

The line is contracted with the question **unresolved from available material**. No claim in this record asserts the existence of an `install.sh`, a Makefile target, or any systemd unit name in either repository. Specifically:

1. **No install mechanism is confirmed.** Neither an `install.sh` nor a Makefile target that writes to `/etc/systemd/system/` has been located in `hngh-automation`. The prior expansion produced a complete probe sequence but no positive hit.

2. **The `hngh-automation` root path was never established.** No prior material provides a concrete path for this repository. The expansion assumed a sibling layout relative to the kernel repo and flagged it as unverified. Without a confirmed root, no file-level probe can be executed or its results interpreted.

3. **The kernel repository root is known but its internal contents are not.** The line itself supplies `[redacted path] as the kernel repo path. No file paths within that tree are confirmed in any prior material on this line. It is possible that `hngh-automation` lives inside or alongside this tree, but this is unverified.

4. **An indirect ecosystem signal exists but does not answer the question.** Vault source `SRC-2026-08-18-010`, titled *"Unsloth ROCm libhsa Segfault Workaround & Systemd Watcher"*, documents a systemd "watcher" component in the broader hngh ecosystem. This raises prior probability that units are emitted somewhere in the project family, but it does not locate them in `hngh-automation` specifically, nor does it name unit files or an install mechanism. It is a hypothesis to test, not a finding.

5. **No unit names are confirmed.** The question's second clause ("what unit names does it emit?") has no answer in the available record. No `.service`, `.timer`, `.socket`, `.target`, or other unit filename has been observed in any cited material.

---

## Recommendations

These steps resolve the line if and when a host with access to the repositories is available. They are idempotent and safe to re-run on idle hosts.

### 0. Resolve the `hngh-automation` root (blocking prerequisite)

```bash
# If it is a sibling of the kernel repo:
ls -d [redacted path] 2>/dev/null
# Or search more broadly:
find [redacted path] -maxdepth 3 -type d -name 'hngh-automation' 2>/dev/null
```

If neither hit, the line cannot be advanced without a path. Record the confirmed root as `<AUTO>` for all subsequent probes. Do not proceed on an assumed path.

### 1. Locate install artifacts (the literal question)

```bash
find <AUTO> -maxdepth 2 \( -name 'install.sh' -o -name 'Makefile' -o -name 'makefile' \) -print
```

- **Zero hits** → the answer is *no install mechanism of this form exists*; close the line.
- **One or more hits** → proceed to probe 2. Record which files exist.

### 2. Find explicit writes to `/etc/systemd/system/` (the core question)

```bash
grep -rn -- '/etc/systemd/system' <AUTO>
```

- **Zero hits** → no explicit write to the system unit dir; the answer is *no*, even if install artifacts exist. Close or narrow the line.
- **One or more hits** → this is the finding. Record file:line for each hit. Proceed to probe 3.

### 3. Enumerate emitted unit names (the "what units" question)

```bash
grep -rEno '\b[a-zA-Z0-9._-]+\.(service|timer|socket|target|mount|path|slice|scope)\b' \
  <AUTO>/install.sh <AUTO>/Makefile 2>/dev/null
```

If the install mechanism is a Makefile target rather than (or in addition to) `install.sh`, also:

```bash
make -C <AUTO> -n install 2>&1 | grep -E '\.service|\.timer|/etc/systemd'
```

- The unit names are whatever this enumeration returns. Do not infer names from the "watcher" hint in `SRC-2026-08-18-010`; that title is a hypothesis to test, not a finding.
- If the enumeration is empty but probe 2 was positive, the units may be generated at install time (templated); inspect the install script or Makefile target body directly.

### 4. Check for a source directory of units

```bash
find <AUTO> -type d \( -name 'units' -o -name 'systemd' -o -name 'packaging' \)
```

If found, list its contents and cross-reference against probe 2's hits.

### 5. Cross-check the kernel repo for co-located automation

```bash
find [redacted path] -maxdepth 3 \( -name 'install.sh' -o -name 'Makefile' \) -print
grep -rn -- '/etc/systemd/system' [redacted path] 2>/dev/null
```

This guards against the possibility that the install surface lives in the kernel repo tree rather than a separate `hngh-automation` directory.

---

## Open Threads

1. **Where does the systemd "watcher" actually live?** `SRC-2026-08-18-010` documents a watcher component but does not name its repository, install path, or unit filename. Resolving this may answer the present line indirectly (the watcher's install mechanism *is* the answer) or redirect it to a different repository entirely.

2. **Does `hngh-automation` contain packaging logic at all?** The prior expansion assumed a sibling layout and flagged it as unverified. It is possible that `hngh-automation` is a pure CI/automation repo with no installation surface, in which case the answer is *no such mechanism exists* and the line closes cleanly. Probe 1 resolves this.

3. **Are units templated or generated at install time?** If probe 2 is positive but probe 3 returns no static unit names, the units may be constructed from variables (e.g., `sed`/`envsubst` into a template). This would require reading the install script body rather than grepping for literal filenames.

4. **Relationship to `system-reproducibility` concept.** The vault concept `[[concepts/system-reproducibility]]` (created 2026-08-18) may encode design intent about how systemd units are deployed in the hngh ecosystem. It is not a finding about file paths but may clarify whether an install surface is expected to exist at all.

---

## Epistemic boundary

This contraction is grounded exclusively in the prior material on this line and the vault pointers listed below. I have **not** read the contents of `[redacted path] or any `hngh-automation` directory. No file path within either repository is cited as confirmed to exist except the kernel repo root itself, which is supplied by the line's own text. All internal structure remains pending the probe sequence above. Where the vault source `SRC-2026-08-18-010` implies a systemd component exists, I report that implication and do not assert its location.

---

## References

| # | Source | Role in this line |
|---|--------|-------------------|
| 1 | `[redacted path] | Kernel repo root; supplied by the line text. No internal file paths confirmed. |
| 2 | `[[sources/SRC-2026-08-18-010]]` — *"Unsloth ROCm libhsa Segfault Workaround & Systemd Watcher"* | Indirect ecosystem signal; documents a systemd watcher but does not name a repo, install script, or unit file. |
| 3 | `[[sources/LES-fail-20260915-Does-the-obs-2026-08-25-hngh-automation-]]` | Prior research lesson on the same question family; no positive finding carried forward. |
| 4 | `[[sources/LES-fail-20260915-What-are-the-exact-file-paths-for-the-ca]]` | Prior research lesson on file-path resolution for this project family; no confirmed paths carried forward. |
| 5 | `[[concepts/system-reproducibility]]` (created 2026-08-18) | Design-intent context for systemd deployment in the hngh ecosystem; not a finding about file paths. |
| 6 | `[[concepts/clean-architecture]]` | Architectural context; no bearing on install-surface existence. |

*No internal file paths within `[redacted path] or any `hngh-automation` directory are cited as confirmed to exist. The `hngh-automation` root path is unknown and must be resolved before any probe can run.*
