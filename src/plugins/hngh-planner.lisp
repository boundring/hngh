;;;; src/plugins/hngh-planner.lisp — C6 Recursive Planner
;;;;
;;;; Reads the project roadmap, extracts gaps (unstarted / in-progress /
;;;; blocked milestones and waves), and produces work-session-shaped tasks
;;;; for the task queue. Wave 0 implements the tolerant, section-aware
;;;; roadmap parser; later waves add decomposition, weighting, and emission.
;;;;
;;;; SPDX-License-Identifier: AGPL-3.0-or-later
;;;; SPDX-FileCopyrightText: 2026 boundring <boundring@gmail.com>

(in-package :hngh.plugins.hngh-planner)

(defvar *running* nil
  "Whether the planner plugin is active.")

(defun init ()
  "Initialize the planner plugin."
  (setf *running* t)
  (hngh.core:log-info "Planner initialized")
  t)

(defun shutdown ()
  "Shut down the planner plugin."
  (setf *running* nil)
  t)

(defun running-p ()
  "Return T when the planner plugin is active."
  *running*)

(defun status ()
  "Return a one-line status summary. Wave 0: parser only, no loop yet."
  (if *running*
      "planner: parser ready (decomposition/loop pending)"
      "planner: inactive"))

;;; --- Roadmap parsing (Wave 0) ---------------------------------------------

