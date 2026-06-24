;;;; plugins/llm-threat-detector.lisp — LLM Threat Detector (B5)
;;;;
;;;; L2: Semantic review for ambiguous/AI-generated plugins.
;;;; L4: Behavioral review on threat flags + periodic drift checks.
;;;;
;;;; SPDX-License-Identifier: AGPL-3.0-or-later
;;;; SPDX-FileCopyrightText: 2026 boundring <boundring@gmail.com>

(in-package :hngh.plugins.llm-threat-detector)

;;; --- State ------------------------------------------------------------------

(defvar *running* nil
  "Whether the LLM Threat Detector plugin is active.")

(defvar *hngh-home* nil
  "Current Hngh home path used by this plugin.")

(defvar *schedule-id* nil
  "Scheduler job id for periodic review.")

(defvar *event-subscriptions* '()
  "Subscription IDs to clean up on shutdown.")

(defvar *review-queue* '()
  "Queued review requests when resources are unavailable.")

(defvar *state-append-lock* (bt:make-lock "hngh-llm-threat-state-append")
  "Mutex guarding read-modify-write append operations on persisted list state.")

(defparameter *prefs-path* "config/plugins/llm-threat/prefs.lisp"
  "Relative state path for llm-threat preferences.")

(defparameter *history-path* "state/plugins/llm-threat/history.lisp"
  "Relative state path for llm-threat review history.")

(defparameter *default-prefs*
  '(:model "llama3.2-3b"
    :model-kind :ollama
    :model-size-mib 1024
    :review-interval-seconds 86400
    :periodic-max-age-seconds 604800
    :confidence-threshold :med)
  "Default preferences for LLM threat review behavior.")

;;; --- Utility helpers --------------------------------------------------------

(defun string-of (value)
  "Convert VALUE to a readable string."
  (cond
    ((null value) "")
    ((stringp value) value)
    ((symbolp value) (symbol-name value))
    (t (princ-to-string value))))

(defun normalize-string (value)
  "Normalize VALUE to lowercase trimmed string."
  (string-downcase
   (string-trim '(#\Space #\Tab #\Newline #\Return)
                (string-of value))))

