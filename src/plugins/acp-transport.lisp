;;;; src/plugins/acp-transport.lisp — ACP newline-delimited JSON-RPC transport
;;;;
;;;; ACP's stdio transport (docs/design/agent-client-protocol.md, transports)
;;;; mandates NEWLINE-delimited JSON messages ("messages are delimited by
;;;; newlines (\n), MUST NOT contain embedded newlines"). The stock cxxxr/jsonrpc
;;;; stdio transport uses LSP-style Content-Length framing instead, which real
;;;; ACP peers will NOT interoperate with. This file defines an acp-transport
;;;; that reuses cxxxr/jsonrpc's connection/processing/dispatch machinery but
;;;; overrides send/receive to write each message as one JSON line + newline.
;;;;
;;;; Registered as JSON-RPC mode :acp so acp-client.lisp can use
;;;; (client-connect ... :mode :acp) and (server-listen ... :mode :acp).
;;;;
;;;; SPDX-License-Identifier: AGPL-3.0-or-later
;;;; SPDX-FileCopyrightText: 2026 boundring <boundring@gmail.com>

(defpackage #:jsonrpc/transport/acp
  (:use #:cl
        #:jsonrpc/transport/interface)
  (:import-from #:jsonrpc/connection
                #:connection
                #:connection-stream)
  (:import-from #:yason)
  (:import-from #:jsonrpc/request-response
                #:parse-message)
  (:import-from #:jsonrpc/yason)
  (:import-from #:bordeaux-threads
                #:make-thread
                #:destroy-thread)
  (:export #:acp-transport))
(in-package #:jsonrpc/transport/acp)

(defclass acp-transport (transport)
  ((input :type stream
          :initarg :input
          :initform *standard-input*
          :accessor acp-transport-input)
   (output :type stream
           :initarg :output
           :initform *standard-output*
           :accessor acp-transport-output)))

;; Build the connection over a two-way stream exactly like the stdio transport
;; does — only the on-wire framing (send/receive) differs from Content-Length.

(defmethod start-server ((transport acp-transport))
  (let* ((stream (make-two-way-stream (acp-transport-input transport)
                                      (acp-transport-output transport)))
         (connection (make-instance 'connection
                                    :stream stream
                                    :request-callback (transport-message-callback transport))))
    (setf (transport-connection transport) connection)
    (let ((thread
            (make-thread
             (lambda ()
               (run-processing-loop transport connection))
             :name "jsonrpc/transport/acp processing")))
      (unwind-protect (run-reading-loop transport connection)
        (destroy-thread thread)))))

(defmethod start-client ((transport acp-transport))
  (let* ((stream (make-two-way-stream (acp-transport-input transport)
                                      (acp-transport-output transport)))
         (connection (make-instance 'connection
                                    :stream stream
                                    :request-callback (transport-message-callback transport))))
    (setf (transport-connection transport) connection)
    (setf (transport-threads transport)
          (list
           (make-thread
            (lambda ()
              (run-processing-loop transport connection))
            :name "jsonrpc/transport/acp processing")
           (make-thread
            (lambda ()
              (run-reading-loop transport connection))
            :name "jsonrpc/transport/acp reading")))
    connection))

(defmethod send-message-using-transport ((transport acp-transport) connection message)
  "Write MESSAGE as one newline-delimited JSON line. No embedded newlines are
emitted (yason encodes JSON without literal newlines), and the message is
terminated by a single \\n, per ACP's stdio framing requirement."
  (declare (ignore transport))
  (let ((stream (connection-stream connection)))
    (yason:encode message stream)
    (write-char #\Newline stream)
    (finish-output stream)))

(defmethod receive-message-using-transport ((transport acp-transport) connection)
  "Read one newline-delimited JSON line and parse it into a message.
Returns NIL at EOF or when the pipe is closed underneath us (Card 100:
the CI flake where a teardown close left the reading thread with an
unhandled SB-INT:SIMPLE-STREAM-ERROR). A dead/closed pipe is the same
clean-shutdown signal as EOF — the reading loop exits quietly, matching
the daemon's disconnect handling. Parse failures (real protocol errors)
still propagate: they are not STREAM-ERRORs and are not caught here."
  (declare (ignore transport))
  (let ((stream (connection-stream connection)))
    (let ((line (handler-case
                    (read-line stream nil nil)
                  (stream-error () nil))))
      (when line
        (parse-message line)))))
