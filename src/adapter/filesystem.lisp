(in-package #:hngh.adapters.filesystem)

;;; Rung 8: operator-facing filesystem transport store. The adapter
;;; persists record lines (flat plists) as one line per record under an
;;; operator-supplied root directory. It is pure Common Lisp by design:
;;; no domain imports, no configuration files, no environment reads.
;;; The store refuses anything that would escape the root or that is
;;; malformed, and reports transport faults when the root is missing,
;;; unreadable, or unwritable.

(defstruct (filesystem-store (:constructor %make-filesystem-store
                                            (root-directory record-file)))
  (root-directory nil :read-only t)
  (record-file nil :read-only t))

(define-condition transport-fault (error)
  ()
  (:documentation "The filesystem store could not reach its root or record file."))

(define-condition store-refusal (error)
  ()
  (:documentation "A record line was malformed or unsafe (path escape, absolute identifier)."))

(defun directory-pathname (root)
  "Return ROOT as a directory pathname (trailing slash, no name/type)."
  (let ((path (pathname root)))
    (if (or (pathname-name path) (pathname-type path))
        (pathname (concatenate 'string (namestring path) "/"))
        path)))

(defun make-filesystem-store (&key root)
  "Create a store rooted at ROOT. Signals TRANSPORT-FAULT when the root
is missing or is not a directory."
  (let* ((directory (directory-pathname root))
         (probe (probe-file directory)))
    (unless (and probe (null (pathname-name probe)))
      (error 'transport-fault))
    (%make-filesystem-store probe (merge-pathnames "record.lisp" probe))))

(defun line-plist-p (line)
  "LINE is a plist of keyword keys with even length."
  (and (listp line)
       (evenp (length line))
       (loop for (key value) on line by #'cddr
             always (keywordp key))))

(defun safe-identifier-p (identifier)
  "IDENTIFIER must be a non-empty relative path segment: no leading
slash, no embedded slash, not '.' or '..'."
  (and (stringp identifier)
       (plusp (length identifier))
       (char/= (char identifier 0) #\/)
       (not (string= identifier "."))
       (not (string= identifier ".."))
       (not (find #\/ identifier))))

(defun optional-string-p (value)
  (or (null value) (stringp value)))

(defun no-newlines-p (line)
  "No string value in LINE may carry a line break: the store keeps one
record per physical line."
  (loop for value in line
        never (and (stringp value)
                   (find-if (lambda (char) (member char '(#\Newline #\Return)))
                            value))))

(defun valid-line-p (line)
  (and (line-plist-p line)
       (safe-identifier-p (getf line :identifier))
       (keywordp (getf line :kind))
       (optional-string-p (getf line :transport))
       (optional-string-p (getf line :scope))
       (no-newlines-p line)))

(defun line-key (line)
  "Identity of a record: identifier, kind, and transport. Records
differing only in scope or payload collide."
  (list (getf line :identifier) (getf line :kind) (getf line :transport)))

(defun read-line-form (stream)
  "Read one record from STREAM; a read error is a transport fault.
Returns NIL at end of file."
  (let ((eof (gensym "EOF")))
    (handler-case
        (let ((form (read stream nil eof)))
          (unless (eq form eof) form))
      (error () (error 'transport-fault)))))

(defun read-lines (file)
  (with-open-file (stream file :direction :input)
    (loop for form = (read-line-form stream)
          while form
          collect form)))

(defun existing-keys (file)
  (if (probe-file file)
      (mapcar #'line-key (read-lines file))
      nil))

(defun append-line (file line)
  (handler-case
      (with-open-file (stream file :direction :output
                              :if-exists :append
                              :if-does-not-exist :create)
        (let ((*print-pretty* nil))
          (write line :stream stream))
        (terpri stream))
    (error () (error 'transport-fault))))

(defun store-record-run (store line)
  "Append LINE to STORE unless an identical record exists. Returns
:RECORDED or :CONFLICT. Refuses malformed or path-escaping lines and
signals TRANSPORT-FAULT when the root vanished or is unwritable."
  (unless (valid-line-p line)
    (error 'store-refusal))
  (unless (probe-file (filesystem-store-root-directory store))
    (error 'transport-fault))
  (let ((key (line-key line))
        (file (filesystem-store-record-file store)))
    (when (member key (existing-keys file) :test #'equal)
      (return-from store-record-run :conflict))
    (append-line file line)
    :recorded))

(defun store-entries (store)
  "Replay every stored record line in append order. A corrupt line is a
transport fault."
  (let ((file (filesystem-store-record-file store)))
    (if (probe-file file)
        (read-lines file)
        nil)))
