;;;; fixture: production must not depend on tests (rule 4)
(defpackage :hngh.plugins.importer
  (:use :cl :hngh.core :hngh.tests)
  (:export #:go))
