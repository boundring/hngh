# What distro packaging prior art (PKGBUILD/AUR, deb/rpm packaging, Nix/system-manager-style declarative layers) should hngh's environment contract and package registry rungs learn from?

Status: crystallized 2026-09-12 from research line `os-harness-distro-packaging`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-os-harness-distro-packaging.md.

# Contracted Research Record

**Line:** What distro packaging prior art (PKGBUILD/AUR, deb/rpm packaging, Nix/system-manager-style declarative layers) should hngh’s environment contract and package registry rungs learn from?  
**Lifecycle state:** contracting  
**Record type:** final structured summary — findings, recommendations, open threads

## Verification Posture

- The hngh kernel repository root is given as `/home/bricker/Projects/etc/hngh`.
- From the supplied context, I cannot verify specific internal file paths inside that repository. Therefore this record does **not** assert concrete hngh file paths beyond the repository root itself.
- The prior material mentioned possible paths such as `/home/bricker/Projects/etc/hngh/nixpkgs` and `/home/bricker/Projects/etc/hngh/debian`. I treat those as unverified and do not rely on them as evidence.
- Claims about PKGBUILD/AUR, deb/rpm, Nix, and systemd-style declarative layers are external packaging prior art. Where they depend on upstream documentation or implementation behavior that I cannot verify here, I mark them explicitly as unverified in this context.

---

## Findings

### 1. PKGBUILD/AUR: The Build Script as an Auditable Lifecycle

**Prior-art idea:**  
Arch’s PKGBUILD model separates packaging into explicit lifecycle phases: source acquisition, preparation, build, package creation, installation, and cleanup. AUR adds a registry-like layer of package scripts rather than only prebuilt binaries.

**Transferable lesson for hngh:**  
hngh’s environment contract should not be only a final installed state. It should expose an explicit lifecycle:

- fetch source or artifact
- verify source/artifact
- prepare environment
- build or materialize package
- install/activate into target environment
- verify runtime state
- clean up or roll back

This is valuable because agent-harness environments often need to be replayable, inspectable, and attributable.

[truncated at model call: completion hit the max_tokens cap (finish_reason=length) - re-run the beat]
