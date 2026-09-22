# 2026-09-22 — Xiaomi AI quota source admission (operator-directed)

Operator-directed action (this session): the operator added a 'Xiaomi AI'
entry to the 1Password 'Hngh Secrets' vault and hand-edited
`automation/lib/secrets.py` to admit `XIAOMI_AI_API_KEY` for the injected
env-var flow (`~/.config/plasma-workspace/env/env_vars.sh`). This record
logs the admission officially as a further source of quota work. Scope is
registration/logging only — no model.sh gate wiring, no provider calls,
no vault writes (1Password was treated read-only).

## Scope

Admit Xiaomi (Xiaomi MiMo-2.6-pro, future consumer: oh-my-pi + hngh
automation) to the provider secret surface: `SECRET_ITEMS` in
`automation/lib/secrets.py`, the vault entry, and the login export path.
NOT in scope: a `automation/lib/model.sh` per-provider gate function,
model enablement in any launcher, and any `op` write.

## Evidence command

```
git diff automation/lib/secrets.py
python3 -c "... importlib-load secrets.py; secret('XIAOMI_AI_API_KEY')"   # redacted
op item list --vault "Hngh Secrets" --format json   # titles only
./automation/lib/opv "Xiaomi AI" password >/dev/null; echo $?
./automation/lib/opv "Xiaomi AI" credential >/dev/null; echo $?; echo "${#v}"
grep -n "secrets.py --exports" ~/.config/plasma-workspace/env/env_vars.sh
```

## Observed result

- The operator's `secrets.py` edit adds
  `'XIAOMI_AI_API_KEY': 'Xiaomi AI'` to `SECRET_ITEMS` — exactly the
  existing per-provider pattern (env-var name -> 1Password item title),
  plus a missing-trailing-newline fix. Taken as-is; no format fix needed.
- Vault item `Xiaomi AI` exists in `Hngh Secrets` (29 items total,
  one xiaomi/mimo title match).
- Seam resolution (values never printed): `opv "Xiaomi AI" credential`
  exits 0 with a 51-char whitespace-clean value; `opv "Xiaomi AI"
  password` exits 1 — the item carries a `credential` field but NO
  `password` field, unlike the other 28 items (e.g. `ZHIPU`,
  `OpenRouter` all have both).
- Consequence, verbatim from the read paths: `secret()` and therefore
  `_exports()` hard-code field `'password'`
  (`automation/lib/secrets.py:53`, `:91`), so the plasma-login export
  (`env_vars.sh:20` evals `python3 secrets.py --exports`, fail-soft per
  item) will WARN and SKIP `XIAOMI_AI_API_KEY` until the operator either
  adds a `password` field to the vault item (matches the other 28
  entries) or a per-item field override lands in `secrets.py`. Consumers
  that need it today call `secret('XIAOMI_AI_API_KEY', field='credential')`.
- Injection path: `~/.config/plasma-workspace/env/env_vars.sh:20` evals
  the exports at plasma login; a login re-source (or manual `eval`) is
  required for the new var to appear in agent environments.

## Remaining unknowns

- Which Xiaomi endpoint/model id (`Xiaomi MiMo-2.6-pro`) will serve
  oh-my-pi, and whether the quota is per-day/per-window — no consumer
  exists yet, so no quota gate numbers.
- Operator decision pending: align the vault item's field name
  (`password`) or introduce per-item field overrides in `secrets.py`.
  Vault writes stayed out of scope here (read-only constraint).