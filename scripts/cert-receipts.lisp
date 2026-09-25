;;; cert-receipts.lisp — mint-time certificate receipts (refoundation P5a).
;;;
;;; Certificates stop being ephemeral: every successful mutation-check
;;; mint appends "ts|content-hash|action|expiry" to the receipt ledger
;;; at ~/.hngh-automation/cert-receipts.tsv (HNGH_RECEIPTS_PATH
;;; overrides for tests). The append is serialized through flock(1) on
;;; a sidecar lock; a ledger fault is reported but never blocks the
;;; ceremony itself — the kernel gate stays the sole authority.
;;;
;;; CLI (verification lane):
;;;   sbcl --script scripts/cert-receipts.lisp append <action> <hash>
;;;   sbcl --script scripts/cert-receipts.lisp cat

(require :asdf)

(defun receipt-path ()
  (or (sb-ext:posix-getenv "HNGH_RECEIPTS_PATH")
      (merge-pathnames ".hngh-automation/cert-receipts.tsv"
                       (user-homedir-pathname))))

(defun format-utc-stamp (universal-time)
  (multiple-value-bind (ss mm hh dd mo yy)
      (decode-universal-time universal-time 0)
    (format nil "~4,'0D-~2,'0D-~2,'0DT~2,'0D:~2,'0D:~2,'0DZ"
            yy mo dd hh mm ss)))

(defun record-receipt (action content-hash &key (ttl 86400))
  "Append one receipt line; returns the line, or nil on a ledger fault.
TTL mirrors the kernel mint (src/main.lisp real-certificate: +86400)."
  (let* ((now (get-universal-time))
         (path (receipt-path))
         (line (format nil "~A|~A|~A|~A"
                       (format-utc-stamp now)
                       content-hash
                       (string-downcase action)
                       (format-utc-stamp (+ now ttl)))))
    (handler-case
        (progn
          (ensure-directories-exist path)
          (uiop:run-program
           (list "flock" (namestring (merge-pathnames
                                      (make-pathname :type "lock") path))
                 "sh" "-c" "echo \"$1\" >> \"$2\"" "_" line
                 (namestring path))
           :output t)
          line)
      (error (condition)
        (format *error-output* "cert-receipt ledger fault: ~A~%"
                condition)
        nil))))

(let ((argv (rest (uiop:raw-command-line-arguments))))
  (when (and argv (member (first argv) '("append" "cat") :test #'string=))
    (cond
      ((string= "append" (first argv))
       (if (= 3 (length argv))
           (let ((line (record-receipt (second argv) (third argv))))
             (uiop:quit (if line 0 1)))
           (progn
             (format *error-output*
                     "usage: cert-receipts append <action> <content-hash>~%")
             (uiop:quit 2))))
      (t
       (handler-case
           (format t "~A" (uiop:read-file-string (receipt-path)))
         (error ()))
       (uiop:quit 0)))))
