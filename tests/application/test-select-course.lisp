(in-package :hngh.tests)

;;; select-course use case (P1 #1.5). The use case validates every
;;; candidate at the port boundary, refuses an empty candidate set, and
;;; records a choice only through the optional record-selection port;
;;; a failing record callback refuses. All checks run against fake
;;; ports, never real stores or processes.

(defun course-selection-with (ports &optional overrides)
  (hngh.application:select-course ports overrides))

(defun make-course-ports (&key fetch-candidates record-selection)
  (hngh.application:make-course-selection-ports
   :fetch-candidates (or fetch-candidates (lambda () nil))
   :record-selection record-selection))

(defun valid-candidate (identifier &key (mounted-p nil) last-increment-ts
                                       (priority-rank 0))
  (hngh.domain:make-course-candidate
   :identifier identifier
   :mounted-p mounted-p
   :last-increment-ts last-increment-ts
   :priority-rank priority-rank))

;;; accepted via overrides
(let ((result (course-selection-with
               (make-course-ports)
               (list (valid-candidate "lane-a" :mounted-p t
                                      :last-increment-ts "2026-08-01T00:00:00Z"
                                      :priority-rank 1)
                     (valid-candidate "lane-b" :priority-rank 0)))))
  (check (eql :accepted
              (hngh.application:course-selection-result-status result))
         "select-course accepts a valid candidate set")
  (check (string= "lane-a"
                  (hngh.application:course-selection-result-chosen-identifier
                   result))
         "select-course returns the policy-ranked choice")
  (check (plusp (length
                 (hngh.application:course-selection-result-reasons result)))
         "select-course justifies the choice"))
(check (eql :accepted
            (hngh.application:course-selection-result-status
             (course-selection-with
              (make-course-ports)
              (list (valid-candidate "lane-a")))))
       "select-course accepts a single valid candidate")

;;; refusal: empty candidate set
(let ((result (course-selection-with (make-course-ports))))
  (check (eql :refused
              (hngh.application:course-selection-result-status result))
         "select-course refuses an empty candidate set")
  (check (equal '("no-courseable-lanes")
                (hngh.application:course-selection-result-labels result))
         "select-course labels an empty refusal no-courseable-lanes"))

;;; invalid: malformed candidates
(let ((result (course-selection-with
               (make-course-ports)
               (list :not-a-candidate))))
  (check (eql :invalid
              (hngh.application:course-selection-result-status result))
         "select-course rejects a malformed candidate")
  (check (equal '("malformed-candidates")
                (hngh.application:course-selection-result-labels result))
         "select-course labels malformed input malformed-candidates"))
(let ((result (course-selection-with
               (make-course-ports)
               (list (valid-candidate "lane-a") 42))))
  (check (eql :invalid
              (hngh.application:course-selection-result-status result))
         "select-course rejects a mixed malformed candidate list"))

;;; fetch-candidates is used when no overrides are supplied
(let ((result (course-selection-with
               (make-course-ports
                :fetch-candidates
                (lambda () (list (valid-candidate "lane-fetched")))))))
  (check (eql :accepted
              (hngh.application:course-selection-result-status result))
         "select-course fetches candidates through the fetch port")
  (check (string= "lane-fetched"
                  (hngh.application:course-selection-result-chosen-identifier
                   result))
         "select-course chooses the fetched candidate"))

;;; fetch port failure refuses
(let ((result (course-selection-with
               (make-course-ports
                :fetch-candidates (lambda () (error "fetch failed"))))))
  (check (eql :invalid
              (hngh.application:course-selection-result-status result))
         "select-course fails closed when fetching candidates errors")
  (check (equal '("fetch-candidates-failed")
                (hngh.application:course-selection-result-labels result))
         "select-course labels fetch failure fetch-candidates-failed"))

;;; recording: a working record-selection port is called with the choice
(let ((recorded nil))
  (let ((result (course-selection-with
                 (make-course-ports
                  :record-selection
                  (lambda (identifier reasons)
                    (setf recorded (cons identifier reasons))))
                 (list (valid-candidate "lane-record")))))
    (check (eql :accepted
                (hngh.application:course-selection-result-status result))
           "select-course accepts when recording succeeds")
    (check (and recorded
                (string= "lane-record" (car recorded))
                (stringp (cdr recorded)))
           "select-course records the chosen identifier and reasons")))

;;; recording failure refuses
(let ((result (course-selection-with
               (make-course-ports
                :record-selection (lambda (identifier reasons)
                                    (declare (ignore identifier reasons))
                                    (error "recording failed")))
               (list (valid-candidate "lane-record")))))
  (check (eql :refused
              (hngh.application:course-selection-result-status result))
         "select-course refuses when recording fails")
  (check (equal '("callback-contract")
                (hngh.application:course-selection-result-labels result))
         "select-course labels recording failure callback-contract"))

;;; ports constructor rejects invalid callbacks
(let ((constructor
        (lambda (&rest arguments)
          (apply (application-function "MAKE-COURSE-SELECTION-PORTS")
                 arguments))))
  (check (signals-error-p
          (lambda () (funcall constructor :fetch-candidates :invalid)))
         "course ports reject a non-function fetch callback")
  (check (signals-error-p
          (lambda () (funcall constructor
                              :fetch-candidates (lambda () nil)
                              :record-selection :invalid)))
         "course ports reject a non-function record callback"))