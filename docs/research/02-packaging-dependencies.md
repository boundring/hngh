---
category: packaging/dependencies
persona: The Quartermaster
status: seed
anchored: 2026-10-03
note: automation anchors predate the 2026-10-04 control-room cut (broadsheet/ghost/wire surfaces retired)
---

# Packaging & Dependencies — what hngh runs today

hngh ships three packaging lanes, each with a no-sudo or one-step-privilege seam. **ISO build**: `automation/iso/build-live-iso.sh` is a thin mkarchiso wrapper — profile at `automation/iso/profile`, work/out under `~/.hngh/db/iso` (never the dev repo), never escalates itself ("run it under sudo yourself"), missing archiso exits 3 (automation/iso/build-live-iso.sh:2-17,50-53). The build profile is archiso >= v76 releng-shaped with syslinux BIOS + systemd-boot UEFI (automation/iso/profile/profiledef.sh:1-5); its `pacman.conf` pins build-host repos, and a cachyos-v3 mirror incident (CDN served a 988-byte HTML page → pacstrap died "GPGME error: No data") forced the rule that the host must trust keyrings first (automation/iso/profile/pacman.conf:1-11). A baked airootfs pacman.conf closes mkarchiso's "serverless conf" gap on the target (automation/iso/profile/airootfs/etc/pacman.conf:1-5). The installer verifies tool deps up front (`have_tools`; automation/iso/profile/airootfs/root/install-hngh-os.sh:381-382), syncs NTP so pacstrap GPG works (:391-397), imports the omarchy packaging key (:400-403), and pacstraps an exact verified package set, handing the live pacman.conf/resolv.conf to the target (:515-531).

**AUR lane**: `automation/jobs/aur-build.sh` is a user-session builder that NEVER runs as root and NEVER sudo: AUR RPC v5 lookup (exact-Name rescue + near-miss refusal), a `pacman -T` dependency gate that must come back empty (exit 4 otherwise), `makepkg --noconfirm` explicitly **never `-s`**, then stage the built package for the privileged `wicket install-file` step (automation/jobs/aur-build.sh:1-29). `automation/lib/wicket.sh` SKIPS AND COUNTS `# aur` lines (`WICKET_AUR_SKIPPED`) and treats `# omarchy-repo` lines as first-class once the signed repo is configured; an empty transaction refuses with rc 4 reporting both counts (automation/lib/wicket.sh:80-114). Sudoers grants copy one user-built pkg into root-owned staging and `pacman -U --noconfirm --needed` — exact commands validated inside a root-owned script (config/wicket.sudoers.example:31-34).

**Manifest discipline**: `automation/config/omarchy-base.packages` pins the additive session stack to omacom/omarchy @ quattro (4.0.x) commit `3faafba234e530b0986196b98dc2c38951e7dd6f`, marks each line `# aur` vs `# omarchy-repo`, and keeps an EXCLUDED avoid-list (linux-omarchy, limine-entry-tool, mkinitcpio/UKI, sddm; :1-13,39-47). Provenance matters: `owe`/`owe-lockfeed` are NOT AUR despite an AUR RPC hit (same-day third-party mirror) — they ship from the signed [omarchy] repo (automation/CHANGELOG.md:146-156). Node tooling is a private `automation/package.json` (jcode-sdk ^1.1.0, axe-core ^4.10.0, puppeteer-core ^23.0.0; automation/package.json:1-11) plus a registry for npm-global CLIs (omp, bili, pi, opencode) in config/hngh-packages.tsv:15-19. Doctrine: `bootstrap.sh` refuses curl|bash installers — jcode is the documented OPTIONAL, never auto-installed (automation/bootstrap.sh:95-99).

## Open questions for web research

1. How do Arch-ecosystem tools verify user-built AUR packages before privileged install — is a signed local repo (`repo-add`) the standard graduation path from a staging dir?
2. Reproducible mkarchiso builds: profile pinning, mirror snapshotting, and ISO provenance attestation practices.
3. Managing global npm CLI tools with lockfile-like provenance (npm global vs corepack vs standalone binaries).
4. Patterns for dependency-closed unprivileged package builds (makepkg without `-s`) and how others enforce the "pacman -T empty" precondition.
5. Keeping live-ISO and installed-target package databases in sync without shipping broken pacman.conf defaults.

## Candidate external systems to survey

- archiso / mkarchiso (releng profile)
- devtools (`pkgctl`, makepkg conventions)
- mkosi
- nixos-generators / Nix image builds
- Debian Live / live-build
