;;;; tests/unit/test-model-routes.lisp — M8 model route table (read-only
;;;; parse test; design doc verification step task #2).
;;;;
;;;; Asserts the route table + the 2026-08 two-role split parse correctly and
;;;; expose the expected primary models. Data-only — no network, no model.
;;;;
;;;; SPDX-License-Identifier: AGPL-3.0-or-later

(in-package :hngh.tests)

(def-suite :hngh.model-routes
  :description "Tests for the M8 model route table (read-only parse)"
  :in :hngh)

(in-suite :hngh.model-routes)

(test route-table-parses
  (let ((routes hngh.plugins.model-routes:*routes*))
    (is (plusp (length routes)))
    ;; every route has the 5 expected fields
    (dolist (r routes)
      (is (keywordp (getf r :id)))
      (is (keywordp (getf r :backend)))
      (is (stringp (getf r :model)))
      (is (numberp (getf r :price)))
      (is (member (getf r :class) '(:local :free :quota :payg))))))

(test known-routes-present
  (is (string= "deepseek-v4-flash"
               (hngh.plugins.model-routes:route-model :or-dsv4)))
  (is (string= "gpt-5.6-luna"
               (hngh.plugins.model-routes:route-model :cheap)))
  (is (string= "gemma-4-12B-it-qat"
               (hngh.plugins.model-routes:route-model :local-12b)))
  (is (null (hngh.plugins.model-routes:route-model :does-not-exist))))

(test kimi-route-is-k3-only-and-anthropic-is-absent
  "Route data permits K3 only for Kimi and never exposes an Anthropic model."
  (let ((routes hngh.plugins.model-routes:*routes*))
    (is (string= "k3" (hngh.plugins.model-routes:route-model :kimi-k3)))
    (is (notany (lambda (route)
                  (search "kimi-for-coding" (getf route :model)
                          :test #'char-equal))
                routes))
    (is (notany (lambda (route)
                  (search "claude" (getf route :model) :test #'char-equal))
                routes))))

(test two-role-split-primary-models
  ;; Cost floor: interactive agentic and coding work start on DeepSeek Flash.
  (is (string= "deepseek-v4-flash"
               (hngh.plugins.model-routes:role-model :agentic)))
  (is (string= "deepseek-v4-flash"
               (hngh.plugins.model-routes:role-model :coding))))

(test role-model-backstop
  ;; unknown role falls back to the agentic primary, never errors
  (is (string= "deepseek-v4-flash"
               (hngh.plugins.model-routes:role-model :research))))
