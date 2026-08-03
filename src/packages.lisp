;;;; packages.lisp — Package definitions for Hngh
;;;;
;;;; SPDX-License-Identifier: AGPL-3.0-or-later
;;;; SPDX-FileCopyrightText: 2026 boundring <boundring@gmail.com>

(defpackage :hngh
  (:documentation "Top-level Hngh package. Re-exports core symbols for user-facing API.")
  (:use :cl)
  (:export #:start
           #:stop
           #:version
           #:main
           #:*hngh-home*
           #:*running*
           #:*state-tree-dirs*
           #:init-state-tree
           #:parse-option
           #:keyword-from-string))

(defpackage :hngh.core
  (:documentation "Core image internals. Not exported to plugins.
All core component implementations live in sub-packages of hngh.core.")
  (:use :cl)
  (:export #:log-info
           #:log-warn
           #:log-error
           #:log-debug
           #:log-message
           #:set-log-level
           #:*log-level*
           #:*log-levels*
           #:log-level-priority
          #:should-log-p))

(defpackage :hngh.core.wire-protocol
  (:documentation "Wire protocol for daemon-client communication — length-prefixed S-expressions.")
  (:use :cl)
  (:export #:make-request
           #:make-response
           #:make-event
           #:message-type
           #:request-p
           #:response-p
           #:event-p
           #:encode-message
           #:encode-request
           #:encode-response
           #:encode-event
           #:decode-message
           #:read-message
           #:request-id
           #:request-op
           #:request-payload
           #:request-policy
           #:response-status
           #:response-result
           #:response-error
           #:event-topic
           #:event-payload
           #:supported-op-p))

(defpackage :hngh.core.daemon
  (:documentation "Daemon core — Unix socket server, client handling, event broadcast.")
  (:use :cl :hngh.core)
  (:export #:daemon-start
           #:daemon-stop
           #:daemon-status
           #:init
           #:shutdown
           #:running-p
           #:register-request-handler
           #:broadcast-event
           #:subscribe-client
           #:unsubscribe-client
           #:daemon-socket-path
           #:*daemon-running*))

(defpackage :hngh.core.config
  (:documentation "Configuration loading and management.")
  (:use :cl :hngh.core)
  (:export #:load-config
           #:load-config-file
           #:merge-config
           #:config-get
           #:config-set
           #:save-config
           #:config-path
           #:*config*
           #:*default-config*))

(defpackage :hngh.data.model-probes
  (:documentation "Model benchmark probe suite — procedural scorers for model evaluation.")
  (:use :cl :hngh.core)
  (:export #:*model-probes*
           #:run-probe
           #:run-probe-suite
           #:probe-suite-report
           #:make-scorer-exact
           #:make-scorer-regex
           #:make-scorer-keywords
           #:make-scorer-property
           #:make-scorer-min-lines
           #:make-scorer-no-forbidden
           #:make-scorer-combinator))

(defpackage :hngh.core.event-bus
  (:documentation "Event Bus (A2) — pub/sub nervous system.")
  (:use :cl)
  (:export #:publish
            #:subscribe
            #:unsubscribe
            #:init
            #:shutdown
            #:running-p
            #:topic-match-p
            #:read-journal-events
            #:journal-file-path
            #:event
            #:event-id
            #:event-topic
            #:event-payload
            #:event-timestamp
           #:event-source
           #:make-event
           #:list-subscriptions
           #:clear-all-subscriptions
           #:*event-bus*))

(defpackage :hngh.core.state-store
  (:documentation "State Store (A3) — file tree + file-based locks.")
  (:use :cl)
  (:export #:init
           #:shutdown
           #:running-p
           #:read-state
           #:read-state-string
           #:write-state
           #:write-state-string
           #:delete-state
           #:state-exists-p
           #:append-journal
           #:read-journal
           #:acquire-lock
           #:release-lock
           #:release-all-locks
           #:list-locks
           #:lock-valid-p
           #:snapshot))

(defpackage :hngh.core.plugin-host
  (:documentation "Plugin Host (A1) — load/unload/reload plugins.")
  (:use :cl :hngh.core)
  (:export #:load-plugin
           #:unload-plugin
           #:reload-plugin
           #:list-plugins
           #:get-plugin
           #:plugin-loaded-p
           #:parse-manifest
           #:validate-manifest
           #:unload-all-plugins
           #:clear-registry
           #:plugin-info
           #:plugin-info-name
           #:plugin-info-version
           #:plugin-info-trust-tier
           #:plugin-info-language
           #:plugin-info-package
           #:plugin-info-init-fn
           #:plugin-info-cleanup-fn
           #:plugin-info-reload-fn
           #:plugin-info-loaded-at
           #:plugin-info-manifest-path
           #:plugin-info-state))

(defpackage :hngh.core.supervisor
  (:documentation "Supervisor (A6) — lifecycle management.")
  (:use :cl :hngh.core)
  (:export #:init
           #:shutdown
           #:running-p
           #:register
           #:unregister
           #:check-health
           #:check-all-health
            #:report-failure
            #:report-success
            #:get-status
           #:list-components
           #:component-count
           #:component-info
           #:component-info-id
           #:component-info-type
           #:component-info-restart-policy
           #:component-info-restart-count
           #:component-info-window-restarts
           #:component-info-status))

(defpackage :hngh.core.scheduler
  (:documentation "Scheduler (A5) — timers and scheduling.")
  (:use :cl :hngh.core)
  (:export #:init
           #:shutdown
           #:running-p
           #:schedule
           #:cancel
           #:list-schedules
           #:schedule-count
           #:schedule-info
           #:schedule-info-id
           #:schedule-info-name
           #:schedule-info-type
           #:schedule-info-next-fire
           #:schedule-info-active-p
           #:schedule-info-fire-count))

(defpackage :hngh.core.threat-detection
  (:documentation "Procedural Threat Detection (A7) — L1 static + L3 runtime.")
  (:use :cl :hngh.core)
  (:export #:init
           #:shutdown
           #:running-p
           #:analyze-manifest
           #:analyze-code
           #:observe-behavior
           #:add-pattern
           #:list-flags
           #:clear-flags
           #:*patterns*
           #:*flags*
           #:l1-verdict
           #:l1-verdict-result
           #:l1-verdict-checks-run
           #:l1-verdict-failures))

(defpackage :hngh.core.resource-manager
  (:documentation "Resource Manager (A4) — GPU/VRAM/CPU/memory arbitration.")
  (:use :cl :hngh.core)
  (:export #:init
           #:shutdown
           #:running-p
           #:request-resource
           #:release
           #:status
           #:preempt
           #:hardware-info
           #:list-grants
           #:grant-info
           #:grant-info-id
           #:grant-info-kind
           #:grant-info-spec
           #:grant-info-holder
           #:grant-info-priority
           #:grant-info-preemptible
           #:grant-info-acquired-at
           #:hardware-info-gpus
           #:hardware-info-cpu-model
           #:hardware-info-cpu-cores
           #:hardware-info-memory-total
           #:hardware-info-memory-available))

(defpackage :hngh.plugins
  (:documentation "Namespace for first-party plugin packages.
Each plugin loads into hngh.plugins.<name> to enforce package-level isolation.")
  (:use :cl))

(defpackage :hngh.plugins.dbus-bridge
  (:documentation "dbus Bridge (B13) — translates between internal bus and systemd dbus.")
  (:use :cl :hngh.core)
  (:export #:init
           #:shutdown
           #:running-p
           #:status
           #:find-gdbus
           #:start-monitor
           #:stop-monitor
           #:call-session-method
           #:call-system-method))

(defpackage :hngh.plugins.dashboard-tui
  (:documentation "Dashboard TUI (B9) — text-based dashboard with ANSI escape codes.")
  (:use :cl :hngh.core)
  (:export #:init
           #:shutdown
           #:running-p
           #:status
           #:render
            #:handle-key
            #:format-event-time))

(defpackage :hngh.plugins.package-manager
  (:documentation "Package Manager (B1) — pacman/yay/paru integration.")
  (:use :cl :hngh.core)
  (:export #:init
           #:shutdown
           #:running-p
           #:status
           #:search
           #:info
           #:list-installed
           #:list-aur
           #:list-updates
           #:list-orphans
           #:install-packages
           #:remove-packages
           #:upgrade-system
           #:check-breakage
           #:history
           #:*history*))

(defpackage :hngh.plugins.system-config
  (:documentation "System Config (B2) — /etc management, btrfs snapshots, theming.")
  (:use :cl :hngh.core)
  (:export #:init
           #:shutdown
           #:running-p
           #:status
           #:read-config
           #:write-config
           #:create-snapshot
           #:list-snapshots
           #:managed-paths
           #:add-managed-path
           #:remove-managed-path))

(defpackage :hngh.plugins.secrets-manager
  (:documentation "Secrets Manager (B8) — 1Password/KeePassXC/age vault, policy-checked access.")
  (:use :cl :hngh.core)
  (:export #:init
           #:shutdown
           #:running-p
           #:status
           #:get-secret
           #:set-secret
           #:list-secrets
           #:authorize
           #:revoke
           #:list-policies
           #:backend-available-p
           #:unlock
           #:lock
            #:*backend*
            #:*policies*
            #:*access-log*))

(defpackage :hngh.plugins.model-runtime
  (:documentation "Model Runtime Manager (B4) — ollama/llama.cpp/unsloth/comfyUI lifecycle.")
  (:use :cl :hngh.core)
  (:export #:init
           #:shutdown
           #:running-p
           #:status
           #:spawn-runtime
           #:stop-runtime
           #:list-runtimes
           #:runtime-info
           #:runtime-info-id
           #:runtime-info-kind
           #:runtime-info-model
           #:runtime-info-pid
           #:runtime-info-port
           #:runtime-info-status
           #:runtime-info-grant-id
           #:runtime-info-started-at
           #:discover-runtimes
           #:*runtimes*))

(defpackage :hngh.plugins.ai-tool-hub
  (:documentation "AI Tool Hub (B11) — agentic CLI invocation + direct API, tool registry, cost tracking.")
  (:use :cl :hngh.core)
  (:export #:init
           #:shutdown
           #:running-p
           #:status
           #:invoke
           #:list-tools
           #:tool-capabilities
           #:estimate-cost
           #:select-tool
           #:kill-invocation
           #:list-invocations
           #:cost-log
           #:*tools*
           #:*invocations*
           #:*cost-log*
           #:tool-info
           #:tool-info-id
           #:tool-info-name
           #:tool-info-type
           #:tool-info-command
           #:tool-info-available-p
           #:tool-info-capabilities
           #:invocation-info
            #:invocation-info-id
            #:invocation-info-tool
            #:invocation-info-task
            #:invocation-info-status
            #:invocation-info-started-at
            #:invocation-info-cost
            #:invocation-info-pid
            #:invocation-info-workdir
            #:invocation-info-result
            #:invocation-info-error))

(defpackage :hngh.plugins.ai-orchestrator
  (:documentation "AI Orchestrator (B3) — coordinator, context packages, inter-tool handoffs.")
  (:use :cl :hngh.core)
  (:export #:init
           #:shutdown
           #:running-p
           #:status
           #:delegate
           #:handoff
           #:meta-context
           #:kill-agent
           #:list-agents
           #:agent-info
           #:agent-info-id
           #:agent-info-tool
           #:agent-info-task
           #:agent-info-status
           #:agent-info-cost
           #:agent-info-started-at
            #:*agents*
            #:*policies*
            ;; Task driver (M3)
            #:submit-task
            #:list-tasks
            #:task-driver-tick
            #:start-task-driver
            #:stop-task-driver
            ;; Pause/Resume and Stale-Lease Recovery (H-A3)
            #:pause-dispatch
            #:resume-dispatch
            #:dispatch-paused-p
            #:dispatch-resume-at
            #:recover-stale-task-leases))

(defpackage :hngh.plugins.mission-control
  (:documentation "Mission Control (M6) — tiled tmux observability and agent summoning.")
  (:use :cl :hngh.core)
  (:export #:init
           #:shutdown
           #:running-p
           #:status
           #:start-session
           #:stop-session
           #:add-pane
           #:summon
           #:session-alive-p
           #:panes
           #:read-squad-registry
           #:squad-definition
           #:squad-up
           #:squad-down
           #:squad-forward-prompt
           #:squad-status))

(defpackage :hngh.plugins.emacs-daemon
  (:documentation "Emacs Daemon (M6.3) — lifecycle management for the emacs daemon server.")
  (:use :cl :hngh.core)
  (:export #:init
           #:shutdown
           #:running-p
           #:status
           #:daemon-alive-p
           #:start-daemon
           #:stop-daemon
           #:health))

(defpackage :hngh.plugins.sentry
  (:documentation "Sentry (M-sentry) — procedural safeguards: secret-guard + context-watch.")
  (:use :cl :hngh.core)
  (:export #:init
           #:shutdown
           #:running-p
           #:status
           #:scan-secrets
           #:guard-text
           #:context-pressure
           #:latest-context-size
           #:*secret-patterns*))

(defpackage :hngh.plugins.maintenance-coordinator
  (:documentation "Maintenance Coordinator (H-B1) — read-only maintenance state from state store and pacman lock.")
  (:use :cl :hngh.core)
  (:export #:init
           #:shutdown
           #:running-p
           #:status
           #:read-maintenance-state))

(defpackage :hngh.plugins.hnghbeats
  (:documentation "Hnghbeats (B6) — scheduler-driven daily event condensation.")
  (:use :cl :hngh.core)
  (:export #:init
           #:shutdown
           #:running-p
           #:status
           #:perform-condensation))

(defpackage :hngh.plugins.knowledge-base
  (:documentation "Knowledge Base (B12) — curated articles, decisions, learned patterns.")
  (:use :cl :hngh.core)
  (:export #:initialize-knowledge-base
           #:shutdown-knowledge-base
           #:knowledge-base-ready-p
           #:kb-write-article
           #:kb-get-article
           #:kb-get-decision
           #:kb-get-pattern
           #:kb-query
           #:kb-record-decision
           #:kb-record-pattern
           #:kb-status))

(defpackage :hngh.plugins.config-watcher
  (:documentation "Config Watcher (M2 Wave 2) — watches Hermes config files for changes and emits targeted reload events.")
  (:use :cl :hngh.core)
  (:export #:init
           #:shutdown
           #:running-p
           #:status))

(defpackage :hngh.plugins.hngh-up
  (:documentation "Hngh-Up — goal-driven squad spin-up with procedural questionnaire, spec derivation, and strategy management.")
  (:use :cl :hngh.core)
  (:export #:init
           #:shutdown
           #:running-p
           #:status
           #:cmd-up
           #:derive-squad-spec
           #:generate-questionnaire
           #:answer-from-agents-md
           #:gather-agents-md-context
           #:list-strategies
           #:save-strategy
           #:load-strategy))
(defpackage :hngh.plugins.llm-threat-detector
  (:documentation "LLM Threat Detector (B5) — L2/L4 semantic and behavioral threat review.")
  (:use :cl :hngh.core)
  (:export #:init
           #:shutdown
           #:running-p
           #:status
           #:review-plugin
           #:review-behavior
           #:explain))

(defpackage :hngh.plugins.backup-manager
  (:documentation "Backup Manager (B7) — git-versioned state backup with secrets exclusion.")
  (:use :cl :hngh.core)
  (:export #:init
           #:shutdown
           #:running-p
           #:status
           #:commit
           #:push-backup
           #:restore
           #:diff
           #:list-history
           #:add-remote
           #:list-remotes
           #:managed-ignore-paths))

(defpackage :hngh.plugins.agents-md
  (:documentation "AGENTS.md discovery/merge (C1) — per-directory context gathering.")
  (:use :cl :hngh.core)
  (:export #:init
           #:shutdown
           #:running-p
           #:status
           #:discover-agents-md
           #:merge-agents-md
           #:extract-section-headers
           #:extract-fenced-code-blocks
           #:extract-freshness-date
           #:extract-bullet-facts))

(defpackage :hngh.plugins.fragment-journal
  (:documentation "Fragment journal writer (C5) — breadcrumbs unfinished-but-valuable squad work.")
  (:use :cl :hngh.core)
  (:export #:init
           #:shutdown
           #:running-p
           #:status
           #:write-fragment-journal
           #:render-fragment-journal
           #:fragment-journal-path
           #:format-journal-timestamp))

(defpackage :hngh.plugins.squad-resources
  (:documentation "Squad resource gate and grants (C2) — VRAM-aware squad sizing.")
  (:use :cl :hngh.core)
  (:export #:init
           #:shutdown
           #:running-p
           #:status
           #:model-vram-mb
           #:local-model-p
           #:estimate-squad-vram
           #:free-vram-mb
           #:check-resource-gate
           #:acquire-squad-grants
           #:release-squad-grants
           #:reject-with-fragment))

(defpackage :hngh.client
  (:documentation "Client CLI — thin client for hngh-daemon wire protocol.")
  (:use :cl :hngh.core :hngh.core.wire-protocol)
(:export #:main
#:client-connect
#:client-disconnect
#:send-request
#:cmd-health
#:cmd-status
#:cmd-submit-task
#:cmd-list-tasks
#:cmd-watch
#:cmd-pause
#:cmd-resume
           #:cmd-stop-daemon))

(defpackage :hngh.core.ascii-art
  (:documentation "Austere brutalist ASCII art and megastructure layout utilities.")
  (:use :cl)
  (:export #:print-megastructure-header
           #:print-brutalist-box
           #:megastructure-banner))
