;;;; core/wire-protocol.lisp — Hngh Daemon Wire Protocol
;;;;
;;;; Length-prefixed S-expression encoding over Unix sockets.
;;;; Message types: :request, :response, :event
;;;;
;;;; SPDX-License-Identifier: AGPL-3.0-or-later
;;;; SPDX-FileCopyrightText: 2026 boundring <boundring@gmail.com>

(in-package :hngh.core.wire-protocol)

;;; --- Constants ------------------------------------------------------------

(defconstant +max-message-size+ (* 1024 1024)  ; 1MB
  "Maximum message size in bytes to prevent memory exhaustion.")

(defconstant +length-header-size+ 4
  "Size of length prefix in bytes (big-endian 32-bit).")

;;; --- Message Types --------------------------------------------------------

(defun make-request (id op payload &key policy)
  "Create a request message plist."
  (list :type :request :id id :op op :payload payload :policy policy))

(defun make-response (id status &key result error)
  "Create a response message plist."
  (list :type :response :id id :status status :result result :error error))

(defun make-event (topic payload)
  "Create an event message plist."
  (list :type :event :topic topic :payload payload))

(defun message-type (msg)
  "Extract message type from a decoded message plist."
  (getf msg :type))

(defun request-p (msg)
  "T if MSG is a request."
  (eq (message-type msg) :request))

(defun response-p (msg)
  "T if MSG is a response."
  (eq (message-type msg) :response))

(defun event-p (msg)
  "T if MSG is an event."
  (eq (message-type msg) :event))

;;; --- Encoding -------------------------------------------------------------

(defun encode-message (msg)
  "Encode a message plist to a byte vector with length prefix.
Returns a (vector (unsigned-byte 8))."
  (let* ((sexp (prin1-to-string msg))
         (bytes (babel:string-to-octets sexp :encoding :utf-8))
         (len (length bytes)))
    (when (> len +max-message-size+)
      (error "Message too large: ~D bytes (max ~D)" len +max-message-size+))
    (let ((out (make-array (+ +length-header-size+ len) :element-type '(unsigned-byte 8))))
      ;; Big-endian 32-bit length
      (setf (aref out 0) (ldb (byte 8 24) len))
      (setf (aref out 1) (ldb (byte 8 16) len))
      (setf (aref out 2) (ldb (byte 8 8) len))
      (setf (aref out 3) (ldb (byte 8 0) len))
      (replace out bytes :start1 +length-header-size+ :start2 0)
      out)))

(defun encode-request (id op payload &key policy)
  "Convenience: encode a request message."
  (encode-message (make-request id op payload :policy policy)))

(defun encode-response (id status &key result error)
  "Convenience: encode a response message."
  (encode-message (make-response id status :result result :error error)))

(defun encode-event (topic payload)
  "Convenience: encode an event message."
  (encode-message (make-event topic payload)))

;;; --- Decoding -------------------------------------------------------------

(defun read-length-header (stream)
  "Read 4-byte big-endian length from STREAM. Returns integer or NIL on EOF."
  (let ((buf (make-array 4 :element-type '(unsigned-byte 8))))
    (let ((read (read-exactly stream buf)))
      (when read
        (+ (ash (aref buf 0) 24)
           (ash (aref buf 1) 16)
           (ash (aref buf 2) 8)
           (aref buf 3))))))

(defun read-exactly (stream buffer)
  "Fill BUFFER from STREAM, tolerating short reads. Return BUFFER or NIL on EOF."
  (loop with offset = 0
        while (< offset (length buffer))
        for next = (read-sequence buffer stream :start offset)
        do (when (= next offset)
             (return-from read-exactly nil))
           (setf offset next)
        finally (return buffer)))

(defun read-message-body (stream length)
  "Read exactly LENGTH bytes from STREAM. Returns byte vector or NIL on EOF."
  (let ((buf (make-array length :element-type '(unsigned-byte 8))))
    (read-exactly stream buf)))

(defun proper-plist-p (value)
  "Return T when VALUE is an even-length proper list with keyword keys."
  (and (listp value)
       (evenp (length value))
       (loop for tail on value by #'cddr
             always (keywordp (first tail)))))

(defun valid-message-p (message)
  "Return T when MESSAGE has the required shape for its declared type."
  (and (proper-plist-p message)
       (case (getf message :type)
         (:request
          (and (integerp (getf message :id))
               (not (minusp (getf message :id)))
               (keywordp (getf message :op))))
         (:response
          (and (integerp (getf message :id))
               (not (minusp (getf message :id)))
               (member (getf message :status) '(:ok :error))))
         (:event
          (let ((topic (getf message :topic)))
            (or (keywordp topic) (stringp topic))))
         (otherwise nil))))

(defun decode-message (bytes)
  "Decode and validate one S-expression message with read-time evaluation disabled."
  (handler-case
      (let ((str (babel:octets-to-string bytes :encoding :utf-8)))
        (let ((*read-eval* nil)
              (*package* (find-package :keyword)))
          (multiple-value-bind (message position)
              (read-from-string str nil :eof)
            (when (eq message :eof)
              (error "Empty message body"))
            (unless (every (lambda (char) (find char " \t\r\n"))
                           (subseq str position))
              (error "Trailing data after message"))
            (unless (valid-message-p message)
              (error "Invalid message shape"))
            message)))
    (error (c)
      (error "Failed to decode message: ~A" c))))

(defun read-message (stream)
  "Read one complete message from STREAM.
Returns (values message-plist nil) on success,
or (values nil :eof) on clean EOF,
or (values nil :error) on protocol error."
  (let ((len (read-length-header stream)))
    (when (null len)
      (return-from read-message (values nil :eof)))
    (when (or (zerop len) (> len +max-message-size+))
      (return-from read-message (values nil :error)))
    (let ((body (read-message-body stream len)))
      (when (null body)
        (return-from read-message (values nil :error)))
      (handler-case
          (values (decode-message body) nil)
        (error (c)
          (declare (ignore c))
          (values nil :error))))))

;;; --- Dispatch Helpers -----------------------------------------------------

(defun request-id (msg)
  "Extract :id from a request message."
  (getf msg :id))

(defun request-op (msg)
  "Extract :op from a request message."
  (getf msg :op))

(defun request-payload (msg)
  "Extract :payload from a request message."
  (getf msg :payload))

(defun request-policy (msg)
  "Extract :policy from a request message."
  (getf msg :policy))

(defun response-status (msg)
  "Extract :status from a response message."
  (getf msg :status))

(defun response-result (msg)
  "Extract :result from a response message."
  (getf msg :result))

(defun response-error (msg)
  "Extract :error from a response message."
  (getf msg :error))

(defun event-topic (msg)
  "Extract :topic from an event message."
  (getf msg :topic))

(defun event-payload (msg)
  "Extract :payload from an event message."
  (getf msg :payload))

;;; --- Supported Operations -------------------------------------------------

(defparameter *supported-ops*
  '(:submit-task :list-tasks :get-task :pause :resume :renew-lease
    :get-status :health :maintenance-status :subscribe-events
    :unsubscribe-events :stop-daemon)
  "Operations supported by the daemon wire protocol.")

(defun supported-op-p (op)
  "Check if OP is a supported operation."
  (member op *supported-ops*))
