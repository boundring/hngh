;;;; fixture: core must not call plugin symbols (rule 2)
(defpackage :hngh.core.x
  (:use :cl)
  (:export #:go))
(in-package :hngh.core.x)
(hngh.plugins.ai-orchestrator:submit-task "hello")
