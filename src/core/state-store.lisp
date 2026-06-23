;;;; core/state-store.lisp — Hngh State Store (A3)
;;;;
;;; Canonical source of truth for all persisted Hngh state.
;;; Hybrid: file tree for most state, file-based locks for cross-plugin
;;; transactional coordination.
;;;
;;; State tree layout (under ~/.hngh/):
;;;   config/             — git-versioned config files
;;;   state/              — runtime state (not versioned if ephemeral)
;;;   journal/            — event journal (append-only)
;;;   journal/events/     — raw event log (owned by Event Bus)
;;;   journal/hnghbeats/  — condensed summaries (owned by Hnghbeats)
;;;   knowledge-base/     — curated articles, decisions, patterns
;;;   plugins/            — plugin manifests, code, state
;;;   agents/             — agent transcripts
;;;   secrets/            — age-encrypted vault (NOT in git tree)
;;;
;;; Locks: file-based (one file per lock resource) with TTL.
;;; Future: migrate to SQLite when cl-sqlite is available.
;;;
;;; SPDX-License-Identifier: AGPL-3.0-or-later
;;; SPDX-FileCopyrightText: 2026 boundring <boundring@gmail.com>

(in-package :hngh.core.state-store)

(defvar *hngh-home* nil
  "Path to the Hngh state directory (set during INIT).")

(defvar *locks-dir* nil
  "Path to the locks directory (state/locks/).")

;;; --- Lifecycle ---

(defun init (&key (hngh-home hngh:*hngh-home*))
  "Initialize the state store.
Sets the Hngh home directory and ensures the state tree exists."
  (setf *hngh-home* hngh-home
        *locks-dir* (merge-pathnames "state/locks/" hngh-home))
  (ensure-directories-exist *locks-dir*)
  (hngh.core:log-info "State store initialized"))

(defun shutdown ()
  "Shut down the state store.
Releases all locks held by this process and cleans up."
  (release-all-locks)
  (setf *hngh-home* nil
        *locks-dir* nil)
  (hngh.core:log-info "State store shut down"))

(defun running-p ()
  "Return T if the state store is initialized."
  (not (null *hngh-home*)))

;;; --- File tree read/write ---

(defun state-path (relative-path)
  "Return the full path for RELATIVE-PATH within the Hngh state tree."
  (unless *hngh-home*
    (error "State store not initialized"))
  (merge-pathnames relative-path *hngh-home*))

