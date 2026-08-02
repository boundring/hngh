;;;; client/main.lisp — Hngh Client CLI
;;;;
;;;; Thin client connecting to hngh-daemon via Unix socket wire protocol.
;;;; Subcommands: submit, list, watch, status, health, stop-daemon
;;;;
;;;; SPDX-License-Identifier: AGPL-3.0-or-later
;;;; SPDX-FileCopyrightText: 2026 boundring <boundring@gmail.com>

(in-package :hngh.client)

;;; --- Dependencies ---------------------------------------------------------

(eval-when (:compile-toplevel :load-toplevel :execute)
  (require :sb-bsd-sockets)
  (require :babel))

;;; --- Constants ------------------------------------------------------------

(defvar *default-socket-path* "daemon/socket"
  "Default Unix socket path relative to *hngh-home*.")

(defvar *request-timeout* 30
  "Default request timeout in seconds.")

;;; --- State ----------------------------------------------------------------

(defvar *client-socket* nil
  "The connected socket.")

(defvar *client-stream* nil
  "The bidirectional stream for the connection.")

(defvar *next-request-id* 0
  "Monotonic request ID counter.")

(defvar *hngh-home* (merge-pathnames ".hngh/" (user-homedir-pathname))
  "Path to the Hngh state directory.")

;;; --- Connection -----------------------------------------------------------

(defun resolve-socket-path (&optional (hngh-home *hngh-home*))
  "Resolve the absolute socket path."
  (merge-pathnames *default-socket-path* hngh-home))