(defparameter *line-split-chars*
  (list #\Newline #\Return #\Linefeed #\Page))

(defun split-lines (text)
  "Split TEXT into lines, trimming leading/trailing whitespace per line.
Handles bare CR, bare LF, CRLF, and lone CR. Returns a list of strings."
  (loop with lines = '()
        with current = (make-string-output-stream)
        for char across text
        do (cond
             ((member char *line-split-chars*)
              (push (string-trim '(#\Space #\Tab) (get-output-stream-string current))
                    lines))
             (t (write-char char current)))
        finally (let ((rest (string-trim '(#\Space #\Tab)
                                         (get-output-stream-string current))))
                  (when (plusp (length rest))
                    (push rest lines)))
        finally (return (nreverse lines))))

(defun trimmed (string)
  "Return STRING with surrounding whitespace and markdown emphasis removed."
  (let ((s (string-trim '(#\Space #\Tab #\Return) string)))
    (string-trim '(#\*) s)))

(defun planner-status (cell)
  "Classify a status cell into :not-started / :in-progress / :done /
:blocked / :unknown. Tolerant of markdown emphasis and parenthetical notes."
  (let ((s (string-downcase (trimmed cell))))
    (cond
      ((search "not started" s) :not-started)
      ((search "blocked" s) :blocked)
      ((or (search "in progress" s) (search "in-progress" s)) :in-progress)
      ((or (search "done" s) (search "complete" s)) :done)
      (t :unknown))))

(defun %split-table-row (line)
  "Split a raw markdown table LINE into trimmed cell strings, dropping the
leading and trailing empty cells from the framing pipes."
  (let* ((stripped (string-trim '(#\Space #\| #\Tab) line))
         (cells (cl-ppcre:split "\\s*\\|\\s*" stripped)))
    cells))

(defun %header-status-index (cells)
  "Given a header row's cell strings, return the index of the 'Status'
column, or NIL if absent."
  (position-if (lambda (c) (search "status" (string-downcase (trimmed c))))
               cells))

(defun %header-wave-index (cells)
  "Given a header row's cell strings, return the index of the 'Wave' column,
or NIL if absent."
  (position-if (lambda (c) (search "wave" (string-downcase (trimmed c))))
               cells))

(defun %parse-wave-row-by-columns (cells wave-idx status-idx)
  "Parse a data row (CELLS) using header-derived column indexes WAVE-IDX and
STATUS-IDX into (:wave <n> :capabilities <str> :status <kw>), or NIL when
the row is not a valid wave row. Capabilities is the widest non-wave,
non-status cell."
  (when (and wave-idx status-idx
             (>= (length cells) (1+ (max wave-idx status-idx))))
    (let* ((wave-cell (nth wave-idx cells))
           (status-cell (nth status-idx cells))
           (wave (ignore-errors (parse-integer (trimmed wave-cell)))))
      (when wave
        (let ((capa-cells
                (loop for i from 0 below (length cells)
                      when (and (not (= i wave-idx))
                                (not (= i status-idx)))
                        collect (nth i cells))))
          (list :wave wave
                :capabilities (trimmed
                               (reduce #'(lambda (a b)
                                           (if (> (length a) (length b)) a b))
                                       capa-cells
                                       :initial-value ""))
                :status (planner-status status-cell)))))))

(defun %parse-milestone-heading (line)
  "Parse a '## Milestone N — Title (status)' heading into
(:milestone <id> :title <str> :status <kw>) or NIL. The id is normalized to
the roadmap's canonical M# form (e.g. '9' -> 'M9'; 'M9' stays 'M9')."
  (cl-ppcre:register-groups-bind (id title status)
      ("^##\\s+Milestone\\s+([A-Za-z0-9]+)\\s*[—‑-]\\s*(.*?)\\s*\\((.*)\\)\\s*$"
       line)
    (list :milestone (%canonical-milestone-id id)
          :title title
          :status (planner-status status))))

(defun %canonical-milestone-id (id)
  "Return ID in canonical M# form: '9' -> 'M9', 'M9' -> 'M9'."
  (if (and (plusp (length id))
           (char-equal (char id 0) #\M)
           (every #'digit-char-p (subseq id 1)))
      id
      (format nil "M~A" id)))

(defun %collect-waves (lines)
  "Collect wave rows from LINES until the next milestone heading. Uses
header-relative column detection so inserted/reordered columns do not break
parsing. Returns a list of wave plists, plus the number of LINES consumed."
  (let ((waves '())
        (consumed 0)
        (wave-idx nil)
        (status-idx nil)
        (saw-header nil))
    (dolist (line lines)
      (if (cl-ppcre:scan "^##\\s+Milestone" line)
          (return (values (nreverse waves) consumed))
          (progn
            (incf consumed)
            ;; A table row with a leading pipe -> a header or data row.
            (let ((tr (string-trim '(#\Space) line)))
              (when (and (plusp (length tr))
                         (char= (char tr 0) #\|))
                (let ((cells (%split-table-row line)))
                  (cond
                    ;; Header row (has both Wave and Status columns).
                    ((and (not saw-header)
                          (%header-wave-index cells)
                          (%header-status-index cells))
                     (setf saw-header t
                           wave-idx (%header-wave-index cells)
                           status-idx (%header-status-index cells)))
                    ;; Data row, once we know the headers.
                    (saw-header
                     (let ((row (%parse-wave-row-by-columns
                                 cells wave-idx status-idx)))
                       (when row (push row waves)))))))))))
    (values (nreverse waves) consumed)))

(defun %milestone-block (heading-line lines)
  "Given a milestone heading LINE and the REMAINING LINES, return a milestone
plist with parsed :waves and the index past this milestone's section."
  (let ((heading (%parse-milestone-heading heading-line)))
    (multiple-value-bind (waves consumed) (%collect-waves lines)
      (values (append heading (list :waves waves)) consumed))))

(defun planner-gap-list (roadmap-text)
  "Parse ROADMAP-TEXT and return a list of milestone plists, one per
milestone with a non-complete status (i.e. an actionable gap). Each plist:
  (:milestone <id> :title <str> :status <kw> :blocked <bool> :waves <list>)
where each wave is (:wave <n> :capabilities <str> :status <kw>).
Complete milestones and non-table sections are ignored."
  (let ((lines (split-lines roadmap-text))
        (milestones '())
        (i 0))
    (loop while (< i (length lines))
          for line = (nth i lines)
          do (if (cl-ppcre:scan "^##\\s+Milestone" line)
                 (multiple-value-bind (milestone next)
                     (%milestone-block line (subseq lines (1+ i)))
                   (when milestone
                     (push milestone milestones))
                   (setf i (+ i 1 next)))
                 (incf i)))
    (let ((gaps (nreverse milestones)))
      (remove-if
       (lambda (m) (eql (getf m :status) :done))
       (mapcar (lambda (m)
                 (let* ((waves (getf m :waves))
                        (blocked (or (eql (getf m :status) :blocked)
                                     (some (lambda (w) (eql (getf w :status) :blocked))
                                           waves))))
                   (append m (list :blocked blocked))))
               gaps)))))

;;; --- Weighting + decomposition + emission (Wave 1) -------------------------
;;;
;;; Scope note (2026-08-07): squads already run tasks end-to-end today via
;;; task-driver-tick -> delegate -> complete-task. These functions are the
;;; *planner-loop* half — turning roadmap gaps into scored, structured queue
;;; tasks. They are kept (not gold-plated away): weighting is pure rule-based
;;; scoring, decomposition is bounded with an optional hook and a
;;; deterministic fallback, and emission stamps :planner source. They only
;;; run when the closed loop calls them; building them now eases that, per
;;; the "anything that eases later work ships earliest" principle. The LLM
;;; decomposition hook is optional — the planner never depends on a live
;;; model.

(defparameter *default-confidence* 0.5
  "Confidence default until the C8/C9 benchmark dataset fills the
planner-feedback-source. See docs/design/planner-design-roadmap.md §4 —
confidence reads from a module, never an inlined constant.")

(defparameter *milestone-priority-base*
  '(("M0" . 10) ("M1" . 30) ("M2" . 40) ("M3" . 60) ("M9" . 70))
  "Base priority (higher = more important) per milestone id. Unlisted
milestones get a modest default. Values are a rubric, not an authority; the
PM/user can override.")

(defparameter *planner-source-tag* :planner
  "Source tag stamped on planner-emitted queue tasks, so re-scans can
distinguish planner-generated tasks from human-written ones and never
re-queue a gap that already has an open planner task.")

(defparameter *max-tasks-per-cycle* 5
  "Hard cap on decomposition output per planner cycle — prevents the loop
from fanning one gap into an unbounded task burst (budget/overflow guard).")

(defparameter *decompose-notify* nil
  "Optional hook: a function of (gap context) that returns task-spec list.
Set by the harness to perform the actual LLM decomposition; defaults to a
coarse one-task fallback so the planner never depends on a live model.")

(defun milestone-priority (milestone)
  "Return the base priority for MILESTONE id, or a safe default when unlisted."
  (or (cdr (assoc milestone *milestone-priority-base* :test #'string=)) 20))

(defun planner-weight (gap)
  "Compute a scoring plist for a gap:
    (:priority <n> :confidence <n> :cost <n> :score <n>)
Priority from milestone ordering + blocked bump; confidence from the
feedback-source module (default 0.5 placeholder); cost is a task-unit
estimate from the gap's wave count (coarse proxy until prior actuals exist).
Never an LLM call — pure rule-based scoring."
  (let* ((milestone (getf gap :milestone))
         (base (milestone-priority milestone))
         (blocked (getf gap :blocked))
         (priority (if blocked (+ base 5) base))
         (confidence *default-confidence*)
         (wave-count (max 1 (length (getf gap :waves))))
         (cost (* wave-count 3))
         (score (* priority confidence
                   (if (zerop cost) 0.1 (/ 1.0 cost)))))
    (list :priority priority
          :confidence confidence
          :cost cost
          :score score)))

(defun planner-decompose (gap &key (context nil) (max-tasks *max-tasks-per-cycle*))
  "Decompose GAP into a list of task-spec plists, capped at MAX-TASKS.
Returns (:task <str> :type <kw> :role <kw> :verification <plist> :source <tag>).
Uses the *DECOMPOSE-NOTIFY* hook when set (bounded by MAX-TASKS); otherwise
a coarse fallback emits a single :research task from the gap's title. The
LLM is bounded here; the loop is bounded by the cap, never by good behavior."
  (let ((raw (if *decompose-notify*
                 (funcall *decompose-notify* gap context)
                 (list
                  (list :task (format nil "Implement ~A: ~A"
                                      (getf gap :milestone)
                                      (getf gap :title))
                        :type :work
                        :role :worker)))))
    (subseq raw 0 (min (length raw) (max 1 max-tasks)))))

(defun planner-emit-task (spec)
  "Submit a single task SPEC plist to the queue via ai-orchestrator:submit-task
with v3 structured fields and a :planner source tag. Returns the new task id."
  (hngh.plugins.ai-orchestrator:submit-task
   (getf spec :task)
   :type (getf spec :type :work)
   :assigned-role (getf spec :role :worker)
   :verification (or (getf spec :verification)
                     (list :command nil :status :pending :observed-at nil))
   :depends-on (getf spec :depends-on)
   :source *planner-source-tag*))

(defun planner-emit-gaps (gaps)
  "Decompose + submit each GAP in GAPS to the queue as a planner task.
Returns the list of new task ids."
  (mapcar (lambda (gap) (planner-emit-task (car (planner-decompose gap))))
          gaps))

;;; --- Closed loop orchestration (Wave 2) -----------------------------------
;;;
;;; planner-cycle ties the roadmap parser + emission into a safe, resumable
;;; loop. It is deliberately conservative:
;;;   - dedups against open planner-sourced tasks (never re-queues a gap)
;;;   - gate: refrains when dispatch is paused
;;;   - cost gate: checks the quota envelope before emitting (fail closed)
;;;   - dry-run mode: scans/plans and reports, submits nothing

(defparameter *planner-open-statuses*
  '(:queued :claimed :running :blocked :proposed)
  "Queue statuses that count as 'the gap is already in flight' for dedup.")

(defun %roadmap-path (cwd)
  "Return the absolute roadmap path under CWD, or NIL."
  (let ((p (merge-pathnames "docs/project/roadmap.md" cwd)))
    (and (probe-file p) p)))

(defun %read-roadmap-text (cwd)
  "Read CWD/docs/project/roadmap.md as a string, or NIL when absent."
  (let ((p (%roadmap-path cwd)))
    (and p (uiop:read-file-string p))))

(defun %open-planner-milestones ()
  "Return the set of milestone ids (as strings) that already have an open
planner-sourced task in the queue. Used for dedup."
  (let ((opened (make-hash-table :test 'equal))
        (source-tag (symbol-name *planner-source-tag*)))
    (dolist (entry (hngh.plugins.ai-orchestrator:list-tasks))
      (let ((src (getf entry :source))
            (status (getf entry :status))
            (task (getf entry :task)))
        (when (and src
                   (string= (symbol-name src) source-tag)
                   (member status *planner-open-statuses*)
                   (stringp task))
          ;; Planner tasks are formatted "Implement M<N>: <title>". Extract
          ;; the milestone id robustly (regex, tolerant of title cls).
          (multiple-value-bind (match? regs)
              (cl-ppcre:scan-to-strings "\\b(M[0-9]+)\\b" task)
            (declare (ignore match?))
            (when (and regs (plusp (length regs)))
              (setf (gethash (aref regs 0) opened) t))))))
    opened))

(defun %gap-already-open-p (gap opened)
  "Return T when GAP's milestone is already represented by an open
planner-sourced task (dedup)."
  (gethash (string (getf gap :milestone)) opened))

(defun %quota-gate-open-p (&optional (route 'kimi-sub))
  "Return T when the quota envelope allows emitting more work now. Fail
closed: unknown envelope or over-even-rate refuses. Uses the general pool
(one-off/emission, not an authority reservation unless caller names one)."
  (hngh.plugins.quota-spreader:quota-general-ok-p route :used 0
                                                  :elapsed-seconds 0))

(defun planner-cycle (cwd &key (dry-run nil) (emit t)
                             (max-emissions *max-tasks-per-cycle*))
  "Run one planner cycle against CWD's roadmap. Returns a summary plist:
  (:gaps <n> :new <n> :skipped-dupe <n> :dry-run <bool> :emitted <ids>)
Behavior:
  - scans gaps from the roadmap (never mutates the roadmap)
  - dedups against open planner tasks
  - if dispatch is paused or the quota gate is closed, scans but emits
    nothing (fail closed)
  - DRY-RUN plans and reports but submits nothing; EMIT NIL also submits
    nothing (scan-only)."
  (let* ((roadmap-text (%read-roadmap-text cwd)))
    (unless roadmap-text
      (return-from planner-cycle
        (list :gaps 0 :new 0 :skipped-dupe 0 :dry-run dry-run
              :emitted '() :error :no-roadmap)))
    (let* ((all-gaps (planner-gap-list roadmap-text))
           (opened (%open-planner-milestones))
           (new-gaps (remove-if (lambda (g) (%gap-already-open-p g opened))
                                all-gaps))
           (paused (hngh.plugins.ai-orchestrator:dispatch-paused-p))
           (gate-open (%quota-gate-open-p))
           (should-emit (and emit (not dry-run) (not paused) gate-open))
           (to-emit (subseq new-gaps 0 (min (length new-gaps)
                                            (max 1 max-emissions))))
           (ids (if should-emit (planner-emit-gaps to-emit) '())))
      (list :gaps (length all-gaps)
            :new (length new-gaps)
            :skipped-dupe (- (length all-gaps) (length new-gaps))
            :dry-run (or dry-run (not emit))
            :paused paused
            :gate-open gate-open
            :emitted ids))))
