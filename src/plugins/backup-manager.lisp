;;;; plugins/backup-manager.lisp — Hngh Backup Manager (B7)
;;;;
;;;; Git-backed backup manager for the Hngh state tree.
;;;; Handles repository initialization, periodic auto-commits,
;;;; remote sync, and restore operations with secret-path protection.
;;;;
;;;; SPDX-License-Identifier: AGPL-3.0-or-later
;;;; SPDX-FileCopyrightText: 2026 boundring <boundring@gmail.com>

(in-package :hngh.plugins.backup-manager)

;;; --- State -----------------------------------------------------------------

(defvar *running* nil
  "Whether the Backup Manager plugin is active.")

(defvar *hngh-home* nil
  "Current Hngh home path used by this plugin.")

(defvar *schedule-id* nil
  "Scheduler job id for periodic backup commits.")

(defvar *event-subscriptions* '()
  "Subscription IDs to clean up on shutdown.")

(defvar *remotes* '()
  "Configured remotes persisted by Backup Manager.")

(defvar *user-ignore-paths* '()
  "User-managed additional ignore paths loaded from state.")

(defvar *history* '()
  "Backup operation history entries (newest-last).")

(defvar *git-lock* (bt:make-lock "backup-manager-git")
  "Mutex serializing git operations that mutate/read staging and working tree.")

(defparameter *config-dir* "config/plugins/backup-manager/"
  "State-store relative config directory for backup manager.")

(defparameter *state-dir* "state/plugins/backup-manager/"
  "State-store relative state directory for backup manager.")

(defparameter *remotes-path* "config/plugins/backup-manager/remotes.lisp"
  "State-store relative path for persisted remotes.")

(defparameter *ignore-path* "config/plugins/backup-manager/ignore.lisp"
  "State-store relative path for user-managed ignore paths.")

(defparameter *history-path* "state/plugins/backup-manager/history.lisp"
  "State-store relative path for backup history.")

(defparameter *default-ignore-paths*
  '("secrets/"
    "state/locks/"
    "config/plugins/secrets-manager/"
    "**/cache/"
    "*.age"
    "*.gpg")
  "Default ignore paths and patterns for backup safety.")

(defparameter *forbidden-prefixes*
  '("secrets/" "state/locks/" "config/plugins/secrets-manager/")
  "Hard forbidden path prefixes that must never be committed.")

(defparameter *forbidden-suffixes* '(".age" ".gpg")
  "Hard forbidden file suffixes that must never be committed.")

(defparameter *default-commit-interval-seconds* 3600
  "Default periodic auto-commit interval in seconds.")

