;;;; hngh.asd — ASDF system definition for Hngh
;;;;
;;;; SPDX-License-Identifier: AGPL-3.0-or-later
;;;; SPDX-FileCopyrightText: 2026 boundring

(defsystem "hngh"
  :description "System harness for CachyOS/Arch Linux with AI agent orchestration"
  :version "0.0.1"
  :license "AGPL-3.0-or-later"
  :author "boundring"
  :depends-on (;; Core dependencies
               ;; Now available via pacman + Quicklisp:
               :bordeaux-threads  ; mutexes for thread-safe shared state
               :cl-ppcre          ; regex for dbus signal parsing
               :babel             ; UTF-8 encoding/decoding for wire protocol
               :jsonrpc           ; ACP client (Wave A1): JSON-RPC 2.0 + stdio transport
               :alexandria
               :yason
               :sb-posix          ; stdio pipe FDs for the ACP transport (tests + client)
               ;; Future dependencies (available via Quicklisp when needed):
               ;;   :cl-json      — for AI tool hub (M1.6)
               ;;   :cl-dbus      — for dbus Bridge upgrade
               ;;   :cl-charms    — for Dashboard TUI upgrade
               ;;   :sqlite       — for State Store locks (M1+)
               :jsown             ; JSON schema validation for model probes
               )
  :pathname "src/"
  :serial t
  :components ((:file "packages")
               (:file "core/logging")
               (:file "core/ascii-art")
               (:file "core/config")
               (:file "core/event-bus")
               (:file "core/state-store")
               (:file "core/plugin-host")
               (:file "core/supervisor")
               (:file "core/scheduler")
               (:file "core/threat-detection")
               (:file "core/resource-manager")
               (:file "core/wire-protocol")
               (:file "core/daemon")
               (:file "core/main")
                ;; Data modules (loaded at runtime with *read-eval* nil, not compiled)
                (:static-file "data/squads.lisp")
                (:static-file "data/model-probes.lisp")
                ;; First-party plugins:
                (:file "plugins/dbus-bridge")
                (:file "plugins/dashboard-tui")
                (:file "plugins/package-manager")
                (:file "plugins/system-config")
                (:file "plugins/secrets-manager")
                 (:file "plugins/model-runtime")
                 (:file "plugins/ai-tool-hub")
                 (:file "plugins/ai-orchestrator")
                 (:file "plugins/mission-control")
                 (:file "plugins/emacs-daemon")
                 (:file "plugins/sentry")
                 (:file "plugins/maintenance-coordinator")
                 (:file "plugins/hnghbeats")
                 (:file "plugins/knowledge-base")
                 (:file "plugins/llm-threat-detector")
                 (:file "plugins/backup-manager")
                 (:file "plugins/config-watcher")
                 (:file "plugins/file-watcher")
                 (:file "plugins/hngh-up")
                 (:file "plugins/agents-md")
                 (:file "plugins/fragment-journal")
                 (:file "plugins/squad-resources")
                 (:file "plugins/squad-dispatch")
                 (:file "plugins/beans")
                 (:file "plugins/hngh-planner")
                 (:file "plugins/quota-spreader")
                 (:file "plugins/signals")
                 (:file "plugins/acp-transport")
                 (:file "plugins/acp-client")
                 (:file "plugins/situation-detectors")
                 (:file "plugins/situation-scoring"))
  :in-order-to ((test-op (test-op "hngh/tests"))))

(defsystem "hngh/client"
  :description "Hngh Client CLI — thin client for daemon wire protocol"
  :depends-on ("hngh" "babel" "sb-bsd-sockets")
  :pathname "src/client/"
  :serial t
  :components ((:file "main"))
  :build-operation "program-op"
  :build-pathname "hngh-client"
  :entry-point "hngh.client:main")

(defsystem "hngh/tests"
  :description "Test suite for Hngh"
  :depends-on ("hngh" "hngh/client" "fiveam")
  :pathname "tests/unit/"
  :serial t
  :components ((:file "packages")
               (:file "harness")
               (:file "test-main")
               (:file "test-event-bus")
               (:file "test-state-store")
               (:file "test-plugin-host")
               (:file "test-supervisor")
               (:file "test-scheduler")
               (:file "test-threat-detection")
               (:file "test-resource-manager")
               (:file "test-dbus-bridge")
               (:file "test-dashboard-tui")
               (:file "test-package-manager")
               (:file "test-system-config")
               (:file "test-secrets-manager")
                (:file "test-model-runtime")
                 (:file "test-ai-tool-hub")
                 (:file "test-ai-orchestrator")
                 (:file "test-task-driver")
                 (:file "test-mission-control")
                 (:file "test-emacs-daemon")
                 (:file "test-sentry")
                 (:file "test-hnghbeats")
                 (:file "test-knowledge-base")
                (:file "test-llm-threat-detector")
                 (:file "test-backup-manager")
                 (:file "test-config-watcher")
                 (:file "test-file-watcher")
                 (:file "test-daemon")
                 (:file "test-client")
                 (:file "test-agents-md")
                 (:file "test-fragment-journal")
                 (:file "test-squad-resources")
                 (:file "test-hngh-up")
                 (:file "test-squad-dispatch")
                 (:file "test-beans")
                 (:file "test-hngh-planner")
                 (:file "test-quota-spreader")
                 (:file "test-signals")
                 (:file "test-acp-client")
                 (:file "test-situation-detectors")
                 (:file "test-situation-scoring")
                 (:file "test-model-probes"))
   :perform (test-op (op c)
                        (declare (ignore op))
                        (uiop:symbol-call :hngh.tests :run-tests)
                        (values)))