(defun client-connect (&optional (socket-path (resolve-socket-path)))
  "Open Unix socket connection to daemon. Returns T on success."
  (handler-case
      (progn
        (setf *client-socket*
              (make-instance 'sb-bsd-sockets:local-socket :type :stream))
        (sb-bsd-sockets:socket-connect *client-socket* (namestring socket-path))
        (setf *client-stream*
              (sb-bsd-sockets:socket-make-stream *client-socket*
                                                 :input t :output t
                                                 :element-type '(unsigned-byte 8)
                                                 :buffering :full))
        (hngh.core:log-debug "Connected to daemon at ~A" (namestring socket-path))
        t)
    (error (c)
      (hngh.core:log-error "Failed to connect to daemon: ~A" c)
      (when *client-socket*
        (ignore-errors (sb-bsd-sockets:socket-close *client-socket*))
        (setf *client-socket* nil))
      (setf *client-stream* nil)
      nil)))

(defun client-disconnect ()
  "Close the client connection."
  (when *client-stream*
    (ignore-errors (close *client-stream*))
    (setf *client-stream* nil))
  (when *client-socket*
    (ignore-errors (sb-bsd-sockets:socket-close *client-socket*))
    (setf *client-socket* nil)))

;;; --- Request/Response -----------------------------------------------------

(defun next-request-id ()
  "Generate next request ID."
  (incf *next-request-id*))

(defun send-request (op payload &key policy)
  "Send a request and wait for the matching response.
Returns (values response-plist error-string)."
  (unless *client-stream*
    (return-from send-request (values nil "Not connected to daemon")))
  (let* ((id (next-request-id))
         (encoded (hngh.core.wire-protocol:encode-request id op payload :policy policy)))
    (handler-case
        (progn
          (write-sequence encoded *client-stream*)
          (force-output *client-stream*)
          (handler-case
              (sb-ext:with-timeout *request-timeout*
                (loop
                  (multiple-value-bind (msg err)
                      (hngh.core.wire-protocol:read-message *client-stream*)
                    (when err
                      (return-from send-request
                        (values nil (format nil "Read error: ~A" err))))
                    (when (and (hngh.core.wire-protocol:response-p msg)
                               (= (hngh.core.wire-protocol:request-id msg) id))
                      (return-from send-request (values msg nil))))))
            (sb-ext:timeout ()
              (values nil "Request timeout"))))
      (error (c)
        (values nil (format nil "Send error: ~A" c))))))

;;; --- Subcommand Implementations -------------------------------------------

(defun cmd-health ()
  "Health check."
  (multiple-value-bind (response err) (send-request :health "")
    (if err
        (format t "Error: ~A~%" err)
        (progn
          (format t "Status: ~A~%" (hngh.core.wire-protocol:response-status response))
          (format t "Result: ~A~%" (hngh.core.wire-protocol:response-result response))))))

(defun cmd-status ()
  "Get daemon status."
  (multiple-value-bind (response err) (send-request :get-status "")
    (if err
        (format t "Error: ~A~%" err)
        (progn
          (format t "Status: ~A~%" (hngh.core.wire-protocol:response-status response))
          (let ((result (hngh.core.wire-protocol:response-result response)))
            (format t "Daemon Status:~%")
            (loop for (k v) on result by #'cddr
                  do (format t "  ~A: ~A~%" k v)))))))

(defun cmd-submit-task (task &key policy)
  "Submit a task to the daemon queue."
  (let ((p (or policy '(:prefer-tool :local-openai-api))))
    (multiple-value-bind (response err) (send-request :submit-task task :policy p)
      (if err
          (format t "Error: ~A~%" err)
          (progn
            (format t "Status: ~A~%" (hngh.core.wire-protocol:response-status response))
            (let ((result (hngh.core.wire-protocol:response-result response)))
              (if (eq (hngh.core.wire-protocol:response-status response) :ok)
                  (format t "Task submitted with ID: ~A~%" result)
                  (format t "Error: ~A~%" result))))))))

(defun cmd-list-tasks (&key status)
  "List tasks from the daemon queue."
  (let ((payload (if status
                     (list :status status)
                     "")))
    (multiple-value-bind (response err) (send-request :list-tasks payload)
      (if err
          (format t "Error: ~A~%" err)
          (progn
            (format t "Status: ~A~%" (hngh.core.wire-protocol:response-status response))
            (let ((result (hngh.core.wire-protocol:response-result response)))
              (if (listp result)
                  (dolist (task result)
                    (format t "  ID: ~A, Status: ~A, Task: ~A~%"
                            (getf task :id)
                            (getf task :status)
                            (subseq (getf task :task) 0 (min 80 (length (getf task :task))))))
                  (format t "Result: ~A~%" result))))))))

(defun cmd-watch (&key topics)
  "Watch events from the daemon."
  (let ((selected (or topics '("*"))))
    (multiple-value-bind (response err)
        (send-request :subscribe-events selected)
      (when err
        (format t "Error: ~A~%" err)
        (return-from cmd-watch nil))
      (unless (eq (hngh.core.wire-protocol:response-status response) :ok)
        (format t "Error: ~A~%" (hngh.core.wire-protocol:response-result response))
        (return-from cmd-watch nil)))
    (format t "Watching events on ~{~A~^, ~}... (Ctrl-C to stop)~%" selected)
    (loop
      (multiple-value-bind (message err)
          (hngh.core.wire-protocol:read-message *client-stream*)
        (when err
          (format t "Event stream closed: ~A~%" err)
          (return nil))
        (when (hngh.core.wire-protocol:event-p message)
          (format t "~S~%" message)
          (force-output))))))

(defun cmd-pause (&key resume-at)
  "Pause H-A3 task dispatch."
  (multiple-value-call #'print-control-response
    (send-request :pause (if resume-at (list :resume-at resume-at) '()))))

(defun cmd-resume ()
  "Resume H-A3 task dispatch."
  (multiple-value-call #'print-control-response (send-request :resume '())))

(defun cmd-stop-daemon ()
  "Request graceful daemon shutdown."
  (multiple-value-call #'print-control-response (send-request :stop-daemon '())))

(defun print-control-response (response error)
  "Print a standard control RESPONSE or ERROR returned as multiple values."
  (if error
      (format t "Error: ~A~%" error)
      (format t "~A: ~S~%"
              (hngh.core.wire-protocol:response-status response)
              (hngh.core.wire-protocol:response-result response))))

;;; --- Main Entry Point -----------------------------------------------------

(defun print-usage ()
  "Print usage information."
  (format t "Usage: hngh <subcommand> [options]~%~%")
  (format t "Subcommands:~%")
  (format t "  health                    Check daemon health~%")
  (format t "  status                    Get daemon status~%")
  (format t "  submit <task>             Submit a task to the queue~%")
  (format t "  list [--status STATUS]    List tasks~%")
  (format t "  watch [--topic TOPIC]     Watch daemon events~%")
  (format t "  pause [--resume-at TIME]  Pause task dispatch~%")
  (format t "  resume                    Resume task dispatch~%")
  (format t "  stop-daemon               Stop the daemon (admin)~%")
  (format t "~%Options:~%")
  (format t "  --hngh-home PATH          Set state directory (default: ~~/.hngh/)~%")
  (format t "  --policy KEY VALUE        Set delegation policy (for submit)~%"))

(defun parse-subcommand-args (args)
  "Parse subcommand and its arguments.
Returns (values subcommand remaining-args hngh-home)."
  (when args
    (let* ((home-index (position "--hngh-home" args :test #'string=))
           (home (when (and home-index
                            (< (1+ home-index) (length args)))
                   (merge-pathnames
                    (concatenate 'string (nth (1+ home-index) args) "/"))))
           (filtered (if home
                         (append (subseq args 0 home-index)
                                 (nthcdr (+ home-index 2) args))
                         args)))
      (when (and home-index (null home))
        (error "--hngh-home requires a path"))
      (values (first filtered) (rest filtered) home))))

(defun option-value (args option &key converter)
  "Return OPTION's following value from ARGS, optionally converted."
  (let ((index (position option args :test #'string=)))
    (when index
      (unless (< (1+ index) (length args))
        (error "~A requires a value" option))
      (let ((value (nth (1+ index) args)))
        (if converter (funcall converter value) value)))))

(defun remove-option (args option)
  "Remove one OPTION VALUE pair from ARGS."
  (let ((index (position option args :test #'string=)))
    (if index
        (append (subseq args 0 index) (nthcdr (+ index 2) args))
        args)))

(defun topic-options (args)
  "Collect repeated --topic values from ARGS."
  (loop with rest = args
        for index = (position "--topic" rest :test #'string=)
        while index
        unless (< (1+ index) (length rest))
          do (error "--topic requires a value")
        collect (nth (1+ index) rest)
        do (setf rest (nthcdr (+ index 2) rest))))

(defun parse-submit-options (args)
  "Return task words and an optional policy plist from submit ARGS."
  (let ((index (position "--policy" args :test #'string=)))
    (if (null index)
        (values args nil)
        (progn
          (unless (< (+ index 2) (length args))
            (error "--policy requires KEY VALUE"))
          (values (append (subseq args 0 index) (nthcdr (+ index 3) args))
                  (list (intern (string-upcase (nth (1+ index) args)) :keyword)
                        (intern (string-upcase (nth (+ index 2) args)) :keyword)))))))

(defun main ()
  "Client CLI entry point."
  (let ((args (uiop:command-line-arguments)))
    (cond
      ((member "--help" args :test #'string=)
       (print-usage)
       (uiop:quit 0))
      ((member "--version" args :test #'string=)
       (format t "hngh-client 0.0.1~%")
       (uiop:quit 0))
      (t
       (multiple-value-bind (subcommand remaining home)
           (parse-subcommand-args args)
         (when home
           (setf *hngh-home* home))
         (unless subcommand
           (print-usage)
           (uiop:quit 1))
         (unless (client-connect)
           (format t "Error: Could not connect to daemon at ~A~%"
                   (namestring (resolve-socket-path)))
           (format t "Is the daemon running? Try: systemctl --user start hngh-daemon~%")
           (uiop:quit 1))
         (unwind-protect
              (cond
                ((string= subcommand "health") (cmd-health))
                ((string= subcommand "status") (cmd-status))
                ((string= subcommand "submit")
                 (multiple-value-bind (task-args policy)
                     (parse-submit-options remaining)
                   (when (null task-args)
                     (format t "Error: submit requires a task string~%")
                     (uiop:quit 1))
                   (cmd-submit-task (format nil "~{~A~^ ~}" task-args)
                                    :policy policy)))
                ((string= subcommand "list")
                 (let ((status (option-value remaining "--status"
                                             :converter (lambda (value)
                                                          (intern (string-upcase value) :keyword)))))
                   (cmd-list-tasks :status status)))
                ((string= subcommand "watch")
                 (cmd-watch :topics (topic-options remaining)))
                ((string= subcommand "pause")
                 (cmd-pause :resume-at
                            (option-value remaining "--resume-at"
                                          :converter #'parse-integer)))
                ((string= subcommand "resume") (cmd-resume))
                ((string= subcommand "stop-daemon")
                 (cmd-stop-daemon))
                (t
                 (format t "Unknown subcommand: ~A~%~%" subcommand)
                 (print-usage)
                 (uiop:quit 1)))
           (client-disconnect)))))))
