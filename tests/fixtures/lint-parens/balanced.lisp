(defun balanced-reader-forms ()
  (let ((message "balanced \\\"(not a form)\\\""))
    ; This line has unmatched-looking punctuation: ( ) ]
    #| outer comment (
       #| nested comment ) |#
    |#
    (list #\( #\) #\Space message)))
