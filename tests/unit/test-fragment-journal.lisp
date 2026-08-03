;;;; tests/unit/test-fragment-journal.lisp — Tests for fragment journal writer (C5)
;;;;
;;;; SPDX-License-Identifier: AGPL-3.0-or-later
;;;; SPDX-FileCopyrightText: 2026 boundring <boundring@gmail.com>

(in-package :hngh.tests)

(def-suite :hngh.fragment-journal
  :description "Tests for fragment journal writer (C5)"
  :in :hngh)

(in-suite :hngh.fragment-journal)

;;; --- Helpers ---------------------------------------------------------------

(defun %fragment-journal-tmp-dir ()
  "Return a fresh temporary journal directory for fragment writer tests."
  (merge-pathnames (format nil "hngh-fragment-journal-test-~D/" (random 1000000))
                    (uiop:temporary-directory)))

;;; --- write-fragment-journal --------------------------------------------------

(test write-fragment-journal-creates-file-with-expected-path
  "The written file lives at <dir>/<name>-<timestamp>-fragment.md."
  (let ((dir (%fragment-journal-tmp-dir)))
    (unwind-protect
         (let ((path (hngh.plugins.fragment-journal:write-fragment-journal
                      "test-squad" "budget exhausted" "a working prototype"
                      "src/plugins/foo.lisp" "run make test" "coordinator — gemma-4-12b, $0"
                      :journal-dir dir :timestamp "20260802T142741Z")))
           (is (probe-file path))
           (is (string= "test-squad-20260802T142741Z-fragment.md" (file-namestring path))))
      (ignore-errors (uiop:delete-directory-tree dir :validate #'identity)))))

(test write-fragment-journal-content-matches-format
  "The written content matches the exact §7 format."
  (let ((dir (%fragment-journal-tmp-dir)))
    (unwind-protect
         (let* ((path (hngh.plugins.fragment-journal:write-fragment-journal
                       "night-ralph" "turn cap" "a passing test worth keeping"
                       "src/plugins/hnghbeats.lisp, commit abc1234"
                       "run make test to confirm still green"
                       "worker — opencode (gemma-4-12b), $0"
                       :journal-dir dir :timestamp "20260803T010101Z"))
                (contents (with-open-file (s path :direction :input)
                            (let ((buf (make-string (file-length s))))
                              (read-sequence buf s)
                              buf))))
           (is (search "# Fragment: night-ralph — turn cap" contents))
           (is (search "**State**: incomplete — turn cap" contents))
           (is (search "**Value**: a passing test worth keeping" contents))
           (is (search "**Location**: src/plugins/hnghbeats.lisp, commit abc1234" contents))
           (is (search "**Resume hint**: run make test to confirm still green" contents))
           (is (search "**Attribution**: worker — opencode (gemma-4-12b), $0" contents)))
      (ignore-errors (uiop:delete-directory-tree dir :validate #'identity)))))

(test fragment-journal-path-uses-given-timestamp
  "fragment-journal-path composes name-timestamp-fragment.md deterministically."
  (let ((path (hngh.plugins.fragment-journal:fragment-journal-path
               "duo-review" :journal-dir #p"hngh/journal/squads/" :timestamp "20260802T142741Z")))
    (is (string= "duo-review-20260802T142741Z-fragment.md" (file-namestring path)))))

(test format-journal-timestamp-matches-existing-convention
  "format-journal-timestamp produces YYYYMMDDTHHMMSSZ, matching existing journal filenames."
  (let ((ts (hngh.plugins.fragment-journal:format-journal-timestamp
             (encode-universal-time 41 27 14 2 8 2026 0))))
    (is (string= "20260802T142741Z" ts))))

(test fragment-journal-plugin-lifecycle
  "init/shutdown/running-p/status behave as a standard plugin surface."
  (hngh.plugins.fragment-journal:init)
  (is-true (hngh.plugins.fragment-journal:running-p))
  (is (getf (hngh.plugins.fragment-journal:status) :running))
  (hngh.plugins.fragment-journal:shutdown)
  (is (not (hngh.plugins.fragment-journal:running-p))))
