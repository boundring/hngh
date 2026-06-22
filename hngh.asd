;;;; hngh.asd — ASDF system definition for Hngh
;;;;
;;;; SPDX-License-Identifier: AGPL-3.0-or-later
;;;; SPDX-FileCopyrightText: 2026 boundring <boundring@gmail.com>

(defsystem "hngh"
  :description "System harness for CachyOS/Arch Linux with AI agent orchestration"
  :version "0.0.1"
  :license "AGPL-3.0-or-later"
  :author "boundring <boundring@gmail.com>"
  :depends-on (;; Core dependencies
                ;; Event bus, state store, plugin host don't need external deps yet.
                ;; These will be added as components are implemented:
                ;;   :sqlite      — for State Store locks (M0.3)
                ;;   :cl-dbus     — for dbus Bridge (M0.7)
                ;;   :cl-yaml     — for plugin manifests (M0.4)
                ;;   :cl-charms   — for Dashboard TUI (M0.8)
                ;;   :bordeaux-threads — for Supervisor concurrency (M0.5)
                ;; For now, no external dependencies — pure SBCL.
                )
  :pathname "src/"
  :serial t
  :components ((:file "packages")
               (:file "core/logging")
               (:file "core/config")
               (:file "core/main")
               ;; Core components will be added here:
               ;; (:file "core/event-bus")
               ;; (:file "core/state-store")
               ;; (:file "core/plugin-host")
               ;; (:file "core/supervisor")
               ;; (:file "core/scheduler")
               ;; (:file "core/threat-detection")
               ;; First-party plugins will be added here:
               ;; (:file "plugins/package-manager")
               ;; (:file "plugins/ai-orchestrator")
               ;; (:file "plugins/ai-tool-hub")
               ;; etc.
               )
  :in-order-to ((test-op (test-op "hngh/tests"))))

(defsystem "hngh/tests"
  :description "Test suite for Hngh"
  :depends-on ("hngh")
  :pathname "tests/unit/"
  :serial t
  :components ((:file "packages")
               (:file "harness")
               (:file "test-main")
               ;; Test files will be added here:
               ;; (:file "test-event-bus")
               ;; (:file "test-state-store")
               ;; (:file "test-plugin-host")
               ;; (:file "test-supervisor")
               ;; (:file "test-scheduler")
               )
  :perform (test-op (op c)
                      (declare (ignore op c))
                      ;; The test harness is loaded and run via Makefile
                      ))
