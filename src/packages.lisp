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
           #:event
           #:event-id
           #:event-topic
           #:event-payload
           #:event-timestamp
           #:event-source
           #:make-event
           #:list-subscriptions
           #:clear-all-subscriptions))

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
  (:use :cl)
  (:export #:load-plugin
           #:unload-plugin
           #:reload-plugin
           #:list-plugins
           #:parse-manifest))

(defpackage :hngh.core.supervisor
  (:documentation "Supervisor (A6) — lifecycle management.")
  (:use :cl)
  (:export #:register
           #:restart-component
           #:suspend
           #:component-status))

(defpackage :hngh.core.scheduler
  (:documentation "Scheduler (A5) — timers and scheduling.")
  (:use :cl)
  (:export #:schedule
           #:cancel
           #:list-schedules))

(defpackage :hngh.core.threat-detection
  (:documentation "Procedural Threat Detection (A7) — L1 static + L3 runtime.")
  (:use :cl)
  (:export #:analyze-manifest
           #:analyze-code
           #:observe-behavior))

(defpackage :hngh.plugins
  (:documentation "Namespace for first-party plugin packages.
Each plugin loads into hngh.plugins.<name> to enforce package-level isolation.")
  (:use :cl))
