;;;; tests/unit/test-llm-threat-detector.lisp — Tests for LLM Threat Detector (B5)
;;;;
;;;; SPDX-License-Identifier: AGPL-3.0-or-later
;;;; SPDX-FileCopyrightText: 2026 boundring <boundring@gmail.com>

(in-package :hngh.tests)

(def-suite :hngh.llm-threat-detector
  :description "Tests for LLM Threat Detector (B5)"
  :in :hngh)

(in-suite :hngh.llm-threat-detector)

;;; --- Helpers ---------------------------------------------------------------

(defun ltd-setup (tmp)
  "Initialize core dependencies and LLM Threat Detector on TMP."
  (hngh.core.event-bus:init :hngh-home tmp)
  (hngh.core.state-store:init :hngh-home tmp)
  (hngh.core.scheduler:init)
  (hngh.core.threat-detection:init :hngh-home tmp)
  (hngh.core.resource-manager:init :hngh-home tmp)
  (hngh.plugins.knowledge-base:initialize-knowledge-base :hngh-home tmp)
  (hngh.plugins.llm-threat-detector:init :hngh-home tmp))

(defun ltd-teardown (tmp)
  "Shutdown LLM Threat Detector and dependencies."
  (ignore-errors (hngh.plugins.llm-threat-detector:shutdown))
  (ignore-errors (hngh.plugins.knowledge-base:shutdown-knowledge-base))
  (ignore-errors (hngh.core.resource-manager:shutdown))
  (ignore-errors (hngh.core.threat-detection:shutdown))
  (ignore-errors (hngh.core.scheduler:shutdown))
  (ignore-errors (hngh.core.event-bus:shutdown))
  (ignore-errors (hngh.core.state-store:shutdown))
  (cleanup-tmp-home tmp))

