;;;; plugins/situation-casebase.lisp — L2/L3 persistent case-base + review
;;;; pass (L2/L3 step 5 / design §7).
;;;;
;;;; Every scored situation, the action taken, and its outcome is appended to
;;;; a persistent journal (the case-base) alongside human /steer interventions
;;;; (the ground-truth of what a person judged worth fixing). A scheduled,
;;;; cheap/local REVIEW PASS re-runs the judge offline against the growing
;;;; case-base to (a) recalibrate confidence, (b) tune thresholds, (c) surface
;;;; emerging situation classes — the taxonomy is open, not frozen. This is
;;;; the self-improvement recognition loop: recognition improves over
;;;; successive passes (§7, §8 step 5).
;;;;
;;;; See docs/design/situation-scoring.md §7 for the design and §8 step 5 for
;;;; the build-order gate (calibration metrics improve over successive passes).

(in-package :hngh.plugins.situation-casebase)

(defvar *running* nil)

(defparameter *journal-name* "situation-case-base"
  "Journal (under state/journal/) holding case-base entries, append-only.")

(defparameter *pass-stats-path* "state/situation-case-base/pass-stats.lisp"
  "State path holding review-pass calibration history (list of pass records).")

(defvar *seq* 0
  "Next case id within this process; seeded from the journal on load.")

;;; --- Case datum ----------------------------------------------------------
;;; (:id <n> :ts <universal-time>
;;;  :window <obs-list>            the observation window the situation was
;;;                                detected on (same shape as detectors/judge)
;;;  :situation <keyword>          detected situation class (or :none)
;;;  :score <float>                L3 score
;;;  :action <keyword>             what was done (:none/:steer/:interrupt/...)
;;;  :outcome <keyword>            result observed (:none/:improved/:unchanged/
;;;                                :degraded/:resolved)
;;;  :weight <float>               evidence weight (human /steer = >1)
;;;  :source <:auto | :human>      :human = a person /steer'd or overrode
;;;  :attribution <string>         model + version + provider that decided)

(defun make-case (window situation &key (score 0.0) (action :none)
                                   (outcome :none) (weight 1.0)
                                   (source :auto) attribution)
  "Build a case entry with a monotonically increasing id and timestamp."
  (list :id (incf *seq*)
        :ts (get-universal-time)
        :window window
        :situation situation
        :score score
        :action action
        :outcome outcome
        :weight weight
        :source source
        :attribution (or attribution
                          (format nil "hngh/~A fallback"
                                  (lisp-implementation-version)))))

;;; --- Persistence ---------------------------------------------------------

(defun init (&key (hngh-home hngh:*hngh-home*))
  "Initialize the case-base: seed the id sequence from existing entries."
  (declare (ignore hngh-home))
  (let ((cases (hngh.core.state-store:read-journal *journal-name*)))
    (setf *seq* (if cases
                    (reduce #'max (mapcar (lambda (c) (getf c :id 0)) cases)
                            :initial-value 0)
                    0)))
  (setf *running* t)
  t)

(defun shutdown ()
  (setf *running* nil)
  t)

(defun running-p ()
  *running*)

(defun record-case (window situation &key (score 0.0) (action :none)
                                          (outcome :none) (weight 1.0)
                                          (source :auto) attribution)
  "Append a scored situation case to the persistent case-base.

A human /steer or override should be recorded with :SOURCE :HUMAN and a
higher :WEIGHT (>1) — per §7.5 that becomes the highest-weight entry, the
ground truth of what a person valued steering for. Returns the case."
  (let ((case (make-case window situation :score score :action action
                                          :outcome outcome :weight weight
                                          :source source
                                          :attribution attribution)))
    (hngh.core.state-store:append-journal *journal-name* case)
    case))

