;;;; plugins/file-watcher.lisp — Hngh File Watcher (Wave 2)
;;;;
;;;; Generalized file-change notification plugin. Registers arbitrary
;;;; filesystem paths and emits file.changed events on the event bus
;;;; when content changes. Uses mtime-poll (inotify is a future
;;;; enhancement). Thread-safe via bordeaux-threads mutex.
;;;;
;;;; SPDX-License-Identifier: AGPL-3.0-or-later
;;;; SPDX-FileCopyrightText: 2026 boundring <boundring@gmail.com>

(in-package :hngh.plugins.file-watcher)

;;; --- State -----------------------------------------------------------------

(defvar *registered-paths* (make-hash-table :test 'equal)
  "Hash of absolute-path-string → plist(:scope :label :snapshot).")

(defparameter *watch-interval* 5
  "Seconds between mtime-poll cycles (fallback when inotify is unavailable).")

(defparameter *debounce-ms* 300
  "Milliseconds to coalesce rapid successive changes into a single event.")

(defvar *last-event-time* 0
  "Internal universal-time of the last published file.changed event.")

(defvar *running* nil
  "Whether the file watcher is active.")

(defvar *watch-thread* nil
  "Background thread polling for file changes.")

(defvar *paths-lock* (bt:make-lock "hngh-file-watcher-paths")
  "Mutex protecting *registered-paths* access.")

;;; --- Helpers ---------------------------------------------------------------

(defun resolve-absolute-path (path)
  "Return absolute pathname string for PATH, or nil if path does not exist."
  (handler-case
      (namestring (truename path))
    (error () nil)))

(defun path-directory-p (path)
  "Return T if PATH is a directory."
  (let ((truename (probe-file path)))
    (and truename (null (pathname-name truename)))))

(defun snapshot-content (path)
  "Return file content string for PATH, or sorted entry list for directories.
Returns nil if PATH is unreadable.
For directories, returns a sorted list of (filename . mtime) pairs."
  (let ((truename (probe-file path)))
    (cond
      ((null truename) nil)
      ((null (pathname-name truename))
       ;; Directory: return sorted list of (filename . mtime) pairs
       (let (entries)
         (let ((seen (make-hash-table :test 'equal)))
           (dolist (entry (append (directory (merge-pathnames "*" truename))
                                  (directory (merge-pathnames "*.*" truename))))
             (let ((name (file-namestring entry)))
               (when (and name (not (string= name "")) (not (gethash name seen)))
                 (setf (gethash name seen) t)
                 (push (cons name (or (file-write-date entry) 0)) entries)))))
         (sort entries #'string< :key #'car)))
      (t
       ;; File: return content string
       (handler-case
           (uiop:read-file-string path)
         (error () nil))))))

(defun compute-file-diff (path before after)
  "Compute a diff summary plist for a file PATH between BEFORE and AFTER states."
  (list :type :modified
        :size-before (when before (length before))
        :size-after (when after (length after))
        :mtime-before nil
        :mtime-after (handler-case (file-write-date path) (error () nil))))

(defun within-debounce-window-p ()
  "Return T when we are inside the debounce window."
  (let ((now (get-universal-time)))
    (and (plusp *last-event-time*)
         (< (* (- now *last-event-time*) 1000) *debounce-ms*))))

(defun publish-file-changed (path info diff &optional before after)
  "Emit a file.changed event through the event bus."
  (declare (ignore before after))
  (when hngh.core.event-bus:*event-bus*
    (handler-case
        (hngh.core.event-bus:publish
         "file.changed"
         (list :path path
               :scope (getf info :scope)
               :label (getf info :label)
               :diff-summary diff
               :timestamp (get-universal-time)
               :source 'file-watcher)
         :source 'file-watcher)
      (error (c)
        (hngh.core:log-warn "File-watcher event publish failed: ~A" c)))))

(defun publish-directory-changes (dir-path info old-entries new-entries)
  "Publish file.changed events for each changed entry in a watched directory."
  ;; Detect new and modified entries
  (dolist (new-entry new-entries)
    (let ((name (car new-entry))
          (mtime (cdr new-entry)))
      (let ((old-entry (assoc name old-entries :test #'string=)))
        (cond
          ((null old-entry)
           ;; New file
           (publish-file-changed
            (namestring (merge-pathnames name (pathname dir-path)))
            info
            (list :type :created
                  :size-before nil
                  :size-after nil
                  :mtime-before nil
                  :mtime-after mtime)))
          ((not (= mtime (cdr old-entry)))
           ;; Modified file
           (publish-file-changed
            (namestring (merge-pathnames name (pathname dir-path)))
            info
            (list :type :modified
                  :size-before nil
                  :size-after nil
                  :mtime-before (cdr old-entry)
                  :mtime-after mtime)))))))
  ;; Detect deleted entries
  (dolist (old-entry old-entries)
    (let ((name (car old-entry)))
      (unless (assoc name new-entries :test #'string=)
        (publish-file-changed
         (namestring (merge-pathnames name (pathname dir-path)))
         info
         (list :type :deleted
               :size-before nil
               :size-after nil
               :mtime-before (cdr old-entry)
               :mtime-after nil))))))

;;; --- Scan loop -------------------------------------------------------------

(defun scan-registered-paths ()
  "Poll every registered path. Publish file.changed when content differs."
  (bt:with-lock-held (*paths-lock*)
    (loop for path being the hash-keys of *registered-paths*
            using (hash-value info)
          do (let* ((previous (getf info :snapshot))
                    (current (snapshot-content path)))
               (unless (equal previous current)
                 (when (within-debounce-window-p)
                   (sleep (/ *debounce-ms* 1000.0)))
                 (setf *last-event-time* (get-universal-time))
                 (setf (getf info :snapshot) current)
                 (if (path-directory-p path)
                     (publish-directory-changes path info previous current)
                     (let ((diff (compute-file-diff path previous current)))
                       (publish-file-changed path info diff previous current))))))))

(defun watch-loop ()
  "Poll registered paths at *watch-interval* seconds."
  (loop while *running* do
        (handler-case
            (scan-registered-paths)
          (error (c)
            (hngh.core:log-warn "File-watcher scan error: ~A" c)))
        (loop repeat *watch-interval*
              while *running*
              do (sleep 1))))

;;; --- Registration API ------------------------------------------------------

(defun register-path (path &key (scope :global) (label nil))
  "Register a filesystem path for change watching.
Returns T on success, NIL if path does not exist (warns, does not error).
If path is already registered, updates scope/label and returns T
without re-seeding the snapshot."
  (let ((abs-path (resolve-absolute-path path)))
    (unless abs-path
      (warn "File watcher: path does not exist: ~A" path)
      (return-from register-path nil))
    (bt:with-lock-held (*paths-lock*)
      (let ((existing (gethash abs-path *registered-paths*)))
        (if existing
            ;; Already registered: update scope/label, keep snapshot
            (progn
              (setf (getf existing :scope) scope
                    (getf existing :label) label)
              t)
            ;; New registration: seed snapshot
            (let ((snapshot (snapshot-content abs-path)))
              (setf (gethash abs-path *registered-paths*)
                    (list :scope scope :label label :snapshot snapshot))
              t))))))

(defun deregister-path (path)
  "Remove a path from change watching.
Returns T if path was registered and removed, NIL if not registered."
  (let ((abs-path (handler-case
                      (namestring (truename path))
                    (error ()
                      (if (stringp path) path (namestring path))))))
    (bt:with-lock-held (*paths-lock*)
      (remhash abs-path *registered-paths*))))

(defun registered-paths (&key (scope nil))
  "Return a list of registered path plists.
If SCOPE is given, return only paths registered under that scope.
Each plist has the form (:path string :scope keyword :label string-or-nil)."
  (bt:with-lock-held (*paths-lock*)
    (loop for path being the hash-keys of *registered-paths*
            using (hash-value info)
          when (or (null scope) (eq (getf info :scope) scope))
          collect (list :path path
                        :scope (getf info :scope)
                        :label (getf info :label)))))

(defun register-role-paths (role squad-root)
  "Register default paths for ROLE under SQUAD-ROOT.
Called by squad startup (Wave 3 dispatch tree creation)."
  (flet ((reg (rel &key (scope role) (label nil))
           (let ((path (merge-pathnames rel squad-root)))
             (register-path path :scope scope :label label))))
    (case role
      (:pm
       (reg "docs/design/" :scope :global :label "pm-design")
       (reg "src/" :scope :global :label "pm-src"))
      (:designer
       (reg "docs/design/" :label "designer-design")
       (reg "designer/inbox.md" :label "designer-inbox")
       (reg "designer/tasks/" :label "designer-tasks"))
      (:coder
       (reg "src/" :label "coder-src")
       (reg "coder/inbox.md" :label "coder-inbox")
       (reg "coder/tasks/" :label "coder-tasks"))
      (:artist
       (reg "docs/design/" :label "artist-design")
       (reg "artist/inbox.md" :label "artist-inbox")
       (reg "assets/" :label "artist-assets"))
      (:accountant
       (reg "accountant/inbox.md" :label "accountant-inbox")
       (reg "journal/" :label "accountant-journal")
       (reg "state.git/log" :label "accountant-state-log"))
      (:worker
       (reg "worker/inbox.md" :label "worker-inbox")
       (reg "worker/tasks/" :label "worker-tasks")
       (register-path
        (merge-pathnames ".hngh-night/tasks/" (user-homedir-pathname))
        :scope :worker :label "worker-night-tasks"))
      (t
       (hngh.core:log-warn "File-watcher: unknown role: ~A" role)))))

;;; --- Lifecycle -------------------------------------------------------------

(defun init (&key (watch-interval *watch-interval*))
  "Initialize the file watcher. Start the background polling thread.
Seeds snapshots for all currently-registered paths. Creates a background
thread named \"hngh-file-watcher\" that runs watch-loop.
Returns T."
  (declare (ignore watch-interval))
  (setf *running* t
        *last-event-time* 0)
  (bt:with-lock-held (*paths-lock*)
    (loop for path being the hash-keys of *registered-paths*
            using (hash-value info)
          do (setf (getf info :snapshot) (snapshot-content path))))
  #+sbcl
  (setf *watch-thread*
        (sb-thread:make-thread #'watch-loop :name "hngh-file-watcher"))
  (hngh.core:log-info "File watcher initialized (~D path(s))"
                      (hash-table-count *registered-paths*))
  t)

(defun shutdown ()
  "Stop the file watcher. Sets *running* to nil, joins the watch thread
(3-second timeout), clears *registered-paths*.
Returns T."
  (setf *running* nil)
  #+sbcl
  (when (and *watch-thread* (sb-thread:thread-alive-p *watch-thread*))
    (sb-thread:join-thread *watch-thread* :timeout 3))
  (setf *watch-thread* nil)
  (bt:with-lock-held (*paths-lock*)
    (clrhash *registered-paths*))
  (hngh.core:log-info "File watcher shut down")
  t)

(defun running-p ()
  "Return T if the file watcher is active."
  *running*)

(defun status ()
  "Return a plist describing the watcher status:
(:running bool :registered-count int :watch-interval int
 :last-event int :paths list-of-strings)"
  (bt:with-lock-held (*paths-lock*)
    (list :running *running*
          :registered-count (hash-table-count *registered-paths*)
          :watch-interval *watch-interval*
          :last-event *last-event-time*
          :paths (loop for path being the hash-keys of *registered-paths*
                       collect path))))

;;; --- Systemd .path unit generation (daemon mode) --------------------------

(defun generate-path-unit (path &key (unit-name nil) (output-dir nil))
  "Generate a systemd .path unit file for PATH.
UNIT-NAME: base name for the unit (default: derived from path hash).
OUTPUT-DIR: directory to write the unit file
(default: ~/.config/systemd/user/).
Returns the path to the generated unit file."
  (let* ((abs-path (resolve-absolute-path path))
         (name (or unit-name
                   (format nil "hngh-file-~A"
                           (subseq (format nil "~X" (sxhash abs-path)) 0 8))))
         (dir (or output-dir
                  (merge-pathnames ".config/systemd/user/"
                                   (user-homedir-pathname))))
         (unit-path (merge-pathnames (format nil "~A.path" name) dir)))
    (ensure-directories-exist unit-path)
    (with-open-file (s unit-path :direction :output :if-exists :supersede)
      (format s "[Unit]~%Description=Hngh file watcher trigger for ~A~%~%"
              name)
      (format s "[Path]~%PathChanged=~A~%~%" abs-path)
      (format s "[Install]~%WantedBy=paths.target~%"))
    (namestring unit-path)))
