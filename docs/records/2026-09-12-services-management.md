# 2026-09-12 — services management (the standing operator pattern)

## The policy

Whatever hngh CAN be authorized to install, configure, manage, and use, it
should. The boundary is authorization, not capability: the installer polls
the operator for every ask-able service; hngh's machinery never widens its
own grants (the permissions profile, docs/records/2026-09-12-privilege-model.md,
stays the authoritative statement of what hngh may do).

Concretely, the lifecycle tiering:

- **Per-run transient operation** (the DEFAULT): services run as transient
  children of the job that needs them — the ComfyUI pattern
  (jobs/imagegen-submit.sh via automation/lib/comfyui.sh). Nothing is left
  running after the job; nothing is installed at boot.
- **Persistent operation**: per-service `systemd --user` units. Each unit is
  still operator-granted (`systemctl --user enable` is printed, never run
  from hngh machinery). No system units, no root.
- **sudo levers**: scoped commands only, as sudoers.d drop-ins generated from
  the permissions profile (install.sh phase 6b; the template is
  automation/config/hngh-automation.sudoers.example). hngh never invents a
  root command at runtime.

## The registry

`automation/config/hngh-services.tsv` — one row per companion service,
open-ended: any future software that benefits from management is a row, and
the guard (automation/tests/test-hngh-services.py) enforces the same
registry+guard pattern as hngh-packages.tsv. Columns: service, role,
install-method, install-path, start-command, health-url, managed-by,
disposition (in-use | operator-run | available | registered-only | absent).

Ask-able set (installer polls the TTY operator): available, registered-only,
absent. Default answer is **register-only** — the choice is recorded in
installer-choices.json (`services` array) and NOTHING is installed. An
explicit operator `install` runs svc_install, which prints the operator step
and exits 1 (install-methods are documented recipes, not silent actions).
Rows whose health endpoint answers are recorded `detected` with no action.

## The management layer

`automation/lib/service-mgmt.sh` — fail-closed verbs over the registry:
`status` (health probe), `start` (transient child via the row's
start-command, setsid so one kill takes the tree, pgid recorded under
~/.hngh-automation/services/), `stop` (only kills the pid hngh itself
started; operator-run processes are refused), `install` (prints the operator
step, installs nothing). Unknown service exits 2. No daemonization, no
units, no privilege escalation tonight — the systemd --user path is the
documented persistent option.

## Seed rows (audited 2026-09-12, citations in the TSV header)

| service | disposition | facts |
|---|---|---|
| comfyui | in-use | /opt/comfyui, venv312 (docs/records/2026-09-11-comfyui-repair.md:38-39); health http://127.0.0.1:8188/; managed transiently by lib/comfyui.sh |
| unsloth-llamaserver | operator-run | UNSLOTH_URL 127.0.0.1:8888 (automation/config.env:24); operator launches via unsloth studio; hngh never starts it |
| ollama | in-use | /usr/local/bin/ollama, OLLAMA_URL 127.0.0.1:11434 (config.env:25); detected up on this box |
| llamacpp | available | /usr/bin/llama-server (llama.cpp vulkan deck leg, config.env:33); not a managed service |

## Tonight's boundary

No installs. The installer services phase renders the registry, detects
live services, records choices, and prints operator steps. Real installs
(comfyui migration into the registry flow, ollama lifecycle ownership,
llama-server named-port instances) are individual future beats, each with
its own authorization.
