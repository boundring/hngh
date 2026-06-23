;;;; core/threat-detection.lisp — Hngh Procedural Threat Detection (A7)
;;;;
;;;; L1: Static analysis of plugin manifests and code before loading.
;;;; L3: Runtime observation of plugin behavior (file access, network, subprocess).
;;;;
;;;; SPDX-License-Identifier: AGPL-3.0-or-later
;;;; SPDX-FileCopyrightText: 2026 boundring <boundring@gmail.com>

(in-package :hngh.core.threat-detection)

;;; --- Data structures ---

(defstruct l1-verdict
  "Verdict from L1 static analysis."
  result        ; :pass | :fail | :ambiguous
  checks-run    ; list of check keywords
  failures)     ; list of (:check name :reason string)

(defvar *patterns* nil
  "List of known-bad patterns. Plist: (:name str :match :symbol|:form :pattern val :severity kw :description str)")

(defvar *patterns-lock* (bt:make-lock "hngh-threat-patterns")
  "Mutex protecting *patterns*.")

(defvar *flags* nil
  "List of flags raised by L3. Plist: (:plugin name :severity kw :evidence str :timestamp ut)")

(defvar *flags-lock* (bt:make-lock "hngh-threat-flags")
  "Mutex protecting *flags*.")

(defvar *running* nil)

(defvar *subscription-ids* nil)

(defvar *hngh-home* nil)

(defvar *observation-log-dir* nil)

