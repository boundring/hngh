;;;; tests/unit/test-client.lisp -- Client CLI argument tests
;;;;
;;;; SPDX-License-Identifier: AGPL-3.0-or-later
;;;; SPDX-FileCopyrightText: 2026 boundring <boundring@gmail.com>

(in-package :hngh.tests)

(def-suite client-suite
  :description "Client CLI argument tests"
  :in :hngh)

(in-suite client-suite)

(test client/consumes-hngh-home-option
  "The client consumes --hngh-home instead of forwarding it as task text."
  (multiple-value-bind (subcommand remaining home)
      (hngh.client::parse-subcommand-args
       '("submit" "m7 task" "--hngh-home" "/tmp/hngh-live"))
    (is (string= subcommand "submit"))
    (is (equal remaining '("m7 task")))
    (is (pathnamep home))
    (is (and (pathnamep home)
             (search "/tmp/hngh-live/" (namestring home))))))

(test client/consumes-leading-hngh-home-option
  "Global state-directory configuration may precede the subcommand."
  (multiple-value-bind (subcommand remaining home)
      (hngh.client::parse-subcommand-args
       '("--hngh-home" "/tmp/hngh-leading" "status"))
    (is (string= subcommand "status"))
    (is (null remaining))
    (is (search "/tmp/hngh-leading/" (namestring home)))))

(test client/parses-list-status
  "List status values are converted to protocol keywords."
  (is (eq :done
          (hngh.client::option-value '("--status" "done") "--status"
                                     :converter (lambda (value)
                                                  (intern (string-upcase value) :keyword))))))

(test client/parses-repeated-watch-topics
  "Watch accepts more than one event topic."
  (is (equal '("task-completed" "agent.*")
             (hngh.client::topic-options
              '("--topic" "task-completed" "--topic" "agent.*")))))

(test client/removes-submit-policy-from-task
  "Submit policy options are encoded separately from task text."
  (multiple-value-bind (task policy)
      (hngh.client::parse-submit-options
       '("do" "the" "work" "--policy" "prefer-tool" "local-openai-api"))
    (is (equal '("do" "the" "work") task))
    (is (equal '(:prefer-tool :local-openai-api) policy))))