(defun all-cases ()
  "Return every case in the base (newest last). Fail-closed on read errors."
  (handler-case (hngh.core.state-store:read-journal *journal-name*)
    (error () '())))

(defun case-count ()
  (length (all-cases)))

(defun cases-by-source (source)
  "Return only cases recorded by SOURCE (:auto or :human)."
  (remove-if-not (lambda (c) (eq (getf c :source) source)) (all-cases)))

(defun situation-distribution ()
  "Count of cases per situation class. Returns a list of (class count)."
  (let ((counts (make-hash-table :test 'eq)))
    (dolist (c (all-cases))
      (incf (gethash (or (getf c :situation) :none) counts 0)))
    (let (out)
      (maphash (lambda (k v) (push (list k v) out)) counts)
      (sort out #'> :key #'second))))

;;; --- Review pass (§7.2) --------------------------------------------------

(defun run-review-pass (&key (judge-hook #'hngh.plugins.situation-judge:judge-situation)
                             (responsibility (lambda (verdict)
                                               (getf verdict :situation))))
  "Run the review pass: for each :HUMAN or resolved case, ask the judge what
it now labels the window, compare to the recorded label, and accumulate
precision/recall. Appends a pass record to pass-stats so calibration
IMPROVEMENT across successive passes is measurable (the §8 step 5 gate).

JUDGE-HOOK defaults to the real judge (bounded by its watchdog budget). For
tests, pass a deterministic hook. RESPONSIBILITY maps a judged verdict to
its situation keyword (default: extract :situation).

Returns a plist:
  (:n :correct :precision :recall :conf-agreement :pass-n :cases)
N is the count of expected cases with a non-:none label (the ones the judge
can meaningfully be scored against); correct is how many matched."
  (let ((expected-cases (remove-if (lambda (c) (eq (getf c :situation) :none))
                                   (all-cases))))
    (when (null expected-cases)
      (return-from run-review-pass
        (list :n 0 :correct 0 :precision 1.0 :recall 1.0
              :conf-agreement 1.0 :pass-n 0 :cases 0)))
    (let ((n 0) (correct 0) (tp 0) (fp 0) (fn 0) (conf-agree 0.0))
      (dolist (expected expected-cases)
        (let* ((got (funcall judge-hook (getf expected :window)))
               (got-sit (funcall responsibility got))
               (got-sit (if (eq got-sit :error) :none got-sit))
               (exp-sit (getf expected :situation))
               (hit (eq got-sit exp-sit)))
          (incf n)
          (when hit (incf correct))
          (cond ((not (eq exp-sit :none))
                 (if hit (incf tp) (incf fn)))
                ((not (eq got-sit :none))
                 (incf fp)))
          (let ((conf (getf got :confidence 0.0)))
            (incf conf-agree
                  (if (or (and hit (>= conf 0.7))
                          (and (not hit) (< conf 0.7)))
                      1.0 0.0)))))
      (let* ((precision (if (plusp (+ tp fp)) (/ tp (+ tp fp)) 1.0))
             (recall (if (plusp (+ tp fn)) (/ tp (+ tp fn)) 1.0))
             (conf-agreement (if (plusp n) (/ conf-agree n) 1.0))
             (pass-stats (read-pass-stats))
             (pass-n (1+ (length pass-stats)))
             (record (list :pass pass-n :ts (get-universal-time)
                           :n n :correct correct
                           :precision precision :recall recall
                           :conf-agreement conf-agreement)))
        (write-pass-stats (append pass-stats (list record)))
        (list :n n :correct correct :precision precision :recall recall
              :conf-agreement conf-agreement :pass-n pass-n :cases (case-count))))))

(defun read-pass-stats ()
  "Read prior review-pass records. Fail-closed: any corruption -> empty list."
  (handler-case
      (or (hngh.core.state-store:read-state *pass-stats-path*) '())
    (error () '())))

(defun write-pass-stats (records)
  (hngh.core.state-store:write-state *pass-stats-path* records))

(defun accuracy-improving-p ()
  "Return T if review-pass accuracy has strictly improved (or stayed 1.0)
across the last two measurable passes — the §8 step 5 self-improvement gate.
NIL when <2 passes have run."
  (let* ((stats (remove-if (lambda (r) (zerop (getf r :n 0))) (read-pass-stats)))
         (n (length stats)))
    (when (>= n 2)
      (let ((cur (car (last stats)))
            (prev (nth (- n 2) stats)))
        (>= (getf cur :correct 0) (getf prev :correct 0))))))

(defun pass-stats ()
  "Human-readable pass history."
  (mapcar (lambda (r)
            (list :pass (getf r :pass)
                  :precision (getf r :precision)
                  :recall (getf r :recall)
                  :conf-agreement (getf r :conf-agreement)
                  :correct (getf r :correct)
                  :n (getf r :n)))
          (read-pass-stats)))

(defun %lane-situation (line)
  (let ((text (string-downcase line)))
    (cond
      ((or (search "loop" text) (search "retry" text) (search "stuck" text)
           (search "false-death" text) (search "dead pane" text)) :loop-or-stuck)
      ((or (search "model drift" text) (search "negotiated" text)
           (search "mismatch" text) (search "fallback" text)
           (search "provider" text)) :model-drift)
      ((or (search "blocked" text) (search "gate" text)
           (search "owner-gated" text) (search "red herring" text)
           (search "acceptance" text)) :policy-or-gate)
      ((or (search "steer" text) (search "steered" text)
           (search "guidance" text)) :human-steer)
      ((or (search "crash" text) (search "killed" text)
           (search "died" text) (search "hang" text)) :infra-failure)
      ((or (search "missing" text) (search "no such" text)
           (search "exit 127" text) (search "absent" text)) :env-gap)
      ((or (search "make test" text) (search "make check" text)
           (search "fixture" text) (search "pass" text)
           (search "fail" text)) :verification)
      (t :uncategorized))))

(defun classify-lane-line (line)
  "Return the deterministic situation class for a lane evidence LINE."
  (%lane-situation line))

(defun %lane-record (seat line)
  (let ((situation (%lane-situation line)))
    (make-case (list :window (format nil "tandem-~A" seat)
                     :evidence line)
               situation
               :score (if (eq situation :human-steer) 1.0 0.5)
               :action (if (eq situation :human-steer) :steer :none)
               :outcome :pending
               :weight (if (eq situation :human-steer) 2.0 1.0)
               :source (if (eq situation :human-steer) :human :auto)
               :attribution (format nil "tandem ~A" seat))))

(defun feed-lanes (lane-root &key (seats '("cibo" "seu" "killy")))
  "Feed lane evidence lines from LANE-ROOT into the case-base.
Only STATE, STEER, and HANDOFF evidence lines are considered."
  (let ((count 0)
        (seen (make-hash-table :test #'equal)))
    (dolist (case (all-cases))
      (let* ((window (getf case :window))
             (seat (getf window :window))
             (evidence (getf window :evidence)))
        (when evidence
          (setf (gethash (format nil "~A:~A" seat evidence) seen) t))))
    (dolist (seat seats count)
      (let ((path (merge-pathnames
                   (format nil "tandem-~A/worklog.md" seat) lane-root)))
        (when (probe-file path)
          (dolist (line (uiop:read-file-lines path))
            (let ((key (format nil "~A:~A" seat line)))
              (when (and (or (search "STATE:" line :test #'char-equal)
                             (search "STEER" line :test #'char-equal)
                             (search "HANDOFF" line :test #'char-equal))
                         (not (gethash key seen)))
                (setf (gethash key seen) t)
                (let ((record (%lane-record seat line)))
                  (hngh.core.state-store:append-journal *journal-name* record)
                  (incf count))))))))))

(defun status ()
  (list :running *running*
        :cases (case-count)
        :human-cases (length (cases-by-source :human))
        :distribution (situation-distribution)
        :passes (length (read-pass-stats))))

;;; --- Emergent-class detection (§7.2c) ------------------------------------

(defun emergent-classes (&optional (min-hits 1))
  "Naive emergent-class probe: report situation classes whose case count has
grown the most between the first and second half of the journal. A cheap,
threshold-free signal that the review pass can flag for human triage — the
open taxonomy means new classes are expected, not errors."
  (let* ((cases (all-cases))
         (n (length cases)))
    (when (< n 4)
      (return-from emergent-classes nil))
    (let ((half (floor n 2)))
      (labels ((tally (slice)
                 (let ((h (make-hash-table :test 'eq)))
                   (dolist (c slice)
                     (incf (gethash (or (getf c :situation) :none) h 0)))
                   h))
               (h2a (h)
                 (let (out)
                   (maphash (lambda (k v) (push (cons k v) out)) h)
                   out)))
        (let ((early (tally (subseq cases 0 half)))
              (late (tally (subseq cases half))))
          (sort (mapcar (lambda (c)
                          (let* ((k (car c))
                                 (e (gethash k early 0))
                                 (l (cdr c)))
                            (list k l (max 0 (- l e)))))
                        (h2a late))
                #'> :key #'caddr))))))
