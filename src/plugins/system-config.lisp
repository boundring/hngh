;;;; plugins/system-config.lisp — Hngh System Config (B2)
;;;;
;;;; Manages system config files, btrfs snapshots, and theming.
;;;; User-owned configs (~/.config/) are written directly.
;;;; System-owned configs (/etc/, /usr/lib/systemd/) go through
;;;; the Hngh system daemon via gdbus.
;;;;
;;;; SPDX-License-Identifier: AGPL-3.0-or-later
;;;; SPDX-FileCopyrightText: 2026 boundring <boundring@gmail.com>

(in-package :hngh.plugins.system-config)

;;; --- State ---------------------------------------------------------------

(defvar *running* nil
  "Whether the system-config plugin is active.")

(defvar *hngh-home* nil
  "Hngh home directory (set during init).")

(defvar *managed-paths* '()
  "List of paths under Hngh's configuration management.")

(defvar *paths-lock* (bt:make-lock "hngh-sysconfig-paths")
  "Mutex protecting *managed-paths*.")

(defvar *snapshots* '()
  "Internally tracked snapshot records. Each is a plist:
  (:id N :description STR :timestamp UT).")

(defvar *snapshots-lock* (bt:make-lock "hngh-sysconfig-snapshots")
  "Mutex protecting *snapshots*.")

(defvar *snapshot-next-id* 0
  "Counter for snapshot IDs (used when tracking our own snapshots).")

(defvar *event-subscriptions* '()
  "List of event subscription IDs for cleanup on shutdown.")

;;; --- Default managed paths -----------------------------------------------

(defparameter *default-managed-paths*
  '("/etc/pacman.conf" "/etc/makepkg.conf" "~/.config/hngh/")
  "Default list of config paths under Hngh management.")

;;; --- Helpers: path resolution ---------------------------------------------

(defun homedir ()
  "Return the user's home directory as a pathname."
  (user-homedir-pathname))

(defun starts-with-p (prefix string)
  "Return T if STRING starts with PREFIX (case-sensitive)."
  (let ((plen (length prefix)))
    (and (>= (length string) plen)
         (string= (subseq string 0 plen) prefix))))

(defun expand-tilde (path)
  "If PATH starts with ~/, replace ~ with the user's home directory.
Returns the expanded path as a string."
  (if (and (>= (length path) 2)
           (char= (char path 0) #\~)
           (char= (char path 1) #\/))
      (namestring (merge-pathnames (subseq path 2) (homedir)))
      path))

(defun resolve-config-path (path)
  "Resolve PATH to an absolute filesystem path.
- /etc/ or /usr/ paths: return as-is (system paths).
- ~/.config/ paths: expand ~ to user home.
- Relative paths: resolve against user home.
Returns the resolved path as a namestring, or nil if invalid."
  (cond
    ;; System paths — keep as-is
    ((or (starts-with-p "/etc/" path)
         (starts-with-p "/usr/" path))
     path)
    ;; Tilde expansion
    ((and (>= (length path) 2)
          (char= (char path 0) #\~)
          (char= (char path 1) #\/))
     (namestring (merge-pathnames (subseq path 2) (homedir))))
    ;; Relative paths — resolve against home
    ((not (char= (char path 0) #\/))
     (namestring (merge-pathnames path (homedir))))
    ;; Other absolute paths — keep as-is
    (t path)))

(defun is-system-path-p (path)
  "Return T if PATH is a system-owned path requiring daemon for writes."
  (or (starts-with-p "/etc/" path)
      (starts-with-p "/usr/lib/systemd/system/" path)))

;;; --- Helper: string-to-gdbus-byte-array -----------------------------------

(defun string-to-gdbus-byte-array (str)
  "Convert a Lisp string to a gdbus byte-array GVariant format:
  '[byte 0x48, byte 0x65, ...]'."
  (with-output-to-string (s)
    (write-char #\[ s)
    (loop for char across str
          for i from 0
          do (if (zerop i)
                 (format s "byte 0x~2,'0X" (char-code char))
                 (format s ", byte 0x~2,'0X" (char-code char))))
    (write-char #\] s)))

(defun gdbus-string (str)
  "Wrap STR in single-quotes for gdbus GVariant string type."
  (format nil "'~A'" (remove #\' (substitute #\Space #\Newline str))))

;;; --- Helper: call-system-daemon -------------------------------------------

(defun call-system-daemon (interface method &rest args)
  "Call a method on the Hngh system daemon via gdbus.
INTERFACE: string like \"org.hngh.System.Files\"
METHOD: string like \"WriteFile\"
ARGS: additional arguments passed to gdbus call.
Returns the gdbus output string on success, NIL on failure.
Checks the process exit code — only returns output if exit code is 0."
  (let ((gdbus-args (append (list "call" "--system"
                                  "--dest" "org.hngh.System"
                                  "--object-path" "/org/hngh/System"
                                  "--method" (format nil "~A.~A" interface method))
                            args)))
    (handler-case
        (let ((proc (sb-ext:run-program "gdbus" gdbus-args
                                         :output :stream
                                         :search t
                                         :wait t)))
          (when proc
            (if (zerop (sb-ext:process-exit-code proc))
                (let ((output (read-line (sb-ext:process-output proc) nil nil)))
                  (sb-ext:process-close proc)
                  output)
                (progn
                  (sb-ext:process-close proc)
                  nil))))
      (error (c)
        (hngh.core:log-warn "System daemon call failed: ~A" c)
        nil))))

;;; --- Helper: event emission -----------------------------------------------

(defun emit-event (topic payload)
  "Emit an event on the event bus if available."
  (when hngh.core.event-bus:*event-bus*
    (hngh.core.event-bus:publish topic payload :source 'system-config)))

;;; --- Helper: file utilities -----------------------------------------------

(defun file-readable-p (path)
  "Return T if PATH exists and is readable."
  (handler-case
      (probe-file (pathname path))
    (error () nil)))

(defun read-file-string (path)
  "Read the entire contents of PATH as a string.
Returns NIL if the file does not exist or cannot be read."
  (handler-case
      (with-open-file (stream path :direction :input :element-type 'character)
        (let* ((len (file-length stream))
               (buf (make-string len)))
          (read-sequence buf stream)
          buf))
    (file-error (c)
      (hngh.core:log-warn "Cannot read config ~A: ~A" path c)
      nil)
    (error (c)
      (hngh.core:log-warn "Error reading config ~A: ~A" path c)
      nil)))

(defun ensure-parent-directories (path)
  "Ensure that the parent directory of PATH exists, creating it if needed."
  (let ((dir (make-pathname :name nil :type nil
                             :defaults (pathname path))))
    (ensure-directories-exist dir)))

;;; --- Managed paths persistence --------------------------------------------

(defun managed-paths-state-path ()
  "Return the state-store relative path for managed-paths."
  "config/plugins/system-config/managed-paths.lisp")

(defun state-store-active-p ()
  "Return T if the state store is available and initialized."
  (and (find-package :hngh.core.state-store)
       (fboundp (find-symbol "RUNNING-P" :hngh.core.state-store))
       (funcall (find-symbol "RUNNING-P" :hngh.core.state-store))))

(defun load-managed-paths ()
  "Load managed paths from the state store.
Returns the list of paths or the default list if no persisted state."
  (if (state-store-active-p)
      (handler-case
          (let ((loaded (hngh.core.state-store:read-state
                         (managed-paths-state-path))))
            (if loaded
                loaded
                (copy-list *default-managed-paths*)))
        (error (c)
          (hngh.core:log-warn "Cannot load managed paths: ~A" c)
          (copy-list *default-managed-paths*)))
      (copy-list *default-managed-paths*)))

(defun persist-managed-paths ()
  "Persist *managed-paths* to the state store."
  (when (state-store-active-p)
    (bt:with-lock-held (*paths-lock*)
      (handler-case
          (hngh.core.state-store:write-state
           (managed-paths-state-path)
           *managed-paths*)
        (error (c)
          (hngh.core:log-warn "Cannot persist managed paths: ~A" c))))))

;;; --- Snapshots persistence ------------------------------------------------

(defun snapshots-state-path ()
  "Return the state-store relative path for snapshots."
  "state/plugins/system-config/snapshots.lisp")

(defun load-snapshots ()
  "Load snapshot records from the state store."
  (when (state-store-active-p)
    (handler-case
        (let ((loaded (hngh.core.state-store:read-state
                       (snapshots-state-path))))
          (when loaded
            (bt:with-lock-held (*snapshots-lock*)
              (setf *snapshots* loaded)
              (setf *snapshot-next-id*
                    (1+ (reduce #'max loaded
                                :key (lambda (s) (getf s :id))
                                :initial-value 0))))))
      (error (c)
        (hngh.core:log-warn "Cannot load snapshots: ~A" c)))))

(defun persist-snapshots ()
  "Persist *snapshots* to the state store."
  (when (state-store-active-p)
    (bt:with-lock-held (*snapshots-lock*)
      (handler-case
          (hngh.core.state-store:write-state
           (snapshots-state-path)
           *snapshots*)
        (error (c)
          (hngh.core:log-warn "Cannot persist snapshots: ~A" c))))))

;;; --- Public API: read-config ----------------------------------------------

(defun read-config (path)
  "Read a config file at PATH.
- System paths (/etc/, /usr/): read directly (may fail on permissions).
- User paths (~/.config/) or relative: resolve against user home.
Returns file contents as a string, or NIL if the file doesn't exist
or cannot be read."
  (let ((resolved (resolve-config-path path)))
    (read-file-string resolved)))

;;; --- Public API: write-config ---------------------------------------------

(defun write-config (path content &key (mode 420))
  "Write CONTENT to a config file at PATH.
- System paths (/etc/, /usr/lib/systemd/system/): call system daemon via gdbus.
- User paths (~/.config/): write directly (create parent dirs if needed).
Emits a config.changed event with :path, :before, :after, and :reason.
MODE is the desired file permissions (integer, e.g. 420 = 0644 octal).
Returns T on success, NIL on failure."
  (let ((before (read-config path)))
    (labels ((on-success ()
               (emit-event "config.changed"
                           (list :path path
                                 :before before
                                 :after content
                                 :reason :user-edit))
               t)
             (on-failure ()
               nil))
      (cond
        ;; System paths — go through daemon
        ((is-system-path-p path)
         (let ((result (call-system-daemon
                        "org.hngh.System.Files" "WriteFile"
                        (gdbus-string path)
                        (string-to-gdbus-byte-array content)
                        (format nil "~D" mode))))
           (if result
               (on-success)
               (progn
                 (hngh.core:log-warn "System daemon write failed for ~A" path)
                 (on-failure)))))
        ;; User paths — write directly
        (t
         (let ((resolved (resolve-config-path path)))
           (handler-case
               (progn
                 (ensure-parent-directories resolved)
                 (with-open-file (stream resolved
                                         :direction :output
                                         :element-type 'character
                                         :if-exists :supersede
                                         :if-does-not-exist :create)
                   (write-string content stream))
                 (on-success))
             (error (c)
               (hngh.core:log-warn "Cannot write config ~A: ~A" path c)
               (on-failure)))))))))

;;; --- Public API: create-snapshot ------------------------------------------

(defun create-snapshot (description)
  "Create a btrfs snapshot via the system daemon.
DESCRIPTION: a human-readable description of the snapshot.
Emits a config.snapshot-created event.
Returns T on success, NIL on failure (e.g., system daemon not running)."
  (let ((result (call-system-daemon
                 "org.hngh.System.Btrfs" "CreateSnapshot"
                 (gdbus-string description))))
    (if result
        (let ((snapshot-id
                (bt:with-lock-held (*snapshots-lock*)
                  (incf *snapshot-next-id*)))
              (now (get-universal-time)))
          ;; Record it internally
          (bt:with-lock-held (*snapshots-lock*)
            (push (list :id snapshot-id
                        :description description
                        :timestamp now)
                  *snapshots*))
          (persist-snapshots)
          (emit-event "config.snapshot-created"
                      (list :description description :timestamp now))
          (hngh.core:log-info "Snapshot created: ~A (id ~D)" description snapshot-id)
          t)
        (progn
          (hngh.core:log-warn "Snapshot creation failed: ~A" description)
          nil))))

;;; --- Public API: list-snapshots -------------------------------------------

(defun list-snapshots ()
  "Return a list of internally tracked snapshot plists.
Each plist has keys :id, :description, and :timestamp.
Returns a list (may be empty)."
  (bt:with-lock-held (*snapshots-lock*)
    (copy-list *snapshots*)))

;;; --- Public API: managed-paths --------------------------------------------

(defun managed-paths ()
  "Return the list of paths under Hngh's configuration management.
Default: (\"/etc/pacman.conf\" \"/etc/makepkg.conf\" \"~/.config/hngh/\")."
  (bt:with-lock-held (*paths-lock*)
    (copy-list *managed-paths*)))

;;; --- Public API: add-managed-path -----------------------------------------

(defun add-managed-path (path)
  "Add PATH to Hngh's managed paths list.
Persists the updated list to the state store.
Returns T on success."
  (bt:with-lock-held (*paths-lock*)
    (pushnew path *managed-paths* :test #'string=))
  (persist-managed-paths)
  (emit-event "config.managed-path-added"
              (list :path path))
  t)

;;; --- Public API: remove-managed-path --------------------------------------

(defun remove-managed-path (path)
  "Remove PATH from Hngh's managed paths list.
Persists the updated list to the state store.
Returns T on success."
  (bt:with-lock-held (*paths-lock*)
    (setf *managed-paths* (remove path *managed-paths* :test #'string=)))
  (persist-managed-paths)
  (emit-event "config.managed-path-removed"
              (list :path path))
  t)

;;; --- Lifecycle: init ------------------------------------------------------

(defun init (&key (hngh-home hngh:*hngh-home*))
  "Initialize the System Config plugin.
Loads managed paths and snapshot records from the state store.
Subscribes to relevant events on the event bus."
  (setf *running* t
        *hngh-home* hngh-home
        *event-subscriptions* '())

  ;; Load managed paths from state store (or use defaults)
  (let ((paths (handler-case
                   (load-managed-paths)
                 (error ()
                   (copy-list *default-managed-paths*)))))
    (setf *managed-paths* paths))

  ;; Load snapshot records
  (handler-case
      (load-snapshots)
    (error ()
      (setf *snapshots* '()
            *snapshot-next-id* 0)))

  ;; Subscribe to relevant events for logging
  (when hngh.core.event-bus:*event-bus*
    (push (hngh.core.event-bus:subscribe
           "config.*"
           (lambda (evt)
             (hngh.core:log-debug "Config event: ~A ~S"
                                   (hngh.core.event-bus:event-topic evt)
                                   (hngh.core.event-bus:event-payload evt))))
          *event-subscriptions*))

  (hngh.core:log-info "System Config plugin initialized (~D managed paths, ~D snapshots)"
                       (length *managed-paths*)
                       (length *snapshots*)))

;;; --- Lifecycle: shutdown --------------------------------------------------

(defun shutdown ()
  "Shut down the System Config plugin.
Unsubscribes from events and clears state."
  (setf *running* nil)

  ;; Unsubscribe from events
  (dolist (sub-id *event-subscriptions*)
    (when hngh.core.event-bus:*event-bus*
      (hngh.core.event-bus:unsubscribe sub-id)))
  (setf *event-subscriptions* '())

  (hngh.core:log-info "System Config plugin shut down"))

;;; --- Lifecycle: running-p -------------------------------------------------

(defun running-p ()
  "Return T if the System Config plugin is active."
  *running*)

;;; --- Lifecycle: status ----------------------------------------------------

(defun status ()
  "Return a plist describing the System Config plugin status."
  (bt:with-lock-held (*paths-lock*)
    (bt:with-lock-held (*snapshots-lock*)
      (list :running *running*
            :managed-paths (copy-list *managed-paths*)
            :snapshots-count (length *snapshots*)))))
