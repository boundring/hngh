# Context budget and tooling wiring record

## Scope

Records two operator-facing decisions made 2026-08-24 after the public
launch, now that Hngh's operator surface runs through the maintained
context-compression route:

1. **Context budget**: the operator prefers active context at roughly 40%
   of the model window (or a little under). With billion-context as the
   single compression authority, omp's own auto-compaction stays disabled,
   and the ~40% preference is encoded where billion-context actually reads
   it.
2. **Toolchain wiring**: `omp` and `pi` are shell functions (fish) that
   route every invocation through `bili` (billion-context launcher); the
   deprecated `billion-context-omp` extension is removed. This is the
   maintained path per the upstream README ("omp ships with the plugin
   built in"; the plugin repository is maintenance-only).

## Decision

`~/.config/billion-context/billion-context.json`:

```json
{
  "compress": {
    "maxContextLimit": "40%",
    "emergencyThresholdPercent": "75%",
    "nudgeGrowthTokens": 20000
  },
  "providers": {}
}
```

- `maxContextLimit: "40%"` — the context-usage ratio at which the proxy
  fires forced-compression nudges (default is 75%). It is a nudge
  threshold, not a hard cap: billion-context is model-driven via the
  `compress` tool. Set lower than default to honor the 40% preference.
- `emergencyThresholdPercent: "75%"` — the hard floor that triggers
  emergency truncation of large tool outputs. Must be >= `maxContextLimit`
  (engine constraint). A draft set 45% and was corrected: the emergency
  layer is a sledgehammer for pathological outputs, not a preferred
  posture; 75% keeps the soft ~40% target inside a sane ceiling.
- `nudgeGrowthTokens: 20000` — smaller growth step (default 50000) for
  more frequent, gentler nudges above the floor.
- omp's `compaction.thresholdPercent: 40` already exists but stays
  `enabled: false`: billion-context is the single compression authority
  (no double compression).

`~/.config/fish/functions/omp.fish` and `pi.fish` route `omp`/`pi` through
`bili`. A fresh launch spawns a fresh proxy on a new port that reads this
config; a session's proxy already running before the file existed keeps
its defaults until relaunched. Deleted the deprecated
`billion-context-omp` extension (its repo maintenance-only; upstream
points to the proxy).

## Evidence

- Config file: `~/.config/billion-context/billion-context.json` (above).
- Fish functions: `~/.config/fish/functions/omp.fish`, `pi.fish`
  (each `command bili <host> -- $argv`); verified once via
  `omp --version` -> `omp/18.0.4` through a fresh proxy log.
- Upstream docs: billion-context `CONFIGURATION.md` (Compression Tuning:
  `maxContextLimit` nudge semantics, `emergencyThresholdPercent` must be
  >= max, `nudgeGrowthTokens`).

## Remaining unknowns

The 40% nudge threshold is a preference encoded in configuration, not yet
measured end-to-end against real sessions; the live session at time of
writing predates the tuned file (next `omp`/`pi` launch picks it up).
Watching the proxy log or its web UI during a long session is the follow-up
that validates (or re-tunes) the value.

## Addendum 2026-08-25 — toolchain reliability: the guardrail outage

The operator toolchain had silently lost its `edit` tool: every
apply_patch-format edit in every omp session was blocked with "Cannot
determine the files targeted by this edit.", regardless of path form or
patch validity. Root cause was not the harness core but a plugin — the
llm-wiki extension (`@zosmaai/pi-llm-wiki` 0.11.4) hooks every `edit`
call to protect its vault, and its patch scanner understood only the
hashline patch format, so apply_patch envelopes parsed as "no determinable
targets" and failed closed.

Lessons for the Hngh operator toolchain:

1. **A middleware guardrail that fails closed on an unrecognized input
   format silently disables an entire tool surface.** The failure
   presented as an edit-tool bug; three sessions of agents burned turns
   retrying path styles against a deterministic block.
2. **Error messages must name their owning layer.** The blocking message
   identified neither the plugin nor the format mismatch. The diagnosis
   that worked in seconds: grep the exact error string across all
   installed packages (harness core, proxy, `~/.omp/plugins`) — the
   string existed only in the plugin's `guardrails.js`. This mirrors
   Hngh's own design rule: refusals carry named labels at the boundary
   that produced them.
3. **Durable local fixes need re-application paths.** The plugin was
   patched in place (dist + TS source) with pristine backups and
   re-appliable diffs kept in `~/.omp/patches/`; a plugin reinstall
   reverts the fix until upstream lands it.

Fix upstream: zosmaai/pi-llm-wiki#162 (envelope-header parsing matched on
the raw untrimmed line so patch body rows quoting envelope syntax are
never misread; hashline parsing unchanged; vault protection verified
still blocking absolute and relative paths). Public failure-case lesson:
MisakaNet intake `contrib_4d2ef67f9a`.
