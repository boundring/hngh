(in-package :hngh.tests)

(defparameter +inward-package-prefixes+
  '("HNGH.DOMAIN" "HNGH.APPLICATION" "HNGH.PRESENTATION"))

(defparameter +forbidden-dependency-prefixes+
  '("HNGH.ADAPTERS." "HNGH.PRESENTATION"))

(defparameter +reference-lexicon-entry-keys+
  '(:surface :original :reference :provenance))

(defparameter +canonical-control-keys+
  '(:state :receipt :cli :use-case :outcome))

(defun package-designator-name (designator)
  (string-upcase (symbol-name designator)))

(defun prefix-member-p (name prefixes)
  (some (lambda (prefix)
          (and (<= (length prefix) (length name))
               (string= prefix name :end2 (length prefix))))
        prefixes))

(defun inward-package-p (name)
  (prefix-member-p name +inward-package-prefixes+))

(defun forbidden-dependency-p (name)
  (prefix-member-p name +forbidden-dependency-prefixes+))

(defun dependency-fixture-allowed-p (form)
  (and (eq (first form) 'defpackage)
       (let* ((package (package-designator-name (second form)))
              (use-clause (find :use (cddr form) :key #'first)))
         (or (not (inward-package-p package))
             (notany (lambda (dependency)
                       (forbidden-dependency-p
                        (package-designator-name dependency)))
                     (rest use-clause))))))

(defun flat-plist-p (value)
  (and (listp value)
       (evenp (length value))
       (loop for key in value by #'cddr
             always (keywordp key))))

(defun reference-entry-p (entry)
  (and (flat-plist-p entry)
       (equal (loop for key in entry by #'cddr collect key)
              +reference-lexicon-entry-keys+)
       (keywordp (getf entry :surface))
       (stringp (getf entry :original))
       (stringp (getf entry :reference))
       (stringp (getf entry :provenance))))

(defun canonical-control-key-present-p (value)
  (cond
    ((atom value) nil)
    ((member (first value) +canonical-control-keys+) t)
    (t (or (canonical-control-key-present-p (first value))
           (canonical-control-key-present-p (rest value))))))

(defun reference-lexicon-safe-p (form)
  (and (flat-plist-p form)
       (equal (loop for key in form by #'cddr collect key) '(:render))
       (not (canonical-control-key-present-p form))
       (listp (getf form :render))
       (every #'reference-entry-p (getf form :render))))