(defun slugify (value)
  "Create a filesystem-safe slug from VALUE."
  (let* ((raw (normalize-string value))
         (chars (loop for ch across raw
                      collect (if (or (alphanumericp ch)
                                      (char= ch #\-)
                                      (char= ch #\_))
                                  ch
                                  #\-)))
         (collapsed (coerce chars 'string))
         (trimmed (string-trim "-" collapsed)))
    (if (zerop (length trimmed))
        "unknown-plugin"
        trimmed)))

(defun safe-read-state (relative-path)
  "Read state RELATIVE-PATH and return NIL on failure."
  (handler-case
      (hngh.core.state-store:read-state relative-path)
    (error (c)
      (hngh.core:log-warn "LLM Threat Detector read failed (~A): ~A" relative-path c)
      nil)))

(defun safe-write-state (relative-path value)
  "Write VALUE to RELATIVE-PATH, returning T on success."
  (handler-case
      (progn
        (hngh.core.state-store:write-state relative-path value)
        t)
    (error (c)
      (hngh.core:log-warn "LLM Threat Detector write failed (~A): ~A" relative-path c)
      nil)))

(defun append-state-entry (relative-path entry)
  "Append ENTRY to a list persisted at RELATIVE-PATH."
  (bt:with-lock-held (*state-append-lock*)
    (let ((existing (safe-read-state relative-path)))
      (safe-write-state
       relative-path
       (append (if (listp existing) existing '()) (list entry))))))

(defun ensure-owned-directories ()
  "Ensure config/state paths owned by this plugin exist."
  (when *hngh-home*
    (ensure-directories-exist (merge-pathnames "config/plugins/llm-threat/" *hngh-home*))
    (ensure-directories-exist (merge-pathnames "state/plugins/llm-threat/" *hngh-home*))
    (ensure-directories-exist (merge-pathnames "state/plugin-observations/" *hngh-home*))
    (ensure-directories-exist (merge-pathnames "plugins/" *hngh-home*))
    t))

(defun maybe-publish (topic payload)
  "Publish TOPIC/PAYLOAD if event bus is available."
  (when hngh.core.event-bus:*event-bus*
    (handler-case
        (hngh.core.event-bus:publish topic payload :source 'llm-threat-detector)
      (error (c)
        (hngh.core:log-warn "LLM Threat Detector publish failed (~A): ~A" topic c)
        nil))))

(defun load-prefs ()
  "Load prefs from state store, or write defaults when absent/invalid."
  (let ((prefs (safe-read-state *prefs-path*)))
    (if (and (listp prefs) (getf prefs :model) (getf prefs :review-interval-seconds))
        prefs
        (progn
          (safe-write-state *prefs-path* *default-prefs*)
          (copy-list *default-prefs*)))))

(defun history-entry (&rest kvs)
  "Create a history plist with current timestamp and KV pairs."
  (append (list :timestamp (get-universal-time)) kvs))

(defun queue-review (kind payload reason)
  "Queue a review request with REASON and return queued entry."
  (let ((entry (list :kind kind
                     :payload payload
                     :reason reason
                     :queued-at (get-universal-time))))
    (push entry *review-queue*)
    (append-state-entry *history-path* (history-entry :action :queued :kind kind :reason reason))
    entry))

(defun plugin-name-from-manifest (manifest)
  "Resolve plugin name from MANIFEST with fallback."
  (or (and (listp manifest) (getf manifest :name))
      "unknown-plugin"))

(defun plugin-verdict-path (plugin-name)
  "Return persisted L2 verdict path for PLUGIN-NAME."
  (format nil "plugins/~A/review-verdict.lisp" (slugify plugin-name)))

(defun plugin-assessment-path (plugin-name)
  "Return persisted L4 assessments path for PLUGIN-NAME."
  (format nil "state/plugin-observations/~A/assessments.lisp" (slugify plugin-name)))

(defun parse-severity (value)
  "Normalize severity VALUE to :low/:medium/:high."
  (let ((s (normalize-string value)))
    (cond
      ((or (string= s "high") (string= s ":high")) :high)
      ((or (string= s "medium") (string= s ":medium") (string= s "med") (string= s ":med")) :medium)
      (t :low))))

(defun concerns-from-l1 (l1-findings)
  "Extract concern plists from L1 findings value."
  (let ((failures
          (cond
            ((typep l1-findings 'hngh.core.threat-detection:l1-verdict)
             (or (hngh.core.threat-detection:l1-verdict-failures l1-findings) '()))
            ((listp l1-findings) (or (getf l1-findings :failures) '()))
            (t '()))))
    (loop for item in failures
          collect (list :severity :high
                        :check (or (getf item :check) :unknown)
                        :reason (or (getf item :reason) "L1 reported a concern")))))

(defun concerns-from-code (code)
  "Extract heuristic concerns from source CODE."
  (let ((text (string-upcase (string-of code)))
        (result '()))
    (when (search "RUN-PROGRAM" text)
      (push (list :severity :high
                  :check :dangerous-functions
                  :reason "Code appears to execute subprocesses (RUN-PROGRAM).")
            result))
    (when (search "EVAL" text)
      (push (list :severity :high
                  :check :dangerous-functions
                  :reason "Code appears to call EVAL.")
            result))
    (when (search "HTTP" text)
      (push (list :severity :medium
                  :check :network-access
                  :reason "Code appears to perform network operations.")
            result))
    (nreverse result)))

(defun confidence-from-concerns (concerns)
  "Compute confidence keyword from CONCERNS list."
  (cond
    ((null concerns) :high)
    ((some (lambda (c) (eq (getf c :severity) :high)) concerns) :high)
    ((> (length concerns) 2) :med)
    (t :low)))

(defun adjust-confidence-for-trust-tier (confidence trust-tier)
  "Adjust CONFIDENCE for TRUST-TIER risk posture.
AI-generated plugins are one notch less confident by default." 
  (if (eq trust-tier :ai-generated)
      (case confidence
        (:high :med)
        (:med :low)
        (otherwise :low))
      confidence))

(defun concerns->suggested-fixes (concerns)
  "Generate fix suggestions from concern list."
  (loop for c in concerns
        collect (list :check (getf c :check)
                      :fix (format nil "Address concern: ~A" (getf c :reason)))))

(defun l1-result-of (l1-findings)
  "Extract :result from L1 findings when available."
  (cond
    ((typep l1-findings 'hngh.core.threat-detection:l1-verdict)
     (hngh.core.threat-detection:l1-verdict-result l1-findings))
    ((listp l1-findings) (getf l1-findings :result))
    (t nil)))

(defun request-review-grant (prefs kind)
  "Request a model-load grant for review KIND.
Returns (values grant-info nil) on success, or (values nil reason-keyword)."
  (unless (and (fboundp 'hngh.core.resource-manager:running-p)
               (hngh.core.resource-manager:running-p))
    (return-from request-review-grant (values nil :resource-manager-unavailable)))
  (multiple-value-bind (grant err)
      (hngh.core.resource-manager:request-resource
       :model-load
       (list :model (getf prefs :model)
             :kind (getf prefs :model-kind)
             :size (getf prefs :model-size-mib 1024)
             :review kind)
       :holder "llm-threat-detector"
       :priority 7
       :preemptible nil)
    (if grant
        (values grant nil)
        (values nil (or err :resource-unavailable)))))

(defun release-review-grant (grant)
  "Release resource grant GRANT when present."
  (when grant
    (ignore-errors
      (hngh.core.resource-manager:release
       (hngh.core.resource-manager:grant-info-id grant)))))

(defun maybe-record-threat-pattern (plugin-name summary assessment)
  "Write a threat pattern into the Knowledge Base when available." 
  (when (and (find-package :hngh.plugins.knowledge-base)
             (fboundp 'hngh.plugins.knowledge-base:knowledge-base-ready-p)
             (hngh.plugins.knowledge-base:knowledge-base-ready-p)
             (member assessment '(:suspicious :malicious)))
    (ignore-errors
      (hngh.plugins.knowledge-base:kb-record-pattern
       (format nil "~A-~D" (slugify plugin-name) (get-universal-time))
       "threats"
       (format nil "Threat review pattern for ~A" plugin-name)
       summary
       :tags (list "threat" (string-downcase (symbol-name assessment)))
       :signals (list summary)
       :actions (list "review-plugin-manifest" "review-capability-declarations")))))

(defun build-l2-verdict (plugin-name code manifest l1-findings context)
  "Build deterministic L2 review verdict plist."
  (declare (ignore context))
  (let* ((concerns (append (concerns-from-l1 l1-findings)
                           (concerns-from-code code)))
          (trust-tier (getf manifest :trust-tier))
          (pass (null concerns))
          (confidence (adjust-confidence-for-trust-tier
                       (confidence-from-concerns concerns)
                       trust-tier))
          (reasoning (if pass
                         (format nil "No semantic security concerns detected for ~A." plugin-name)
                         (format nil "Detected ~D concern(s) while reviewing plugin ~A." (length concerns) plugin-name))))
    (list :pass pass
          :confidence confidence
          :concerns concerns
          :suggested-fixes (concerns->suggested-fixes concerns)
          :reasoning reasoning
          :trust-tier trust-tier
          :reviewed-at (get-universal-time))))

(defun severity-from-evidence (entry)
  "Extract severity keyword from one evidence ENTRY."
  (let ((raw (or (getf entry :severity)
                 (getf (getf entry :payload) :severity)
                 :low)))
    (parse-severity raw)))

(defun build-l4-assessment (plugin-name since evidence)
  "Build deterministic L4 behavioral assessment plist."
  (let* ((normalized (if (listp evidence) evidence '()))
         (severities (mapcar #'severity-from-evidence normalized))
         (high-count (count :high severities))
         (medium-count (count :medium severities))
         (assessment (cond
                       ((plusp high-count) :malicious)
                       ((or (plusp medium-count) (> (length normalized) 2)) :suspicious)
                       (t :benign)))
         (confidence (cond
                       ((eq assessment :malicious) :high)
                       ((eq assessment :suspicious) :med)
                       (t :low)))
         (reasoning (format nil "Behavioral review for ~A examined ~D evidence item(s): ~A."
                            plugin-name
                            (length normalized)
                            assessment)))
    (list :plugin plugin-name
          :since since
          :assessment assessment
          :confidence confidence
          :evidence-count (length normalized)
          :reasoning reasoning
          :reviewed-at (get-universal-time))))

(defun collect-flags-since (since)
  "Collect threat flags from L3 since SINCE universal time."
  (let ((flags (if (fboundp 'hngh.core.threat-detection:list-flags)
                   (hngh.core.threat-detection:list-flags)
                   '())))
    (loop for flag in flags
          for ts = (or (getf flag :timestamp) 0)
          when (>= ts since)
          collect flag)))

(defun group-evidence-by-plugin (evidence)
  "Group EVIDENCE list by plugin name.
Returns an alist of (plugin-name . entries)."
  (let ((table (make-hash-table :test 'equal)))
    (dolist (entry evidence)
      (let ((plugin (or (getf entry :plugin)
                        (getf (getf entry :payload) :plugin)
                        "unknown-plugin")))
        (push entry (gethash (string-of plugin) table))))
    (loop for key being the hash-keys of table
          using (hash-value value)
          collect (cons key (nreverse value)))))

(defun run-periodic-reviews ()
  "Periodic scheduler callback for L4 drift review." 
  (when *running*
    (let* ((prefs (load-prefs))
           (window (getf prefs :periodic-max-age-seconds 604800))
           (since (- (get-universal-time) window))
           (flags (collect-flags-since since)))
      (dolist (bucket (group-evidence-by-plugin flags))
        (review-behavior (car bucket) :since since :evidence (cdr bucket))))))

;;; --- Public API -------------------------------------------------------------

(defun init (&key (hngh-home hngh:*hngh-home*))
  "Initialize LLM Threat Detector plugin." 
  (when *running*
    (shutdown))
  (setf *hngh-home* hngh-home
        *schedule-id* nil
        *event-subscriptions* '()
        *review-queue* '())
  (ensure-owned-directories)
  (load-prefs)

  (when hngh.core.event-bus:*event-bus*
    (push (hngh.core.event-bus:subscribe
           "threat.flag"
           (lambda (event)
             (when *running*
               (let* ((payload (hngh.core.event-bus:event-payload event))
                      (plugin (or (getf payload :plugin)
                                  (string-of (hngh.core.event-bus:event-source event))
                                  "unknown-plugin"))
                      (timestamp (or (getf payload :timestamp) (get-universal-time))))
                 (review-behavior plugin :since timestamp :evidence (list payload)))))
           :persistent nil)
          *event-subscriptions*))

  (when (hngh.core.scheduler:running-p)
    (let* ((prefs (load-prefs))
           (interval (getf prefs :review-interval-seconds 86400)))
      (setf *schedule-id*
            (hngh.core.scheduler:schedule
             "llm-threat.periodic-review"
             (list :interval interval)
             (list :function #'run-periodic-reviews)
             :source 'llm-threat-detector))))

  (setf *running* t)
  (hngh.core:log-info "LLM Threat Detector initialized")
  t)

(defun shutdown ()
  "Shutdown LLM Threat Detector plugin." 
  (when *schedule-id*
    (ignore-errors
      (when (hngh.core.scheduler:running-p)
        (hngh.core.scheduler:cancel *schedule-id*)))
    (setf *schedule-id* nil))

  (dolist (sub-id *event-subscriptions*)
    (ignore-errors
      (when hngh.core.event-bus:*event-bus*
        (hngh.core.event-bus:unsubscribe sub-id))))

  (setf *event-subscriptions* '()
        *running* nil)
  (hngh.core:log-info "LLM Threat Detector shut down")
  t)

(defun running-p ()
  "Return T if plugin is active."
  *running*)

(defun review-plugin (code manifest l1-findings &key context)
  "Perform L2 semantic plugin review and persist a verdict plist." 
  (unless *running*
    (return-from review-plugin nil))
  (let* ((plugin-name (plugin-name-from-manifest manifest))
         (prefs (load-prefs))
         (urgent (or (eq (getf manifest :trust-tier) :ai-generated)
                     (eq (l1-result-of l1-findings) :ambiguous))))
    (multiple-value-bind (grant err)
        (request-review-grant prefs :l2)
      (let ((verdict
              (if grant
                  (build-l2-verdict plugin-name code manifest l1-findings context)
                  (progn
                    (queue-review :l2
                                  (list :plugin plugin-name
                                        :manifest manifest
                                        :l1 l1-findings)
                                  err)
                    (list :pass nil
                          :confidence :low
                          :concerns (list (list :severity :high
                                                :check :resource-unavailable
                                                :reason (format nil "Model resources unavailable (~A)." err)))
                          :suggested-fixes (list (list :check :resource-unavailable
                                                       :fix "Retry review when resources are available."))
                          :reasoning (if urgent
                                         "Urgent L2 review failed closed due to unavailable model resources."
                                         "L2 review queued because model resources are unavailable.")
                          :reviewed-at (get-universal-time))))))
        (unwind-protect
             (progn
               (safe-write-state (plugin-verdict-path plugin-name) verdict)
               (append-state-entry
                *history-path*
                (history-entry :action :review-plugin
                               :plugin plugin-name
                               :layer :l2
                               :result (if (getf verdict :pass) :pass :fail)
                               :confidence (getf verdict :confidence)
                               :model (getf prefs :model)))
               (maybe-publish "threat.review-verdict"
                              (list :plugin plugin-name
                                    :layer :L2
                                    :verdict verdict))
               verdict)
          (release-review-grant grant))))))

(defun review-behavior (plugin &key since evidence)
  "Perform L4 behavioral review and persist an assessment plist." 
  (unless *running*
    (return-from review-behavior nil))
  (let* ((plugin-name (string-of plugin))
         (prefs (load-prefs))
         (start-time (or since (- (get-universal-time)
                                  (getf prefs :periodic-max-age-seconds 604800)))))
    (multiple-value-bind (grant err)
        (request-review-grant prefs :l4)
      (let ((assessment
              (if grant
                  (build-l4-assessment plugin-name start-time (or evidence '()))
                  (progn
                    (queue-review :l4
                                  (list :plugin plugin-name
                                        :since start-time
                                        :evidence evidence)
                                  err)
                    (list :plugin plugin-name
                          :since start-time
                          :assessment :suspicious
                          :confidence :low
                          :evidence-count (length (or evidence '()))
                          :reasoning (format nil "L4 review queued; resources unavailable (~A)." err)
                          :reviewed-at (get-universal-time))))))
        (unwind-protect
             (progn
               (append-state-entry (plugin-assessment-path plugin-name) assessment)
               (append-state-entry
                *history-path*
                (history-entry :action :review-behavior
                               :plugin plugin-name
                               :layer :l4
                               :assessment (getf assessment :assessment)
                               :confidence (getf assessment :confidence)
                               :model (getf prefs :model)))
               (maybe-publish "threat.review-verdict"
                              (list :plugin plugin-name
                                    :layer :L4
                                    :verdict (list :pass (eq (getf assessment :assessment) :benign)
                                                   :confidence (getf assessment :confidence)
                                                   :reasoning (getf assessment :reasoning))))
               (maybe-publish "threat.assessment"
                              (list :plugin plugin-name
                                    :assessment (getf assessment :assessment)
                                    :reasoning (getf assessment :reasoning)))
               (maybe-record-threat-pattern plugin-name
                                            (getf assessment :reasoning)
                                            (getf assessment :assessment))
               assessment)
          (release-review-grant grant))))))

(defun explain (plugin question)
  "Return a user-facing explanation plist for PLUGIN and QUESTION." 
  (let* ((plugin-name (string-of plugin))
         (verdict (safe-read-state (plugin-verdict-path plugin-name)))
         (assessments (safe-read-state (plugin-assessment-path plugin-name)))
         (latest-assessment (if (listp assessments) (car (last assessments)) nil))
         (summary
           (cond
             ((and verdict latest-assessment)
              (format nil "Plugin ~A has L2 verdict pass=~A and latest L4 assessment=~A."
                      plugin-name
                      (getf verdict :pass)
                      (getf latest-assessment :assessment)))
             (verdict
              (format nil "Plugin ~A has an L2 verdict pass=~A." plugin-name (getf verdict :pass)))
             (latest-assessment
              (format nil "Plugin ~A has latest L4 assessment ~A." plugin-name
                      (getf latest-assessment :assessment)))
             (t
              (format nil "No prior threat review artifacts found for plugin ~A." plugin-name)))))
    (list :plugin plugin-name
          :question (string-of question)
          :latest-verdict verdict
          :latest-assessment latest-assessment
          :explanation summary
          :generated-at (get-universal-time))))

(defun status ()
  "Return a status plist for LLM Threat Detector runtime state." 
  (let ((history (safe-read-state *history-path*)))
    (list :running *running*
          :schedule-id *schedule-id*
          :subscriptions (length *event-subscriptions*)
          :queue-depth (length *review-queue*)
          :history-count (if (listp history) (length history) 0)
          :prefs (load-prefs))))
