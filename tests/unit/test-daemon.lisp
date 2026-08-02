;;;; tests/unit/test-daemon.lisp -- Daemon Core + Wire Protocol Tests
;;;;
;;;; SPDX-License-Identifier: AGPL-3.0-or-later
;;;; SPDX-FileCopyrightText: 2026 boundring <boundring@gmail.com>

(in-package :hngh.tests)

;;; --- Test Suite -----------------------------------------------------------

(def-suite daemon-suite
  :description "Daemon core and wire protocol tests"
  :in :hngh)

(in-suite daemon-suite)

;;; --- Wire Protocol Tests --------------------------------------------------

(test wire-protocol/encode-decode-roundtrip
  "Encoding and decoding a message should preserve its structure."
  (let* ((msg (make-request 42 :submit-task "test task" :policy '(:prefer-tool :local-openai-api)))
         (encoded (encode-message msg))
         ;; decode-message expects body only (without length prefix)
         (decoded (decode-message (subseq encoded 4))))
    (is (equalp (getf decoded :type) :request))
    (is (= (getf decoded :id) 42))
    (is (equalp (getf decoded :op) :submit-task))
    (is (equalp (getf decoded :payload) "test task"))
    (is (equalp (getf decoded :policy) '(:prefer-tool :local-openai-api)))))

(test wire-protocol/response-encode-decode
  "Response message roundtrip."
  (let* ((msg (make-response 42 :ok :result 7))
         (encoded (encode-message msg))
         (decoded (decode-message (subseq encoded 4))))
    (is (equalp (getf decoded :type) :response))
    (is (= (getf decoded :id) 42))
    (is (equalp (getf decoded :status) :ok))
    (is (= (getf decoded :result) 7))))

(test wire-protocol/event-encode-decode
  "Event message roundtrip."
  (let* ((msg (make-event :task-completed '(:id 7 :status :done)))
         (encoded (encode-message msg))
         (decoded (decode-message (subseq encoded 4))))
    (is (equalp (getf decoded :type) :event))
    (is (equalp (getf decoded :topic) :task-completed))
    (is (equalp (getf decoded :payload) '(:id 7 :status :done)))))

(test wire-protocol/length-prefix
  "Length prefix should be 4 bytes big-endian."
  (let* ((msg (make-request 1 :health ""))
         (encoded (encode-message msg))
         (len (length encoded)))
    (is (> len 4))
    ;; First 4 bytes should encode the length of the rest
    (let ((payload-len (- len 4))
          (prefix-len (+ (ash (aref encoded 0) 24)
                         (ash (aref encoded 1) 16)
                         (ash (aref encoded 2) 8)
                         (aref encoded 3))))
      (is (= prefix-len payload-len)))))

(test wire-protocol/supported-ops
  "Supported operations list should include expected ops."
  (is (supported-op-p :submit-task))
  (is (supported-op-p :list-tasks))
  (is (supported-op-p :health))
  (is (supported-op-p :get-status))
  (is (supported-op-p :subscribe-events))
  (is (not (supported-op-p :unknown-op))))

(test wire-protocol/read-eval-disabled
  "Wire input cannot execute reader-eval forms."
  (let* ((text "(:type :request :id 1 :op :health :payload #.(error \"executed\"))")
         (bytes (babel:string-to-octets text :encoding :utf-8)))
    (signals error (decode-message bytes))))

(test wire-protocol/rejects-trailing-form
  "Exactly one S-expression is accepted per frame."
  (let ((bytes (babel:string-to-octets
                "(:type :request :id 1 :op :health :payload nil) (:extra t)"
                :encoding :utf-8)))
    (signals error (decode-message bytes))))

(test wire-protocol/rejects-invalid-message-shape
  "Decoded forms must be protocol messages rather than arbitrary Lisp data."
  (let ((bytes (babel:string-to-octets "(:hello :world)" :encoding :utf-8)))
    (signals error (decode-message bytes))))

;;; --- Daemon Core Tests ----------------------------------------------------

(test daemon/init-shutdown
  "Daemon core init and shutdown should succeed."
  (is (hngh.core.daemon:init))
  ;; init does not start the server, so running-p is NIL until daemon-start
  (is (not (hngh.core.daemon:running-p)))
  (is (hngh.core.daemon:shutdown))
  (is (not (hngh.core.daemon:running-p))))

(test daemon/status-structure
  "Daemon status should return expected plist structure."
  (hngh.core.daemon:init)
  (let ((status (hngh.core.daemon:daemon-status)))
    ;; running is NIL because daemon-start wasn't called
    (is (member :running status))
    (is (stringp (getf status :socket-path)))
    (is (integerp (getf status :connected-clients)))
    (is (listp (getf status :subscribed-topics))))
  (hngh.core.daemon:shutdown))

(test daemon/request-handler-registration
  "Custom request handlers can be registered."
  (hngh.core.daemon:init)
  (let ((called nil))
    (hngh.core.daemon:register-request-handler :test-op
      (lambda (client-id msg)
        (declare (ignore client-id msg))
        (setf called t)
        (make-response 1 :ok :result "custom")))
    (is (hngh.core.daemon:register-request-handler :test-op
      (lambda (client-id msg)
        (declare (ignore client-id msg))
        (make-response 1 :ok :result "custom"))))
  (hngh.core.daemon:shutdown)))

(test daemon/builtin-health-handler
  "Built-in health handler responds correctly."
  (hngh.core.daemon:init)
  ;; The health handler is registered during init
  (let ((handler (gethash :health hngh.core.daemon::*request-handlers*)))
    (is (not (null handler)))
    (let ((response (funcall handler 1
                               (make-request 1 :health ""))))
      (is (equalp (response-status response) :ok))
      (is (getf (response-result response) :status))))
  (hngh.core.daemon:shutdown))

(test daemon/builtin-status-handler
  "Built-in get-status handler responds correctly."
  (hngh.core.daemon:init)
  (let ((handler (gethash :get-status hngh.core.daemon::*request-handlers*)))
    (is (not (null handler)))
    (let ((response (funcall handler 1
                               (make-request 1 :get-status ""))))
      (is (equalp (response-status response) :ok))
      (let ((result (response-result response)))
        ;; daemon-start isn't called, so :running is NIL; assert key presence
        (is (member :running result))
        (is (stringp (getf result :socket-path))))))
  (hngh.core.daemon:shutdown))

(test daemon/submit-task-handler-registration
  "Submit-task requests have a registered daemon handler."
  (hngh.core.daemon:init)
  (is (not (null (gethash :submit-task hngh.core.daemon::*request-handlers*))))
  (hngh.core.daemon:shutdown))

(test daemon/list-tasks-handler-registration
  "List-tasks requests have a registered daemon handler."
  (hngh.core.daemon:init)
  (is (not (null (gethash :list-tasks hngh.core.daemon::*request-handlers*))))
  (hngh.core.daemon:shutdown))

(test daemon/event-control-handler-registration
  "Streaming and H-A3 control operations have daemon handlers."
  (hngh.core.daemon:init)
  (dolist (operation '(:subscribe-events :unsubscribe-events :pause :resume))
    (is (functionp (gethash operation hngh.core.daemon::*request-handlers*))))
  (hngh.core.daemon:shutdown))

(test daemon/submit-list-roundtrip
  "Submit-task and list-tasks handlers use the persistent orchestrator queue."
  (with-aio-light (tmp)
    (hngh.core.daemon:init)
    (let ((submitted
            (hngh.core.daemon::handle-request
             1 (make-request 1 :submit-task "m7 handler test"
                             :policy '(:prefer-tool :local-openai-api)))))
      (is (equalp (response-status submitted) :ok))
      (is (integerp (response-result submitted)))
      (let ((listed
              (hngh.core.daemon::handle-request
               1 (make-request 2 :list-tasks ""))))
        (is (equalp (response-status listed) :ok))
        (is (find "m7 handler test" (response-result listed)
                  :key (lambda (entry) (getf entry :task))
                  :test #'string=))))
    (hngh.core.daemon:shutdown)))

(test daemon/submit-task-nonstring-fails-closed
  "Non-string submit payloads return a descriptive error response."
  (with-aio-light (tmp)
    (hngh.core.daemon:init)
    (let ((response
            (hngh.core.daemon::handle-request
             1 (make-request 1 :submit-task 42))))
      (is (equalp (response-status response) :error))
      (is (search "string" (response-result response) :test #'char-equal)))
    (hngh.core.daemon:shutdown)))

(test daemon/orchestrator-unavailable-fails-closed
  "Submit-task fails closed when the orchestrator is not initialized."
  (hngh.core.daemon:init)
  (let ((response
          (hngh.core.daemon::handle-request
           1 (make-request 1 :submit-task "unavailable test"))))
    (is (equalp (response-status response) :error))
    (is (search "unavailable" (response-result response) :test #'char-equal)))
  (hngh.core.daemon:shutdown))

;;; --- Client Connection Tests ----------------------------------------------

(test daemon/client-connect-disconnect
  "Daemon can accept and close a client connection."
  (hngh.core.daemon:init)
  (ignore-errors (hngh.core.daemon:daemon-start))
  (sleep 0.5) ; Let server start
  
  (handler-case
      (let ((socket (make-instance 'sb-bsd-sockets:local-socket :type :stream)))
        (sb-bsd-sockets:socket-connect socket (namestring (hngh.core.daemon:daemon-socket-path)))
        (let ((stream (sb-bsd-sockets:socket-make-stream socket :input t :output t
                                                         :element-type '(unsigned-byte 8)
                                                         :buffering :full)))
          ;; Send a health request
          (let ((request (encode-request 1 :health "")))
            (write-sequence request stream)
            (force-output stream)
            ;; Read response
            (multiple-value-bind (msg err) (read-message stream)
              (is (null err))
              (is (equalp (response-status msg) :ok))))
          (close stream)))
    (error (c)
      (fail "Connection test failed: ~A" c)))
  
  (hngh.core.daemon:daemon-stop)
  (hngh.core.daemon:shutdown))

(defun open-daemon-test-stream (socket-path)
  "Connect a binary test stream to SOCKET-PATH."
  (let ((socket (make-instance 'sb-bsd-sockets:local-socket :type :stream)))
    (sb-bsd-sockets:socket-connect socket (namestring socket-path))
    (sb-bsd-sockets:socket-make-stream
     socket :input t :output t :element-type '(unsigned-byte 8) :buffering :full)))

(defun subscribe-test-stream (stream id topics)
  "Subscribe STREAM and assert an OK response."
  (write-sequence (encode-request id :subscribe-events topics) stream)
  (force-output stream)
  (multiple-value-bind (response error) (read-message stream)
    (is (null error))
    (is (eq :ok (response-status response)))))

(test daemon/broadcasts-event-bus-events-to-multiple-clients
  "Every matching daemon subscriber receives orchestrator event-bus traffic."
  (let ((tmp (make-tmp-home))
        (first-stream nil)
        (second-stream nil))
    (unwind-protect
         (progn
           (hngh.core.event-bus:init :hngh-home tmp)
           (hngh.core.daemon:init :hngh-home tmp)
           (is (hngh.core.daemon:daemon-start :hngh-home tmp))
           (setf first-stream
                 (open-daemon-test-stream (hngh.core.daemon:daemon-socket-path tmp))
                 second-stream
                 (open-daemon-test-stream (hngh.core.daemon:daemon-socket-path tmp)))
           (subscribe-test-stream first-stream 1 '(:task-completed))
           (subscribe-test-stream second-stream 2 '("*"))
           (hngh.core.event-bus:publish
            :task-completed '(:id 17 :status :done) :source 'ai-orchestrator)
           (dolist (stream (list first-stream second-stream))
             (multiple-value-bind (event error)
                 (sb-ext:with-timeout 2 (read-message stream))
               (is (null error))
               (is (event-p event))
               (is (eq :task-completed (event-topic event)))
               (is (= 17 (getf (event-payload event) :id))))))
      (when first-stream (ignore-errors (close first-stream)))
      (when second-stream (ignore-errors (close second-stream)))
      (ignore-errors (hngh.core.daemon:shutdown))
      (ignore-errors (hngh.core.event-bus:shutdown))
      (cleanup-tmp-home tmp))))

;;; --- Test Runner ----------------------------------------------------------

(defun run-daemon-tests ()
  "Run all daemon tests."
  (run! 'daemon-suite))
