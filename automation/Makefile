SHELL := /bin/bash
.PHONY: smoke enable disable status test sweep adhoc

# smoke: end-to-end proof — real fetches + real model call + dashboard HTTP check.
# Runs jobs against the real repo; snapshots/digests/STATE are append-only so a
# smoke run just adds today's real data, which is fine (and desired) here.
smoke:
	bash scripts/smoke-test.sh

# enable: install + start user systemd units (dashboard service, 3 timers)
# Run only after the operator has reviewed the smoke run.
enable:
	mkdir -p ~/.config/systemd/user
	cp systemd/*.service systemd/*.timer ~/.config/systemd/user/
	systemctl --user daemon-reload
	systemctl --user enable --now hngh-automation.timer hngh-security.timer hngh-morning.timer
	systemctl --user enable --now hngh-night-agent.timer hngh-morning-report.timer hngh-night-research.timer hngh-model-bench.timer
	systemctl --user enable --now hngh-autonomy.timer
	systemctl --user enable --now hngh-credential-health.timer
	systemctl --user enable --now hngh-cadence-1m.timer hngh-cadence-5m.timer hngh-cadence-10m.timer
	systemctl --user enable --now hngh-cadence-day.timer hngh-cadence-week.timer hngh-cadence-month.timer
	systemctl --user enable --now hngh-cadence-30m.timer hngh-cadence-hour.timer
	systemctl --user enable --now hngh-overnight.timer
	systemctl --user enable --now hngh-dashboard.service
	@echo "enabled timers (hourly / 4h / 06-09 / night-agent / report 07:30 / research 23:40 / bench 01:10 / autonomy hourly / credential-health hourly / cadence 1m-5m-10m-30m-hour-day-week-month / overnight 2h) + dashboard service :8890"

disable:
	systemctl --user disable --now hngh-automation.timer hngh-security.timer hngh-morning.timer
	systemctl --user disable --now hngh-night-agent.timer hngh-morning-report.timer hngh-night-research.timer hngh-model-bench.timer
	systemctl --user disable --now hngh-autonomy.timer
	systemctl --user disable --now hngh-credential-health.timer
	systemctl --user disable --now hngh-cadence-1m.timer hngh-cadence-5m.timer hngh-cadence-10m.timer
	systemctl --user disable --now hngh-cadence-day.timer hngh-cadence-week.timer hngh-cadence-month.timer
	systemctl --user disable --now hngh-cadence-30m.timer hngh-cadence-hour.timer
	systemctl --user disable --now hngh-overnight.timer
	systemctl --user disable --now hngh-dashboard.service
	@echo "disabled all hngh-automation units"

status:
	systemctl --user list-timers 'hngh-*'
	systemctl --user status hngh-dashboard.service --no-pager | head -n 12
	@echo "--- latest breadcrumbs ---"
	@tail -n 5 STATE.md

# sweep: commit job-produced artifacts (append-only data, logs, units)
sweep:
	bash jobs/sweep-artifacts.sh

test:
	find cadence jobs lib scripts -name '*.sh' -print0 | xargs -0 -n8 bash -n
	python3 -B tests/test-plan-acceptance.py
	python3 -B tests/test-notify-email.py
	python3 -B tests/test-credentials.py
	python3 -B tests/test-router-tick.py
	python3 -B tests/test-router-feed.py
	python3 -B tests/test-slow-units.py
	python3 -B tests/test-readout-writers.py
	python3 -B tests/test-service-ctl.py
	python3 -B tests/test-queue-progress.py
	python3 -B tests/test-email-qa.py
	python3 -B tests/test-agent-supervision.py
	python3 -B tests/test-agent-respawn.py
	python3 -B tests/test-session-launch.py
	python3 -B tests/test-bctx-launch.py
	python3 -B tests/test-resume-pass.py
	python3 -B tests/test-context-ratio.py
	bash tests/test-news-screen.sh
	python3 -B jobs/agent-supervision.py --selfcheck
	bash tests/test-model-deck-leg.sh
	bash tests/test-model-lobehub-leg.sh
	bash tests/test-overnight-shutdown.sh
	bash tests/test-model-kimi-leg.sh
	bash tests/test-model-pin-routing.sh
	bash tests/test-notify-seam.sh
	bash tests/test-marked-cut.sh
	bash tests/test-context-pack.sh
	bash tests/test-bctx-canary.sh
	bash tests/test-research-governor.sh
	bash tests/test-research-accel2.sh
	bash tests/test-failfirst.sh
	bash tests/test-dev-plan-synth.sh
	bash tests/test-remote-push.sh
	python3 -B tests/test-plan-identity.py
	python3 -B tests/test-omp-bridge.py
	python3 -B tests/test-plan-templates.py
	python3 -B tests/test-mcp-server.py
	bash tests/test-model-demote.sh
	bash tests/test-quota-routing.sh
	bash tests/test-unit-model-env.sh
	bash tests/test-wiki-health.sh
	bash tests/test-ttsr-fit.sh
	bash tests/test-probe-hygiene.sh
	bash tests/test-bootstrap.sh
	bash scripts/lint-identifiers.sh
	@echo "identifier lint passed; run make smoke for the end-to-end proof"

# adhoc: run one cadence tick for a tier now (no systemd required).
# usage: make adhoc TIER=5m
adhoc:
	bash jobs/cadence-tick.sh TIER="$(TIER)"