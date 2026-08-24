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