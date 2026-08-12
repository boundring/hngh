(defun project-root ()
  (merge-pathnames "../" (make-pathname :name nil :type nil :defaults *load-truename*)))

(defun project-file (relative)
  (merge-pathnames relative (project-root)))

(load (project-file "src/packages.lisp"))
(load (project-file "src/kernel/profile.lisp"))

(in-package :hngh.tests)

(defun check (condition description)
  (unless condition
    (error "check failed: ~A" description)))

(defun signals-error-p (thunk)
  (handler-case
      (progn (funcall thunk) nil)
    (error () t)))

(check (equal '(:work :observe)
              (hngh:validate-profile '(:work :observe)))
       "profile preserves explicit mode order")
(check (signals-error-p (lambda () (hngh:validate-profile '(:work :unknown))))
       "unknown mode fails closed")
(check (signals-error-p (lambda () (hngh:validate-profile '(:work :work))))
       "duplicate mode fails closed")
(check (signals-error-p (lambda () (hngh:validate-profile :work)))
       "non-list profile fails closed")

(format t "4 checks passed.~%")
