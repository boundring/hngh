;;;; tests/unit/test-agents-md.lisp — Tests for AGENTS.md discovery/merge (C1)
;;;;
;;;; SPDX-License-Identifier: AGPL-3.0-or-later
;;;; SPDX-FileCopyrightText: 2026 boundring <boundring@gmail.com>

(in-package :hngh.tests)

(def-suite :hngh.agents-md
  :description "Tests for AGENTS.md discovery/merge (C1)"
  :in :hngh)

(in-suite :hngh.agents-md)

;;; --- Helpers ---------------------------------------------------------------

(defun %agents-md-tmp-root ()
  "Return a fresh temporary directory for building a fixture tree."
  (merge-pathnames (format nil "hngh-agents-md-test-~D/" (random 1000000))
                    (uiop:temporary-directory)))

(defun %write-agents-md (dir content)
  "Write CONTENT to DIR/AGENTS.md, creating DIR if needed."
  (let ((path (merge-pathnames "AGENTS.md" dir)))
    (ensure-directories-exist path)
    (with-open-file (stream path :direction :output :if-exists :supersede
                                 :if-does-not-exist :create)
      (write-string content stream))
    path))

;;; --- discover-agents-md ------------------------------------------------------

(test discover-agents-md-nested-fixture-tree
  "Given a 3-level nested fixture, returns nearest-first AGENTS.md paths."
  (let* ((root (%agents-md-tmp-root))
         (mid (merge-pathnames "mid/" root))
         (leaf (merge-pathnames "leaf/" mid)))
    (unwind-protect
         (progn
           (%write-agents-md root "## Root~%Root content")
           (%write-agents-md mid "## Mid~%Mid content")
           (%write-agents-md leaf "## Leaf~%Leaf content")
           (let ((found (hngh.plugins.agents-md:discover-agents-md leaf)))
             (is (= 3 (length found)))
             (is (string= "AGENTS.md" (file-namestring (first found))))
             ;; nearest-first: leaf's own AGENTS.md must come before mid's and root's
             (is (search "leaf" (namestring (first found))))
             (is (search "mid" (namestring (second found))))
             (is (not (search "mid" (namestring (third found)))))))
      (ignore-errors (uiop:delete-directory-tree root :validate #'identity)))))

(test discover-agents-md-skips-missing-levels
  "A directory chain with only some AGENTS.md files present returns only those."
  (let* ((root (%agents-md-tmp-root))
         (mid (merge-pathnames "mid/" root))
         (leaf (merge-pathnames "leaf/" mid)))
    (unwind-protect
         (progn
           (ensure-directories-exist leaf)
           (%write-agents-md root "## Root~%Root content")
           (let ((found (hngh.plugins.agents-md:discover-agents-md leaf)))
             (is (= 1 (length found)))
             (is (equal (truename (merge-pathnames "AGENTS.md" root)) (first found)))))
      (ignore-errors (uiop:delete-directory-tree root :validate #'identity)))))

(test discover-agents-md-none-found
  "A fixture tree with no AGENTS.md files anywhere returns an empty list."
  (let* ((root (%agents-md-tmp-root))
         (leaf (merge-pathnames "leaf/" root)))
    (unwind-protect
         (progn
           (ensure-directories-exist leaf)
           (let ((found (hngh.plugins.agents-md:discover-agents-md leaf)))
             (is (null found))))
      (ignore-errors (uiop:delete-directory-tree root :validate #'identity)))))

;;; --- merge-agents-md ---------------------------------------------------------

(test merge-agents-md-nearest-wins-sections-additive
  "Nearest file wins on header conflict; sections from other files are additive."
  (let* ((root (%agents-md-tmp-root))
         (leaf (merge-pathnames "leaf/" root)))
    (unwind-protect
         (progn
           (%write-agents-md root (format nil "## Coordination contract~%Root rule.~%~%## Repo notes~%Root repo notes.~%"))
           (%write-agents-md leaf (format nil "## Coordination contract~%Leaf rule wins.~%"))
           (let* ((paths (hngh.plugins.agents-md:discover-agents-md leaf))
                  (merged (hngh.plugins.agents-md:merge-agents-md paths))
                  (sections (getf merged :sections)))
             (is (string= "Leaf rule wins."
                          (cdr (assoc "Coordination contract" sections :test #'string=))))
             (is (string= "Root repo notes."
                          (cdr (assoc "Repo notes" sections :test #'string=))))))
      (ignore-errors (uiop:delete-directory-tree root :validate #'identity)))))

(test merge-agents-md-extracts-commands-freshness-facts
  "merge-agents-md surfaces fenced commands, freshness date, and bullet facts."
  (let* ((root (%agents-md-tmp-root)))
    (unwind-protect
         (progn
           (%write-agents-md root
                              (format nil "## Repo notes~%~%\`\`\`~%make test~%\`\`\`~%~%## Current state (2026-08-02)~%~%- **Tests**: green~%"))
           (let* ((paths (hngh.plugins.agents-md:discover-agents-md root))
                  (merged (hngh.plugins.agents-md:merge-agents-md paths)))
             (is (member "make test" (getf merged :commands) :test #'string=))
             (is (string= "2026-08-02" (getf merged :freshness)))
             (is (string= "green" (cdr (assoc "Tests" (getf merged :facts) :test #'string=))))))
      (ignore-errors (uiop:delete-directory-tree root :validate #'identity)))))

(test extract-bullet-facts-matches-known-pattern
  "extract-bullet-facts parses `- **Key**: value` lines into an alist."
  (let ((facts (hngh.plugins.agents-md:extract-bullet-facts
                (format nil "- **Tests**: 1203/1203~%- **M7 daemon**: committed~%- not a fact line~%"))))
    (is (= 2 (length facts)))
    (is (string= "1203/1203" (cdr (assoc "Tests" facts :test #'string=))))
    (is (string= "committed" (cdr (assoc "M7 daemon" facts :test #'string=))))))

(test agents-md-plugin-lifecycle
  "init/shutdown/running-p/status behave as a standard plugin surface."
  (hngh.plugins.agents-md:init)
  (is-true (hngh.plugins.agents-md:running-p))
  (is (getf (hngh.plugins.agents-md:status) :running))
  (hngh.plugins.agents-md:shutdown)
  (is (not (hngh.plugins.agents-md:running-p))))
