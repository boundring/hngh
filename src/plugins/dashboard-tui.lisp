;;;; plugins/dashboard-tui.lisp — Hngh Dashboard TUI (B9)
;;;;
;;; Minimal text-based dashboard using raw ANSI escape codes.
;;; No external TUI library dependency (cl-charms/croatoan) needed.
;;;;
;;; Views:
;;;   Overview — Hngh status, active components, recent events
;;;   Events   — live event feed
;;;   Plugins  — loaded plugins
;;;
;;; SPDX-License-Identifier: AGPL-3.0-or-later
;;; SPDX-FileCopyrightText: 2026 boundring <boundring@gmail.com>

(in-package :hngh.plugins.dashboard-tui)

(defvar *running* nil
  "Whether the TUI is active.")

(defvar *current-view* :overview
  "Current view: :overview, :events, :plugins, :watch, :steers, :owner-inbox, :seats, :claims")

(defvar *help-open* nil
  "Whether the keyboard help panel is shown.")

(defparameter *level-map*
  '((:overview . "B1-Core")
    (:events . "B3-Event Bus")
    (:plugins . "B2-Scheduler")
    (:watch . "B4-Watcher")
    (:steers . "B5-Steers")
    (:owner-inbox . "B6-Owner")
    (:seats . "B7-Seats")
    (:claims . "B8-Claims"))
  "View-keyword to megastructure floor name mapping.")

(defvar *event-buffer* '()
  "Recent events for the event feed (newest first, max 100).")

(defvar *buffer-lock* (bt:make-lock "hngh-tui-buffer")
  "Mutex protecting *event-buffer*.")

(defvar *event-subscription* nil
  "Subscription ID for the wildcard event subscription.")

(defvar *input-thread* nil
  "Background thread reading keyboard input.")

(defvar *watch-state-path* "/tmp/hngh-live-watch.state"
  "Path to the live-watch state feed consumed by the dashboard.")

(defvar *steers-log-path* "/tmp/hngh-steers.log"
  "Path to the centralized steer delivery log.")

(defvar *seat-registry-path* "/home/bricker/.hngh-night/seat-names.md"
  "Path to the seat registry.")

(defvar *owner-inbox-path* "/home/bricker/.hngh-night/owner/inbox.md"
  "Path to the owner-facing decision inbox.")

(defvar *seat-lanes-root* "/home/bricker/.hngh-night"
  "Root containing tandem seat lane directories.")

(defvar *claims-register-path* "/home/bricker/.hngh-night/state/claims.lisp"
  "Path to the append-only surface claims register.")

(defvar *headless* nil
  "If T, don't render TUI (for service/SSH mode).")

;;; --- ANSI escape codes ---

(defparameter +ansi-clear+ (coerce '(#\Esc #\[ #\2 #\J) 'string))
(defparameter +ansi-home+ (coerce '(#\Esc #\[ #\H) 'string))
(defparameter +ansi-clear-line+ (coerce '(#\Esc #\[ #\2 #\K) 'string))
(defparameter +ansi-bold+ (coerce '(#\Esc #\[ #\1 #\m) 'string))
(defparameter +ansi-dim+ (coerce '(#\Esc #\[ #\2 #\m) 'string))
(defparameter +ansi-green+ (coerce '(#\Esc #\[ #\3 #\2 #\m) 'string))
(defparameter +ansi-yellow+ (coerce '(#\Esc #\[ #\3 #\3 #\m) 'string))
(defparameter +ansi-red+ (coerce '(#\Esc #\[ #\3 #\1 #\m) 'string))
(defparameter +ansi-cyan+ (coerce '(#\Esc #\[ #\3 #\6 #\m) 'string))
(defparameter +ansi-reset+ (coerce '(#\Esc #\[ #\0 #\m) 'string))

(defun ansi (code)
  "Output an ANSI escape code to *standard-output*."
  (write-string code)
  (finish-output))

(defun clear-screen ()
  "Clear the screen and move cursor to home."
  (ansi +ansi-clear+)
  (ansi +ansi-home+))

;;; --- Lifecycle ---

