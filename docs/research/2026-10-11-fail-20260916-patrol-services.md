# Why did patrol alert identity patrol:services fire service-down on comfyui (http://127.0.0.1:8188/ unreachable: URLError) from 2026-09-16 onward, and what disposition (fix or park) closes it?

Status: fixed 2026-10-11 from research line `fail-20260916-patrol-services`
(carrier plan `2026-09-16-routed-patrol-services.plan.md`, duplicate-parked by the
curator 2026-10-01 while the identity stayed live; landed here because the
identity had exhausted re-routes — router parked it at re-route bound 3 after
14 occurrences, 2026-10-02/03 — and no live carrier was closing it).

## Root cause (check-design defect, not a service outage)

`jobs/patrol.py` `check_service_health` probes one HTTP health-url per
`in-use`/`operator-run` row of `automation/config/hngh-services.tsv`. The
comfyui row is `in-use` with health-url `http://127.0.0.1:8188/`, but its
lifecycle contract is TRANSIENT: `automation/lib/comfyui.sh` header
("Spawn -> poll /health -> use -> stop, all inside the imagegen-submit run
process; never a daemon, no systemd unit") and the sibling check
`check_service_children` treats a managed child ALIVE at patrol time as a
leak. Down between imagegen runs is the expected state, so the fixed-URL
probe reported the expected state as `service-down` on every patrol tick
without an active imagegen run.

Live reproduction 2026-10-11T12:20Z: `check_service_health` -> FAIL
`comfyui service-down http://127.0.0.1:8188/ unreachable: URLError` while
`check_service_children` -> PASS `comfyui no transient child (pattern
'port 8188')`. Structural contradiction confirmed by the two checks.

Recurrence: alert identity `patrol:services` re-fired past carriers
2026-09-12/16/18/24; router counted 13 occurrences by 2026-10-02T10:00:41Z
and 14 by 2026-10-03T11:00:41Z, then parked the identity at re-route bound 3
(STATE.md rows 78048-78050, 90876-90878). Carriers 2026-09-16/18 were
parked as duplicates 2026-10-01 (curator, "newest carrier
2026-09-24-routed-patrol-services-2 stays live").

## Fix (automation free-commit surface, no registry/service change)

`check_service_health` now skips rows whose `managed-by` starts with
`automation/` — automation-managed lifecycles are transient by the
2026-09-13 no-daemon boundary — emitting PASS `transient
automation-managed, not probed`. Operator-managed rows (ollama,
unsloth-llamaserver) stay probed; their aliveness is the operator's
signal. The registry row is unchanged (correct as recorded); the check
was wrong to poll a transient row.

Failing-first test: `tests/test-patrol.py::Patrol.
test_service_health_skips_transient_managed` (transient row not probed;
operator row on a dead port still fails service-down). Suite: 54/54 green.
Live check after fix: `patrol --patrol services` -> PASS comfyui
(transient, not probed), PASS unsloth-llamaserver, PASS ollama.

Commit: automation `b6f4f314` (2026-10-11, pushed to origin/main).