(defvar *plugin-baselines* (make-hash-table :test 'equal))

;;; --- Constants ---

(defparameter *valid-trust-tiers*
  '(:first-party :signed-community :user :ai-generated))

(defparameter *valid-languages*
  '(:cl :python :wasm))

(defparameter *required-manifest-keys*
  '(:name :version :trust-tier :language))

(defparameter *known-capability-categories*
  '(:filesystem :network :subprocess :dbus :ai :knowledge-base :secrets))

;; Dangerous function names as strings (case-insensitive matching)
(defparameter *dangerous-function-names*
  '("EVAL" "LOAD" "COMPILE-FILE" "RUN-PROGRAM" "SB-EXT:RUN-PROGRAM" "UIOP:RUN-PROGRAM"
    "UIOP:QUIT" "SB-EXT:QUIT" "SB-EXT:SAVE-LISP-AND-DIE")
  "Uppercase names of functions considered dangerous.")

(defparameter *capability-function-map*
  '((:subprocess "RUN-PROGRAM" "SB-EXT:RUN-PROGRAM" "UIOP:RUN-PROGRAM")
    (:network "SOCKET-CONNECT" "SOCKET-SERVER" "HTTP-REQUEST" "DRAKMA:HTTP-REQUEST")
    (:filesystem "OPEN" "WITH-OPEN-FILE")
    (:dbus "DBUS:CALL" "DBUS:CALL-METHOD"))
  "Mapping from capability category to function name strings (uppercase).")

;;; --- Helpers ---

(defun manifest-get (manifest key)
  (getf manifest key))

(defun capability-value (manifest cap-category cap-subkey)
  (let ((caps (manifest-get manifest :capabilities)))
    (when caps
      (let ((cat (getf caps cap-category)))
        (when cat
          (getf cat cap-subkey))))))

(defun plugin-has-capability-p (manifest cap-category)
  (let ((caps (manifest-get manifest :capabilities)))
    (when caps
      (not (null (getf caps cap-category))))))

(defun symbol-name-string (sym)
  "Return the uppercase string name of SYM, or NIL if not a symbol."
  (when (symbolp sym)
    (string-upcase (string sym))))

;;; --- L1: Manifest Analysis ---

(defun analyze-manifest (manifest)
  "Analyze a plugin manifest for threat indicators (L1 static)."
  (let* ((checks-run (list :manifest-schema :capability-validation
                           :pattern-db :trust-tier-rules))
         (failures nil))

    ;; 1. Schema validation
    (multiple-value-bind (ok missing) (validate-manifest-schema manifest)
      (unless ok
        (push (list :check :manifest-schema
                    :reason (format nil "Missing required keys: ~{~A~^, ~}" missing))
              failures))
      (let ((tier (manifest-get manifest :trust-tier)))
        (when (and tier (not (member tier *valid-trust-tiers*)))
          (push (list :check :manifest-schema
                      :reason (format nil "Invalid :trust-tier ~S (must be one of ~{~A~^, ~})"
                                      tier *valid-trust-tiers*))
                failures)))
      (let ((lang (manifest-get manifest :language)))
        (when (and lang (not (member lang *valid-languages*)))
          (push (list :check :manifest-schema
                      :reason (format nil "Invalid :language ~S (must be one of ~{~A~^, ~})"
                                      lang *valid-languages*))
                failures))))

    ;; 2. Capability validation
    (let ((caps (manifest-get manifest :capabilities)))
      (when caps
        (unless (listp caps)
          (push (list :check :capability-validation
                      :reason ":capabilities must be a plist")
                failures))
        (when (listp caps)
          (loop for key in caps by #'cddr
                do (unless (member key *known-capability-categories*)
                     (push (list :check :capability-validation
                                 :reason (format nil "Unknown capability category: ~S" key))
                           failures))))))

    ;; 3. Pattern DB check
    (let ((name (manifest-get manifest :name)))
      (when name
        (bt:with-lock-held (*patterns-lock*)
          (loop for pattern in *patterns*
                do (when (member (getf pattern :match) '(:symbol :form))
                     (let ((pat (getf pattern :pattern)))
                       (when (and (stringp pat) (string-equal pat name))
                         (push (list :check :pattern-db
                                     :reason (format nil "Plugin ~A matches known-bad pattern: ~A"
                                                     name (getf pattern :description)))
                               failures))))))))

    ;; 4. Trust tier rules
    (let ((tier (manifest-get manifest :trust-tier)))
      (when (eq tier :ai-generated)
        (unless (manifest-get manifest :review)
          (push (list :check :trust-tier-rules
                      :reason "AI-generated plugin must include a :review section (mandatory L2 review)")
                failures))))

    (let ((result (if failures :fail :pass)))
      (make-l1-verdict :result result
                       :checks-run checks-run
                       :failures (nreverse failures)))))

(defun validate-manifest-schema (manifest)
  (let ((missing nil))
    (dolist (key *required-manifest-keys*)
      (unless (manifest-get manifest key)
        (push key missing)))
    (values (null missing) (nreverse missing))))

;;; --- L1: Code Analysis ---

(defun analyze-code (path &optional manifest)
  "Analyze plugin source code for threat indicators (L1 static)."
  (unless (probe-file path)
    (return-from analyze-code
      (make-l1-verdict :result :fail
                       :checks-run '(:file-read)
                       :failures (list (list :check :file-read
                                            :reason (format nil "File not found: ~A" (namestring path)))))))

  (let ((forms nil)
        (findings nil))

    ;; Read file safely
    (handler-case
        (with-open-file (stream path :direction :input)
          (let ((*read-eval* nil))
            (loop for form = (read stream nil nil)
                  while form
                  do (push form forms))))
      (error (c)
        (return-from analyze-code
          (make-l1-verdict :result :fail
                           :checks-run '(:file-read)
                           :failures (list (list :check :file-read
                                                :reason (format nil "Failed to read file: ~A" c)))))))

    ;; Walk forms using inline recursive function (guaranteed to work)
    (labels ((walk (form)
               (when (listp form)
                 (let ((head (car form)))
                   (unless (member head '(quote function))
                     (let ((name (symbol-name-string head)))
                       (when name
                         (when (member name *dangerous-function-names* :test #'string=)
                           (push (list :check :dangerous-functions
                                       :function head
                                       :reason (format nil "Plugin code calls dangerous function ~S" head))
                                 findings))
                         (when manifest
                           (loop for (cap . fns) in *capability-function-map*
                                 do (when (member name fns :test #'string=)
                                      (unless (plugin-has-capability-p manifest cap)
                                        (push (list :check :capability-cross-check
                                                    :function head
                                                    :required-capability cap
                                                    :reason (format nil "Code calls ~S but manifest does not declare :~(~A~) capability"
                                                                    head cap))
                                              findings)))))))
                     (dolist (sub (cdr form))
                       (walk sub)))))))
      (dolist (form (nreverse forms))
        (walk form)))

    ;; Pattern DB check
    (bt:with-lock-held (*patterns-lock*)
      (dolist (pattern *patterns*)
        (when (eq (getf pattern :match) :form)
          (dolist (form (nreverse forms))
            (when (form-contains-p form (getf pattern :pattern))
              (push (list :check :pattern-db
                          :reason (format nil "Code matches pattern ~A: ~A"
                                          (getf pattern :name) (getf pattern :description)))
                    findings))))))

    (let* ((failures (nreverse findings))
           (result (if failures :fail :pass)))
      (make-l1-verdict :result result
                       :checks-run '(:dangerous-functions :capability-cross-check :pattern-db)
                       :failures failures))))

(defun scan-form (form findings &optional manifest)
  "Recursively scan FORM for dangerous functions and capability violations.
FINDINGS is a list that gets mutated with push."
  (when (listp form)
    (let ((head (car form)))
      ;; Skip QUOTE and FUNCTION forms (they contain literal data, not code)
      (unless (member head '(quote function))
        ;; Check head for dangerous functions
        (let ((name (symbol-name-string head)))
          (when name
            (when (member name *dangerous-function-names* :test #'string=)
              (push (list :check :dangerous-functions
                          :function head
                          :reason (format nil "Plugin code calls dangerous function ~S" head))
                    findings))
            ;; Capability cross-check
            (when manifest
              (loop for (cap . fns) in *capability-function-map*
                    do (when (member name fns :test #'string=)
                         (unless (plugin-has-capability-p manifest cap)
                           (push (list :check :capability-cross-check
                                       :function head
                                       :required-capability cap
                                       :reason (format nil "Code calls ~S but manifest does not declare :~(~A~) capability"
                                                       head cap))
                                 findings)))))))
        ;; Recurse into children
        (dolist (sub (cdr form))
          (scan-form sub findings manifest))))))

(defun form-contains-p (form target)
  "Return T if FORM contains TARGET structurally."
  (cond
    ((equal form target) t)
    ((and (symbolp target) (form-contains-symbol-p form target)) t)
    ((atom form) nil)
    (t (or (form-contains-p (car form) target)
           (loop for sub in (cdr form)
                 thereis (form-contains-p sub target))))))

(defun form-contains-symbol-p (form target)
  (cond
    ((eq form target) t)
    ((atom form) nil)
    (t (or (form-contains-symbol-p (car form) target)
           (loop for sub in (cdr form)
                 thereis (form-contains-symbol-p sub target))))))

;;; --- Pattern Management ---

(defun add-pattern (pattern)
  (bt:with-lock-held (*patterns-lock*)
    (push pattern *patterns*))
  (hngh.core:log-debug "Added threat pattern: ~A" (getf pattern :name))
  (persist-patterns)
  (length *patterns*))

(defun persist-patterns ()
  (when (and *hngh-home* (hngh.core.state-store:running-p))
    (handler-case
        (hngh.core.state-store:write-state "state/patterns.lisp" *patterns*)
      (error (c)
        (hngh.core:log-warn "Failed to persist patterns: ~A" c)))))

(defun load-patterns ()
  (when (and *hngh-home* (hngh.core.state-store:running-p))
    (when (hngh.core.state-store:state-exists-p "state/patterns.lisp")
      (handler-case
          (let ((loaded (hngh.core.state-store:read-state "state/patterns.lisp")))
            (when (listp loaded)
              (bt:with-lock-held (*patterns-lock*)
                (setf *patterns* (append loaded *patterns*)))
              (hngh.core:log-debug "Loaded ~D patterns from state/patterns.lisp" (length loaded))))
        (error (c)
          (hngh.core:log-warn "Failed to load patterns: ~A; starting with empty DB" c)))))
  *patterns*)

;;; --- L3: Runtime Observation ---

(defun observe-behavior (plugin-name event)
  "Process a runtime observation event for a plugin (L3 runtime).
Returns the flag plist if a threat was detected, NIL if benign."
  (when (stringp event)
    (return-from observe-behavior nil))

  (let ((topic (get-event-topic event)))
    (unless topic
      (return-from observe-behavior nil))

    (update-baseline plugin-name)

    (cond
      ((string= topic "secret.denied")
       (let ((payload (get-event-payload event)))
         (raise-flag plugin-name :high
                     (format nil "Unauthorized secret access attempt by ~A" plugin-name))))

      ((string= topic "plugin.subprocess-started")
       (let* ((payload (get-event-payload event))
              (binary (getf payload :binary)))
         (when (and binary (plugin-violates-capability-p plugin-name :subprocess binary))
           (raise-flag plugin-name :high
                       (format nil "Undeclared subprocess: ~A" binary)))))

      ((or (string= topic "plugin.file-accessed")
           (string= topic "plugin.file-written"))
       (let* ((payload (get-event-payload event))
              (path (getf payload :path)))
         (when (and path (plugin-violates-capability-p plugin-name :filesystem path))
           (raise-flag plugin-name :medium
                       (format nil "File access outside declared paths: ~A" path)))))

      ((string= topic "plugin.network-connection")
       (let* ((payload (get-event-payload event))
              (host (getf payload :host)))
         (when (and host (plugin-violates-capability-p plugin-name :network host))
           (raise-flag plugin-name :high
                       (format nil "Network connection to undeclared host: ~A" host)))))

      ((string= topic "plugin.dbus-call")
       (let* ((payload (get-event-payload event))
              (bus-name (getf payload :bus-name)))
         (when (and bus-name (plugin-violates-capability-p plugin-name :dbus bus-name))
           (raise-flag plugin-name :medium
                       (format nil "Dbus call to undeclared bus name: ~A" bus-name))))))))

(defun get-event-topic (event)
  (etypecase event
    (hngh.core.event-bus:event (hngh.core.event-bus:event-topic event))
    (list (getf event :topic))
    (t nil)))

(defun get-event-payload (event)
  (etypecase event
    (hngh.core.event-bus:event (hngh.core.event-bus:event-payload event))
    (list (getf event :payload))
    (t nil)))

(defun plugin-violates-capability-p (plugin-name cap-category value)
  (let ((info (hngh.core.plugin-host:get-plugin plugin-name)))
    (unless info (return-from plugin-violates-capability-p nil))
    (let ((manifest-path (hngh.core.plugin-host:plugin-info-manifest-path info)))
      (unless manifest-path (return-from plugin-violates-capability-p nil))
      (let ((manifest (handler-case (hngh.core.plugin-host:parse-manifest manifest-path) (error () nil))))
        (unless manifest (return-from plugin-violates-capability-p nil))
        (unless (plugin-has-capability-p manifest cap-category)
          (return-from plugin-violates-capability-p t))
        (ecase cap-category
          (:subprocess
           (let ((allowed (capability-value manifest :subprocess :allowed)))
             (and allowed (listp allowed) (not (member value allowed :test #'string-equal)))))
          (:network
           (let ((hosts (capability-value manifest :network :hosts)))
             (and hosts (listp hosts) (not (member value hosts :test #'string-equal)))))
          (:filesystem
           (let ((all-paths (append (capability-value manifest :filesystem :read)
                                    (capability-value manifest :filesystem :write))))
             (and all-paths (listp all-paths)
                  (not (path-in-declared-paths-p value all-paths)))))
          (:dbus
           (let ((all-names (append (capability-value manifest :dbus :system)
                                    (capability-value manifest :dbus :session))))
             (and all-names (listp all-names) (not (member value all-names :test #'string-equal)))))
          (:ai nil)
          (:knowledge-base nil)
          (:secrets nil))))))

(defun raise-flag (plugin-name severity evidence &optional (source 'threat-detection))
  (let ((flag (list :plugin plugin-name :severity severity :evidence evidence
                    :timestamp (get-universal-time) :layer :L3)))
    (bt:with-lock-held (*flags-lock*)
      (push flag *flags*))
    (update-baseline plugin-name :flag)
    (when hngh.core.event-bus:*event-bus*
      (hngh.core.event-bus:publish "threat.flag"
        (list :plugin plugin-name :severity severity :evidence evidence
              :layer :L3 :timestamp (get-universal-time))
        :source source))
    (hngh.core:log-warn "Threat flag raised for ~A (severity: ~A): ~A" plugin-name severity evidence)
    flag))

(defun path-in-declared-paths-p (path declared-paths)
  (loop for declared in declared-paths
        thereis (or (string-equal path declared)
                    (and (> (length path) (length declared))
                         (string-equal (subseq path 0 (length declared)) declared)))))

;;; --- Baseline management ---

(defun update-baseline (plugin-name &optional (action :event))
  (let* ((baseline (gethash plugin-name *plugin-baselines*)))
    (unless baseline
      (setf baseline (list :start-time (get-universal-time) :event-count 0 :flags-raised 0))
      (setf (gethash plugin-name *plugin-baselines*) baseline))
    (ecase action
      (:event (incf (getf baseline :event-count)))
      (:flag (incf (getf baseline :flags-raised))))))

;;; --- Query ---

(defun list-flags ()
  (bt:with-lock-held (*flags-lock*)
    (copy-list *flags*)))

(defun clear-flags ()
  (bt:with-lock-held (*flags-lock*)
    (setf *flags* nil)))

;;; --- Lifecycle ---

(defun init (&key (hngh-home hngh:*hngh-home*))
  (setf *hngh-home* hngh-home
        *observation-log-dir* (merge-pathnames "state/plugin-observations/" hngh-home))
  (ensure-directories-exist *observation-log-dir*)
  (bt:with-lock-held (*patterns-lock*) (setf *patterns* nil))
  (bt:with-lock-held (*flags-lock*) (setf *flags* nil))
  (setf *plugin-baselines* (make-hash-table :test 'equal)
        *subscription-ids* nil *running* t)
  (load-patterns)
  (when hngh.core.event-bus:*event-bus*
    (let ((sub-id (hngh.core.event-bus:subscribe "plugin.*"
                    (lambda (event)
                      (when (and *running* event)
                        (let ((source (hngh.core.event-bus:event-source event)))
                          (when source
                            (observe-behavior (princ-to-string source) event)))))
                    :persistent nil :queue-max 500 :drop-policy :drop)))
      (push sub-id *subscription-ids*))
    (let ((sub-id (hngh.core.event-bus:subscribe "secret.*"
                    (lambda (event)
                      (when (and *running* event)
                        (let ((topic (hngh.core.event-bus:event-topic event)))
                          (when (string= topic "secret.denied")
                            (let* ((payload (hngh.core.event-bus:event-payload event))
                                   (requester (getf payload :requester)))
                              (when (stringp requester)
                                (observe-behavior requester event)))))))
                    :persistent nil :queue-max 500 :drop-policy :drop)))
      (push sub-id *subscription-ids*))
    (hngh.core:log-debug "Threat detection L3 subscribed to event bus topics"))
  (hngh.core:log-info "Threat detection initialized (patterns: ~D, flags: 0)" (length *patterns*))
  t)

(defun shutdown ()
  (when (and *subscription-ids* hngh.core.event-bus:*event-bus*)
    (dolist (sub-id *subscription-ids*)
      (handler-case (hngh.core.event-bus:unsubscribe sub-id)
        (error (c) (hngh.core:log-warn "Failed to unsubscribe ~D during shutdown: ~A" sub-id c)))))
  (setf *running* nil *subscription-ids* nil *hngh-home* nil *observation-log-dir* nil)
  (bt:with-lock-held (*patterns-lock*) (setf *patterns* nil))
  (bt:with-lock-held (*flags-lock*) (setf *flags* nil))
  (clrhash *plugin-baselines*)
  (hngh.core:log-info "Threat detection shut down"))

(defun running-p ()
  *running*)
