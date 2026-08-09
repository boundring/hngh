;;;; fixture: plugins must not :use each other (rule 1)
(defpackage :hngh.plugins.alpha
  (:use :cl :hngh.core)
  (:export #:work))
(defpackage :hngh.plugins.beta
  (:use :cl :hngh.core :hngh.plugins.alpha)
  (:export #:more))
