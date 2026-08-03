;;;; plugins/fragment-journal.lisp — Fragment journal writer (C5)
;;;;
;;;; Extends the two-file journal convention (-projected.md / -actual.md,
;;;; docs/design/agent-platoons.md §2) with a third artifact for
;;;; unfinished-but-valuable work, per docs/design/squad-autonomy.md §7.
;;;; Additive only — does not touch existing journal, hngh-up, or squad
;;;; launch code paths. Callable from mission-control's pause path.
;;;;
;;;; SPDX-License-Identifier: AGPL-3.0-or-later
;;;; SPDX-FileCopyrightText: 2026 boundring <boundring@gmail.com>

(in-package :hngh.plugins.fragment-journal)

(defvar *running* nil
  "Whether the fragment-journal plugin is active.")

(defun format-journal-timestamp (&optional (universal-time (get-universal-time)))
  "Return UNIVERSAL-TIME formatted as YYYYMMDDTHHMMSSZ, matching the
{{timestamp}} convention used by existing -projected.md/-actual.md journal
filenames."
  (multiple-value-bind (sec min hr day mon year)
      (decode-universal-time universal-time 0)
    (format nil "~4,'0D~2,'0D~2,'0DT~2,'0D~2,'0D~2,'0DZ"
            year mon day hr min sec)))

(defun fragment-journal-path (squad-name &key (journal-dir #p"journal/squads/")
                                            (timestamp nil))
  "Return the pathname for a squad's fragment journal file, following the
hngh/journal/squads/<name>-<timestamp>-fragment.md convention."
  (let ((ts (or timestamp (format-journal-timestamp))))
    (merge-pathnames
     (format nil "~A-~A-fragment.md" squad-name ts)
     journal-dir)))

(defun render-fragment-journal (squad-name reason value location resume-hint attribution)
  "Render the fragment journal Markdown body per
docs/design/squad-autonomy.md §7."
  (format nil "# Fragment: ~A — ~A~%~%**State**: incomplete — ~A~%**Value**: ~A~%**Location**: ~A~%**Resume hint**: ~A~%**Attribution**: ~A~%"
          squad-name reason reason value location resume-hint attribution))

(defun write-fragment-journal (squad-name reason value location resume-hint attribution
                                &key (journal-dir #p"journal/squads/") (timestamp nil))
  "Write a fragment journal for SQUAD-NAME to
<journal-dir>/<squad-name>-<timestamp>-fragment.md, matching the format in
docs/design/squad-autonomy.md §7.

REASON: one-line reason the work is incomplete (budget exhausted / VRAM
preempted / turn cap).
VALUE: why this fragment is worth keeping even unfinished.
LOCATION: files/branches/commits this fragment touches.
RESUME-HINT: the single most useful next action for whoever picks this up.
ATTRIBUTION: role — model, harness, cost.

Returns the pathname written to."
  (let ((path (fragment-journal-path squad-name :journal-dir journal-dir :timestamp timestamp)))
    (ensure-directories-exist path)
    (with-open-file (stream path :direction :output
                                 :if-exists :supersede
                                 :if-does-not-exist :create)
      (write-string (render-fragment-journal squad-name reason value location
                                              resume-hint attribution)
                    stream))
    path))

;;; --- Plugin lifecycle -------------------------------------------------------

(defun init (&key (hngh-home hngh:*hngh-home*))
  "Initialize the fragment-journal plugin. Stateless — journal writes are
on-demand, callable from mission-control's pause path or elsewhere."
  (declare (ignore hngh-home))
  (setf *running* t)
  (hngh.core:log-info "Fragment-journal plugin initialized")
  t)

(defun shutdown ()
  "Shut down the fragment-journal plugin."
  (setf *running* nil)
  (hngh.core:log-info "Fragment-journal plugin shut down")
  t)

(defun running-p ()
  "Return T if the plugin is active."
  *running*)

(defun status ()
  "Return a plist with plugin status."
  (list :running *running*))
