# Omarchy Theming Map: Blueprints -> omarchy tpl engine

Procedural mapping from the operator's skeuomorphic KDE palette
(`Blueprints.colors`, kdeglobals `ColorScheme=Blueprints`) onto omarchy's
theme-template engine, so phase 4 (look port) is fill-in-the-blanks.

Upstream reference: omacom/omarchy v4.0.4 (sha c668141e), clone at
`~/Projects/etc/omarchy-upstream`. Canonical templates in
`default/themed/*.tpl`; user overrides in `config/omarchy/themed/*.tpl`;
appliers `bin/omarchy-theme-set` (+ per-app wrappers) and
`bin/omarchy-font-set`; drop-in hooks `theme-set.d/` + `font-set.d/`.

## a. Strip-variable mapping table

`*_strip` = bare hex (no `#`); bare names (`{{ accent }}` etc.) are the
`#`-prefixed forms of the same value. `magenta` / `bright_magenta` exist as
separate template vars alongside `purple` (confirmed in clone; pi.json.tpl and
vscode-theme.json.tpl use `magenta`).

| omarchy var               | Blueprints value | Rationale                                        |
|---------------------------|------------------|--------------------------------------------------|
| `background`              | #1e3f58          | window_bg; primary surface                       |
| `foreground`              | #ffffff          | foreground; default text                         |
| `selection_foreground`    | #ffffff          | text stays white on moss selection               |
| `selection_background`    | #567e65          | selection_bg (moss green)                        |
| `red`                     | #b30404          | negative; brick red                              |
| `green`                   | #43c897          | positive                                         |
| `yellow`                  | #f67400          | neutral (KDE orange, slot reuses yellow)         |
| `blue`                    | #357591          | accent rgb(53,117,145); modal teal-blue          |
| `purple` / `magenta`      | OPEN             | no Blueprints analogue; proposed #eda771 (wm_active_bg peach) as magenta stand-in, or lighten selection_bg |
| `cyan`                    | #4ace77          | focus glow; keeps cyan slot in the green family  |
| `muted`                   | #456479          | view_bg_alt; dimmed panels/lines                 |
| `bright_foreground`       | #ffffff          | foreground already max; same value               |
| `bright_red`              | #ce0003          | visited link red                                 |
| `bright_green`            | #39ce8b          | hover                                            |
| `bright_yellow`           | OPEN             | proposed #f5a623 (lightened neutral)             |
| `bright_blue`             | #2e647f          | header_bg; lighter structural blue               |
| `bright_purple` / `bright_magenta` | OPEN    | follow purple pick: lighten #eda771 -> #f2c49b   |
| `bright_cyan`             | OPEN             | proposed #6fe0a4 (lightened focus)               |
| `accent`                  | #357591          | same as blue; drives hypr_gradient + UI accents  |
| `dark_foreground`         | #e5d5cf          | foreground_inactive (vscode uses for dim text)   |
| `background_rgb`          | 1e3f58           | derived: background minus `#` (rgb() contexts)   |
| `light_foreground`        | OPEN             | proposed #ffffff                                 |
| `lighter_background`      | OPEN             | proposed #263e56 (window_bg_alt)                 |
| `dark_background`         | OPEN             | proposed #02040b (complementary_bg)              |
| `darker_background`       | OPEN             | proposed #02040b                                 |

Derived blends available via template filters — no manual picks needed:
`{{ mix background foreground 6%|10%|20%|30% }}`,
`{{ mix background accent 12%|22% }}`, `{{ mix background green 12% }}`,
`{{ mix background red 12% }}`, `{{ mix foreground background 34%|52% }}`.

Unused-but-available Blueprints values (map into overrides/hooks as needed):
`#263e56` window_bg_alt, `#275373` view_bg, `#3a5264` button_bg,
`#2e647f` header_bg, `#1a4059` header_bg_inactive, `#476481` tooltip_bg,
`#eda771` wm_active_bg.

## b. Hyprland decoration

`hyprland.lua.tpl` consumes:
```
{{ hypr_gradient hyprland_active_border accent }}
{{ hypr_gradient hyprland_inactive_border rgba(595959aa) }}
```
Pick: keep **accent #357591** for the active border. Justification: the whole
scheme is a deep blue-teal envelope; the wm peach #eda771 is a chrome accent
(KDE titlebar) that reads as a highlight, not a frame — a peach border would
fight every terminal/panel surface. If the operator later wants the skeuomorphic
"glow" statement, override in `config/omarchy/themed/hyprland.lua.tpl` with
`{{ hypr_gradient hyprland_active_border #eda771 }}`; inactive stays default grey.

## c. Fonts

`bin/omarchy-font-set` + `font-set.d/` hooks.

