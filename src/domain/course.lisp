(in-package #:hngh.domain)

;;; Pure course-selection policy (P1 #1.5). A course candidate is an
;;; in-queue lane with the three facts the machine-steered selector
;;; ranks by: whether a .slice card is mounted, the UTC timestamp of
;;; its last increment (nil when never incremented), and its queue
;;; priority index. Ranking is fixed written policy: mounted cards
;;; first, then ascending last-increment (never-incremented ranks most
;;; due), then queue priority as the tiebreaker. The domain owns the
;;; policy; ports and presentation only carry its result.

(defstruct (course-candidate
            (:constructor %make-course-candidate
                (identifier mounted-p last-increment-ts priority-rank))
            (:conc-name %course-candidate-))
  (identifier nil :read-only t)
  (mounted-p nil :read-only t)
  (last-increment-ts nil :read-only t)
  (priority-rank nil :read-only t))

(defun make-course-candidate (&key identifier mounted-p last-increment-ts
                                   priority-rank)
  (unless (and (stringp identifier) (plusp (length identifier)))
    (error "course candidate identifier must be a nonempty string"))
  (unless (typep mounted-p 'boolean)
    (error "course candidate mounted-p must be a boolean"))
  (unless (or (null last-increment-ts)
              (utc-string-p last-increment-ts))
    (error "course candidate last-increment-ts must be nil or a UTC string"))
  (ensure-nonnegative-integer priority-rank "course candidate priority rank")
  (%make-course-candidate (copy-seq identifier) mounted-p
                          (and last-increment-ts (copy-seq last-increment-ts))
                          priority-rank))

(defun course-candidate-identifier (candidate)
  (copy-seq (%course-candidate-identifier candidate)))

(defun course-candidate-mounted-p (candidate)
  (%course-candidate-mounted-p candidate))

(defun course-candidate-last-increment-ts (candidate)
  (let ((ts (%course-candidate-last-increment-ts candidate)))
    (and ts (copy-seq ts))))

(defun course-candidate-priority-rank (candidate)
  (%course-candidate-priority-rank candidate))

(defun valid-course-candidate-p (value)
  "True when VALUE is a well-formed course candidate: a
course-candidate with a nonempty identifier, a boolean mounted flag, a
nil-or-UTC-string last increment, and a nonnegative priority rank.
Non-erroring, for validating untrusted candidates at the port boundary."
  (and (course-candidate-p value)
       (let ((identifier (%course-candidate-identifier value))
             (last-increment-ts (%course-candidate-last-increment-ts value))
             (priority-rank (%course-candidate-priority-rank value)))
         (and (stringp identifier) (plusp (length identifier))
              (typep (%course-candidate-mounted-p value) 'boolean)
              (or (null last-increment-ts)
                  (utc-string-p last-increment-ts))
              (integerp priority-rank) (not (minusp priority-rank))))))

(defun candidate-less-ts-p (a b)
  "True when A's last increment is due before B's: never-incremented
(nil) before any timestamp, then ascending timestamp order. Pure string
comparison is safe because timestamps are fixed-width UTC."
  (let ((ta (course-candidate-last-increment-ts a))
        (tb (course-candidate-last-increment-ts b)))
    (cond ((and (null ta) (null tb)) nil)
          ((null ta) t)
          ((null tb) nil)
          (t (string< ta tb)))))

(defun course-candidate-< (a b)
  "Fixed course-ranking policy between two candidates: mounted first,
then ascending last-increment (never-incremented ranks most due), then
ascending queue priority. Identical candidates compare NIL both ways."
  (cond
    ((and (course-candidate-mounted-p a)
          (not (course-candidate-mounted-p b)))
     t)
    ((and (not (course-candidate-mounted-p a))
          (course-candidate-mounted-p b))
     nil)
    ((candidate-less-ts-p a b) t)
    ((candidate-less-ts-p b a) nil)
    (t (< (course-candidate-priority-rank a)
          (course-candidate-priority-rank b)))))

(defun candidate-reasons (candidate)
  "Justification string for a chosen candidate, in the stable
`card mounted`/`last increment` vocabulary the cadence reports use."
  (let ((ts (course-candidate-last-increment-ts candidate)))
    (cond
      ((course-candidate-mounted-p candidate)
       (if ts (format nil "card mounted, last increment ~A" ts)
           "card mounted, never incremented"))
      (ts (format nil "last increment ~A" ts))
      (t "never incremented"))))

(defun select-course-candidate (candidates)
  "Pure machine-steered selector: the earliest candidate by
COURSE-CANDIDATE-<. Returns (values chosen reasons-string), or
(values nil \"empty-candidates\") when CANDIDATES is empty."
  (if (endp candidates)
      (values nil "empty-candidates")
      (let ((chosen (reduce (lambda (best candidate)
                              (if (course-candidate-< candidate best)
                                  candidate best))
                            (rest candidates)
                            :initial-value (first candidates))))
        (values chosen (candidate-reasons chosen)))))