;;;; plugins/squad-dispatch.lisp — Squad Dispatch Tree (Wave 3)
;;;;
;;;; On-disk dispatch tree, dispatch.md root index, git-backed atomic
;;;; rollback via state.git/, and bean (message) planting/harvesting.
;;;; Every PM action is a git commit. No LLM is involved.
;;;;
;;;; SPDX-License-Identifier: AGPL-3.0-or-later
;;;; SPDX-FileCopyrightText: 2026 boundring <boundring@gmail.com>

(in-package :hngh.plugins.squad-dispatch)

;;; --- State -----------------------------------------------------------------

(defvar *running* nil
  "Whether the squad-dispatch plugin is active (no daemon in Wave 3).")

(defvar *locks* (make-hash-table :test 'equal)
  "Hash table of squad-root pathstring → bt:lock for dispatch.md access.")

(defvar *locks-table-lock* (bt:make-lock "squad-dispatch-locks")
  "Mutex protecting the *locks* hash table itself.")

;;; --- Helpers: git ----------------------------------------------------------

(defun %work-tree-pathspecs (squad-root)
  "Return top-level work-tree paths, excluding the embedded state repository."
  (append (list ".gitignore" "dispatch.md")
          (loop for path in (directory (merge-pathnames "*" squad-root))
                for relative = (enough-namestring path squad-root)
                unless (or (string= relative "state.git")
                           (and (>= (length relative) 10)
                                (string= (subseq relative 0 10) "state.git/")))
                collect relative)))

(defun %git (args squad-root)
  "Run git with --git-dir=<state.git> --work-tree=<squad-root>.
Returns plist: (:ok bool :code int :output string :error string)."
  (let* ((state-git (merge-pathnames "state.git/" squad-root))
         (safe-args (if (and (equal (first args) "add")
                             (member "-A" args :test #'string=))
                        (append (list "add" "-A" "--")
                                (%work-tree-pathspecs squad-root))
                        args))
         (full-args (append (list "--git-dir" (namestring state-git)
                                 "--work-tree" (namestring squad-root))
                            safe-args)))
    (handler-case
        (let* ((proc (sb-ext:run-program "git" full-args
                                        :search t :wait t
                                        :directory squad-root
                                        :output :stream :error :stream))
               (stdout (with-output-to-string (out)
                         (when (sb-ext:process-output proc)
                           (loop for line = (read-line (sb-ext:process-output proc) nil nil)
                                 while line
                                 do (progn (write-string line out)
                                          (write-char #\Newline out))))))
               (stderr (with-output-to-string (out)
                         (when (sb-ext:process-error proc)
                           (loop for line = (read-line (sb-ext:process-error proc) nil nil)
                                 while line
                                 do (progn (write-string line out)
                                          (write-char #\Newline out))))))
               (code (sb-ext:process-exit-code proc)))
          (list :ok (zerop code)
                :code code
                :output stdout
                :error stderr))
      (error (c)
        (list :ok nil :code -1 :output "" :error (princ-to-string c))))))

(defun %git-or-die (args squad-root action)
  "Run git and signal an error if it fails."
  (let ((result (%git args squad-root)))
    (unless (getf result :ok)
      (error "git ~{~A ~}failed (~A): ~A"
             args action
             (or (getf result :error) (getf result :output))))
    result))

(defun %git-commit-sha (squad-root)
  "Return current HEAD commit SHA."
  (let ((result (%git (list "rev-parse" "HEAD") squad-root)))
    (when (getf result :ok)
      (string-trim '(#\Space #\Tab #\Newline #\Return)
                    (or (getf result :output) "")))))

;;; --- Helpers: atomic write, timestamp, paths -------------------------------

(defun %atomic-write (path content)
  "Write CONTENT to PATH atomically (write-then-rename)."
  (let* ((tmp (merge-pathnames
               (make-pathname :name (format nil ".tmp-~D" (random 1000000)))
               path)))
    (with-open-file (out tmp :direction :output
                         :if-exists :supersede
                         :if-does-not-exist :create
                         :element-type 'character)
      (write-string content out))
    (rename-file tmp path)
    path))

(defun %format-timestamp (&optional (universal-time (get-universal-time)))
  "Return ISO-8601 string like 2026-08-03T12:30:00."
  (multiple-value-bind (s m h dd mm yyyy)
      (decode-universal-time universal-time)
    (format nil "~4,'0D-~2,'0D-~2,'0DT~2,'0D:~2,'0D:~2,'0D"
            yyyy mm dd h m s)))

(defun %format-hhmm (&optional (universal-time (get-universal-time)))
  "Return HH:MM string."
  (multiple-value-bind (s m h dd mm yyyy)
      (decode-universal-time universal-time)
    (declare (ignore s dd mm yyyy))
    (format nil "~2,'0D:~2,'0D" h m)))

(defun %squad-home (home)
  "Resolve the home directory for squads."
  (or home
      (if (and (find-package :hngh)
               (boundp 'hngh:*hngh-home*)
               hngh:*hngh-home*)
          hngh:*hngh-home*
          (merge-pathnames ".hngh/" (user-homedir-pathname)))))

(defun %role-dir (squad-root role)
  "Return pathname for role directory."
  (merge-pathnames (format nil "~A/" (string-downcase role)) squad-root))

(defun %inbox-path (squad-root role)
  (merge-pathnames (format nil "~A/inbox.md" (string-downcase role)) squad-root))

(defun %outbox-path (squad-root role)
  (merge-pathnames (format nil "~A/outbox.md" (string-downcase role)) squad-root))

(defun %tasks-dir (squad-root role)
  (merge-pathnames (format nil "~A/tasks/" (string-downcase role)) squad-root))

(defun %dispatch-path (squad-root)
  (merge-pathnames "dispatch.md" squad-root))

(defun %state-git-path (squad-root)
  (merge-pathnames "state.git/" squad-root))

;;; --- Helpers: locks --------------------------------------------------------

(defun %get-lock (squad-root)
  "Get or create a mutex for SQUAD-ROOT."
  (let ((key (namestring squad-root)))
    (bt:with-lock-held (*locks-table-lock*)
      (or (gethash key *locks*)
          (setf (gethash key *locks*)
                (bt:make-lock (format nil "squad-dispatch-~A" key)))))))

(defmacro with-squad-lock ((squad-root) &body body)
  "Execute BODY while holding the per-squad mutex."
  `(bt:with-lock-held ((%get-lock ,squad-root))
     ,@body))

;;; --- Helpers: dispatch.md parsing/rewriting --------------------------------

(defun %parse-table-rows (lines start-idx)
  "Parse markdown table rows from LINES (vector) starting at START-IDX.
Returns (values rows end-idx) where rows is a list of lists of trimmed cell strings.
Skips the header row and separator row(s)."
  (let ((rows '())
        (idx start-idx)
        (header-skipped nil))
    (loop
      (when (>= idx (length lines))
        (return))
      (let ((line (aref lines idx)))
        (cond
          ;; Not a table row (doesn't start with |) — stop
          ((or (<= (length line) 0)
               (not (char= (char line 0) #\|)))
           (return))
          ;; Separator row (|---|---|---|) — skip
          ((cl-ppcre:scan "^\\|[\\s\\-|]+\\|$" line)
           (incf idx))
          ;; Header row (first non-separator pipe-line) — skip
          ((not header-skipped)
           (setf header-skipped t)
           (incf idx))
          ;; Data row — parse cells
          (t
           (let* ((parts (cl-ppcre:split "\\|" line))
                  (cells-raw (if (and parts
                                      (string= (first parts) ""))
                                 (cdr parts)
                                 parts))
                  (cells (mapcar (lambda (c)
                                   (string-trim '(#\Space #\Tab) c))
                                 cells-raw))
                  (trimmed (if (and cells
                                    (string= (car (last cells)) ""))
                               (butlast cells)
                               cells)))
             (push trimmed rows))
           (incf idx)))))
    (values (nreverse rows) idx)))

(defun %parse-dispatch-md (squad-root)
  "Read and parse dispatch.md, returning a plist:
(:squad-root <path> :squad-name <string> :roles (list) :tasks (list) :communications (list))"
  (let* ((content (uiop:read-file-string (%dispatch-path squad-root)))
         (lines (coerce (cl-ppcre:split "\\r?\\n" content) 'vector))
         (squad-name nil)
         (roles '())
         (tasks '())
         (communications '()))
    ;; Parse header
    (loop for i from 0 below (length lines)
          for line = (aref lines i)
          do (multiple-value-bind (full groups)
                 (cl-ppcre:scan-to-strings "^# Squad: (.+)$" line)
               (when full
                 (setf squad-name (aref groups 0)))))
    ;; Parse sections
    (loop for i from 0 below (length lines)
          for line = (aref lines i)
          do
          (cond
            ((cl-ppcre:scan "^## Roles" line)
             (multiple-value-bind (rows next-idx)
                 (%parse-table-rows lines (1+ i))
               (declare (ignore next-idx))
               (setf roles
                     (loop for row in rows
                           collect (list :role (nth 0 row)
                                        :status (nth 1 row)
                                        :model (nth 2 row)
                                        :last-seen (nth 3 row))))))
            ((cl-ppcre:scan "^## Tasks" line)
             (multiple-value-bind (rows next-idx)
                 (%parse-table-rows lines (1+ i))
               (declare (ignore next-idx))
               (setf tasks
                     (loop for row in rows
                           collect (list :id (nth 0 row)
                                        :title (nth 1 row)
                                        :assigned (nth 2 row)
                                        :status (nth 3 row)
                                        :blocked-by (nth 4 row))))))
            ((cl-ppcre:scan "^## Communications" line)
             (multiple-value-bind (rows next-idx)
                 (%parse-table-rows lines (1+ i))
               (declare (ignore next-idx))
               (setf communications
                     (loop for row in rows
                           collect (list :from (nth 0 row)
                                        :to (nth 1 row)
                                        :bean (nth 2 row)
                                        :status (nth 3 row))))))))
    (list :squad-root squad-root
          :squad-name (or squad-name "")
          :roles roles
          :tasks tasks
          :communications communications)))

(defun %rewrite-dispatch-md (squad-root parsed)
  "Serialize PARSED plist back to dispatch.md format and write atomically."
  (let ((output (with-output-to-string (out)
                  (format out "# Squad: ~A~%~%" (getf parsed :squad-name))
                  ;; Roles table
                  (format out "## Roles~%")
                  (format out "| Role | Status | Model | Last seen |~%")
                  (format out "|---|---|---|---|~%")
                  (dolist (r (getf parsed :roles))
                    (format out "| ~A | ~A | ~A | ~A |~%"
                             (or (getf r :role) "")
                             (or (getf r :status) "")
                             (or (getf r :model) "")
                             (or (getf r :last-seen) "—")))
                  (format out "~%")
                  ;; Tasks table
                  (format out "## Tasks~%")
                  (format out "| ID | Title | Assigned | Status | Blocked by |~%")
                  (format out "|---|---|---|---|---|~%")
                  (dolist (t-row (getf parsed :tasks))
                    (format out "| ~A | ~A | ~A | ~A | ~A |~%"
                             (or (getf t-row :id) "")
                             (or (getf t-row :title) "")
                             (or (getf t-row :assigned) "")
                             (or (getf t-row :status) "")
                             (or (getf t-row :blocked-by) "—")))
                  (format out "~%")
                  ;; Communications table
                  (format out "## Communications~%")
                  (format out "| From | To | Bean | Status |~%")
                  (format out "|---|---|---|---|~%")
                  (dolist (c (getf parsed :communications))
                    (format out "| ~A | ~A | ~A | ~A |~%"
                             (or (getf c :from) "")
                             (or (getf c :to) "")
                             (or (getf c :bean) "")
                             (or (getf c :status) ""))))))
    (%atomic-write (%dispatch-path squad-root) output)))

;;; --- Helpers: bean parsing -------------------------------------------------

(defun %parse-bean-section (section-text)
  "Parse a bean section (text between --- delimiters) into a plist."
  (let* ((lines (cl-ppcre:split "\\r?\\n" section-text))
         (husk-lines '())
         (body-lines '())
         (in-husk t))
    (loop for line in lines
          do
          (if in-husk
              (if (string= line "")
                  (progn
                    (setf in-husk nil)
                    (push line body-lines))
                  (push line husk-lines))
              (push line body-lines)))
    (setf husk-lines (nreverse husk-lines)
          body-lines (nreverse body-lines))
    ;; Parse husk key: value pairs
    (let ((bean nil)
          (from nil)
          (to nil)
          (planted nil)
          (type nil)
          (status nil)
          (expires nil))
      (dolist (hl husk-lines)
        (let ((colon-pos (position #\: hl)))
          (when (and colon-pos (> (length hl) colon-pos))
            (let ((key (string-trim '(#\Space #\Tab) (subseq hl 0 colon-pos)))
                  (val (string-trim '(#\Space #\Tab) (subseq hl (1+ colon-pos)))))
              (cond
                ((string= key "bean") (setf bean val))
                ((string= key "from") (setf from val))
                ((string= key "to") (setf to val))
                ((string= key "planted") (setf planted val))
                ((string= key "type") (setf type val))
                ((string= key "status") (setf status val))
                ((string= key "expires")
                 (setf expires (unless (string= val "") val))))))))
      ;; Body content: skip leading empty lines
      (let ((body-start 0))
        (loop for line in body-lines
              while (string= line "")
              do (incf body-start))
        (let ((content
               (with-output-to-string (out)
                 (loop for line in (nthcdr body-start body-lines)
                       for first = t then nil
                       do (if first
                              (write-string line out)
                              (progn (write-char #\Newline out)
                                    (write-string line out)))))))
          (list :bean bean
                :from from
                :to to
                :planted planted
                :type type
                :status status
                :expires expires
                :content content))))))

(defun %parse-inbox (content)
  "Parse inbox.md content into a list of bean plists."
  (let* ((sections (cl-ppcre:split "\\n---\\n" content))
         (beans '()))
    (let ((start-idx (if (and sections (string= (first sections) ""))
                         1 0)))
      (loop for i from start-idx below (length sections) by 2
            for husk = (nth i sections)
            for body = (nth (1+ i) sections)
            when husk
              do
              (let ((bean-plist (%parse-bean-section
                                 (if body
                                     (format nil "~A~%~A" husk body)
                                     husk))))
                (push bean-plist beans))))
    (nreverse beans)))

;;; --- Public API: squad lifecycle -------------------------------------------

(defun create-squad (squad-name &key
                                   (roles '(:pm :designer :coder :worker
                                            :accountant :artist))
                                   (home nil)
                                   (model-config nil))
  "Create a squad dispatch tree with git-backed state.
Returns plist: (:squad-name :squad-root :state-git :roles :commit-sha)."
  (let* ((squad-home (%squad-home home))
         (squad-root (merge-pathnames
                      (format nil "squad/~A/" squad-name)
                      squad-home)))
    (when (probe-file squad-root)
      (error "Squad ~A already exists" squad-name))
    (ensure-directories-exist squad-root)
    ;; Initialize bare git repo
    (let ((init-result
           (handler-case
               (sb-ext:run-program
                "git" (list "init" "--bare"
                           (namestring (merge-pathnames "state.git/" squad-root)))
                :search t :wait t :output :stream :error :stream)
             (error (c)
               (error "git init --bare failed: ~A" c)))))
      (unless (zerop (sb-ext:process-exit-code init-result))
        (error "git init --bare failed: ~A"
               (format nil "exit code ~D"
                       (sb-ext:process-exit-code init-result)))))
    ;; Create role directories and files
    (dolist (role roles)
      (let ((rdir (%role-dir squad-root role)))
        (ensure-directories-exist rdir)
        (ensure-directories-exist (merge-pathnames "tasks/" rdir))
        (%atomic-write (merge-pathnames "inbox.md" rdir) "")
        (%atomic-write (merge-pathnames "outbox.md" rdir) "")))
    ;; Create journal directory
    (let ((journal-dir (merge-pathnames "journal/" squad-root)))
      (ensure-directories-exist journal-dir)
      (%atomic-write (merge-pathnames "projected.md" journal-dir)
                    (format nil "# Projected: ~A~%~%Created: ~A~%~%Roles: ~{~A~^, ~}~%"
                            squad-name
                            (%format-timestamp)
                            (mapcar #'string-downcase roles)))
      (%atomic-write (merge-pathnames "actual.md" journal-dir) "")
      (%atomic-write (merge-pathnames "fragment.md" journal-dir) ""))
    ;; Write dispatch.md
    (let ((roles-plist
           (loop for role in roles
                 for model = (or (and model-config
                                      (getf model-config role))
                                 "free")
                 for status = (if (eq role :pm) "active" "idle")
                 for last-seen = (if (eq role :pm) (%format-hhmm) "—")
                 collect (list :role (string-downcase role)
                              :status status
                              :model model
                              :last-seen last-seen))))
      (%rewrite-dispatch-md squad-root
                           (list :squad-name squad-name
                                 :roles roles-plist
                                 :tasks '()
                                 :communications '())))
    ;; Write .gitignore to ignore the embedded state repository
    (%atomic-write (merge-pathnames ".gitignore" squad-root)
                  (format nil "state.git~%state.git/~%**/state.git~%**/state.git/**~%"))
    ;; Set git identity for the repo
    (%git (list "config" "user.email" "hngh-squad@localhost") squad-root)
    (%git (list "config" "user.name" "Hngh Squad") squad-root)
    ;; Stage and commit
    (%git-or-die (list "add" "-A") squad-root "stage")
    (%git-or-die (list "commit" "-m"
                       (format nil "[dispatch] create-squad: ~A" squad-name))
                squad-root "commit")
    (let ((sha (%git-commit-sha squad-root)))
      (list :squad-name squad-name
            :squad-root squad-root
            :state-git (merge-pathnames "state.git/" squad-root)
            :roles roles
            :commit-sha sha))))

(defun rollback-squad (squad-root sha &key (dry-run nil))
  "Rollback squad state to a given commit SHA.
Returns plist: (:squad-root :restored-sha :commit-sha :success)."
  (unless (probe-file squad-root)
    (error "Squad root does not exist: ~A" squad-root))
  (unless (probe-file (%state-git-path squad-root))
    (error "state.git not found in ~A" squad-root))
  ;; Validate SHA
  (let ((validate-result
         (%git (list "rev-parse" "--verify" sha) squad-root)))
    (unless (getf validate-result :ok)
      (error "Invalid SHA: ~A" sha)))
  (when dry-run
    (return-from rollback-squad
      (list :squad-root squad-root
            :restored-sha sha
            :commit-sha nil
            :success t)))
  (with-squad-lock (squad-root)
    ;; Checkout files to the SHA state
    (%git-or-die (list "checkout" sha "--" ".") squad-root "checkout")
    ;; Stage and commit the rollback
    (%git (list "add" "-A") squad-root)
    (let ((commit-result
           (%git (list "commit" "-m"
                       (format nil "[rollback] checkout ~A" sha))
                squad-root)))
      (if (getf commit-result :ok)
          (list :squad-root squad-root
                :restored-sha sha
                :commit-sha (%git-commit-sha squad-root)
                :success t)
          (list :squad-root squad-root
                :restored-sha sha
                :commit-sha nil
                :success nil
                :reason "already-at-sha")))))

(defun get-squad-status (squad-root)
  "Parse dispatch.md and return a status plist."
  (unless (probe-file squad-root)
    (error "Squad root does not exist: ~A" squad-root))
  (unless (probe-file (%dispatch-path squad-root))
    (error "Cannot read dispatch.md"))
  (with-squad-lock (squad-root)
    (%parse-dispatch-md squad-root)))

(defun squad-log (squad-root &key (limit nil) (oneline t))
  "Return git log output as a string."
  (let ((args (append (list "log")
                      (when oneline (list "--oneline"))
                      (when limit (list (format nil "-~D" limit))))))
    (let ((result (%git args squad-root)))
      (when (getf result :ok)
        (or (getf result :output) "")))))

;;; --- Public API: bean operations ------------------------------------------

(defun plant-bean (squad-root from to bean-name &key
                                            (type :message)
                                            (content "")
                                            (model-config nil))
  "Plant a bean in the recipient's inbox and commit.
Returns plist: (:squad-root :bean :from :to :commit-sha)."
  (declare (ignore model-config))
  (unless (probe-file squad-root)
    (error "Squad root does not exist: ~A" squad-root))
  (let ((recipient-dir (%role-dir squad-root to)))
    (unless (probe-file recipient-dir)
      (error "Unknown role: ~A" to)))
  (let* ((inbox-path (%inbox-path squad-root to))
         (timestamp (%format-timestamp))
         (bean-section
          (format nil "---~%bean: ~A~%from: ~A~%to: ~A~%planted: ~A~%type: ~A~%status: planted~%---~%~%~A~%"
                  bean-name
                  (string-downcase from)
                  (string-downcase to)
                  timestamp
                  (string-downcase type)
                  content)))
    (with-squad-lock (squad-root)
      ;; Append bean to inbox
      (let ((existing-content
             (handler-case
                 (uiop:read-file-string inbox-path)
               (error () ""))))
        (%atomic-write inbox-path
                      (if (string= existing-content "")
                          bean-section
                          (concatenate 'string existing-content bean-section))))
      ;; Update dispatch.md Communications table
      (let ((parsed (%parse-dispatch-md squad-root)))
        (setf (getf parsed :communications)
              (append (getf parsed :communications)
                      (list (list :from (string-downcase from)
                                 :to (string-downcase to)
                                 :bean bean-name
                                 :status "planted"))))
        (%rewrite-dispatch-md squad-root parsed))
      ;; Stage and commit
      (%git-or-die (list "add" "-A") squad-root "stage")
      (%git-or-die (list "commit" "-m"
                        (format nil "[bean] ~A -> ~A: ~A"
                                (string-downcase from)
                                (string-downcase to)
                                bean-name))
                  squad-root "commit"))
    (list :squad-root squad-root
          :bean bean-name
          :from from
          :to to
          :commit-sha (%git-commit-sha squad-root))))

(defun %format-bean-section (bean-plist)
  "Format a bean plist as a markdown section for inbox.md."
  (format nil "---~%bean: ~A~%from: ~A~%to: ~A~%planted: ~A~%type: ~A~%status: ~A~%---~%~%~A~%"
          (getf bean-plist :bean)
          (getf bean-plist :from)
          (getf bean-plist :to)
          (getf bean-plist :planted)
          (getf bean-plist :type)
          (getf bean-plist :status)
          (getf bean-plist :content)))

(defun harvest-bean (squad-root role bean-name)
  "Harvest a bean from the role's inbox, marking it harvested.
Returns plist: (:squad-root :bean :role :content :commit-sha)."
  (unless (probe-file squad-root)
    (error "Squad root does not exist: ~A" squad-root))
  (let ((role-dir (%role-dir squad-root role)))
    (unless (probe-file role-dir)
      (error "Unknown role: ~A" role)))
  (let ((inbox-path (%inbox-path squad-root role)))
    (with-squad-lock (squad-root)
      (let* ((content (handler-case
                          (uiop:read-file-string inbox-path)
                        (error () "")))
             (beans (%parse-inbox content))
             (target-bean
              (find bean-name beans
                   :key (lambda (b) (getf b :bean))
                   :test #'string=)))
        (unless target-bean
          (error "Bean ~A not found in ~A inbox" bean-name role))
        (when (string= (getf target-bean :status) "harvested")
          (error "Bean ~A already harvested" bean-name))
        (unless (string= (getf target-bean :to)
                        (string-downcase role))
          (error "Bean ~A is not addressed to ~A" bean-name role))
        ;; Mark the bean as harvested in the parsed list
        (setf (getf target-bean :status) "harvested")
        ;; Rebuild inbox content from all beans
        (let ((new-content
               (with-output-to-string (out)
                 (dolist (bean beans)
                   (write-string (%format-bean-section bean) out)))))
          (%atomic-write inbox-path new-content))
        ;; Update dispatch.md Communications table
        (let ((parsed (%parse-dispatch-md squad-root)))
          (setf (getf parsed :communications)
                (loop for c in (getf parsed :communications)
                      collect (if (and (string= (getf c :bean) bean-name)
                                      (string= (getf c :to)
                                             (string-downcase role)))
                                  (progn
                                    (setf (getf c :status) "harvested")
                                    c)
                                  c)))
          (%rewrite-dispatch-md squad-root parsed))
        ;; Stage and commit
        (%git-or-die (list "add" "-A") squad-root "stage")
        (%git-or-die (list "commit" "-m"
                          (format nil "[bean] ~A harvested: ~A"
                                  (string-downcase role)
                                  bean-name))
                    squad-root "commit")
        (list :squad-root squad-root
              :bean bean-name
              :role role
              :content (getf target-bean :content)
              :commit-sha (%git-commit-sha squad-root))))))

;;; --- Public API: task operations ------------------------------------------

(defun assign-task (squad-root task-id title assigned-role &key (blocked-by nil))
  "Assign a task to a role. Creates task file and updates dispatch.md.
Returns plist: (:squad-root :task-id :title :assigned :blocked-by :commit-sha)."
  (unless (probe-file squad-root)
    (error "Squad root does not exist: ~A" squad-root))
  (let ((role-dir (%role-dir squad-root assigned-role)))
    (unless (probe-file role-dir)
      (error "Unknown role: ~A" assigned-role)))
  (with-squad-lock (squad-root)
    ;; Update dispatch.md Tasks table
    (let ((parsed (%parse-dispatch-md squad-root)))
      (setf (getf parsed :tasks)
            (append (getf parsed :tasks)
                    (list (list :id task-id
                               :title title
                               :assigned (string-downcase assigned-role)
                               :status "pending"
                               :blocked-by (or blocked-by "—")))))
      (%rewrite-dispatch-md squad-root parsed))
    ;; Create task file
    (let ((tasks-dir (%tasks-dir squad-root assigned-role)))
      (ensure-directories-exist tasks-dir)
      (%atomic-write (merge-pathnames
                    (format nil "~A.md" task-id) tasks-dir)
                   (format nil "# Task: ~A~%~%Assigned: ~A~%Status: pending~%Blocked by: ~A~%~%## Acceptance Criteria~%~%[placeholder]~%"
                           title
                           (string-downcase assigned-role)
                           (or blocked-by "—"))))
    ;; Stage and commit
    (%git-or-die (list "add" "-A") squad-root "stage")
    (%git-or-die (list "commit" "-m"
                      (format nil "[assign] pm -> ~A: ~A~@[ (blocked by: ~A)~]"
                              (string-downcase assigned-role)
                              task-id
                              blocked-by))
                squad-root "commit"))
  (list :squad-root squad-root
        :task-id task-id
        :title title
        :assigned assigned-role
        :blocked-by blocked-by
        :commit-sha (%git-commit-sha squad-root)))

(defun update-task-status (squad-root task-id status &key (blocked-by nil))
  "Update a task's status in dispatch.md.
Returns plist: (:squad-root :task-id :status :commit-sha)."
  (unless (probe-file squad-root)
    (error "Squad root does not exist: ~A" squad-root))
  (with-squad-lock (squad-root)
    (let ((parsed (%parse-dispatch-md squad-root)))
      (setf (getf parsed :tasks)
            (loop for task in (getf parsed :tasks)
                  collect (if (string= (getf task :id) task-id)
                              (progn
                                (setf (getf task :status) status)
                                (when blocked-by
                                  (setf (getf task :blocked-by) blocked-by))
                                task)
                              task)))
      (%rewrite-dispatch-md squad-root parsed))
    ;; Stage and commit
    (%git-or-die (list "add" "-A") squad-root "stage")
    ;; Get the assigned role for the commit message
    (let* ((parsed2 (%parse-dispatch-md squad-root))
           (task (find task-id (getf parsed2 :tasks)
                       :key (lambda (task) (getf task :id)) :test #'string=))
           (assigned (or (and task (getf task :assigned)) "unknown")))
      (%git-or-die (list "commit" "-m"
                        (format nil "[status] ~A: ~A ~A"
                                assigned task-id status))
                  squad-root "commit")))
  (list :squad-root squad-root
        :task-id task-id
        :status status
        :commit-sha (%git-commit-sha squad-root)))

(defun update-role-status (squad-root role status &key (model nil) (last-seen nil))
  "Update a role's status in dispatch.md.
Returns plist: (:squad-root :role :status :commit-sha)."
  (unless (probe-file squad-root)
    (error "Squad root does not exist: ~A" squad-root))
  (with-squad-lock (squad-root)
    (let ((parsed (%parse-dispatch-md squad-root)))
      (setf (getf parsed :roles)
            (loop for r in (getf parsed :roles)
                  collect (if (string= (getf r :role)
                                       (string-downcase role))
                              (progn
                                (setf (getf r :status) status)
                                (when model
                                  (setf (getf r :model) model))
                                (when last-seen
                                  (setf (getf r :last-seen) last-seen))
                                r)
                              r)))
      (%rewrite-dispatch-md squad-root parsed))
    ;; Stage and commit
    (%git-or-die (list "add" "-A") squad-root "stage")
    (%git-or-die (list "commit" "-m"
                      (format nil "[status] ~A: ~A"
                              (string-downcase role) status))
                squad-root "commit"))
  (list :squad-root squad-root
        :role role
        :status status
        :commit-sha (%git-commit-sha squad-root)))

;;; --- Public API: precondition gates ----------------------------------------

(defun check-preconditions (spec &key (cwd nil))
  "Evaluate preconditions from SPEC (plist with :preconditions key).
Returns plist: (:all-passed :results)."
  (let* ((cwd (or cwd (uiop:getcwd)))
         (preconditions (getf spec :preconditions))
         (results '())
         (all-passed t))
    (dolist (precond preconditions)
      (let* ((check-type (first precond))
             (result
              (case check-type
                (:file-exists
                 (let* ((rel-path (second precond))
                        (full-path (merge-pathnames rel-path cwd))
                        (exists (probe-file full-path)))
                   (list :check :file-exists
                        :path rel-path
                        :passed (not (null exists)))))
                (:function-exists
                 (let* ((pkg-kw (second precond))
                        (sym-kw (third precond))
                        (pkg (find-package pkg-kw)))
                   (if pkg
                       (let ((sym (find-symbol (string sym-kw) pkg)))
                         (list :check :function-exists
                              :package pkg-kw
                              :symbol sym-kw
                              :passed (and sym (fboundp sym))))
                       (list :check :function-exists
                            :package pkg-kw
                            :symbol sym-kw
                            :passed nil
                            :reason "package not found"))))
                (:package-exports
                 (let* ((pkg-kw (second precond))
                        (symbols (cddr precond))
                        (pkg (find-package pkg-kw)))
                   (if pkg
                       (let ((missing '()))
                         (dolist (sym-kw symbols)
                           (multiple-value-bind (sym status)
                               (find-symbol (string sym-kw) pkg)
                             (declare (ignore sym))
                             (unless (eq status :external)
                               (push sym-kw missing))))
                         (list :check :package-exports
                              :package pkg-kw
                              :symbols symbols
                              :passed (null missing)
                              :missing (nreverse missing)))
                       (list :check :package-exports
                            :package pkg-kw
                            :symbols symbols
                            :passed nil
                            :reason "package not found"))))
                (:callable-p
                 (let* ((pkg-kw (second precond))
                        (sym-kw (third precond))
                        (pkg (find-package pkg-kw)))
                   (if pkg
                       (multiple-value-bind (sym status)
                           (find-symbol (string sym-kw) pkg)
                         (list :check :callable-p
                              :package pkg-kw
                              :symbol sym-kw
                              :passed (and sym
                                          (eq status :external)
                                          (fboundp sym))))
                       (list :check :callable-p
                            :package pkg-kw
                            :symbol sym-kw
                            :passed nil
                            :reason "package not found"))))
                (:file-contains
                 (let* ((rel-path (second precond))
                        (substring (third precond))
                        (full-path (merge-pathnames rel-path cwd)))
                   (handler-case
                       (let ((content (uiop:read-file-string full-path)))
                         (list :check :file-contains
                              :path rel-path
                              :substring substring
                              :passed (search substring content)))
                     (error ()
                       (list :check :file-contains
                            :path rel-path
                            :substring substring
                            :passed nil
                            :reason "file not readable")))))
                (:custom
                 (let ((fn (second precond)))
                   (handler-case
                       (list :check :custom
                            :passed (not (null (funcall fn cwd))))
                     (error (c)
                       (list :check :custom
                            :passed nil
                            :reason (princ-to-string c))))))
                (t
                 (error "Unknown precondition check: ~A" check-type)))))
        (push result results)
        (unless (getf result :passed)
          (setf all-passed nil))))
    (list :all-passed all-passed
          :results (nreverse results))))

;;; --- Plugin lifecycle ------------------------------------------------------

(defun init ()
  "Initialize the squad-dispatch plugin. Stateless in Wave 3."
  (setf *running* t)
  (hngh.core:log-info "Squad-dispatch plugin initialized")
  t)

(defun shutdown ()
  "Shut down the squad-dispatch plugin."
  (setf *running* nil)
  (hngh.core:log-info "Squad-dispatch plugin shut down")
  t)

(defun running-p ()
  "Return T when the squad-dispatch plugin is active."
  *running*)

(defun status ()
  "Return a plist describing the plugin status."
  (list :running *running*
        :locks (hash-table-count *locks*)))
