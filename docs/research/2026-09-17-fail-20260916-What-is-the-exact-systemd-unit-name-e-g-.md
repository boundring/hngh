# What is the exact systemd unit name (e.g., `hngh.service`, `hngh-timer.timer`) required to execute the R1 verification commands?

Status: crystallized 2026-09-17 from research line `fail-20260916-What-is-the-exact-systemd-unit-name-e-g-`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-fail-20260916-What-is-the-exact-systemd-unit-name-e-g-.md.

# Research Line Contract: Systemd Unit Names for R1 Verification

**Line:** What is the exact systemd unit name (e.g., `hngh.service`, `hngh-timer.timer`) required to execute the R1 verification commands?
**State:** contracting → **contracted**
**Date:** 2026-09-17

---

## Findings

### F1 — No static unit files exist in the kernel repository

The hngh kernel repository at `[redacted path] contains kernel module source (`.c`, `.h`), build infrastructure (`Makefile`, `Kbuild`), and does **not** contain any `.service` or `.timer` unit files. This was established in the prior expanding beat (2026-09-17) and is consistent with the two LES-fail notes from 2026-09-15, which record failed attempts to identify R1 units via static analysis of the source tree.

> **Confidence:** High — grounded in prior beat 2026-09-17 and corroborated by both LES-fail entries. I cannot independently re-verify the absence of files without live filesystem access; this claim rests on the recorded prior investigation.

### F2 — Unit definitions are generated externally

Systemd unit files for hngh are produced by an **external installer or harness script** that resides outside the kernel source tree. The prior material references an adjacent `hngh-automation` repository (and possibly a `hngh-tools` repo) as candidate locations, but no concrete file path for the installer script was confirmed in any prior beat.

> **Confidence:** Medium — the *existence* of an external generator is inferred from the absence of units in the kernel tree and the drift observation (F4). The *specific location* of the generator script remains unconfirmed. I cannot verify whether `hngh-automation` or another repository contains it without live inspection.

### F3 — "R1" is not defined in available prior art

The label "R1" appears in the research line and in the LES-fail titles but is **not explicitly defined** in any vault note or kernel-repository file cited in the prior material. It is interpreted as an internal verification round (likely "Round 1" integration testing), but no authoritative definition was located.

> **Confidence:** High that it is *undefined* in the available record. The interpretation as "Round 1" is a working hypothesis, not a verified fact.

### F4 — Documented history of doc-vs-install drift

The observation note `obs-2026-08-25-night-check-hngh-harness-healthy-timer-doc-vs-install-drift-` records that the installed systemd state on the host has diverged from what documentation describes. This means any unit name found in a README or script comment may not match what is actually loaded in `/etc/systemd/system/`.

> **Confidence:** High — directly grounded in the cited observation note.

### F5 — The only reliable determination method is live inspection

Given F1 (no static files), F2 (external generation), and F4 (drift history), the exact unit name(s) required for R1 can only be determined by inspecting the **live systemd state** on the target host:

```bash
systemctl list-units --all | grep -i hngh
ls /etc/systemd/system/ | grep -i hngh
```

No prior beat recorded a successful execution of these commands that yielded a definitive answer. The LES-fail notes from 2026-09-15 represent failed static-analysis attempts, not live-inspection results.

> **Confidence:** High as a methodological conclusion. I cannot assert what the *actual* unit names are because no prior beat recorded a successful live inspection.

---

## Recommendations

### R1 — Do not assume or hardcode unit names

Any automation (in `hngh-automation` or elsewhere) that references hngh systemd units must use **dynamic discovery** rather than static names:

```bash
HN_GH_UNITS=$(systemctl list-units --all | grep -i hngh | awk '{print $1}')
for unit in $HN_GH_UNITS; do
    systemctl status "$unit"
done
```

This is robust against the documented drift (F4) and against any future renaming by the external installer (F2).

### R2 — Locate and pin the external installer script

The next concrete research step is to identify the script that generates and installs hngh unit files. Search candidates:

- Parent or sibling directories of `[redacted path]
- The `hngh-automation` repository (path unconfirmed in prior art)
- Any `Makefile`, `install.sh`, or `setup` target in the kernel repo that references `systemd`, `.service`, `.timer`, or `/etc/systemd/system/`

Once located, the unit names it emits become the **authoritative source**, superseding any documentation.

### R3 — Define "R1" in a stable, citable location

Before the next verification cycle, the term "R1" and its associated commands should be written into a single canonical file (e.g., `hngh-automation/README.md` or a dedicated `r1-verification.sh`) so that future research beats do not re-litigate what R1 means.

### R4 — Record live state at each verification point

Each time R1 is executed, capture the output of `systemctl list-units --all | grep -i hngh` and `ls /etc/systemd/system/ | grep -i hngh` into the vault as an observation note. This builds a temporal record that makes drift (F4) detectable and unit-name changes traceable.

---

## Open Threads

| # | Thread | Status |
|---|--------|--------|
| O1 | Exact path of the external installer/harness script that generates hngh systemd units | **Unresolved.** No prior beat confirmed a concrete file path. Candidate locations (`hngh-automation`, `hngh-tools`) are hypothesized but unverified. |
| O2 | Authoritative definition of "R1" and its exact command sequence | **Unresolved.** Not defined in any cited vault note or kernel-repo file. Working hypothesis: "Round 1" integration verification. |
| O3 | The actual unit name(s) loaded on the target host at the time of R1 execution | **Unresolved.** No prior beat recorded a successful live `systemctl` inspection that yielded an answer. The LES-fail notes (2026-09-15) were static-analysis failures, not live-inspection results. |
| O4 | Whether the kernel repo's build system (`Makefile`, `Kbuild`) contains an install target that emits unit files | **Unresolved.** The prior beat states the repo contains build scripts but does not record whether those scripts reference systemd installation. This would require reading the Makefile/Kbuild contents directly. |

---

## References

- `[redacted path] — hngh kernel repository (no `.service` or `.timer` files present per prior investigation; contains `Makefile`, `Kbuild`, `.c`, `.h` sources)
- `[[sources/LES-fail-20260915-Has-R1-systemctl-status-list-timers-jour]]` — Failed attempt to identify R1 units via static analysis (2026-09-15)
- `[[sources/LES-fail-20260915-What-are-the-exact-file-paths-for-the-ca]]` — Failed attempt to locate unit file paths (2026-09-15)
- `[[obs-2026-08-25-night-check-hngh-harness-healthy-timer-doc-vs-install-drift-]]` — Observation of drift between documented and installed systemd state (2026-08-25)
- `[[sources/SRC-2026-08-18-010]]` — Unsloth ROCm libhsa Segfault Workaround & Systemd Watcher (contextual; not directly relevant to unit naming)
- `[[concepts/delegated-contract-verification]]` — Concept note on delegated contract verification (contextual)

> **Verification caveat:** All claims above are grounded in the prior material provided for this research line. I do not have live filesystem or systemd access in this contracting pass. Where a claim would require inspecting the target host (e.g., the actual unit names loaded, the contents of the external installer script), I have marked it as unresolved rather than asserting an answer. The kernel-repository path `[redacted path] is taken from the research-line prompt; the prior beat redacted this path as `[redacted path]`, so I flag that the exact mount point should be re-confirmed on the host if any discrepancy is suspected.
