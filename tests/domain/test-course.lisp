(in-package :hngh.tests)

;;; Course-selection domain policy (P1 #1.5). The comparator and
;;; selector are pure written policy: mounted cards first, then
;;; ascending last-increment (never-incremented most due), then queue
;;; priority as tiebreaker. These checks pin that ordering and the
;;; fail-closed validation of candidate shapes.

(defun course-candidate (identifier &key (mounted-p nil) last-increment-ts
                                       (priority-rank 0))
  (hngh.domain:make-course-candidate
   :identifier identifier
   :mounted-p mounted-p
   :last-increment-ts last-increment-ts
   :priority-rank priority-rank))

;;; constructor guards
(check (signals-error-p
        (lambda () (hngh.domain:make-course-candidate
                    :identifier "" :mounted-p nil :priority-rank 0)))
       "empty candidate identifier fails closed")
(check (signals-error-p
        (lambda () (hngh.domain:make-course-candidate
                    :identifier "lane" :mounted-p nil
                    :last-increment-ts "not-a-timestamp" :priority-rank 0)))
       "malformed last-increment timestamp fails closed")
(check (signals-error-p
        (lambda () (hngh.domain:make-course-candidate
                    :identifier "lane" :mounted-p t :priority-rank -1)))
       "negative priority rank fails closed")
(check (not (hngh.domain:valid-course-candidate-p :not-a-candidate))
       "non-struct candidate is not valid")
(check (not (hngh.domain:valid-course-candidate-p
             (hngh.domain::%make-course-candidate
              "lane" "yes" nil 0)))
       "string mounted flag is not a valid candidate")
(check (hngh.domain:valid-course-candidate-p
        (course-candidate "lane" :mounted-p t
                          :last-increment-ts "2026-08-01T00:00:00Z"
                          :priority-rank 3))
       "well-formed candidate is valid")

;;; comparator
(check (hngh.domain:course-candidate-<
        (course-candidate "mounted" :mounted-p t)
        (course-candidate "unmounted"))
       "mounted candidate ranks before unmounted")
(check (not (hngh.domain:course-candidate-<
             (course-candidate "unmounted")
             (course-candidate "mounted" :mounted-p t)))
       "unmounted candidate never ranks before mounted")
(check (hngh.domain:course-candidate-<
        (course-candidate "never" :mounted-p t)
        (course-candidate "newer" :mounted-p t
                          :last-increment-ts "2026-08-01T00:00:00Z"))
       "never-incremented mounted candidate ranks before incremented")
(check (hngh.domain:course-candidate-<
        (course-candidate "older" :mounted-p t
                          :last-increment-ts "2026-08-01T00:00:00Z")
        (course-candidate "newer" :mounted-p t
                          :last-increment-ts "2026-08-02T00:00:00Z"))
       "older increment ranks before newer")
(check (not (hngh.domain:course-candidate-<
             (course-candidate "newer" :mounted-p t
                               :last-increment-ts "2026-08-02T00:00:00Z")
             (course-candidate "older" :mounted-p t
                               :last-increment-ts "2026-08-01T00:00:00Z")))
       "newer increment never ranks before older")
(check (hngh.domain:course-candidate-<
        (course-candidate "a" :mounted-p t :priority-rank 1)
        (course-candidate "b" :mounted-p t :priority-rank 2))
       "equal keys tiebreak by ascending priority rank")
(check (not (hngh.domain:course-candidate-<
             (course-candidate "b" :mounted-p t :priority-rank 2)
             (course-candidate "a" :mounted-p t :priority-rank 1)))
       "higher priority rank never ranks before lower")

;;; selector
(multiple-value-bind (chosen reasons)
    (hngh.domain:select-course-candidate
     (list (course-candidate "newer" :mounted-p t
                             :last-increment-ts "2026-08-02T00:00:00Z"
                             :priority-rank 9)
           (course-candidate "unmounted-old"
                             :last-increment-ts "2026-08-01T00:00:00Z")
           (course-candidate "never" :priority-rank 0)))
  (check (and chosen
              (string= "newer"
                       (hngh.domain:course-candidate-identifier chosen)))
         "selector prefers any mounted candidate over unmounted")
  (check (equal "card mounted, last increment 2026-08-02T00:00:00Z" reasons)
         "selectors justify a mounted choice"))

(multiple-value-bind (chosen reasons)
    (hngh.domain:select-course-candidate
     (list (course-candidate "older"
                             :last-increment-ts "2026-08-01T00:00:00Z")
           (course-candidate "never" :priority-rank 0)))
  (check (and chosen
              (string= "never"
                       (hngh.domain:course-candidate-identifier chosen)))
         "among unmounted lanes the never-incremented ranks first")
  (check (equal "never incremented" reasons)
         "selectors justify a never-incremented choice"))

(multiple-value-bind (chosen reasons)
    (hngh.domain:select-course-candidate
     (list (course-candidate "mounted-new" :mounted-p t
                             :last-increment-ts "2026-08-02T00:00:00Z")
           (course-candidate "mounted-old" :mounted-p t
                             :last-increment-ts "2026-08-01T00:00:00Z")))
  (check (and chosen
              (string= "mounted-old"
                       (hngh.domain:course-candidate-identifier chosen)))
         "selector prefers the older mounted lane")
  (check (equal "card mounted, last increment 2026-08-01T00:00:00Z" reasons)
         "selectors justify a mounted old choice"))

(multiple-value-bind (chosen reasons)
    (hngh.domain:select-course-candidate nil)
  (check (null chosen) "empty candidate list selects nothing")
  (check (equal "empty-candidates" reasons)
         "empty candidate list is justified as empty-candidates"))