(defun read-state (relative-path)
  "Read a Lisp value from RELATIVE-PATH within the state tree.
Returns NIL if the file doesn't exist."
  (let ((path (state-path relative-path)))
    (when (probe-file path)
      (with-open-file (stream path :direction :input :element-type 'character)
        (let ((*read-eval* nil))
          (read stream nil nil))))))

(defun read-state-string (relative-path)
  "Read raw string content from RELATIVE-PATH.
Returns NIL if the file doesn't exist."
  (let ((path (state-path relative-path)))
    (when (probe-file path)
      (with-open-file (stream path :direction :input :element-type 'character)
        (let ((contents (make-string (file-length stream))))
          (read-sequence contents stream)
          contents)))))

(defun write-state (relative-path value)
  "Write a Lisp value to RELATIVE-PATH within the state tree.
Creates parent directories if needed. Overwrites existing content."
  (let ((path (state-path relative-path)))
    (ensure-directories-exist path)
    (with-open-file (stream path :direction :output
                              :if-exists :supersede
                              :if-does-not-exist :create)
      (let ((*print-case* :downcase)
            (*print-pretty* t))
        (prin1 value stream)
        (terpri stream)))
    path))

(defun write-state-string (relative-path string)
  "Write raw string content to RELATIVE-PATH.
Creates parent directories if needed. Overwrites existing content."
  (let ((path (state-path relative-path)))
    (ensure-directories-exist path)
    (with-open-file (stream path :direction :output
                              :if-exists :supersede
                              :if-does-not-exist :create
                              :element-type 'character)
      (write-string string stream))
    path))

(defun delete-state (relative-path)
  "Delete a file at RELATIVE-PATH within the state tree.
Returns T if deleted, NIL if file didn't exist."
  (let ((path (state-path relative-path)))
    (when (probe-file path)
      (delete-file path)
      t)))

(defun state-exists-p (relative-path)
  "Return T if RELATIVE-PATH exists in the state tree."
  (probe-file (state-path relative-path)))

;;; --- Journal append ---

(defun append-journal (journal-name entry)
  "Append ENTRY to journal JOURNAL-NAME.
Journal names map to files under journal/. Each entry is written as
a readable Lisp form, one per line."
  (let* ((journal-path (merge-pathnames
                          (concatenate 'string "journal/" journal-name ".lisp")
                          *hngh-home*))
         (dir (make-pathname :directory (pathname-directory journal-path))))
    (ensure-directories-exist dir)
    (with-open-file (stream journal-path :direction :output
                              :if-exists :append
                              :if-does-not-exist :create)
      (let ((*print-case* :downcase)
            (*print-pretty* nil))
        (prin1 entry stream)
        (terpri stream)))
    journal-path))

(defun read-journal (journal-name)
  "Read all entries from journal JOURNAL-NAME.
Returns a list of Lisp forms."
  (let ((journal-path (merge-pathnames
                          (concatenate 'string "journal/" journal-name ".lisp")
                          *hngh-home*)))
    (when (probe-file journal-path)
      (with-open-file (stream journal-path :direction :input)
        (let ((*read-eval* nil))
          (loop for form = (read stream nil nil)
                while form
                collect form))))))

;;; --- Cross-plugin locks (file-based with TTL) ---
;;;
;;; Each lock is a file in state/locks/ named after the resource ID.
;;; File contents: (holder timestamp ttl)
;;; A lock is valid if: file exists AND (current-time < timestamp + ttl)
;;; Stale locks (expired TTL) are automatically reclaimable.

(defun lock-file-path (resource-id)
  "Return the path to the lock file for RESOURCE-ID."
  (merge-pathnames (concatenate 'string (string-downcase resource-id) ".lock")
                   *locks-dir*))

(defun read-lock-file (path)
  "Read a lock file. Returns (holder acquired-time ttl) or NIL."
  (when (probe-file path)
    (with-open-file (stream path :direction :input)
      (let ((*read-eval* nil))
        (let ((form (read stream nil nil)))
          (when (and (listp form) (= (length form) 3))
            form))))))

(defun lock-valid-p (resource-id)
  "Return T if RESOURCE-ID has a valid (non-expired) lock."
  (let* ((path (lock-file-path resource-id))
         (lock-data (read-lock-file path)))
    (when lock-data
      (destructuring-bind (holder acquired ttl) lock-data
        (declare (ignore holder))
        (< (get-universal-time) (+ acquired ttl))))))

(defun acquire-lock (resource-id &key (holder "hngh") (ttl 300))
  "Acquire a lock on RESOURCE-ID.
HOLDER: string identifying the lock holder (default: \"hngh\")
TTL: time-to-live in seconds (default: 300 = 5 minutes)
Returns T if acquired, NIL if already locked by someone else.
If the existing lock is expired, it is automatically reclaimed."
  (let ((path (lock-file-path resource-id)))
    (cond
      ;; If we already hold a valid lock, renew it
      ((and (lock-valid-p resource-id)
            (string= (first (read-lock-file path)) holder))
       (write-lock-file path holder ttl)
       t)
      ;; If someone else holds a valid lock, fail
      ((lock-valid-p resource-id)
       nil)
      ;; No valid lock — delete stale file if present, then try atomic creation
      (t
       (ensure-directories-exist path)
       (when (probe-file path)
         (ignore-errors (delete-file path)))
       (handler-case
           (with-open-file (stream path :direction :output
                                     :if-exists nil
                                     :if-does-not-exist :create)
             (if stream
                 (progn
                   (let ((*print-case* :downcase))
                     (format stream "(~S ~D ~D)~%" holder (get-universal-time) ttl))
                   t)
                 nil))
         (error () nil))))))

(defun write-lock-file (path holder ttl)
  "Write a lock file."
  (ensure-directories-exist path)
  (with-open-file (stream path :direction :output
                            :if-exists :supersede
                            :if-does-not-exist :create)
    (let ((*print-case* :downcase))
      (format stream "(~S ~D ~D)~%" holder (get-universal-time) ttl))))

(defun release-lock (resource-id &key (holder "hngh"))
  "Release a lock on RESOURCE-ID.
Only releases if HOLDER matches the current lock holder.
Returns T if released, NIL if not held by HOLDER."
  (let* ((path (lock-file-path resource-id))
         (lock-data (read-lock-file path)))
    (when lock-data
      (destructuring-bind (existing-holder acquired ttl) lock-data
        (declare (ignore acquired ttl))
        (when (string= existing-holder holder)
          (delete-file path)
          (return-from release-lock t))))
    nil))

(defun list-locks ()
  "Return a list of all active (non-expired) locks.
Each element is (resource-id holder acquired-time ttl)."
  (when (probe-file *locks-dir*)
    (loop for path in (directory (merge-pathnames "*.lock" *locks-dir*))
          for lock-data = (read-lock-file path)
          when lock-data
          collect (destructuring-bind (holder acquired ttl) lock-data
                    (list (pathname-name path) holder acquired ttl)))))

(defun release-all-locks (&key (holder "hngh"))
  "Release all locks held by HOLDER.
Used during shutdown."
  (when (probe-file *locks-dir*)
    (loop for path in (directory (merge-pathnames "*.lock" *locks-dir*))
          for lock-data = (read-lock-file path)
          when lock-data
          do (destructuring-bind (existing-holder acquired ttl) lock-data
               (declare (ignore acquired ttl))
               (when (string= existing-holder holder)
                 (ignore-errors (delete-file path)))))))

;;; --- Snapshot ---

(defun snapshot ()
  "Compute a hash of the entire state tree.
Returns an integer hash value (SBCL's SXHASH on the tree structure).
This is a simple hash for integrity checking; for cryptographic
integrity, use a proper hash function (future)."
  (unless *hngh-home*
    (error "State store not initialized"))
  (let ((tree-hash 0))
    (labels ((walk-tree (path)
               (when (probe-file path)
                 (cond
                   ((uiop:directory-exists-p path)
                    (dolist (entry (directory (merge-pathnames "*.*" path)))
                      (walk-tree entry)))
                   (t
                    ;; Include file name and size in hash
                    (setf tree-hash
                          (logxor tree-hash
                                  (sxhash (namestring path))
                                  (sxhash (file-size-or-0 path)))))))))
      (walk-tree *hngh-home*))
    tree-hash))

(defun file-size-or-0 (path)
  "Return file size or 0 if not accessible."
  (handler-case
      (with-open-file (s path :direction :input)
        (file-length s))
    (error () 0)))
