;;;; tests/unit/test-acp-client.lisp — Tests for ACP client (Wave A1)
;;;;
;;;; Uses the cxxxr/jsonrpc stdio pattern (server over pipe FDs) to exercise
;;;; the client deterministically against an in-CL mock agent — no external
;;;; subprocess framing to fight. Params for ACP objects are string-keyed
;;;; hash-tables (camelCase), per the ACP wire contract.
;;;;
;;;; SPDX-License-Identifier: AGPL-3.0-or-later
;;;; SPDX-FileCopyrightText: 2026 boundring <boundring@gmail.com>

(in-package :hngh.tests)

(def-suite :hngh.acp-client
  :description "Tests for ACP client (Wave A1)"
  :in :hngh)

(in-suite :hngh.acp-client)

;;; --- Fixtures -------------------------------------------------------------

(defun %obj (&rest pairs)
  "Build a string-keyed hash-table (JSON object) from KEY VALUE pairs, same
rule as the client params — yason encodes hash-tables as objects and plain
lists (incl. alists) as arrays."
  (let ((h (make-hash-table :test 'equal)))
    (loop for (k v) on pairs by #'cddr
          do (setf (gethash k h) v))
    h))

(defun %mock-agent-server (input output)
  "Run a JSON-RPC server on INPUT/OUTPUT exposing a minimal ACP agent:
initialize (returns protocol v1 + agentCapabilities), session/new,
session/prompt. Runs in the calling thread (call from a worker thread in the
tests)."
  (let ((server (jsonrpc:make-server)))
    (jsonrpc:expose
     server "initialize"
     (lambda (params)
       (declare (ignore params))
       (%obj "protocolVersion" 1
             "agentCapabilities"
             (%obj "loadSession" t
                   "promptCapabilities"
                   (%obj "image" nil "audio" nil "embeddedContext" nil)
                   "sessionCapabilities" (%obj))
             "agentInfo" (%obj "name" "mock-agent" "version" "1.0")
             "authMethods" nil)))
    (jsonrpc:expose
     server "session/new"
     (lambda (params)
       (%obj "sessionId" (format nil "ses_~D" (hash-table-count params)))))
    (jsonrpc:expose
     server "session/prompt"
     (lambda (params)
       (declare (ignore params))
       (%obj "stopReason" "end_turn" "content" nil)))
    (jsonrpc:server-listen server :mode :stdio
                           :input input :output output)))

(defmacro with-mock-agent ((conn) &body body)
  "Open an ACP connection to an in-CL mock agent over stdio pipes, run BODY
with CONN bound, then disconnect and destroy the server thread."
  `(multiple-value-bind (in1 out1) (sb-posix:pipe)
     (multiple-value-bind (in2 out2) (sb-posix:pipe)
       (let ((server-thread
               (bt:make-thread
                (lambda ()
                  (%mock-agent-server
                   (sb-sys:make-fd-stream in1 :input t)
                   (sb-sys:make-fd-stream out2 :output t)))))
             (conn nil))
         (unwind-protect
              (progn
                (sleep 0.3)
                (setf conn
                      (hngh.plugins.acp-client:acp-connect-stdio
                       (sb-sys:make-fd-stream in2 :input t)
                       (sb-sys:make-fd-stream out1 :output t)))
                ,@body)
           (when conn
             (hngh.plugins.acp-client:acp-disconnect conn))
           (bt:destroy-thread server-thread))))))

;;; --- Initialize + capability negotiation ----------------------------------

(test acp-initialize-parses-capabilities
  (with-mock-agent (conn)
    (let ((result (hngh.plugins.acp-client:acp-initialize conn)))
      (is (= 1 (gethash "protocolVersion" result)))
      (is (string= "mock-agent"
                   (gethash "name"
                            (hngh.plugins.acp-client:acp-agent-info conn))))
      (is (gethash "loadSession"
                   (hngh.plugins.acp-client:acp-agent-capabilities conn))))))

(test acp-midturn-mode-interrupt-when-no-injection-capability
  ;; Mock agent does NOT advertise in-turn injection => :interrupt, never
  ;; :steer and never :unknown after initialize.
  (with-mock-agent (conn)
    (hngh.plugins.acp-client:acp-initialize conn)
    (is (eql :interrupt
             (hngh.plugins.acp-client:acp-midturn-mode conn)))))

(test acp-midturn-mode-unknown-before-initialize
  ;; A connection with no initialize yet (nil capabilities) => :unknown.
  ;; Construct the object directly without a transport; only the capability
  ;; accessor matters for this decision.
  (let ((conn (make-instance 'hngh.plugins.acp-client:acp-connection
                             :client nil :input nil :output nil)))
    (is (eql :unknown (hngh.plugins.acp-client:acp-midturn-mode conn)))))

;;; --- Session lifecycle ----------------------------------------------------

(test acp-session-new-and-prompt-roundtrip
  (with-mock-agent (conn)
    (hngh.plugins.acp-client:acp-initialize conn)
    (let ((sid (hngh.plugins.acp-client:acp-session-new conn :cwd "/tmp")))
      (is (stringp sid))
      (is (search "ses_" sid))
      ;; prompt returns a response with stopReason.
      (let ((resp (hngh.plugins.acp-client:acp-prompt
                   conn sid "build the thing" :timeout 5)))
        (is (string= "end_turn" (gethash "stopReason" resp)))))))

(test acp-object-params-keep-camelcase-keys
  ;; Regression: %ht must NOT downcase ACP camelCase wire keys. Exercise the
  ;; internal helper directly (it is what builds every request's params).
  (let ((ht (funcall (intern "%HT" "HNGH.PLUGINS.ACP-CLIENT")
                     "protocolVersion" 1 "sessionId" "s1")))
    (is (eql 1 (gethash "protocolVersion" ht)))
    (is (equal "s1" (gethash "sessionId" ht)))
    (is-false (gethash "protocolversion" ht))))