(defmacro with-ltd ((tmp-var) &body body)
  "Run BODY with temporary home and LLM Threat Detector initialized."
  `(let ((,tmp-var (make-tmp-home)))
     (cleanup-tmp-home ,tmp-var)
     (unwind-protect
          (progn
            (ltd-setup ,tmp-var)
            ,@body)
       (ltd-teardown ,tmp-var))))

;;; --- Tests -----------------------------------------------------------------

(test ltd-lifecycle-registers-and-cancels-schedule
  (with-ltd (tmp)
    (is (hngh.plugins.llm-threat-detector:running-p)
        "Plugin should report running after init")
    (let* ((status (hngh.plugins.llm-threat-detector:status))
           (schedule-id (getf status :schedule-id))
           (has-job (find "llm-threat.periodic-review"
                          (hngh.core.scheduler:list-schedules)
                          :test #'string=
                          :key #'hngh.core.scheduler:schedule-info-name)))
      (is (integerp schedule-id)
          "Init should register periodic review scheduler job")
      (is (not (null has-job))
          "Scheduler should contain llm-threat periodic review job")
      (is (= 1 (getf status :subscriptions))
          "Plugin should subscribe to threat.flag events"))
    (hngh.plugins.llm-threat-detector:shutdown)
    (is (not (hngh.plugins.llm-threat-detector:running-p))
        "Plugin should report not running after shutdown")
    (is (null (find "llm-threat.periodic-review"
                    (hngh.core.scheduler:list-schedules)
                    :test #'string=
                    :key #'hngh.core.scheduler:schedule-info-name))
        "Shutdown should cancel periodic review schedule")))

(test ltd-review-plugin-persists-history-and-emits
  (with-ltd (tmp)
    (let ((received '()))
      (hngh.core.event-bus:subscribe
       "threat.review-verdict"
       (lambda (evt)
         (push (hngh.core.event-bus:event-payload evt) received)))

      (let* ((verdict (hngh.plugins.llm-threat-detector:review-plugin
                       "(defun risky () (run-program \"curl\"))"
                       '(:name "demo-plugin" :trust-tier :ai-generated)
                       '(:result :ambiguous
                         :failures ((:check :dangerous-functions
                                     :reason "Calls run-program")))
                       :context '(:source :test)))
             (verdict-path "plugins/demo-plugin/review-verdict.lisp")
             (history-path "state/plugins/llm-threat/history.lisp")
             (history (hngh.core.state-store:read-state history-path)))
        (is (listp verdict) "review-plugin should return a verdict plist")
        (is (hngh.core.state-store:state-exists-p verdict-path)
            "L2 verdict should be persisted under plugins/<name>/review-verdict.lisp")
        (is (hngh.core.state-store:state-exists-p history-path)
            "History should be persisted under state/plugins/llm-threat/history.lisp")
        (is (listp history) "History file should contain a list")
        (is (plusp (length history)) "History should contain at least one review entry")
        (is (= 1 (length received))
            "review-plugin should emit one threat.review-verdict event")
        (is (member (getf verdict :confidence) '(:med :low))
            "AI-generated plugin reviews should downshift confidence from :high")
        (let ((payload (first received)))
          (is (equal "demo-plugin" (getf payload :plugin))
              "Emitted verdict event should include plugin name")
          (is (eq :L2 (getf payload :layer))
              "Emitted verdict event should identify L2 layer"))))))

(test ltd-run-periodic-reviews-processes-l3-flags
  (with-ltd (tmp)
    (let* ((now (get-universal-time))
           (since (- now 60))
           (plugin-a-path "state/plugin-observations/periodic-plugin-a/assessments.lisp")
           (plugin-b-path "state/plugin-observations/periodic-plugin-b/assessments.lisp"))
      ;; Seed L3 flags directly to validate periodic callback behavior itself,
      ;; independent from threat.flag event subscription flow.
      (setf hngh.core.threat-detection::*flags*
            (list (list :plugin "periodic-plugin-a"
                        :severity :medium
                        :evidence "periodic check A"
                        :timestamp since
                        :layer :L3)
                  (list :plugin "periodic-plugin-b"
                        :severity :high
                        :evidence "periodic check B"
                        :timestamp since
                        :layer :L3)))

      (is (not (hngh.core.state-store:state-exists-p plugin-a-path))
          "Before periodic callback, plugin A should have no persisted assessments")
      (is (not (hngh.core.state-store:state-exists-p plugin-b-path))
          "Before periodic callback, plugin B should have no persisted assessments")

      (hngh.plugins.llm-threat-detector::run-periodic-reviews)

      (is (hngh.core.state-store:state-exists-p plugin-a-path)
          "Periodic callback should persist assessment for flagged plugin A")
      (is (hngh.core.state-store:state-exists-p plugin-b-path)
          "Periodic callback should persist assessment for flagged plugin B")

      (let ((a-assessments (hngh.core.state-store:read-state plugin-a-path))
            (b-assessments (hngh.core.state-store:read-state plugin-b-path)))
        (is (listp a-assessments) "Plugin A persisted periodic assessments should be a list")
        (is (listp b-assessments) "Plugin B persisted periodic assessments should be a list")
        (is (plusp (length a-assessments)) "Plugin A should have at least one periodic assessment")
        (is (plusp (length b-assessments)) "Plugin B should have at least one periodic assessment")))))

(test ltd-review-behavior-persists-and-emits-assessment
  (with-ltd (tmp)
    (let ((received '()))
      (hngh.core.event-bus:subscribe
       "threat.assessment"
       (lambda (evt)
         (push (hngh.core.event-bus:event-payload evt) received)))

      (let* ((assessment (hngh.plugins.llm-threat-detector:review-behavior
                          "behavior-plugin"
                          :since (- (get-universal-time) 120)
                          :evidence '((:plugin "behavior-plugin"
                                       :severity :high
                                       :evidence "Undeclared subprocess"))))
             (assessment-path "state/plugin-observations/behavior-plugin/assessments.lisp")
             (persisted (hngh.core.state-store:read-state assessment-path)))
        (is (listp assessment) "review-behavior should return assessment plist")
        (is (hngh.core.state-store:state-exists-p assessment-path)
            "L4 assessments should be persisted under state/plugin-observations/<name>/")
        (is (listp persisted) "Persisted assessments should be a list")
        (is (= 1 (length persisted)) "First review should append one persisted assessment")
        (is (= 1 (length received))
            "review-behavior should emit one threat.assessment event")
        (let ((payload (first received)))
          (is (equal "behavior-plugin" (getf payload :plugin))
              "Assessment event should include plugin name")
          (is (member (getf payload :assessment) '(:benign :suspicious :malicious))
              "Assessment event should include normalized assessment"))))))

(test ltd-threat-flag-event-triggers-l4-review
  (with-ltd (tmp)
    (hngh.core.event-bus:publish
     "threat.flag"
     '(:plugin "flagged-plugin"
       :severity :medium
       :evidence "Behavioral drift detected"
       :timestamp 1700000000)
     :source 'threat-detection)

    ;; Event bus delivery is synchronous in-process; verify persisted artifact.
    (is (hngh.core.state-store:state-exists-p
         "state/plugin-observations/flagged-plugin/assessments.lisp")
        "Publishing threat.flag should trigger L4 review and persistence")))

(test ltd-explain-returns-latest-summary
  (with-ltd (tmp)
    (hngh.plugins.llm-threat-detector:review-plugin
     "(defun safe () :ok)"
     '(:name "explain-plugin" :trust-tier :user)
     '(:result :pass :failures nil)
     :context '(:source :test))
    (hngh.plugins.llm-threat-detector:review-behavior
     "explain-plugin"
     :since (- (get-universal-time) 60)
     :evidence '((:plugin "explain-plugin" :severity :low :evidence "normal activity")))
    (let ((result (hngh.plugins.llm-threat-detector:explain
                   "explain-plugin"
                   "Why was this plugin assessed this way?")))
      (is (listp result) "explain should return a plist")
      (is (equal "explain-plugin" (getf result :plugin))
          "explain response should include plugin name")
      (is (stringp (getf result :explanation))
          "explain response should include human-readable explanation")
      (is (not (null (getf result :latest-verdict)))
          "explain should surface latest L2 verdict when available"))))
