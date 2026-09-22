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
	python3 -B tests/test-identity-seam.py
	python3 -B tests/test-slug-mint-residual.py
	python3 -B tests/test-plan-feed-graph.py
	python3 -B tests/test-curator-beat.py
	python3 -B tests/test-render-blocks-feed.py
	python3 -B tests/test-rehearse-gate.py
	python3 -B tests/test-notify-email.py
	python3 -B tests/test-notify-send-path.py
	python3 -B tests/test-cap-block-operator-item.py
	python3 -B tests/test-email-dismiss-durability.py
	python3 -B tests/test-imap-poll.py
	python3 -B tests/test-credentials.py
	python3 -B tests/test-credential-evidence.py
	python3 -B tests/test-doc-secrets.py
	python3 -B tests/test-doc-hygiene.py
	python3 -B tests/test-getting-started-links.py
	python3 -B tests/test-leg-budgets.py
	python3 -B tests/test-hngh-packages.py
	python3 -B tests/test-hngh-services.py
	python3 -B tests/test-doc-filter.py
	python3 -B tests/test-router-tick.py
	python3 -B tests/test-alert-lifecycle.py
	python3 -B tests/test-router-feed.py
	python3 -B tests/test-slow-units.py
	python3 -B tests/test-readout-writers.py
	python3 -B tests/test-story-view.py
	python3 -B tests/test-dashboard-feedback.py
	python3 -B tests/test-dashboard-p0.py
	python3 -B tests/test-dashboard-p1.py
	python3 -B tests/test-dashboard-p1-ui.py
	python3 -B tests/test-history-view.py
	python3 -B tests/test-routes-view.py
	python3 -B tests/test-dashboard-selfreview-ledger-skew.py
	python3 -B tests/test-digest-html.py
	python3 -B tests/test-digest-append-scrub.py
	python3 -B tests/test-email-digest-overwide-intake.py
	python3 -B tests/test-scrub-module.py
	python3 -B tests/test-gdelt-news.py
	python3 -B tests/test-news-desk.py
	bash tests/test-news-articles.sh
	python3 -B tests/test-newspaper-window.py
	python3 -B tests/test-manga-draft.py
	python3 -B tests/test-manga-collage.py
	python3 -B tests/test-manga-vision-token-mode.py
	python3 -B tests/test-narrative-ledger.py
	python3 -B tests/test-feedback-apply.py
	python3 -B tests/test-correction-linkage.py
	python3 -B tests/test-service-ctl.py
	python3 -B tests/test-queue-progress.py
	python3 -B tests/test-email-qa.py
	python3 -B tests/test-agent-supervision.py
	python3 -B tests/test-agent-respawn.py
	python3 -B tests/test-beat-watchdog.py
	python3 -B tests/test-patrol.py
	python3 -B tests/test-candidate-hash-reconciliation.py
	python3 -B tests/test-viz-schema-patrol.py
	python3 -B tests/test-viz-schema-version.py
	python3 -B tests/test-viz-schema-history.py
	python3 -B tests/test-history-feed.py
	python3 -B tests/test-fleet-feed.py
	python3 -B tests/test-graph-data.py
	python3 -B tests/test-system-feed.py
	python3 -B tests/test-report-queue-evidence.py
	python3 -B tests/test-report-queue-redaction.py
	bash tests/test-config-backup-fail-redact.sh
	bash tests/test-oversight-tick-alert-redact.sh
	bash tests/test-research-beat-ingest-redact.sh
	bash tests/test-research-dispositions-redact.sh
	bash tests/test-research-tsv-path-sweep.sh
	bash tests/test-research-sweep-selfheal.sh
	# default scope = the four research data files + docs/research/*.md
	# (2026-09-17 writer-gap follow-through: the crystallized-doc title
	# emitter is gate-covered too)
	python3 -B scripts/research-tsv-path-sweep.py --check
	python3 -B tests/test-hngh-home-catalog.py
	python3 -B tests/test-harness-adapters.py
	bash tests/test-beat-blockers.sh
	bash tests/test-plan-priority-selector.sh
	bash tests/test-session-class.sh
	bash tests/test-launch-jcode.sh
	bash tests/test-worker-render.sh
	bash tests/test-memory-gate.sh
	python3 -B tests/test-session-launch.py
	python3 -B tests/test-bctx-launch.py
	python3 -B tests/test-ocgo-attribution.py
	python3 -B tests/test-ocgo-launch.py
	python3 -B tests/test-ocgo-config-cost.py
	python3 -B tests/test-sessions-feed.py
	bash tests/test-model-zai-proxy.sh
	python3 -B tests/test-causes.py
	python3 -B tests/test-launcher-templates.py
	python3 -B tests/test-resume-pass.py
	python3 -B tests/test-context-ratio.py
	bash tests/test-news-screen.sh
	python3 -B jobs/agent-supervision.py --selfcheck
	bash tests/test-model-deck-leg.sh
	bash tests/test-model-remote-token-mode.sh
	bash tests/test-model-bearer-argv.sh
	bash tests/test-model-refresh-hygiene.sh
	bash tests/test-model-reply-scrub.sh
	python3 -B ng/test-dispatch-gate.py

	bash tests/test-overnight-shutdown.sh
	bash tests/test-overnight-forethought.sh
	python3 -B tests/test-overnight-awk-disposition.py
	bash tests/test-model-kimi-leg.sh
	bash tests/test-model-ocgo-leg.sh
	bash tests/test-model-pin-routing.sh
	bash tests/test-review-ladder.sh
	bash tests/test-notify-seam.sh
	bash tests/test-marked-cut.sh
	bash tests/test-context-pack.sh
	bash tests/test-bctx-canary.sh
	bash tests/test-research-governor.sh
	bash tests/test-research-accel2.sh
	bash tests/test-research-review.sh
	python3 -B tests/test-research-harvest.py
	bash tests/test-publication-review.sh
	bash tests/test-research-blockers.sh
	bash tests/test-failfirst.sh
	bash tests/test-system-awareness.sh
	bash tests/test-dev-plan-synth.sh
	python3 -B tests/test-external-content.py
	bash tests/test-remote-push.sh
	python3 -B tests/test-plan-identity.py
	python3 -B tests/test-omp-bridge.py
	python3 -B tests/test-hngh-bridge-plugin.py
	python3 -B tests/test-plan-templates.py
	python3 -B tests/test-mcp-server.py
	bash tests/test-model-demote.sh
	python3 -B tests/test-lib-dependencies.py
	bash tests/test-quota-routing.sh
	bash tests/test-unit-model-env.sh
	bash tests/test-wiki-health.sh
	bash tests/test-ttsr-fit.sh
	bash tests/test-probe-hygiene.sh
	bash tests/test-credential-health-argv.sh
	bash tests/test-probe-token-mode.sh
	bash tests/test-bootstrap.sh
	bash tests/test-installer.sh
	bash tests/test-permissions.sh
	bash tests/test-imagegen-submit.sh
	bash tests/test-dispatch.sh
	python3 -B tests/test-digest-local.py
	bash tests/test-deck-availability.sh
	bash scripts/lint-identifiers.sh
	@echo "identifier lint passed; run make smoke for the end-to-end proof"

# adhoc: run one cadence tick for a tier now (no systemd required).
# usage: make adhoc TIER=5m
adhoc:
	bash jobs/cadence-tick.sh TIER="$(TIER)"