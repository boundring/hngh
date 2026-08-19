(in-package #:hngh.domain)

(defstruct (receipt
            (:constructor %make-receipt (kind facts))
            (:conc-name %receipt-))
  (kind nil :read-only t)
  (facts nil :read-only t))

(defun make-receipt (&key kind facts)
  (%make-receipt
   (ensure-keyword kind "receipt kind")
   (ensure-label-list facts "receipt facts")))

(defun receipt-kind (receipt)
  (%receipt-kind receipt))

(defun receipt-facts (receipt)
  (mapcar #'copy-seq (%receipt-facts receipt)))

(defstruct (score-record
            (:constructor %make-score-record
                (delivery cost headroom turnaround lesson-reuse))
            (:conc-name %score-record-))
  (delivery nil :read-only t)
  (cost nil :read-only t)
  (headroom nil :read-only t)
  (turnaround nil :read-only t)
  (lesson-reuse nil :read-only t))

(defun make-score-record (&key delivery cost headroom turnaround lesson-reuse)
  (%make-score-record
   (ensure-nonnegative-integer delivery "delivery score")
   (ensure-nonnegative-integer cost "cost score")
   (ensure-nonnegative-integer headroom "headroom score")
   (ensure-nonnegative-integer turnaround "turnaround score")
   (ensure-nonnegative-integer lesson-reuse "lesson reuse score")))

(defstruct (afterlife-record
            (:constructor %make-afterlife-record
                (terminal-cause observed-facts salvage-labels
                 rejected-hypotheses lesson-candidate))
            (:conc-name %afterlife-record-))
  (terminal-cause nil :read-only t)
  (observed-facts nil :read-only t)
  (salvage-labels nil :read-only t)
  (rejected-hypotheses nil :read-only t)
  (lesson-candidate nil :read-only t))

(defun make-afterlife-record (&key terminal-cause observed-facts salvage-labels
                                rejected-hypotheses lesson-candidate)
  (%make-afterlife-record
   (ensure-keyword terminal-cause "terminal cause")
   (ensure-label-list observed-facts "observed facts")
   (ensure-label-list salvage-labels "salvage labels")
   (ensure-label-list rejected-hypotheses "rejected hypotheses")
   (ensure-nonempty-string lesson-candidate "lesson candidate")))
