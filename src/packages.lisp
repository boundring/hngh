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
            #:stop-task-driver))

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
           #:panes))

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