| Role | Font | Package | Status |
|------|------|---------|--------|
| UI (weight 500) | Averia | VERIFY — `otf-averia` candidate; not confirmed in official repos/extra. If absent, vendor TTF into ~/.local/share/fonts or an AUR build | VERIFY |
| Mono (10pt) | Iosevka | `ttf-iosevka` (official: extra) | confirmed |

## d. App coverage

Themed via existing upstream tpls (operator-critical set):
`foot.ini.tpl`, `kitty.conf.tpl`, `alacritty.toml.tpl`, `ghostty.conf.tpl`,
`chromium.theme.tpl`, `vscode-theme.json.tpl`, `obsidian.css.tpl`,
`btop.theme.tpl`, `neovim.lua.tpl`, `helix.toml.tpl` — plus
`gum_env.lua.tpl`, `shell.toml.tpl`, `hermes.yaml.tpl`,
`hyprland-preview-share-picker.css.tpl`, `keyboard.rgb.tpl`,
`t3code.json.tpl`, `pi.json.tpl`, `claude.json.tpl`.

No tpl / gaps:
- GTK apps (the Redmond97 surface): continue working under Hyprland via GTK
  settings pointing at `~/.themes/Redmond97*` (39 variants installed,
  e.g. Redmond97 Dangerous Creatures, Redmond97 CDE, Redmond97 Aqua).
  Settings mechanism gap: omarchy ships no GTK-theme applier. KDE's
  kde-gtk-config does NOT run in a Hyprland session. Options: run
  `xsettingsd` (with `~/.xsettingsd` setting Net/ThemeName) or `nwg-look`
  to persist `~/.config/gtk-3.0/settings.ini` + `gtk-4.0`. Pick one at
  phase 4; nwg-look is the low-effort default.
- Qt apps outside a KDE session: `platformtheme` / `QT_QPA_PLATFORMTHEME`
  must be pinned to the Blueprints scheme file; no tpl covers this — needs a
  hook in `theme-set.d/` if any Qt tools survive the Hyprland move.
- Widget style 'Windows' and aurorae 'irixium' window deco are KDE-only;
  they do not port. Hyprland decoration = section b only.
- Icons: Memphis98 via `~/.local/share/icons` + gtk icon-theme setting;
  rides the same nwg-look/xsettingsd write as the GTK theme.

## e. omp / oh-my-pi seam

Upstream ships `pi.json.tpl` and `claude.json.tpl` — the agent-config layer is
already a first-class citizen of the theme engine, so Hngh's omp theme config
needs no custom pipeline: the omp role/theme color values are rendered from
the same template vars (background/foreground/accent/mix blends) and rewritten
by `omarchy-theme-set` whenever the theme changes. Phase 4 work is therefore:
fill `config/omarchy/themed/pi.json.tpl` (and claude equivalent) with the
palette table above — nothing else to wire.

## f. Phase 4 execution order

1. Write `config/omarchy/themed/*.tpl` set from table (a): copy upstream tpls
   as base is unnecessary — overrides only need to differ; start with the
   operator-critical set (foot, kitty, alacritty, chromium, vscode, obsidian,
   btop, neovim, pi.json, hyprland.lua).
2. Run `omarchy-theme-set <name>`; confirm all appliers rewrite configs.
3. Run `omarchy-font-set` for Averia UI 500 + Iosevka 10pt (resolve VERIFY
   package first).
4. Verify in-session: terminal colors, chromium scheme, vscode theme, hypr
   border, agent JSON regen.
5. Add `theme-set.d/` hook for GTK (xsettingsd/nwg-look theme+icons) and any
   Qt pinning; add `font-set.d/` hook if font needs per-app flags.
6. Only then port dashboard continuity check: dashboard palette
   (`broadsheet.css:26-33`: --paper #f4f0e6, --ink #26221c, --moss #4a6b3a)
   stays independent — it is a web surface, not omarchy-themed. No change
   required; noted for contrast review only.

## Provenance

- Recon session 2026-09-27: upstream omacom/omarchy ref v4.0.4, sha c668141e;
  clone inspected at `~/Projects/etc/omarchy-upstream` (working HEAD
  3faafba234e, ahead of tag; tpl var set re-verified against working tree).
- Template vars confirmed in clone: full `*_strip` family incl.
  `purple_strip`, `magenta`/`bright_magenta`, `accent`, `background_rgb`,
  `dark_/darker_/lighter_background`, `dark_foreground`, `light_foreground`,
  `theme_type`, `mode`, `selection`, `brown`, `orange`,
  `{{ hypr_gradient ... }}`, `{{ mix a b N% }}`.
- Palette source: `Blueprints.colors` (kdeglobals `ColorScheme=Blueprints`).
- GTK themes: `~/.themes` (39 Redmond97* + Irixium, Millennium); dashboard:
  `broadsheet.css:26-33`.
