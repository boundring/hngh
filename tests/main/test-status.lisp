(in-package #:hngh.tests)

;;; S3 CLI status verb (interface-plan slice S3 / command-center awareness
;;; contract). dispatch-status reads the spine from three OPTIONAL sources --
;;; system.json (cpu/mem/disk + headroom), data.json digest block (digest
;;; status + breadcrumbs), readout.json (queue + roster) -- resolving each via
;;; the *status-*-source* parameters (tests bind these to hermetic fixtures,
;;; which is why the parameter wins over the environment). Every source fails
;;; closed to an `unavailable` pane when missing or malformed, never a
;;; fabricated number; the single verdict fronted first is unavailable unless
;;; BOTH the digest status AND the headroom booleans are present. A source
;;; carrying a `generated_at`/`g` UTC-Z stamp more than 10 minutes older than
;;; the injected clock renders ` (stale Nm)`.

(defun status-fixture-root ()
  (let* ((base (uiop:with-temporary-file (:pathname p :keep t)
                 (delete-file p)
                 p))
         (root (uiop:ensure-directory-pathname base)))
    (ensure-directories-exist root)
    root))

(defun write-status-fixture (root name json)
  (let ((path (merge-pathnames name root)))
    (with-open-file (stream path :direction :output :if-exists :supersede)
      (write-string json stream))
    path))

(defun status-result (fixtures &optional (clock #'fixed-clock))
  "Dispatch `status` with the *status-*-source* parameters bound to FIXTURES
(a plist of :system/:data/:readout => path; omit a key to leave that source
falling back to the environment). Returns (values output exit)."
  (let ((hngh.main::*status-system-source* (getf fixtures :system))
        (hngh.main::*status-data-source* (getf fixtures :data))
        (hngh.main::*status-readout-source* (getf fixtures :readout))
        (*error-output* (make-string-output-stream)))
    (multiple-value-list
     (hngh.main:dispatch-command '("status") :clock-now clock))))

(defun healthy-status-fixtures (root)
  (list
   :system (write-status-fixture root "system.json"
             "{\"cpu\":12.3,\"mem\":45,\"disk\":61.0,\
             \"headroom\":{\"cpu\":true,\"mem\":true,\"disk\":true},\
             \"generated_at\":\"2026-08-24T00:00:00Z\"}")
   :data (write-status-fixture root "data.json"
          "{\"digest\":{\"status\":\"ok\"},\"mounted\":\"slice-a\",\
            \"running\":\"run-1\",\"generated_at\":\"2026-08-24T00:00:00Z\"}")
   :readout (write-status-fixture root "readout.json"
             "{\"queue\":[{\"id\":\"task-1\"},{\"id\":\"task-2\"}],\
               \"roster\":{\"working\":2,\"idle\":1,\"parked\":0},\
               \"generated_at\":\"2026-08-24T00:00:00Z\"}")))

;;; Happy path: the single verdict first, then the bound facts, nothing stale.
(let* ((root (status-fixture-root))
       (result (status-result (healthy-status-fixtures root))))
  (check (= 0 (exit-code result)) "status healthy exits 0")
  (check (has-output "verdict: all-clear" result) "status verdict is all-clear")
  (check (not (has-output "(stale" result))
         "status fresh sources carry no stale marker")
  (check (has-output "system: 12.3%/45%/61.0%" result)
         "status renders system percentages")
  (check (has-output "active: mounted=slice-a running=run-1" result)
         "status renders active work")
  (check (has-output "next: task-1" result) "status renders the next queue id")
  (check (has-output "roster: working=2 idle=1 parked=0" result)
         "status renders roster counts by state")
  (check (has-output (format nil "~A~%~A~%~A~%~A~%~A"
                             "verdict: all-clear"
                             "system: 12.3%/45%/61.0%"
                             "active: mounted=slice-a running=run-1"
                             "next: task-1"
                             "roster: working=2 idle=1 parked=0")
                     result)
         "status renders the exact multi-line block")
  (uiop:delete-directory-tree root :validate t))

;;; Percent values may be numeric strings; missing ones fail the pane.
(let* ((root (status-fixture-root))
       (data (getf (healthy-status-fixtures root) :data))
       (readout (getf (healthy-status-fixtures root) :readout))
       (system (write-status-fixture root "system.json"
                "{\"cpu\":\"12.5\",\"mem\":\"45.0\",\"disk\":61,\
                 \"headroom\":{\"cpu\":true,\"mem\":true,\"disk\":true},\
                 \"generated_at\":\"2026-08-24T00:00:00Z\"}"))
       (result (status-result (list :system system :data data :readout readout))))
  (check (has-output "system: 12.5%/45.0%/61%" result)
         "status accepts numeric-string percentages")
  (uiop:delete-directory-tree root :validate t))

;;; attention: a false headroom boolean raises attention naming the pane.
(let* ((root (status-fixture-root))
       (fixtures (healthy-status-fixtures root)))
  (setf (getf fixtures :system)
        (write-status-fixture root "system.json"
          "{\"cpu\":12.3,\"mem\":95,\"disk\":61.0,\
            \"headroom\":{\"cpu\":true,\"mem\":false,\"disk\":true},\
            \"generated_at\":\"2026-08-24T00:00:00Z\"}"))
  (let ((result (status-result fixtures)))
    (check (has-output "verdict: attention (mem)" result)
           "a false headroom boolean raises attention naming the pane"))
  (uiop:delete-directory-tree root :validate t))

;; attention: a non-ok digest status flags the digest.
(let* ((root (status-fixture-root))
       (fixtures (healthy-status-fixtures root)))
  (setf (getf fixtures :data)
        (write-status-fixture root "data.json"
          "{\"digest\":{\"status\":\"attention\"},\"mounted\":\"slice-a\",\
            \"running\":\"run-1\",\"generated_at\":\"2026-08-24T00:00:00Z\"}"))
  (let ((result (status-result fixtures)))
    (check (has-output "verdict: attention (digest)" result)
           "a non-ok digest status raises attention naming the digest"))
  (uiop:delete-directory-tree root :validate t))

;; Each missing source -> its pane unavailable AND the verdict unavailable.
(let* ((root (status-fixture-root))
       (missing (merge-pathnames "absent.json" root))
       (result (status-result (list :system missing :data missing
                                    :readout missing))))
  (check (= 0 (exit-code result)) "status with all sources absent exits 0")
  (check (has-output "verdict: unavailable" result)
         "missing data+system leaves the verdict unavailable")
  (check (has-output "system: unavailable" result)
         "missing system source renders the system pane unavailable")
  (check (has-output "active: unavailable" result)
         "missing data source renders the active pane unavailable")
  (check (has-output "next: unavailable" result)
         "missing readout renders the next pane unavailable")
  (check (has-output "roster: unavailable" result)
         "missing readout renders the roster pane unavailable")
  (uiop:delete-directory-tree root :validate t))

;; Malformed JSON fails closed: no crash, the pane unavailability and the
;; verdict unavailability.
(let* ((root (status-fixture-root))
       (fixtures (healthy-status-fixtures root)))
  (setf (getf fixtures :data)
        (write-status-fixture root "data.json" "{not json at all"))
  (let ((result (status-result fixtures)))
    (check (= 0 (exit-code result)) "status survives malformed source JSON")
    (check (has-output "verdict: unavailable" result)
           "malformed digest source leaves the verdict unavailable")
    (check (has-output "active: unavailable" result)
           "malformed data leaves the active pane unavailable")
    (check (has-output "next: task-1" result)
           "other panes stay available when one source is malformed"))
  (uiop:delete-directory-tree root :validate t))

;; Stale stamps are labelled, never re-derived: 15 minutes at the fixed clock.
(let* ((root (status-fixture-root))
       (system (write-status-fixture root "system.json"
                "{\"cpu\":12.3,\"mem\":45,\"disk\":61.0,\
                  \"headroom\":{\"cpu\":true,\"mem\":true,\"disk\":true},\
                  \"generated_at\":\"2026-08-23T23:45:00Z\"}"))
       (data (write-status-fixture root "data.json"
              "{\"digest\":{\"status\":\"ok\"},\"mounted\":\"slice-a\",\
                \"running\":\"run-1\",\"generated_at\":\"2026-08-23T23:45:00Z\"}"))
       (readout (write-status-fixture root "readout.json"
                 "{\"queue\":[{\"id\":\"task-1\"}],\
                   \"roster\":{\"working\":1},\
                   \"generated_at\":\"2026-08-23T23:45:00Z\"}"))
       (result (status-result (list :system system :data data :readout readout))))
  (check (has-output "verdict: all-clear (stale 15m)" result)
         "a stale verdict carries the max source stale label")
  (check (has-output "system: 12.3%/45%/61.0% (stale 15m)" result)
         "a stale system pane is labelled")
  (check (has-output "active: mounted=slice-a running=run-1 (stale 15m)" result)
         "a stale active pane is labelled")
  (check (has-output "next: task-1 (stale 15m)" result)
         "a stale next pane is labelled")
  (check (has-output "roster: working=1 (stale 15m)" result)
         "a stale roster pane is labelled")
  (uiop:delete-directory-tree root :validate t))

;; An unstamped source is not timed: no stale marker at all.
(let* ((root (status-fixture-root))
       (system (write-status-fixture root "system.json"
                "{\"cpu\":12.3,\"mem\":45,\"disk\":61.0,\
                  \"headroom\":{\"cpu\":true,\"mem\":true,\"disk\":true}}"))
       (data (write-status-fixture root "data.json"
              "{\"digest\":{\"status\":\"ok\"},\"mounted\":\"slice-a\",\
                \"running\":\"run-1\"}"))
       (result (status-result (list :system system :data data))))
  (check (has-output "verdict: all-clear" result)
         "an unstamped source keeps the verdict all-clear")
  (check (has-output "system: 12.3%/45%/61.0%" result)
         "an unstamped system pane has no stale suffix")
  (check (not (has-output "(stale" result))
         "no source is timed when none carries a stamp")
  (uiop:delete-directory-tree root :validate t))

;;; Combined attention: a bad digest AND a false headroom boolean both name
;;; their parts, digest first.
(let* ((root (status-fixture-root))
       (fixtures (healthy-status-fixtures root)))
  (setf (getf fixtures :data)
        (write-status-fixture root "data.json"
          "{\"digest\":{\"status\":\"attention\"},\"mounted\":\"slice-a\",\
            \"generated_at\":\"2026-08-24T00:00:00Z\"}"))
  (setf (getf fixtures :system)
        (write-status-fixture root "system.json"
          "{\"cpu\":12.3,\"mem\":95,\"disk\":61.0,\
            \"headroom\":{\"cpu\":true,\"mem\":false,\"disk\":true},\
            \"generated_at\":\"2026-08-24T00:00:00Z\"}"))
  (let ((result (status-result fixtures)))
    (check (has-output "verdict: attention (digest, mem)" result)
           "combined digest + headroom attention lists both parts"))
  (uiop:delete-directory-tree root :validate t))

;;; Queue items may be raw strings; every next-pane queue id is the first
;;; ordered one, and an empty roster renders unavailable (never a whim zero).
(let* ((root (status-fixture-root))
       (system (getf (healthy-status-fixtures root) :system))
       (data (getf (healthy-status-fixtures root) :data))
       (readout (write-status-fixture root "readout.json"
                 "{\"queue\":[\"card-x\",\"card-y\"],\"roster\":{},\
                   \"generated_at\":\"2026-08-24T00:00:00Z\"}"))
       (result (status-result (list :system system :data data :readout readout))))
  (check (has-output "next: card-x" result)
         "next renders the first raw-string queue id")
  (check (has-output "roster: unavailable" result)
         "an empty roster renders unavailable, never a fabricated zero")
  (uiop:delete-directory-tree root :validate t))

;;; The `g` stamp alias is honoured exactly like `generated_at`.
(let* ((root (status-fixture-root))
       (system (write-status-fixture root "system.json"
                "{\"cpu\":12.3,\"mem\":45,\"disk\":61.0,\
                  \"headroom\":{\"cpu\":true,\"mem\":true,\"disk\":true},\
                  \"g\":\"2026-08-24T00:00:00Z\"}"))
       (data (getf (healthy-status-fixtures root) :data))
       (result (status-result (list :system system :data data))))
  (check (not (has-output "(stale" result))
         "status honours the g stamp alias and stays fresh")
  (uiop:delete-directory-tree root :validate t))

;;; Freshness boundary: exactly 10 minutes is still fresh; only over 10 is
;;; stale (older than the bound is labelled, per the awareness contract).
(let* ((root (status-fixture-root))
       (system (write-status-fixture root "system.json"
                "{\"cpu\":12.3,\"mem\":45,\"disk\":61.0,\
                  \"headroom\":{\"cpu\":true,\"mem\":true,\"disk\":true},\
                  \"generated_at\":\"2026-08-23T23:50:00Z\"}"))
       (data (getf (healthy-status-fixtures root) :data))
       (result (status-result (list :system system :data data))))
  (check (not (has-output "(stale" result))
         "status treats a 10-minute-old source as fresh")
  (uiop:delete-directory-tree root :validate t))

;;; Malformed invocation: any status operand or option is rejected (exit 2).
(let ((operand (dispatch '("status" "extra"))))
  (check (= 2 (exit-code operand)) "a status operand is malformed"))
(let ((option (dispatch '("status" "x=y"))))
  (check (= 2 (exit-code option)) "a status option is malformed"))
(check (has-output "status takes no" (dispatch '("status" "extra")))
       "status names its no-operand rule on rejection")