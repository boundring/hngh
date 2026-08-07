;;;; tests/unit/test-signals.lisp — Tests for Signals (C6 W1.5)
;;;;
;;;; Fixture tests exercise the fixed signal vocabulary, plant/receive over
;;;; the durable inbox + event bus, invalid-kind fail-closed, and the thin
;;;; exported-transition mapping.
;;;;
;;;; SPDX-License-Identifier: AGPL-3.0-or-later
;;;; SPDX-FileCopyrightText: 2026 boundring <boundring@gmail.com>

(in-package :hngh.tests)

(def-suite :hngh.signals
  :description "Tests for Signals (C6 W1.5)"
  :in :hngh)

(in-suite :hngh.signals)

;;; --- Signal vocabulary ----------------------------------------------------

(test signal-kind-vocabulary
  (dolist (kind '(:ask :affirm :negate :wink :double-take
                  :block :permit :retry :pause :done))
    (is-true (hngh.plugins.signals:valid-signal-kind-p kind)))
  (is-false (hngh.plugins.signals:valid-signal-kind-p :gibberish))
  (is-false (hngh.plugins.signals:valid-signal-kind-p nil)))

;;; --- Plant / receive (durable inbox) --------------------------------------

(test signal-plant-and-receive
  (with-aio-light (tmp)
    (hngh.core.event-bus:init :hngh-home tmp)
    (hngh.core.state-store:init :hngh-home tmp)
    (hngh.plugins.signals:plant-signal 'coder :wink :context-ref "bean-1"
                                 :source 'pm)
    (let ((inbox (hngh.plugins.signals:receive-signals 'coder)))
      (is (= 1 (length inbox)))
      (let ((e (first inbox)))
        (is (eql :wink (getf e :kind)))
        (is (equal "bean-1" (getf e :context-ref)))))))

(test signal-recipient-filtering
  (with-aio-light (tmp)
    (hngh.core.event-bus:init :hngh-home tmp)
    (hngh.core.state-store:init :hngh-home tmp)
    (hngh.plugins.signals:plant-signal 'coder :wink :source 'pm)
    (hngh.plugins.signals:plant-signal 'designer :negate :source 'pm)
    (is (= 1 (length (hngh.plugins.signals:receive-signals 'coder))))
    (is (= 1 (length (hngh.plugins.signals:receive-signals 'designer))))
    (is (zerop (length (hngh.plugins.signals:receive-signals 'artist))))))

(test signal-invalid-kind-fails-closed
  (with-aio-light (tmp)
    (hngh.core.event-bus:init :hngh-home tmp)
    (hngh.core.state-store:init :hngh-home tmp)
    (handler-case
        (progn
          (hngh.plugins.signals:plant-signal 'coder :gibberish)
          (is-false t "should have signaled an error"))
      (error () nil))
    ;; Nothing was journaled even on failure.
    (is (null (hngh.plugins.signals:receive-signals 'coder)))))

;;; --- Exported-transition mapping ------------------------------------------

(test apply-signal-informational-is-noop
  (is-false (hngh.plugins.signals:apply-signal '(:kind :wink))))

(test apply-signal-pause-maps-to-dispatch
  ;; :pause maps onto the exported pause-dispatch; verify dispatch flips.
  (with-aio-light (tmp)
    (hngh.core.event-bus:init :hngh-home tmp)
    (hngh.core.state-store:init :hngh-home tmp)
    (hngh.plugins.ai-orchestrator:init :hngh-home tmp)
    (unwind-protect
         (progn
           (is-true (hngh.plugins.signals:apply-signal '(:kind :pause)))
           (is-true (hngh.plugins.ai-orchestrator:dispatch-paused-p)))
      (hngh.plugins.ai-orchestrator:resume-dispatch))))