(defmacro with-git-lock (() &body body)
  "Execute BODY while holding *git-lock*."
  `(bt:with-lock-held (*git-lock*)
     ,@body))

;;; --- Helpers: string/path/process ------------------------------------------

(defun trim-string (value)
  "Trim whitespace from VALUE and return a string."
  (string-trim '(#\Space #\Tab #\Newline #\Return)
               (if (stringp value) value (princ-to-string value))))

(defun split-lines (value)
  "Split VALUE into non-empty trimmed lines."
  (if (stringp value)
      (remove-if
       (lambda (line) (zerop (length line)))
       (mapcar #'trim-string (uiop:split-string value :separator '(#\Newline))))
      '()))

(defun string-prefix-p (prefix value)
  "Return T when VALUE starts with PREFIX."
  (and (stringp prefix)
       (stringp value)
       (<= (length prefix) (length value))
       (string= prefix value :end2 (length prefix))))

(defun string-suffix-p (suffix value)
  "Return T when VALUE ends with SUFFIX."
  (and (stringp suffix)
       (stringp value)
       (<= (length suffix) (length value))
       (string= suffix value :start2 (- (length value) (length suffix)))))

(defun path-under-home-p (path)
  "Return T when PATH resolves under *hngh-home*."
  (and *hngh-home*
       (let* ((home (namestring *hngh-home*))
              (candidate (if (pathnamep path)
                             (namestring path)
                             (if (stringp path) path (princ-to-string path)))))
         (string-prefix-p home candidate))))

(defun normalize-path-for-git (path)
  "Normalize PATH for git CLI execution relative to *hngh-home* when possible."
  (let* ((raw (if (pathnamep path)
                  (namestring path)
                  (if (stringp path) path (princ-to-string path))))
         (home (and *hngh-home* (namestring *hngh-home*))))
    (if (and home (string-prefix-p home raw))
        (subseq raw (length home))
        raw)))

(defun unquote-git-path (path)
  "Normalize git-quoted PATH from diff/ls outputs.
If PATH is wrapped in double quotes, strip them and unescape common C escapes."
  (if (and (stringp path)
           (>= (length path) 2)
           (char= (char path 0) #\")
           (char= (char path (1- (length path))) #\"))
      (let ((inner (subseq path 1 (1- (length path)))))
        (with-output-to-string (out)
          (loop for i from 0 below (length inner)
                do (let ((ch (char inner i)))
                     (if (and (char= ch #\\) (< (1+ i) (length inner)))
                         (let ((next (char inner (1+ i))))
                           (cond
                             ((char= next #\") (write-char #\" out) (incf i))
                             ((char= next #\\) (write-char #\\ out) (incf i))
                             (t (write-char ch out))))
                         (write-char ch out))))))
      path))

(defun safe-git-arg-p (s)
  "Return T when S is a non-empty string and not an option-like git argument."
  (and (stringp s)
       (plusp (length s))
       (not (char= (char s 0) #\-))))

(defun read-process-output (stream)
  "Read all data from process STREAM and return it as a string."
  (if stream
      (with-output-to-string (out)
        (loop for line = (read-line stream nil nil)
              while line
              do (progn
                   (write-string line out)
                   (write-char #\Newline out))))
      ""))

(defun run-git (args)
  "Run git with ARGS inside *hngh-home*.
Returns plist: (:ok bool :code int :output string), or NIL on process failure."
  (unless *hngh-home*
    (return-from run-git nil))
  (handler-case
      (let* ((proc (sb-ext:run-program "git" args
                                       :directory *hngh-home*
                                       :output :stream
                                       :error :output
                                       :wait t
                                       :search t))
             (output (read-process-output (sb-ext:process-output proc)))
             (code (sb-ext:process-exit-code proc)))
        (list :ok (zerop code)
              :code code
              :output output))
    (error (c)
      (hngh.core:log-warn "Backup Manager git call failed (~{~A~^ ~}): ~A" args c)
      nil)))

(defun git-output-ok (result)
  "Return RESULT output when RESULT is successful, else NIL."
  (when (and result (getf result :ok))
    (trim-string (or (getf result :output) ""))))

(defun git-repo-initialized-p ()
  "Return T when *hngh-home* is already a git repository."
  (and *hngh-home* (probe-file (merge-pathnames ".git/" *hngh-home*))))

;;; --- Helpers: persistence + events -----------------------------------------

(defun safe-write-state (relative-path value)
  "Write VALUE to RELATIVE-PATH, returning T on success."
  (handler-case
      (progn
        (hngh.core.state-store:write-state relative-path value)
        t)
    (error (c)
      (hngh.core:log-warn "Backup Manager write failed (~A): ~A" relative-path c)
      nil)))

(defun safe-read-state (relative-path)
  "Read and return value at RELATIVE-PATH, or NIL on failure/miss."
  (handler-case
      (hngh.core.state-store:read-state relative-path)
    (error (c)
      (hngh.core:log-warn "Backup Manager read failed (~A): ~A" relative-path c)
      nil)))

(defun maybe-publish (topic payload)
  "Publish TOPIC/PAYLOAD if event bus is available."
  (when hngh.core.event-bus:*event-bus*
    (handler-case
        (hngh.core.event-bus:publish topic payload :source 'backup-manager)
      (error (c)
        (hngh.core:log-warn "Backup Manager publish failed (~A): ~A" topic c)
        nil))))

(defun ensure-owned-directories ()
  "Ensure config/state paths owned by Backup Manager exist."
  (when *hngh-home*
    (ensure-directories-exist (merge-pathnames *config-dir* *hngh-home*))
    (ensure-directories-exist (merge-pathnames *state-dir* *hngh-home*))
    t))

(defun managed-ignore-paths ()
  "Return merged ignore path list (defaults + user paths)."
  (remove-duplicates (append (copy-list *default-ignore-paths*)
                             (if (listp *user-ignore-paths*)
                                 (copy-list *user-ignore-paths*)
                                 '()))
                     :test #'string=))

(defun persist-state ()
  "Persist Backup Manager remotes/ignore/history to state-store."
  (safe-write-state *remotes-path* (if (listp *remotes*) *remotes* '()))
  (safe-write-state *ignore-path* (if (listp *user-ignore-paths*) *user-ignore-paths* '()))
  (safe-write-state *history-path* (if (listp *history*) *history* '()))
  t)

(defun load-state ()
  "Load remotes, user ignore paths, and history from state-store."
  (let ((loaded-remotes (safe-read-state *remotes-path*))
        (loaded-ignore (safe-read-state *ignore-path*))
        (loaded-history (safe-read-state *history-path*)))
    (setf *remotes* (if (listp loaded-remotes) loaded-remotes '())
          *user-ignore-paths* (if (listp loaded-ignore) loaded-ignore '())
          *history* (if (listp loaded-history) loaded-history '()))
    t))

(defun append-history (entry)
  "Append ENTRY to history and persist state."
  (setf *history* (append (if (listp *history*) *history* '()) (list entry)))
  (safe-write-state *history-path* *history*)
  entry)

;;; --- Helpers: git safety + setup -------------------------------------------

(defun write-gitignore ()
  "Write managed .gitignore in *hngh-home* with security defaults."
  (unless *hngh-home*
    (return-from write-gitignore nil))
  (let ((gitignore-path (merge-pathnames ".gitignore" *hngh-home*))
        (entries (managed-ignore-paths)))
    (handler-case
        (with-open-file (out gitignore-path
                             :direction :output
                             :if-exists :supersede
                             :if-does-not-exist :create
                             :element-type 'character)
          (write-line "# Managed by Hngh Backup Manager (B7)" out)
          (write-line "# SECURITY: secret and ephemeral paths must never be versioned." out)
          (dolist (entry entries)
            (write-line entry out))
          t)
      (error (c)
        (hngh.core:log-warn "Backup Manager could not write .gitignore: ~A" c)
        nil))))

(defun ensure-git-init ()
  "Initialize git repository in *hngh-home* when missing (idempotent)."
  (if (git-repo-initialized-p)
      t
      (let ((result (run-git '("init"))))
        (if (and result (getf result :ok))
            t
            (progn
              (hngh.core:log-warn "Backup Manager git init failed: ~A"
                                  (and result (getf result :output)))
              nil)))))

(defun ensure-git-identity ()
  "Set local git user.email/user.name if not configured."
  (let ((email-result (run-git '("config" "user.email")))
        (name-result (run-git '("config" "user.name"))))
    (when (or (null email-result)
              (not (getf email-result :ok))
              (zerop (length (trim-string (or (getf email-result :output) "")))))
      (run-git '("config" "user.email" "hngh@localhost")))
    (when (or (null name-result)
              (not (getf name-result :ok))
              (zerop (length (trim-string (or (getf name-result :output) "")))))
      (run-git '("config" "user.name" "Hngh Backup")))
    t))

(defun ensure-git-remotes ()
  "Ensure persisted remotes are configured in local git repo."
  (dolist (remote *remotes*)
    (let ((name (getf remote :name))
          (url (getf remote :url)))
      (when (and (safe-git-arg-p name)
                 (safe-git-arg-p url))
        (let ((get-url (run-git (list "remote" "get-url" "--" name))))
          (if (and get-url (getf get-url :ok))
              (run-git (list "remote" "set-url" "--" name url))
              (run-git (list "remote" "add" "--" name url))))))))

(defun staged-files ()
  "Return currently staged file paths as relative strings."
  (let ((result (run-git '("diff" "--cached" "--name-only"))))
    (if (and result (getf result :ok))
        (mapcar #'unquote-git-path
                (split-lines (or (getf result :output) "")))
        '())))

(defun forbidden-staged-path-p (path)
  "Return T when PATH violates secret safety rules."
  (or (some (lambda (prefix) (string-prefix-p prefix path)) *forbidden-prefixes*)
      (some (lambda (suffix) (string-suffix-p suffix path)) *forbidden-suffixes*)))

(defun enforce-staging-guard ()
  "Defense-in-depth staging guard. Returns T when staged files are safe.
On violation, logs an error, resets staged files, and returns NIL."
  (let* ((files (staged-files))
         (violations (remove-if-not #'forbidden-staged-path-p files)))
    (if (null violations)
        t
        (progn
          (hngh.core:log-error
           "Backup Manager blocked commit due to forbidden staged paths: ~{~A~^, ~}"
           violations)
          (ignore-errors (run-git (append (list "reset" "--") violations)))
          nil))))

(defun stage-paths (paths)
  "Stage PATHS (or all changes when PATHS is NIL)."
  (if (and (listp paths) paths)
      (let ((normalized (loop for path in paths
                              for normalized = (normalize-path-for-git path)
                              when (and (stringp normalized) (plusp (length normalized)))
                                collect normalized)))
        (if normalized
            (run-git (append (list "add" "--") normalized))
            (run-git '("add" "--all"))))
      (run-git '("add" "--all"))))

(defun git-head-hash ()
  "Return current HEAD commit hash string, or NIL when unavailable."
  (let ((result (run-git '("rev-parse" "HEAD"))))
    (when (and result (getf result :ok))
      (let ((value (trim-string (or (getf result :output) ""))))
        (unless (zerop (length value))
          value)))))

(defun register-schedule ()
  "Register periodic auto-commit schedule when scheduler is available."
  (setf *schedule-id* nil)
  (when (hngh.core.scheduler:running-p)
    (setf *schedule-id*
          (hngh.core.scheduler:schedule
           "backup-manager.periodic-commit"
           (list :interval *default-commit-interval-seconds*)
           (list :function
                 (lambda ()
                   (when *running*
                     (ignore-errors
                       (commit :message "backup-manager: auto-commit")))))
           :source 'backup-manager))))

(defun handle-config-changed (event)
  "Handle config.changed event by reloading persisted ignore/remotes and rewriting .gitignore."
  (declare (ignore event))
  (when *running*
    (load-state)
    (write-gitignore)
    (ensure-git-remotes)))

;;; --- Public API: lifecycle -------------------------------------------------

(defun init (&key (hngh-home hngh:*hngh-home*))
  "Initialize Backup Manager plugin.
Ensures owned dirs, git init, managed .gitignore, loaded state,
periodic scheduler registration, and config.changed subscription."
  (when *running*
    (shutdown))
  (setf *hngh-home* hngh-home
        *schedule-id* nil
        *event-subscriptions* '()
        *remotes* '()
        *user-ignore-paths* '()
        *history* '())
  (ensure-owned-directories)
  (load-state)
  (unless (ensure-git-init)
    (return-from init nil))
  (write-gitignore)
  (ensure-git-identity)
  (ensure-git-remotes)
  (register-schedule)
  (when hngh.core.event-bus:*event-bus*
    (push (hngh.core.event-bus:subscribe
           "config.changed"
           #'handle-config-changed
           :persistent nil)
          *event-subscriptions*))
  (setf *running* t)
  t)

(defun shutdown ()
  "Shut down Backup Manager plugin and persist state."
  (when *schedule-id*
    (ignore-errors
      (when (hngh.core.scheduler:running-p)
        (hngh.core.scheduler:cancel *schedule-id*)))
    (setf *schedule-id* nil))

  (dolist (sub-id *event-subscriptions*)
    (ignore-errors
      (when hngh.core.event-bus:*event-bus*
        (hngh.core.event-bus:unsubscribe sub-id))))
  (setf *event-subscriptions* '())

  (persist-state)

  (setf *running* nil
        *hngh-home* nil
        *remotes* '()
        *user-ignore-paths* '()
        *history* '())
  t)

(defun running-p ()
  "Return T when Backup Manager plugin is active."
  *running*)

(defun status ()
  "Return current Backup Manager status plist."
  (list :running *running*
        :git-initialized (not (null (git-repo-initialized-p)))
        :remotes-count (length (if (listp *remotes*) *remotes* '()))
        :ignore-count (length (managed-ignore-paths))
        :history-count (length (if (listp *history*) *history* '()))
        :last-commit (git-head-hash)))

;;; --- Public API: backup operations -----------------------------------------

(defun commit (&key message paths)
  "Create a git commit for staged state changes.
Returns commit plist on success, or NIL when not ready / no changes / blocked."
  (with-git-lock ()
    (unless (and *running* (git-repo-initialized-p))
      (return-from commit nil))
    (ensure-git-identity)
    (let ((stage-result (stage-paths paths)))
      (unless (and stage-result (getf stage-result :ok))
        (hngh.core:log-warn "Backup Manager stage failed: ~A"
                            (and stage-result (getf stage-result :output)))
        (return-from commit nil)))

    (unless (enforce-staging-guard)
      (return-from commit nil))

    (let ((files (staged-files)))
      (when (null files)
        (return-from commit nil))
      (let* ((commit-message (or message
                                 (format nil "backup-manager: checkpoint ~D"
                                         (get-universal-time))))
             (commit-result (run-git (list "commit" "-m" commit-message))))
        (if (and commit-result (getf commit-result :ok))
            (let ((entry (list :hash (git-head-hash)
                               :message commit-message
                               :paths files
                               :committed-at (get-universal-time))))
              (append-history entry)
              (maybe-publish "backup.committed" entry)
              entry)
            (progn
              (hngh.core:log-warn "Backup Manager commit failed: ~A"
                                  (and commit-result (getf commit-result :output)))
              nil))))))

(defun push-backup (&key remote)
  "Push backup commits to REMOTE (default first configured remote or origin)."
  (with-git-lock ()
    (unless (and *running* (git-repo-initialized-p))
      (return-from push-backup (list :remote (or remote "origin")
                                     :status :failed
                                     :reason :not-ready)))
    (let ((target-remote (or remote
                             (and (listp *remotes*) (getf (first *remotes*) :name))
                             "origin")))
      (unless (safe-git-arg-p target-remote)
        (return-from push-backup (list :remote target-remote
                                       :status :failed
                                       :reason :invalid-remote)))
      (let* ((result (run-git (list "push" "--" target-remote "HEAD")))
             (payload (if (and result (getf result :ok))
                          (list :remote target-remote
                                :status :ok
                                :output (trim-string (or (getf result :output) ""))
                                :pushed-at (get-universal-time))
                          (list :remote target-remote
                                :status :failed
                                :error (if result
                                           (trim-string (or (getf result :output) ""))
                                           "git push process failed")
                                :pushed-at (get-universal-time)))))
        (maybe-publish "backup.pushed" payload)
        payload))))

(defun restore (commit-ish &key paths (confirm nil))
  "Restore files from COMMIT-ISH.
When CONFIRM is NIL, returns :needs-confirmation and performs no tree modification."
  (unless confirm
    (return-from restore
      (list :status :needs-confirmation
            :commit-ish commit-ish
            :paths paths
            :message "Set :confirm t to perform restore.")))
  (with-git-lock ()
    (unless (and *running* (git-repo-initialized-p))
      (return-from restore (list :status :failed :reason :not-ready)))
    (unless (safe-git-arg-p commit-ish)
      (return-from restore (list :status :failed
                                 :reason :invalid-ref
                                 :commit-ish commit-ish)))

    (let* ((normalized-paths (if (and (listp paths) paths)
                                 (loop for path in paths
                                       for normalized = (normalize-path-for-git path)
                                       when (and (stringp normalized) (plusp (length normalized)))
                                         collect normalized)
                                 nil))
           (target-paths (or normalized-paths (list "."))))
      (when (some #'forbidden-staged-path-p target-paths)
        (return-from restore (list :status :failed
                                   :reason :forbidden-paths
                                   :message "Restore of secret paths is not permitted.")))
      (let* ((stash-result
               (run-git (list "stash" "push" "--include-untracked"
                              "-m" "backup-manager: pre-restore auto-stash")))
             (stash-output (trim-string (or (and stash-result (getf stash-result :output)) "")))
             (stashed (and stash-result
                           (getf stash-result :ok)
                           (not (search "No local changes" stash-output :test #'char-equal)))))
        (when (and stash-result
                   (not (getf stash-result :ok))
                   (not (search "No local changes" stash-output :test #'char-equal)))
          (hngh.core:log-warn "Backup Manager restore pre-stash failed: ~A" stash-output))
        (let* ((args (append (list "checkout" commit-ish "--") target-paths))
               (result (run-git args)))
          (if (and result (getf result :ok))
              (let ((payload (list :status :ok
                                   :commit-ish commit-ish
                                   :paths (or normalized-paths :all)
                                   :stashed (not (null stashed))
                                   :restored-at (get-universal-time))))
                (append-history (list :action :restore
                                      :commit-ish commit-ish
                                      :paths (or normalized-paths :all)
                                      :stashed (not (null stashed))
                                      :restored-at (get-universal-time)))
                (maybe-publish "backup.restored" payload)
                payload)
              (list :status :failed
                    :commit-ish commit-ish
                    :paths (or normalized-paths :all)
                    :stashed (not (null stashed))
                    :error (if result
                               (trim-string (or (getf result :output) ""))
                               "git checkout process failed"))))))))

(defun diff (&key path)
  "Return git diff output string (or empty string)."
  (unless (and *running* (git-repo-initialized-p))
    (return-from diff ""))
  (let* ((args (if path
                   (list "diff" "--" (normalize-path-for-git path))
                   (list "diff")))
         (result (run-git args)))
    (if (and result (getf result :ok))
        (or (getf result :output) "")
        "")))

(defun list-history ()
  "Return persisted history list (newest-last)."
  (copy-list (if (listp *history*) *history* '())))

(defun add-remote (name url &key (type :git))
  "Add/update backup remote and persist configuration."
  (unless (and (safe-git-arg-p name)
               (safe-git-arg-p url))
    (return-from add-remote nil))
  (when (and *running* (git-repo-initialized-p))
    (let ((existing (run-git (list "remote" "get-url" "--" name))))
      (if (and existing (getf existing :ok))
          (run-git (list "remote" "set-url" "--" name url))
          (run-git (list "remote" "add" "--" name url)))))
  (let ((entry (list :name name :url url :type type)))
    (setf *remotes*
          (append (remove-if (lambda (remote)
                               (string= (or (getf remote :name) "") name))
                             (if (listp *remotes*) *remotes* '()))
                  (list entry)))
    (safe-write-state *remotes-path* *remotes*)
    t))

(defun list-remotes ()
  "Return configured remote list."
  (copy-list (if (listp *remotes*) *remotes* '())))
