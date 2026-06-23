;;;; plugins/package-manager.lisp — Hngh Package Manager (B1)
;;;;
;;;; Read-only queries run directly as user via sb-ext:run-program.
;;;; Privileged operations (install/remove/upgrade) go through the
;;;; system daemon's dbus interface (gdbus call --system).
;;;;
;;;; SPDX-License-Identifier: AGPL-3.0-or-later
;;;; SPDX-FileCopyrightText: 2026 boundring <boundring@gmail.com>

(in-package :hngh.plugins.package-manager)

;; search shadows cl:search — unintern then shadow the name so
;; SBCL's package lock doesn't prevent defining our own SEARCH.
(eval-when (:compile-toplevel :load-toplevel :execute)
  (let ((sym (find-symbol "SEARCH")))
    (when sym (unintern sym)))
  ;; Shadow creates a NEW internal symbol, blocking re-inheritance from CL
  (shadow '("SEARCH"))
  ;; Export it so it matches the package's export list
  (export (find-symbol "SEARCH")))

;;; --- State ---------------------------------------------------------------

(defvar *running* nil
  "Whether the package manager plugin is active.")

(defvar *history* '()
  "List of past package operations. Each entry is a plist:
  (:timestamp <ut> :op :install/:remove/:upgrade :packages (list) :result :success/:failure)")

(defvar *history-lock* (bt:make-lock "hngh-pkgmgr-history")
  "Mutex protecting *history*.")

(defvar *aur-helper* nil
  "Detected AUR helper: :paru, :yay, or nil if none found.")

(defvar *event-subscriptions* '()
  "List of event subscription IDs for cleanup on shutdown.")

;;; --- Helper: run-command -------------------------------------------------

(defun run-command (program args)
  "Run PROGRAM with ARGS via sb-ext:run-program.
Returns (values output-string exit-code stderr-string).
On process-start failure (program not found), returns (values nil 127 stderr)."
  (handler-case
      (let* ((out-str (make-string-output-stream))
             (err-str (make-string-output-stream))
             (proc (sb-ext:run-program program args
                                        :output out-str
                                        :error err-str
                                        :search t
                                        :wait t))
             (exit-code (sb-ext:process-exit-code proc)))
        (values (get-output-stream-string out-str)
                exit-code
                (get-output-stream-string err-str)))
    (error (c)
      (hngh.core:log-debug "Command ~A ~{~A~^ ~} failed: ~A" program args c)
      (values nil 127 (princ-to-string c)))))

(defun run-command-lines (program args)
  "Run PROGRAM with ARGS and return stdout as a list of non-empty lines.
Returns NIL if the command fails."
  (multiple-value-bind (output exit-code stderr)
      (run-command program args)
    (declare (ignore stderr))
    (when (and output (zerop exit-code))
      (remove-if (lambda (s) (zerop (length s)))
                 (lines output)))))

;;; --- Helper: string utilities --------------------------------------------

(defun lines (string)
  "Split STRING into lines, trimming trailing carriage returns."
  (when (stringp string)
    (loop with len = (length string)
          for start = 0 then (1+ end)
          for end = (position #\Newline string :start start)
          for line = (subseq string start (if end end len))
          for trimmed = (string-right-trim '(#\Return) line)
          collect trimmed
          while end)))

(defun which-exists-p (program)
  "Return T if PROGRAM is available on PATH."
  (handler-case
      (let ((proc (sb-ext:run-program "which" (list program)
                                      :output :stream :wait t :search t)))
        (zerop (sb-ext:process-exit-code proc)))
    (error () nil)))

;;; --- Helper: AUR helper detection ----------------------------------------

(defun detect-aur-helper ()
  "Detect which AUR helper is available.  Sets *aur-helper* globally."
  (setf *aur-helper*
        (cond
          ((which-exists-p "paru") :paru)
          ((which-exists-p "yay") :yay)
          (t nil)))
  (hngh.core:log-info "AUR helper detected: ~A" *aur-helper*)
  *aur-helper*)

(defun aur-helper-command (op &rest args)
  "Return (values program args) for an AUR helper operation.
Signals an error if no AUR helper is available."
  (unless *aur-helper*
    (error "No AUR helper (paru/yay) found on this system"))
  (values (ecase *aur-helper* (:paru "paru") (:yay "yay"))
          (cons op args)))

;;; --- Helper: pacman info parsing -----------------------------------------

(defun parse-pacman-info (output)
  "Parse pacman -Si/-Qi output into a plist.
Keys are normalized to lowercase-hyphenated keywords (:depends-on, etc.).
The :depends-on value is split into a list of strings."
  (let ((plist '()))
    (dolist (line (lines output))
      (let ((colon-pos (position #\: line)))
        (when colon-pos
          (let ((key (string-trim " " (subseq line 0 colon-pos)))
                (value (string-trim " " (subseq line (1+ colon-pos)))))
            (when (and (plusp (length key)) (plusp (length value)))
              (let ((kw (normalize-keyword key)))
                (push kw plist)
                (push (if (eq kw :depends-on)
                          (split-depends value)
                          value)
                      plist)))))))
    (nreverse plist)))

(defun normalize-keyword (field-name)
  "Convert a pacman field name like \"Depends On\" to keyword :depends-on."
  (let* ((lower (string-downcase field-name))
         (normalized (substitute #\- #\Space lower)))
    (intern (string-upcase normalized) :keyword)))

(defun split-depends (value)
  "Split a space-separated Depends On value into a list of strings.
Values like \"None\" return an empty list."
  (if (string-equal value "none")
      '()
      (loop with start = 0
            with len = (length value)
            while (< start len)
            for end = (or (position #\Space value :start start) len)
            for pkg = (subseq value start end)
            do (setf start (1+ end))
            unless (zerop (length pkg))
            collect pkg)))

;;; --- Helper: system daemon dbus call -------------------------------------

(defun call-system-daemon (method &rest args)
  "Call METHOD on the Hngh system daemon via gdbus call --system.
Returns (values output-string exit-code)."
  (let ((gdbus-args (list* "call" "--system"
                           "--dest" "org.hngh.System"
                           "--object-path" "/org/hngh/System"
                           "--method" method
                           args)))
    (multiple-value-bind (output exit-code stderr)
        (run-command "gdbus" gdbus-args)
      (unless (zerop exit-code)
        (hngh.core:log-warn "System daemon call ~A failed: ~A" method stderr))
      (values output exit-code))))

;;; --- Helper: JSON formatting (manual, no dependency) ---------------------

(defun json-list-of-strings (strings)
  "Format a list of strings as a JSON array: [\"a\",\"b\"]."
  (with-output-to-string (s)
    (write-char #\[ s)
    (do ((rest strings (cdr rest)))
        ((null rest))
      (write-char #\" s)
      (write-string (car rest) s)
      (write-char #\" s)
      (when (cdr rest)
        (write-char #\, s)))
    (write-char #\] s)))

;;; --- Helper: history management ------------------------------------------

(defun add-to-history (op packages result)
  "Append an operation record to *history* and persist to state store."
  (bt:with-lock-held (*history-lock*)
    (push (list :timestamp (get-universal-time)
                :op op
                :packages (if (listp packages) packages (list packages))
                :result result)
          *history*))
  ;; Persist to state store
  (handler-case
      (hngh.core.state-store:write-state
       "config/plugins/package-manager/history.lisp"
       *history*)
    (error (c)
      (hngh.core:log-warn "Failed to persist package history: ~A" c))))

(defun emit-event (topic payload)
  "Emit a package event on the event bus if available."
  (when hngh.core.event-bus:*event-bus*
    (hngh.core.event-bus:publish topic payload :source 'package-manager)))

;;; --- Read-Only Queries ---------------------------------------------------

;;; 1. search

(defun search (query &key aur-p)
  "Search for packages matching QUERY.
Without AUR: uses pacman -Ssq, returning repo packages.
With AUR: uses the AUR helper -Ssq, including AUR results.
Returns a list of package name strings."
  (if aur-p
      (multiple-value-bind (program args)
          (aur-helper-command "-Ssq" query)
        (or (run-command-lines program args) '()))
      (or (run-command-lines "pacman" (list "-Ssq" query)) '())))

;;; 2. info

(defun info (name &key aur-p)
  "Get detailed information about package NAME.
Without AUR: tries pacman -Si (repo) then pacman -Qi (installed).
With AUR: uses the AUR helper -Si.
Returns a plist with keys :name, :version, :description, :repository,
:url, :depends-on (list), and any other fields from the output.
Returns NIL if the package is not found."
  (if aur-p
      (multiple-value-bind (program args)
          (aur-helper-command "-Si" name)
        (multiple-value-bind (output code)
            (run-command program args)
          (when (and output (zerop code) (plusp (length output)))
            (parse-pacman-info output))))
      (let ((info-plist (multiple-value-bind (output code)
                            (run-command "pacman" (list "-Si" name))
                          (when (and output (zerop code) (plusp (length output)))
                            (parse-pacman-info output)))))
        (if info-plist
            info-plist
            (multiple-value-bind (output code)
                (run-command "pacman" (list "-Qi" name))
              (when (and output (zerop code) (plusp (length output)))
                (parse-pacman-info output)))))))

;;; 3. list-installed

(defun list-installed (&key explicit-p)
  "List installed packages.
If EXPLICIT-P is T, returns only explicitly installed packages (pacman -Qeq).
Otherwise returns all installed packages (pacman -Qq).
Returns a list of package name strings."
  (or (run-command-lines "pacman"
                         (if explicit-p '("-Qeq") '("-Qq")))
      '()))

;;; 4. list-aur

(defun list-aur ()
  "List foreign/AUR packages (pacman -Qmq).
Returns a list of package name strings."
  (or (run-command-lines "pacman" '("-Qmq")) '()))

;;; 5. list-updates

(defun list-updates (&key aur-p)
  "List available package updates.
Returns repo updates from checkupdates, and optionally AUR updates.
Each entry is a plist: (:name \"linux\" :old-version \"6.9.1-1\" :new-version \"6.9.2-1\").
Returns a list (possibly empty if no updates available)."
  (let ((results '()))
    ;; Repo updates via checkupdates
    (when (which-exists-p "checkupdates")
      (multiple-value-bind (output code)
          (run-command "checkupdates" '())
        (when (and output (zerop code))
          (dolist (line (lines output))
            (when (plusp (length line))
              (let ((parsed (parse-update-line line)))
                (when parsed
                  (push parsed results))))))))
    ;; AUR updates
    (when aur-p
      (when *aur-helper*
        (multiple-value-bind (program args)
            (aur-helper-command "-Qua")
          (multiple-value-bind (output code)
              (run-command program args)
            (when (and output (zerop code))
              (dolist (line (lines output))
                (when (plusp (length line))
                  ;; paru -Qua output may include repo prefix: "aur/pkg 1.0 -> 1.1"
                  (let ((cleaned (clean-aur-update-line line)))
                    (when cleaned
                      (let ((parsed (parse-update-line cleaned)))
                        (when parsed
                          (push parsed results))))))))))))
    (nreverse results)))

(defun parse-update-line (line)
  "Parse an update line like \"pkg old-ver -> new-ver\" into a plist.
Returns NIL if the line doesn't match the expected format."
  (cl-ppcre:register-groups-bind (name old-ver new-ver)
      ("^(\\S+)\\s+(\\S+)\\s+->\\s+(\\S+)$" line)
    (list :name name :old-version old-ver :new-version new-ver)))

(defun clean-aur-update-line (line)
  "Strip repository prefix from AUR update lines like \"aur/pkg 1.0 -> 1.1\".
Returns the cleaned line or the original if no prefix found."
  (if (cl-ppcre:scan "^\\w+/" line)
      (cl-ppcre:regex-replace "^\\w+/" line "")
      line))

;;; 6. list-orphans

(defun list-orphans ()
  "List orphaned packages (pacman -Qdtq).
Returns a list of package name strings."
  (or (run-command-lines "pacman" '("-Qdtq")) '()))

;;; --- Privileged Operations (via system daemon) ---------------------------

;;; 7. install-packages

(defun install-packages (packages &key reason)
  "Install PACKAGES via the system daemon.
PACKAGES: a list of package name strings.
REASON: optional reason string for the operation log.
Emits package.op-started and package.op-completed/package.op-failed events.
Appends to history. Returns T on success, NIL on failure."
  (let* ((pkg-json (json-list-of-strings packages))
         (reason-str (or reason "")))
    (emit-event "package.op-started"
                (list :op :install :packages packages :reason reason-str))
    (hngh.core:log-info "Installing packages: ~{~A~^, ~}" packages)
    (multiple-value-bind (output code)
        (call-system-daemon "org.hngh.System.PackageManager.InstallPackages"
                            pkg-json reason-str)
      (declare (ignore output))
      (if (zerop code)
          (progn
            (emit-event "package.op-completed"
                        (list :op :install :packages packages :reason reason-str))
            (add-to-history :install packages :success)
            t)
          (progn
            (emit-event "package.op-failed"
                        (list :op :install :packages packages
                              :reason reason-str :error "daemon call failed"))
            (add-to-history :install packages :failure)
            nil)))))

;;; 8. remove-packages

(defun remove-packages (packages &key reason)
  "Remove PACKAGES. Currently not implemented via the system daemon.
Emits package.op-failed with :not-implemented reason.
Returns NIL."
  (declare (ignore reason))
  (hngh.core:log-warn "Package removal not yet supported via system daemon")
  (emit-event "package.op-failed"
              (list :op :remove :packages packages :reason :not-implemented))
  (add-to-history :remove packages :not-implemented)
  nil)

;;; 9. upgrade-system

(defun upgrade-system (&key reason)
  "Perform a full system upgrade.
1. Creates a btrfs snapshot via the system daemon.
2. Calls InstallPackages with all available update packages.
3. Runs check-breakage after the upgrade.
Emits events at each step. Returns T on success, NIL on failure."
  (let* ((reason-str (or reason "system-upgrade"))
         (updates (list-updates :aur-p t))
         (update-packages (mapcar (lambda (p) (getf p :name)) updates))
         ;; Find all current packages for snapshot
         (snapshot-name (format nil "pre-upgrade-~D" (get-universal-time))))
    (unless update-packages
      (hngh.core:log-info "No updates available — nothing to upgrade")
      (return-from upgrade-system t))

    (hngh.core:log-info "Starting system upgrade: ~D packages" (length update-packages))

    ;; Step 1: Create snapshot
    (emit-event "package.op-started"
                (list :op :snapshot :name snapshot-name :reason reason-str))
    (multiple-value-bind (snap-out snap-code)
        (call-system-daemon "org.hngh.System.Snapshot.CreateSnapshot"
                            (format nil "\"~A\"" snapshot-name))
      (if (zerop snap-code)
          (hngh.core:log-info "Snapshot created: ~A" snapshot-name)
          (hngh.core:log-warn "Snapshot creation returned non-zero (continuing): ~A" snap-out)))

    ;; Step 2: Install all update packages
    (emit-event "package.op-started"
                (list :op :upgrade :packages update-packages :reason reason-str))
    (let* ((pkg-json (json-list-of-strings update-packages))
           (success nil))
      (multiple-value-bind (output code)
          (call-system-daemon "org.hngh.System.PackageManager.InstallPackages"
                              pkg-json
                              (format nil "\"~A\"" reason-str))
        (declare (ignore output))
        (if (zerop code)
            (progn
              (emit-event "package.op-completed"
                          (list :op :upgrade :packages update-packages :reason reason-str))
              (add-to-history :upgrade update-packages :success)
              (setf success t))
            (progn
              (emit-event "package.op-failed"
                          (list :op :upgrade :packages update-packages
                                :reason reason-str :error "daemon call failed"))
              (add-to-history :upgrade update-packages :failure)
              (setf success nil))))

      ;; Step 3: Post-upgrade breakage check (regardless of success)
      (when success
        (let ((breakage (check-breakage)))
          (when (getf breakage :broken-p)
            (hngh.core:log-warn "Breakage detected after upgrade: ~A" breakage))))

      success)))

;;; --- Breakage Detection --------------------------------------------------

;;; 10. check-breakage

(defun check-breakage ()
  "Check for package breakage.
Runs pacman -Qk (missing files) and pacman -Qdtq (orphans).
If issues are found, emits a package.breakage-detected event.
Returns a plist: (:missing-files (list) :orphans (list) :broken-p nil)."
  (let ((missing-files '())
        (orphans '())
        (broken-p nil))
    ;; Check missing files via pacman -Qk
    ;; pacman -Qk missing-file warnings go to stderr.
    (multiple-value-bind (output code stderr)
        (run-command "pacman" '("-Qk"))
      (declare (ignore output code))
      (when stderr
        (dolist (line (lines stderr))
          (when (and (plusp (length line))
                     (cl-ppcre:scan "^(warning:)?" line))
            (let ((pkg-name (parse-missing-file-line line)))
              (when pkg-name
                (pushnew pkg-name missing-files :test #'string=)))))))

    ;; Check orphans
    (setf orphans (list-orphans))

    ;; Determine if broken
    (when (or missing-files orphans)
      (setf broken-p t)
      (emit-event "package.breakage-detected"
                  (list :missing-files missing-files :orphans orphans)))

    (list :missing-files missing-files
          :orphans orphans
          :broken-p broken-p)))

(defun parse-missing-file-line (line)
  "Extract package name from a pacman -Qk warning line.
Example: \"warning: firefox: /usr/lib/firefox/... (No such file or directory)\" → \"firefox\""
  (cl-ppcre:register-groups-bind (pkg)
      ("^warning:\\s*(\\S+):" line)
    pkg))

;;; --- History -------------------------------------------------------------

(defun history ()
  "Return the current operation history as a list of plists.
Most recent operations first."
  (bt:with-lock-held (*history-lock*)
    (copy-list *history*)))

;;; --- Lifecycle -----------------------------------------------------------

(defun init (&key (hngh-home hngh:*hngh-home*))
  "Initialize the package manager plugin.
Detects AUR helper, loads history from state store, subscribes to events."
  (declare (ignore hngh-home))
  (setf *running* t
        *event-subscriptions* '())

  ;; Detect AUR helper
  (detect-aur-helper)

  ;; Load history from state store
  (handler-case
      (let ((loaded (hngh.core.state-store:read-state
                     "config/plugins/package-manager/history.lisp")))
        (when loaded
          (setf *history* loaded)
          (hngh.core:log-info "Loaded package history: ~D entries"
                               (length *history*))))
    (error (c)
      (hngh.core:log-warn "Could not load package history: ~A" c)))

  ;; Subscribe to package events for logging
  (when hngh.core.event-bus:*event-bus*
    (push (hngh.core.event-bus:subscribe
           "package.*"
           (lambda (evt)
             (hngh.core:log-debug "Package event: ~A ~S"
                                   (hngh.core.event-bus:event-topic evt)
                                   (hngh.core.event-bus:event-payload evt))))
          *event-subscriptions*))

  (hngh.core:log-info "Package manager initialized (aur: ~A)" *aur-helper*))

(defun shutdown ()
  "Shut down the package manager plugin.
Unsubscribes from events, clears state."
  (setf *running* nil)

  ;; Unsubscribe from events
  (dolist (sub-id *event-subscriptions*)
    (when hngh.core.event-bus:*event-bus*
      (hngh.core.event-bus:unsubscribe sub-id)))
  (setf *event-subscriptions* '())

  (hngh.core:log-info "Package manager shut down"))

(defun running-p ()
  "Return T if the package manager plugin is active."
  *running*)

(defun status ()
  "Return a plist describing the package manager status."
  (bt:with-lock-held (*history-lock*)
    (list :running *running*
          :aur-helper (or *aur-helper* :none)
          :packages-installed (length (list-installed))
          :history-entries (length *history*))))
