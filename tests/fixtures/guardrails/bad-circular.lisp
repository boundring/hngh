;;;; fixture: circular plugin call (rule 3)
(defpackage :hngh.plugins.circ-a
  (:use :cl :hngh.core)
  (:export #:a))
(defpackage :hngh.plugins.circ-b
  (:use :cl :hngh.core)
  (:export #:b))
(in-package :hngh.plugins.circ-a)
(hngh.plugins.circ-b:b)
(in-package :hngh.plugins.circ-b)
(hngh.plugins.circ-a:a)
