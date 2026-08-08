;;;; plugins/situation-detectors.lisp — L2 situation recognition (Tier-0)
;;;;
;;;; The observation model + procedural situation detectors that feed the
;;;; L3 scorer (situation-scoring.lisp) and, through it, the A3 ACP actuator.
;;;; Tier-0 means: deterministic, model-free, cheap, always-on, fail-closed.
;;;; Detectors never interrupt on their own; they emit a situation datum on
;;;; the event bus and let the scorer decide the action.
;;;;
;;;; Observation model: an observation is a plist
;;;;   (:ts <universal-time> :agent <string> :kind <kw> :tool <string>
;;;;    :args <string> :fingerprint <string> :error-class <string-or-nil>
;;;;    :tokens <int> :ok <bool-or-nil> :artifacts <list> :seconds <int>)
;;;; with :kind one of :tool-call :tool-result :thinking :wait :message
;;;; :cost-exceeded. :artifacts is the agent's reported progress snapshot
;;;; (file/test list); :seconds the waited duration on :wait observations.
;;;; A window is a vector/list of observations in chronological order.
;;;; A situation datum is a plist
;;;;   (:category <kw> :confidence <0..1> :stage <1..4> :evidence <string>
;;;;    :agent <string> :count <int>)
;;;;
;;;; SPDX-License-Identifier: AGPL-3.0-or-later
;;;; SPDX-FileCopyrightText: 2026 boundring <boundring@gmail.com>

(in-package :hngh.plugins.situation-detectors)

(eval-when (:compile-toplevel :load-toplevel :execute)
  (require :sb-md5))

(defvar *running* nil)
(defvar *window* nil
  "Rolling observation window (NEWEST LAST). Append with OBSERVE; cleared by RESET-WINDOW.")

(defparameter *window-size* 64
  "Max observations kept in the rolling window.")

(defparameter *ok-fingerprint-cache*
  (make-hash-table :test 'equal)
  "Cache of (hash) -> T for identical-call-loop detection.")

;;; --- Fingerprinting --------------------------------------------------------

(defun fingerprint (tool args)
  "Return a stable hex fingerprint of TOOL+ARGS (md5; not cryptographic, just
equality detection). Polling tools are NOT exempted here — exemption is the
caller's job via *POLL-TOOLS*."
  (let ((bytes (sb-md5:md5sum-string (format nil "~A\x00~A" tool args))))
    (with-output-to-string (s)
      (map nil (lambda (b) (format s "~2,'0X" b)) bytes))))

