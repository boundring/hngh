# hngh dashboard as an Omarchy shell plugin (2026-09-29)

## Problem

The operator's Omarchy desktop has no native surface for the hngh
automation dashboard: checking the operator queue means opening
http://127.0.0.1:8890/ in a browser tab. Omarchy 4.x shell plugins
(Quickshell/QML, manifest.json contract) are the desktop-native way to
expose a live queue count and quick dispositions without leaving the
shell.

## Change

- `automation/omarchy-plugin/boundring.hngh/` — hand-installable
  plugin folder (hand-made folders are a supported install path;
  public git publishing is a later operator decision):
  - `manifest.json`: schemaVersion 1, id `boundring.hngh` (not in the
    reserved `omarchy.*` namespace), kind `bar-widget`, entry point
    `BarWidget.qml`, right default section, `allowMultiple: false`.
  - `BarWidget.qml`: bar button "hngh N" (N = live operator queue
    count); polls `http://127.0.0.1:8890/newspaper.json` every 30s
    (`triggeredOnStart`); dashboard unreachable => `operatorQueue = -1`
    and an honest "hngh ?" display (fail-open, no invented data).
    Loads `Panel.qml` through a Loader with the clock-plugin
    injectPanel pattern.
  - `Panel.qml`: `KeyboardPanel` + `PanelKeyCatcher`; lists operator
    decision cards (kicker + headline); per card a handle
    pseudo-button (POST `/operator-item/handle {id}`) and a park note
    TextField + park button (POST `/operator-item/park {id, note}`,
    disabled until the note is non-empty — the server 400s on empty);
    a broadsheet link row via `Qt.openUrlExternally`. No qs.Ui
    dependency (plain Rectangle+MouseArea pseudo-buttons).
  - `README.md`: hand-install (`cp -r` into
    `~/.config/omarchy/plugins/` + shell `rescanPlugins`), validation
    via `omarchy plugin validate`, contract, live-unexercised status.
- `automation/tests/test-omarchy-plugin.py` (10 tests, registered in
  the gate): manifest schema/identity/required fields/entry files
  exist/no symlinks; QML contract pins (moduleName, Panel loader,
  newspaper.json read, queue fail-open); security pins — every http
  literal is `http://127.0.0.1:8890/*` (no external hosts) and every
  operator-item endpoint literal is within the server's verb set
  {handle, park, dismiss, expire, suppress, acknowledge}; park POST
  must carry a non-empty note. README install/validation pins.
- v1 is a CLIENT of the running dashboard; server provisioning stays
  with `automation/iso/profile/airootfs/root/install-hngh-os.sh`.

## Verification

- Suite: 10/10 OK; registered in `automation/Makefile` `test:`.
- `qmllint` on both QML files: exit 0, no warnings (syntax; qs.*
  imports resolve only inside omarchy-shell).
- Live behavior on an Omarchy desktop is unexercised on this host (no
  omarchy CLI / omarchy-shell); `omarchy plugin validate` on a target
  box is the named check, stated honestly in the README.
