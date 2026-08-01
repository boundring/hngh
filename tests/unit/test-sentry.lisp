;;;; tests/unit/test-sentry.lisp — fixture-based tests for the sentry plugin.
;;;;
;;;; Fixtures: synthetic secret STRINGS (never real credentials) must be
;;;; caught; clean text must pass. Evidence is redacted — no secret value
;;;; may appear in any flag or return.
;;;;
;;;; SPDX-License-Identifier: AGPL-3.0-or-later

(in-package :hngh.tests)

(def-suite :hngh.sentry
  :description "Tests for the Sentry plugin (M-sentry)"
  :in :hngh)

(in-suite :hngh.sentry)

;;; --- scan-secrets: each pattern fires on a synthetic fixture --------------

(test scan-detects-openrouter-key
  (is (member "openrouter-key"
              (hngh.plugins.sentry:scan-secrets
               "here is sk-or-v1abcdef1234567890abcdef1234567890 ok")
              :test #'string=)))

(test scan-detects-private-key-block
  (is (member "private-key-block"
              (hngh.plugins.sentry:scan-secrets
               "-----BEGIN RSA PRIVATE KEY----- and more")
              :test #'string=)))

(test scan-detects-github-pat
  (is (member "github-pat"
              (hngh.plugins.sentry:scan-secrets
               "token ghp_abcdefghijklmnopqrstuvwxyz0123456789 here")
              :test #'string=)))

(test scan-detects-google-api-key
  (is (member "google-api-key"
              (hngh.plugins.sentry:scan-secrets
               "key = AIzaSyA1234567890abcdefghijklmnopqrstuvwx")
              :test #'string=)))

(test scan-clean-text-passes
  (is (null (hngh.plugins.sentry:scan-secrets
             "a perfectly ordinary string about lists and functions")))
  (is (null (hngh.plugins.sentry:scan-secrets ""))))

;;; --- guard-text contract ---------------------------------------------------

(test guard-text-clean-returns-true
  (multiple-value-bind (ok hits)
      (hngh.plugins.sentry:guard-text "nothing secret here")
    (is (eq ok t))
    (is (null hits))))

(test guard-text-secret-returns-nil-and-hits
  (multiple-value-bind (ok hits)
      (hngh.plugins.sentry:guard-text
       "leak: sk-or-v1abcdef1234567890abcdef1234567890")
    (is (null ok))
    (is (member "openrouter-key" hits :test #'string=))))

(test guard-text-redacts-evidence
  ;; the secret VALUE must never appear in the returned hits
  (multiple-value-bind (ok hits)
      (hngh.plugins.sentry:guard-text
       "leak: sk-or-v1SECRETVALUE1234567890abcdef")
    (declare (ignore ok))
    (is (notany (lambda (h) (search "SECRETVALUE" h)) hits))))

;;; --- context-watch ----------------------------------------------------------

(test context-pressure-unknown-when-no-log
  (multiple-value-bind (status size)
      (hngh.plugins.sentry:context-pressure
       #p"/nonexistent/path/agent.log")
    (is (eq status :unknown))
    (is (null size))))

(test context-pressure-green-on-small-log
  (let ((tmp (merge-pathnames "sentry-test-agent.log" (uiop:temporary-directory))))
    (unwind-protect
         (progn
           (with-open-file (s tmp :direction :output :if-exists :supersede)
             (format s "API call #1: in=1000 out=50 total=1050~%"))
           (multiple-value-bind (status size)
               (hngh.plugins.sentry:context-pressure tmp)
             (is (eq status :green))
             (is (= size 1000))))
      (ignore-errors (delete-file tmp)))))

(test context-pressure-red-on-large-log
  (let ((tmp (merge-pathnames "sentry-test-agent2.log" (uiop:temporary-directory))))
    (unwind-protect
         (progn
           (with-open-file (s tmp :direction :output :if-exists :supersede)
             (format s "API call #9: in=240000 out=100 total=240100~%"))
           (multiple-value-bind (status size)
               (hngh.plugins.sentry:context-pressure tmp)
             (is (eq status :red))
             (is (= size 240000))))
      (ignore-errors (delete-file tmp)))))

;;; --- standard plugin surface ------------------------------------------------

(test sentry-status-shape
  (let ((s (hngh.plugins.sentry:status)))
    (is (listp s))
    (is (not (null (getf s :secret-patterns))))))
