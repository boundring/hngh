# boundring.hngh — hngh dashboard as an Omarchy shell plugin

A bar widget + desk panel for omarchy-shell: the operator queue count in
the bar, and a panel listing decision cards with one-click handle / park
(note required) against the local hngh dashboard at
`http://127.0.0.1:8890`.

## Install (on an Omarchy machine)

Hand-made install (no git repo needed yet):

```sh
mkdir -p ~/.config/omarchy/plugins
cp -r automation/omarchy-plugin/boundring.hngh ~/.config/omarchy/plugins/
omarchy-shell shell rescanPlugins
```

Once published as a git repo:

```sh
omarchy plugin add <git-url> --enable
```

Validate before/after edits:

```sh
omarchy plugin validate automation/omarchy-plugin/boundring.hngh
```

## Requires

- The hngh dashboard serving `127.0.0.1:8890` (landed by
  `automation/iso/profile/airootfs/root/install-hngh-os.sh` on hngh OS
  machines; on other boxes run the automation dashboard yourself).
- omarchy-shell (Quickshell/QML). The widget fails open: unreachable
  dashboard shows `hngh ?` and an empty desk.

## Contract

- Bar: `hngh N` where N = `queues.operator` from `newspaper.json`
  (polled every 30 s); `hngh ?` when the dashboard is unreachable.
- Panel: current operator decision cards; `handle` posts
  `/operator-item/handle {id}`, `park` posts `/operator-item/park
  {id, note}` (button disabled until a note is typed — the dashboard
  rejects a noteless park); link opens the full broadsheet.
- The plugin only talks to `127.0.0.1:8890` and only the six
  allowlisted `/operator-item/*` endpoints (pinned by
  `automation/tests/test-omarchy-plugin.py`).

## Status

v0.1.0 — structure validated against the Omarchy plugin contract
(manifest schema, entry points, no symlinks) and pinned by the repo
suite; QML is live-unexercised (no omarchy-shell on this host) — run
`omarchy plugin validate` on the target box after install.