(defparameter *poll-tools*
  '("poll" "process" "watch" "status" "list" "wait" "sleep")
  "Tool-name substrings that are polling/status-only; fingerprint-loop
detection ignores calls whose tool matches one of these (they are expected
to repeat).")

(defun poll-tool-p (tool)
  "Return T when TOOL is a polling/status tool (expected to repeat)."
  (some (lambda (p) (search p tool :test #'char-equal)) *poll-tools*))

(defun observe (obs &key (window *window*))
  "Append OBS (a plist) to WINDOW, trimming to *WINDOW-SIZE*. Returns the
window. OBS gets a :fingerprint slot if it is a tool-call without one."
  (let* ((fingerprinted
           (if (and (eq (getf obs :kind) :tool-call)
                    (null (getf obs :fingerprint)))
               (list* :fingerprint (fingerprint (getf obs :tool) (getf obs :args))
                      obs)
               obs))
         (new (append window (list fingerprinted))))
    (setf window (subseq new (max 0 (- (length new) *window-size*))))))

(defun reset-window (&optional (window *window*))
  "Clear WINDOW. Returns the empty window."
  (setf window nil))

;;; --- Situation datums ------------------------------------------------------

(defun make-situation (category &key confidence stage evidence agent count)
  "Construct a situation datum plist. FAIL CLOSED: confidence defaults to a
high-deterministic 0.9 (Tier-0 is the firmest evidence class)."
  (list :category category
        :confidence (or confidence 0.9)
        :stage (or stage 1)
        :evidence (or evidence "")
        :agent (or agent "unknown")
        :count (or count 1)))

(defun publish-situation (situation &key (source 'situation-detectors))
  "Publish a SITUATION datum on the event bus (threat.flag-style). No-op when
the bus is absent (tests, standalone)."
  (when hngh.core.event-bus:*event-bus*
    (hngh.core.event-bus:publish
     "situation.detected"
     (list* :plugin source :timestamp (get-universal-time) situation)
     :source source))
  situation)

;;; --- Detectors (each: window -> situation-datum or NIL) -------------------

(defun detect-identical-call-loop (window &key (min-repeats 3) (limit 10))
  "Identical tool+args fingerprint repeated >= MIN-REPEATS in the recent
LIMIT calls (polling tools exempt). Returns a situation datum or NIL."
  (let ((calls (remove-if (lambda (o)
                            (not (and (eq (getf o :kind) :tool-call)
                                      (not (poll-tool-p (getf o :tool))))))
                          window))
        (counts (make-hash-table :test 'equal)))
    (dolist (call (last calls limit))
      (let ((h (getf call :fingerprint)))
        (when h
          (incf (gethash h counts 0)))))
    (let ((best-count 0)
          (best-hash nil))
      (maphash (lambda (h n)
                 (when (> n best-count)
                   (setf best-count n best-hash h)))
               counts)
      (when (>= best-count min-repeats)
        (make-situation :identical-call-loop
                        :confidence 0.95
                        :stage 1
                        :evidence (format nil "identical tool+args ~Dx (fingerprint ~A)"
                                          best-count best-hash)
                        :count best-count)))))

(defun detect-retry-without-progress (window &key (min-cycles 2))
  ">= MIN-CYCLES consecutive failure cycles where the agent re-issued the
same tool with cosmetically changed args (different fingerprint) and the
error class stayed the same — retrying without a new approach. Returns a
situation datum or NIL."
  (let ((cycles 0)
        (last-err nil)
        (last-fail-fp nil)
        (recent-call-fp nil))
    (dolist (o window)
      (case (getf o :kind)
        (:tool-call
         (setf recent-call-fp (or (getf o :fingerprint)
                                  (fingerprint (getf o :tool) (getf o :args)))))
        (:tool-result
         (let ((err (getf o :error-class)))
           (cond
             ((and err last-err
                   (string= err last-err)
                   recent-call-fp last-fail-fp
                   (not (string= recent-call-fp last-fail-fp)))
              (incf cycles)
              (setf last-fail-fp recent-call-fp))
             (t
              (setf last-err err last-fail-fp recent-call-fp cycles 0)))
           (setf recent-call-fp nil)))))
    (when (>= cycles min-cycles)
      (make-situation :retry-without-progress
                      :confidence 0.9
                      :stage 2
                      :evidence (format nil "~D retry cycles, error class ~A unchanged"
                                        cycles last-err)
                      :count cycles))))

(defun detect-zero-progress (window &key (min-steps 2))
  ">= MIN-STEPS consecutive tool-results with no NEW element in the artifact
list (progress snapshot unchanged). Returns a situation datum or NIL."
  (let ((progresses '())
        (unchanged 0))
    (dolist (o window)
      (when (getf o :artifacts)
        (let ((a (getf o :artifacts)))
          (if (and progresses (equal a (car progresses)))
              (incf unchanged)
              (setf unchanged 0))
          (push a progresses))))
    (when (>= unchanged min-steps)
      (make-situation :zero-progress
                      :confidence 0.85
                      :stage 2
                      :evidence (format nil "artifact list unchanged ~D steps" unchanged)
                      :count unchanged))))

(defun detect-token-sink (window &key (token-budget 16000) (min-tokens 4000))
  "A :thinking run (no intervening tool-call/result) that crosses
TOKEN-BUDGET tokens with at least MIN-TOKENS in the run. Returns a situation
datum or NIL."
  (let ((run-tokens 0)
        (run-length 0)
        (best-tokens 0)
        (best-length 0))
    (labels ((flush ()
               (when (> run-tokens best-tokens)
                 (setf best-tokens run-tokens best-length run-length))
               (setf run-tokens 0 run-length 0)))
      (dolist (o window)
        (if (eq (getf o :kind) :thinking)
            (progn
              (incf run-tokens (or (getf o :tokens) 0))
              (incf run-length))
            (flush)))
      (flush))
    (when (and (> best-tokens min-tokens)
               (> best-tokens token-budget))
      (make-situation :token-sink
                      :confidence 0.8
                      :stage 1
                      :evidence (format nil "~D tokens in ~D consecutive thinking steps, no env interaction"
                                        best-tokens best-length)
                      :count best-length))))

(defun detect-failing-verification (window &key (min-reruns 2))
  "Same verification command (test/build) re-run >= MIN-RERUNS with the same
fingerprint and a non-ok result, with no relevant diff (no artifact change
between runs). Returns a situation datum or NIL."
  (let ((reruns 0)
        (verif-tools '("make" "test" "pytest" "sbcl" "build")))
    (dolist (o window)
      (when (and (eq (getf o :kind) :tool-result)
                 (some (lambda (v) (search v (getf o :tool) :test #'char-equal))
                       verif-tools)
                 (null (getf o :ok)))
        (incf reruns)))
    (when (>= reruns min-reruns)
      (make-situation :failing-verification
                      :confidence 0.9
                      :stage 2
                      :evidence (format nil "verification re-ran ~D times without passing"
                                        reruns)
                      :count reruns))))

(defun detect-excessive-waits (window &key (min-waits 3) (max-wait-seconds 120))
  ">= MIN-WAITS :wait observations, or any single wait exceeding
MAX-WAIT-SECONDS. Returns a situation datum or NIL."
  (let* ((waits (remove-if-not (lambda (o) (eq (getf o :kind) :wait)) window))
         (over (remove-if-not (lambda (o) (> (or (getf o :seconds) 0) max-wait-seconds))
                              waits)))
    (when (or (>= (length waits) min-waits) over)
      (make-situation :excessive-waits
                      :confidence 0.9
                      :stage 1
                      :evidence (format nil "~D waits, ~D over ~D s"
                                        (length waits) (length over) max-wait-seconds)
                      :count (length waits)))))

(defun detect-cost-exceedance (window &key (budget nil))
  "Cost/token budget crossed. BUDGET may be (:spent <n> :limit <n>) or the
quota-spreader gate; when the caller passes NIL a window observation with
:kind :cost-exceeded triggers. Returns a situation datum or NIL. FAIL CLOSED:
no budget info -> NIL (never guesses)."
  (let ((spent (getf budget :spent))
        (limit (getf budget :limit))
        (hit (some (lambda (o) (eq (getf o :kind) :cost-exceeded)) window)))
    (when (or hit (and spent limit (> spent limit)))
      (make-situation :cost-exceedance
                      :confidence 0.95
                      :stage 1
                      :evidence (format nil "budget crossed (spent ~A limit ~A)"
                                        spent limit)
                      :count 1))))

(defun detect-chatter-loop (window &key (min-pings 3))
  ">= MIN-PINGS consecutive :message observations with no artifact-producing
tool-result between them. Returns a situation datum or NIL."
  (let ((run 0)
        (best-run 0))
    (labels ((flush ()
               (when (> run best-run) (setf best-run run))
               (setf run 0)))
      (dolist (o window)
        (case (getf o :kind)
          (:message (incf run))
          (t (when (eq (getf o :kind) :tool-result) (flush)))))
      (flush))
    (when (>= best-run min-pings)
      (make-situation :chatter-loop
                      :confidence 0.8
                      :stage 1
                      :evidence (format nil "~D message pings without artifact progress"
                                        best-run)
                      :count best-run))))

;;; --- Combined entry point --------------------------------------------------

(defun detect-situations (window)
  "Run all Tier-0 detectors on WINDOW. Returns a list of situation datums
(possibly empty). Never signals; each detector is wrapped so one bad detector
cannot take down the observation stream."
  (let ((detectors (list #'detect-identical-call-loop
                         #'detect-retry-without-progress
                         #'detect-zero-progress
                         #'detect-token-sink
                         #'detect-failing-verification
                         #'detect-excessive-waits
                         #'detect-cost-exceedance
                         #'detect-chatter-loop)))
    (remove nil
            (mapcar (lambda (d)
                      (handler-case (funcall d window)
                        (error () nil)))
                    detectors))))

(defun analyze (obs &key (window *window*) (publish t))
  "OBSERVE OBS into WINDOW, detect situations, optionally publish each on the
event bus. Returns (values situations window)."
  (let ((w (observe obs :window window)))
    (let ((situations (detect-situations w)))
      (when publish
        (mapc #'publish-situation situations))
      (values situations w))))

;;; --- Standard plugin surface ----------------------------------------------

(defun init (&key (hngh-home hngh:*hngh-home*))
  (declare (ignore hngh-home))
  (setf *running* t)
  (hngh.core:log-info "Situation detectors initialized (Tier-0, ~D detectors)"
                      (length '(detect-identical-call-loop
                                detect-retry-without-progress
                                detect-zero-progress
                                detect-token-sink
                                detect-failing-verification
                                detect-excessive-waits
                                detect-cost-exceedance
                                detect-chatter-loop)))
  t)

(defun shutdown ()
  (setf *running* nil)
  (hngh.core:log-info "Situation detectors shut down"))

(defun running-p () *running*)

(defun status ()
  (list :running *running*
        :window-size (length *window*)
        :poll-tools *poll-tools*))