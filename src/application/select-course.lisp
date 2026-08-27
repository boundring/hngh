(in-package #:hngh.application)

;;; Machine-steered course selection use case (P1 #1.5): the pure
;;; kernel pick of the next course among in-queue lanes. The candidate
;;; set comes from the ports' fetch-candidates callback, or directly
;;; from the caller via CANDIDATE-OVERRIDES. Every untrusted candidate
;;; is validated; malformed input fails closed as :invalid, an empty
;;; set refuses as no-courseable-lanes, and a choice is recorded
;;; through the optional record-selection port whose failure refuses.

(defun select-course (ports &optional candidate-overrides)
  (unless (course-selection-ports-p ports)
    (error "select course requires course selection ports"))
  (let* ((candidates
           (if candidate-overrides
               candidate-overrides
               (multiple-value-bind (status value)
                   (callback-value
                    (lambda ()
                      (funcall
                       (%course-selection-ports-fetch-candidates ports))))
               (when (not (eq status :returned))
                   (return-from select-course
                     (make-course-selection-result
                    :status :invalid :labels '("fetch-candidates-failed"))))
               value)))
         (valid (and (listp candidates)
                     (every #'hngh.domain:valid-course-candidate-p
                            candidates))))
    (cond
      ((not valid)
      (make-course-selection-result :status :invalid
                                     :labels '("malformed-candidates")))
      ((endp candidates)
      (make-course-selection-result :status :refused
                                     :labels '("no-courseable-lanes")))
      (t
       (multiple-value-bind (chosen reasons)
           (hngh.domain:select-course-candidate candidates)
         (unless chosen
           (return-from select-course
             (make-course-selection-result :status :refused
                                           :labels '("no-courseable-lanes"))))
         (let ((record-port (%course-selection-ports-record-selection ports)))
           (when record-port
             (multiple-value-bind (status value)
                 (callback-value
                  (lambda ()
                    (funcall record-port
                             (hngh.domain:course-candidate-identifier chosen)
                             reasons)))
               (declare (ignore value))
               (unless (eq status :returned)
                 (return-from select-course
                   (make-course-selection-result
                    :status :refused :labels '("callback-contract"))))))
           (make-course-selection-result
            :status :accepted
            :chosen-identifier (hngh.domain:course-candidate-identifier chosen)
            :reasons reasons)))))))