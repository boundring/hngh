;;;; core/ascii-art.lisp — Hngh Megastructural ASCII & Brutalist Layout Utilities
;;;;
;;;; SPDX-License-Identifier: AGPL-3.0-or-later
;;;; SPDX-FileCopyrightText: 2026 boundring

(defpackage :hngh.core.ascii-art
  (:use :cl)
  (:export #:print-megastructure-header
           #:print-brutalist-box
           #:megastructure-banner))

(in-package :hngh.core.ascii-art)

(defun megastructure-banner ()
  "Return the austere brutalist ASCII banner string."
  (format nil "~
  +----------------------------------------------------+~%~
  |  H N G H   [ M E G A S T R U C T U R E   C O R E ]  |~%~
  +----------------------------------------------------+~%"))

(defun print-megastructure-header (title &optional (stream *standard-output*))
  "Print an austere industrial header box for TITLE."
  (let ((line "════════════════════════════════════════════════════"))
    (format stream "~&╔~A╗~%" line)
    (format stream "║ HNGH CORE // ~A~%" (string-upcase title))
    (format stream "╚~A╝~%" line)))

(defun print-brutalist-box (lines &optional (stream *standard-output*))
  "Render LINES inside a reinforced concrete ASCII bounding box."
  (let* ((max-len (if lines (reduce #'max lines :key #'length) 10))
         (border (make-string max-len :initial-element #\─)))
    (format stream "┌─~A─┐~%" border)
    (dolist (l lines)
      (format stream "│ ~A~V@T │~%" l (- max-len (length l)) ""))
    (format stream "└─~A─┘~%" border)))
