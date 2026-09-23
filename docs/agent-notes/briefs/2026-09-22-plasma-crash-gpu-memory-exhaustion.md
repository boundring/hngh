# Plasma crash 2026-09-22 -- GPU memory exhaustion diagnosis (read-only investigation)

## Timeline (from journal, boot spanning the event)

- 09:04:30 kernel `amdgpu: Not enough memory for command submission!` (5x) --
  amdgpu buffer-object (VRAM+GTT) allocation failed under user.slice peak
  27G/30G RAM + 15.2G swap (chrome 2.9G+1.7G swap alone, firefox, steam,
  tauonmb, unsloth LLM server resident and serving).
- Within 1s: Mesa radeonsi/libgallium SIGABRT in the Xorg CS thread
  ('Xorg:cs0') -- X server killed -> session 5 scope terminated -> sudden
  logout. Coredumps: Xorg, firefox-agent-bridge-host, tauonmb (all SIGABRT,
  same 09:04:31-37 window, consistent with GPU-context loss, not
  independent bugs).
- 09:04-09:05 re-login: plasmalogin (the display manager is Plasma Login,
  NOT sddm) kwin_wayland greeter could not get a GPU context while VRAM was
  still exhausted (`vkCreateDevice ErrorOutOfDeviceMemory`,
  `amdgpu_bo_alloc failed (-12)`, `EGL_BAD_ALLOC`) -- greeter ran ~9s then
  stopped. First X relaunch refused by Xorg.wrap; second X start 09:05:12
  reached plasma-workspace-x11.target but the desktop was degraded; operator
  issued reboot 09:06:14.

## Trigger chain (refined 2026-09-22 evening session)

- 09:03:09 a local-chain chat request (hour-tier beat traffic; the news lane
  pins LOCAL always per automation/README and jobs/news-articles.py
  `pick_pin`) hit /v1/chat/completions (401, then /api/auth/refresh, then
  retry).
- 09:03:10 the studio auto-loaded Qwen3.8-27B-UD-Q2_K_XL.gguf with the log
  lines `Context auto-reduced: 262144 -> 127488 (model: 10.0 GB, est. KV
  cache: 8.4 GB)` and `GGUF size: 9.2 GB, mmproj: 0.9 GB, est. KV cache:
  8.4 GB, context: 127488, GPUs free: [(0, 20420)]` -- "the whole load
  (20.5 GB) fits without paging" (the fit-to-free-VRAM behavior).
- 09:03:16 llama-server ready at zero desktop headroom.
- 09:04:30 kernel `amdgpu: Not enough memory for command submission!` (x5)
  as desktop GPU buffers grew, then `amdgpu: The CS has been rejected (-12)`,
  plasmashell `QRhiGles2: Context is lost`, Mesa/libgallium SIGABRT inside
  Xorg (systemd-coredump) -- session lost.

## Root cause (high confidence, ~80% + certain supporting)

GPU/system memory exhaustion -> amdgpu BO allocation failure -> Mesa hard
abort of Xorg. Same error class occurred 2026-09-20 17:25:55 -- recurring,
not one-off.

## Ruled out

Kernel OOM-killer (no oom lines); amdgpu ring timeout/reset/hang (none --
allocation class only); sddm (not installed as the manager; plasmalogin);
Wayland session crash (crashed + re-login sessions were X11, kwin_x11 +
Xorg -- only the greeter was Wayland; operator's 'Wayland' label was a
misreport); partial upgrade (no pacman activity 09-21/09-22); plasmashell /
kwin_wayland / kded6 coredumps (none exist); systemd/logind malfunction
(orderly teardown, reboot explicitly user-requested).

## hngh impact

Amended 2026-09-22 evening: hngh was a contributing trigger -- its
local-chain request drove the 20.5 GB load above. The failing allocations
still belonged to the desktop apps (chrome, firefox, steam, tauonmb), and
this was not the OOM-killer (no oom lines) -- that point stands.
Linger=yes kept user@1000 alive; cadence timers re-ticked at login.

## Prevention (operator decisions pending)

1. Bound the hogs: daily restart or cap of the long-lived chrome session;
   close VRAM-heavy games before long desktop sessions; keep GTT/VRAM
   headroom against the unsloth server. The unsloth half LANDED 2026-09-22
   evening: small-model lane (default unsloth/Ornith-1.0-9B-GGUF), per-load
   context pin (ctx-standard 16384 / ctx-deep 32768 via POST
   /api/inference/load max_seq_length), quota-tier fallbacks (zai / xiaomi /
   ocgo / kimi), and cadence unit RAM caps. Still operator items: the
   studio-side fit policy (it sizes a load to fill free VRAM unless
   max_seq_length is sent; a studio default/headroom setting would also
   protect non-hngh loads) and the two upstream reports in item 4 (Mesa
   aborting all of X on one BO-alloc failure; plasmalogin greeter
   no-retry/no-software-fallback).
2. TTY fallback: Ctrl+Alt+F3 console worked when the GUI was dead -- keep in
   operator runbook; consider kernel.sysrq=1 for emergency REISUB.
3. Recurrence watch: patrol journal signature for 'Not enough memory for
   command submission' and 'amdgpu_bo_alloc failed' (same pattern seen
   2026-09-20) -- filed as bead for the patrol allowlist.
4. Upstream reports: (a) Mesa radeonsi aborting the whole X server on a
   transient BO-alloc failure; (b) plasmalogin greeter no-retry /
   no-software-fallback after ErrorOutOfDeviceMemory.

Machine:omp session 2026-09-22; investigation read-only.