(defun init (&key (headless nil))
  "Initialize the dashboard TUI.
If HEADLESS is T, subscribes to events but doesn't render TUI."
  (setf *running* t
        *current-view* :overview
        *event-buffer* '()
        *headless* headless)
  ;; Subscribe to all events
  (when hngh.core.event-bus:*event-bus*
    (setf *event-subscription*
          (hngh.core.event-bus:subscribe "*"
            (lambda (evt)
              (bt:with-lock-held (*buffer-lock*)
                (push evt *event-buffer*)
                (when (> (length *event-buffer*) 100)
                  (setf *event-buffer* (subseq *event-buffer* 0 100))))))))
  ;; Start input thread (only in interactive mode)
  (unless headless
    #+sbcl
    (setf *input-thread*
          (sb-thread:make-thread #'input-loop :name "hngh-tui-input")))
  (hngh.core:log-info "Dashboard TUI initialized (~A)"
                       (if headless "headless" "interactive")))

(defun shutdown ()
  "Shut down the TUI."
  (setf *running* nil)
  ;; Unsubscribe from events
  (when *event-subscription*
    (hngh.core.event-bus:unsubscribe *event-subscription*)
    (setf *event-subscription* nil))
  ;; Stop input thread
  #+sbcl
  (when (and *input-thread* (sb-thread:thread-alive-p *input-thread*))
    ;; Thread checks *running* flag and exits
    (sb-thread:join-thread *input-thread* :timeout 2))
  (setf *input-thread* nil)
  ;; Reset terminal
  (unless *headless*
    (ansi +ansi-reset+))
  (hngh.core:log-info "Dashboard TUI shut down"))

(defun running-p ()
  "Return T if the TUI is active."
  *running*)

;;; --- Rendering ---

(defun render-help-panel ()
  "Render the keyboard help overlay."
  (format t "~A~A╔═══════════════════════════╗~A~%" +ansi-bold+ +ansi-cyan+ +ansi-reset+)
  (format t "~A~A║ KEY        COMMAND       ║~A~%" +ansi-bold+ +ansi-cyan+ +ansi-reset+)
  (format t "~A~A╠═══════════════════════════╣~A~%" +ansi-bold+ +ansi-cyan+ +ansi-reset+)
  (format t "~A║ 1          Overview      ║~A~%" +ansi-dim+ +ansi-reset+)
  (format t "~A║ 2          Events        ║~A~%" +ansi-dim+ +ansi-reset+)
  (format t "~A║ 3          Plugins       ║~A~%" +ansi-dim+ +ansi-reset+)
  (format t "~A║ 4          Megastructure ║~A~%" +ansi-dim+ +ansi-reset+)
  (format t "~A║ ?          Help          ║~A~%" +ansi-dim+ +ansi-reset+)
  (format t "~A║ q/Q        Quit          ║~A~%" +ansi-dim+ +ansi-reset+)
  (format t "~A~A╚═══════════════════════════╝~A~%" +ansi-bold+ +ansi-cyan+ +ansi-reset+)
  (format t "~%"))

(defun render ()
  "Render the current view to the terminal."
  (when *headless*
    (return-from render))
  (clear-screen)
  (if *help-open*
      (render-help-panel)
      (case *current-view*
        (:overview (render-overview))
        (:events (render-events))
        (:plugins (render-plugins))
        (:watch (render-watch-state))
        (:steers (render-steers))
        (:owner-inbox (render-owner-inbox))
        (:seats (render-seats))
        (:claims (render-claims))))
  (render-footer))

(defun render-to-string ()
  "Return terminal text for fixture inspection, not a headless event view."
  (with-output-to-string (*standard-output*)
    (let ((*headless* nil))
      (render))))

(defun render-level-indicator ()
  "Render the current megastructure floor beneath the header box."
  (let ((level (or (cdr (assoc *current-view* *level-map*)) "??-Unknown")))
    (format t "~A~A[Level ~A]~A~%"
            +ansi-bold+ +ansi-cyan+ level +ansi-reset+)))
(defun render-header (title)
  "Render the header bar with megastructure floor indicator."
  (format t "~A~A╔══════════════════════════════════════════════════════╗~A~%"
          +ansi-bold+ +ansi-cyan+ +ansi-reset+)
  (format t "~A~A║ Hngh v~A [Megastructure] — ~A                     ║~A~%"
          +ansi-bold+ +ansi-cyan+ (hngh:version) title +ansi-reset+)
  (format t "~A~A╚══════════════════════════════════════════════════════╝~A~%"
          +ansi-bold+ +ansi-cyan+ +ansi-reset+)
  (render-level-indicator)
  (format t "~%"))

(defun read-steers-log (path)
  "Read non-delivery lines from the centralized steer log at PATH."
  (remove-if (lambda (line)
               (or (string= line "")
                   (uiop:string-prefix-p "delivery=" line)))
             (uiop:read-file-lines path)))

(defun read-owner-inbox (path)
  "Read owner inbox lines from PATH."
  (uiop:read-file-lines path))

(defun render-steers ()
  "Render the centralized steer feed."
  (render-header "Steers")
  (if (probe-file *steers-log-path*)
      (dolist (line (last (read-steers-log *steers-log-path*) 30))
        (format t "  ~A~%" line))
      (format t "  ~A(no steer log)~A~%" +ansi-dim+ +ansi-reset+)))

(defun render-owner-inbox ()
  "Render the owner-facing decision inbox."
  (render-header "Owner Inbox")
  (if (probe-file *owner-inbox-path*)
      (dolist (line (last (read-owner-inbox *owner-inbox-path*) 40))
        (format t "  ~A~%" line))
      (format t "  ~A(no owner inbox)~A~%" +ansi-dim+ +ansi-reset+)))

(defun read-seat-status (registry lanes-root)
  "Read assigned seats and model truth from REGISTRY and LANES-ROOT."
  (let ((seats nil))
    (dolist (line (uiop:read-file-lines registry))
      (when (search "— ASSIGNED" line)
        (let* ((name (string-trim '(#\Space #\Tab #\-)
                                  (subseq line 0 (search "—" line))))
               (lane (merge-pathnames
                      (format nil "tandem-~A/" (string-downcase name))
                      lanes-root))
               (status-file (merge-pathnames "model-status" lane))
               (error-file (merge-pathnames "model-error" lane))
               (status (cond ((probe-file status-file) "verified")
                             ((probe-file error-file) "paused")
                             (t "unknown"))))
          (push (cons name (list :status status)) seats))))
    (nreverse seats)))

(defun render-seats ()
  "Render assigned seat truth from the registry and lane status files."
  (render-header "Seats")
  (if (probe-file *seat-registry-path*)
      (dolist (entry (read-seat-status *seat-registry-path* *seat-lanes-root*))
        (format t "  ~A  ~A~%" (car entry) (getf (cdr entry) :status)))
      (format t "  ~A(no seat registry)~A~%" +ansi-dim+ +ansi-reset+)))

(defun read-claims-register (path)
  "Read active CLAIM lines from PATH, excluding released surfaces."
  (let ((released (make-hash-table :test #'equal))
        (claims nil))
    (dolist (line (uiop:read-file-lines path))
      (cond
        ((uiop:string-prefix-p "CLAIM-RELEASE:" line)
         (setf (gethash (second (uiop:split-string line)) released) t))
        ((uiop:string-prefix-p "CLAIM:" line)
         (push line claims))))
    (nreverse
     (remove-if (lambda (line)
                  (gethash (second (uiop:split-string line)) released))
                claims))))

(defun render-claims ()
  "Render active surface claims from the append-only register."
  (render-header "Claims")
  (if (probe-file *claims-register-path*)
      (dolist (line (read-claims-register *claims-register-path*))
        (format t "  ~A~%" line))
      (format t "  ~A(no claims register)~A~%" +ansi-dim+ +ansi-reset+)))

(defun render-watch-state ()
  "Render the latest live-watch state for each seat."
  (format t "~A~%Live Watch~A~%" +ansi-bold+ +ansi-reset+)
  (if (probe-file *watch-state-path*)
      (dolist (entry (read-watch-state *watch-state-path*))
        (let ((seat (car entry))
              (state (cdr entry)))
          (format t "  ~A  ~A ~A idle=~Ds~%"
                  seat
                  (or (getf state :status) "unknown")
                  (or (getf state :action) "none")
                  (getf state :idle-s 0))))
      (format t "  ~A(no watcher state)~A~%" +ansi-dim+ +ansi-reset+)))

(defun render-overview ()
  "Render the overview view."
  (render-header "Overview")
  (format t "Status:     ~A~A~A~%"
          (if hngh:*running*
              (concatenate 'string +ansi-green+ "RUNNING" +ansi-reset+)
              (concatenate 'string +ansi-red+ "STOPPED" +ansi-reset+))
          "" "")
  (format t "State dir:  ~A~%" (namestring hngh:*hngh-home*))
  (format t "Log level:   ~A~%" hngh.core:*log-level*)
  (format t "~%")
  (format t "~AComponents:~A~%" +ansi-bold+ +ansi-reset+)
  ;; Event bus
  (format t "  Event Bus:     ~A~%"
          (if (hngh.core.event-bus:running-p)
              (concatenate 'string +ansi-green+ "active" +ansi-reset+)
              (concatenate 'string +ansi-red+ "inactive" +ansi-reset+)))
  ;; State store
  (format t "  State Store:    ~A~%"
          (if (hngh.core.state-store:running-p)
              (concatenate 'string +ansi-green+ "active" +ansi-reset+)
              (concatenate 'string +ansi-red+ "inactive" +ansi-reset+)))
  ;; Supervisor
  (format t "  Supervisor:     ~A (~D components)~%"
          (if (hngh.core.supervisor:running-p)
              (concatenate 'string +ansi-green+ "active" +ansi-reset+)
              (concatenate 'string +ansi-red+ "inactive" +ansi-reset+))
          (hngh.core.supervisor:component-count))
  ;; Scheduler
  (format t "  Scheduler:      ~A (~D schedules)~%"
          (if (hngh.core.scheduler:running-p)
              (concatenate 'string +ansi-green+ "active" +ansi-reset+)
              (concatenate 'string +ansi-red+ "inactive" +ansi-reset+))
          (if (hngh.core.scheduler:running-p)
              (length (hngh.core.scheduler:list-schedules))
              0))
  ;; Plugins health grid
  (format t "~APlugins:~A~%" +ansi-bold+ +ansi-reset+)
  (let ((plugins (hngh.core.plugin-host:list-plugins)))
    (if plugins
        (dolist (info plugins)
          (let ((running (handler-case
                            (eq :loaded (hngh.core.plugin-host:plugin-info-state info))
                          (error () nil))))
            (format t "  ~A~22A~A   ~A~A~A~%"
                    +ansi-bold+
                    (hngh.core.plugin-host:plugin-info-name info)
                    +ansi-reset+
                    (if running +ansi-green+ +ansi-red+)
                    (if running "[+] active" "[-] inactive")
                    +ansi-reset+)))
        (format t "  ~A(no plugins loaded)~A~%" +ansi-dim+ +ansi-reset+))))

(defun severity-color (topic)
  "Map an event TOPIC string to its severity ANSI color."
  (let ((name (string-downcase (string topic))))
    (cond
      ((some (lambda (p) (search p name))
             '("error" "fault" "breach")) +ansi-red+)
      ((some (lambda (p) (search p name))
             '("warn" "pause" "throttle")) +ansi-yellow+)
      ((some (lambda (p) (search p name))
             '("complete" "done" "green")) +ansi-green+)
      (t +ansi-cyan+))))

(defun render-events ()
  "Render the live event feed with severity color-coding."
  (render-header "Events")
  (let ((events (bt:with-lock-held (*buffer-lock*)
                  (subseq *event-buffer* 0 (min 30 (length *event-buffer*))))))
    (if events
        (dolist (evt events)
          (format t "  ~A~A~A ~A~A~A ~A~S~A~%"
                  +ansi-dim+ (format-event-time evt) +ansi-reset+
                  (severity-color (hngh.core.event-bus:event-topic evt))
                  (hngh.core.event-bus:event-topic evt) +ansi-reset+
                  +ansi-dim+
                  (hngh.core.event-bus:event-payload evt)
                  +ansi-reset+))
        (format t "  ~A(no events yet)~A~%" +ansi-dim+ +ansi-reset+))))

(defun render-plugins ()
  "Render the loaded plugins view."
  (render-header "Plugins")
  (let ((plugins (hngh.core.plugin-host:list-plugins)))
    (if plugins
        (dolist (info plugins)
          (format t "  ~A~A~A v~A [~A]~%"
                  +ansi-green+
                  (hngh.core.plugin-host:plugin-info-name info)
                  +ansi-reset+
                  (hngh.core.plugin-host:plugin-info-version info)
                  (hngh.core.plugin-host:plugin-info-trust-tier info)))
        (format t "  ~A(no plugins loaded)~A~%" +ansi-dim+ +ansi-reset+))))

(defun buffer-fill-bar (n max)
  "Return a ten-segment ASCII bar string representing N / MAX fill."
  (let* ((denom (max max 1))
         (ratio (/ (max 0 (min n max)) denom))
         (filled (round (* ratio 10))))
    (concatenate 'string
     (make-string filled :initial-element #\█)
     (make-string (- 10 filled) :initial-element #\░))))

(defun read-watch-state (path)
  "Read the latest state entry for each seat from PATH."
  (let ((states nil))
    (dolist (line (uiop:read-file-lines path))
      (let* ((fields (uiop:split-string line))
             (seat (second fields))
             (values (loop for field in (cddr fields)
                           for equal = (position #\= field)
                           when equal
                             collect (cons (subseq field 0 equal)
                                           (subseq field (1+ equal))))))
        (when seat
          (push (cons seat
                      (list :status (cdr (assoc "status" values :test #'string=))
                            :action (cdr (assoc "action" values :test #'string=))
                            :idle-s (parse-integer
                                     (or (cdr (assoc "idle_s" values :test #'string=)) "0")
                                     :junk-allowed t)))
                states))))
    (mapcar (lambda (seat)
              (cons seat (cdr (assoc seat states :test #'string=))))
            (remove-duplicates (mapcar #'car states) :test #'string=))))

(defun render-footer ()
  "Render the footer with navigation hints and event-buffer status bar."
  (format t "~%")
  (format t "~A[1]Overview [2]Events [3]Plugins [4]Watch [5]Steers [6]Owner [7]Seats [8]Claims [?]Help [q]uit~A"
          +ansi-dim+ +ansi-reset+)
  (bt:with-lock-held (*buffer-lock*)
    (let ((n (length *event-buffer*)))
      (format t "  |  Events: ~D/100  ~A~A~A~%"
              n +ansi-yellow+ (buffer-fill-bar n 100) +ansi-reset+))))

(defun format-event-time (evt)
  "Format an event's timestamp as HH:MM:SS."
  (multiple-value-bind (sec min hr)
      (decode-universal-time (hngh.core.event-bus:event-timestamp evt))
    (format nil "~2,'0D:~2,'0D:~2,'0D" hr min sec)))

;;; --- Input handling ---

(defun input-loop ()
  "Background thread that reads keyboard input and dispatches commands."
  (loop while *running* do
        (handler-case
            (let ((char (read-char *standard-input* nil nil)))
              (when char
                (handle-key char)))
          (error (c)
            (when *running*
              (hngh.core:log-debug "TUI input error: ~A" c)
              (sleep 1))))))

(defun handle-key (char)
  "Handle a keyboard input character."
  (if *help-open*
      (progn
        (setf *help-open* nil)
        (render))
      (progn
        (case char
          (#\? (setf *help-open* t) (render))
          (#\1 (setf *current-view* :overview) (render))
          (#\2 (setf *current-view* :events) (render))
          (#\3 (setf *current-view* :plugins) (render))
          (#\4 (setf *current-view* :watch) (render))
          (#\5 (setf *current-view* :steers) (render))
          (#\6 (setf *current-view* :owner-inbox) (render))
          (#\7 (setf *current-view* :seats) (render))
          (#\8 (setf *current-view* :claims) (render))
          (#\q (setf *running* nil))
          (#\Q (setf *running* nil))))))

;;; --- Status ---

(defun status ()
  "Return a plist describing the TUI status."
  (list :running *running*
        :view *current-view*
        :headless *headless*
        :events-buffered (length *event-buffer*)))
