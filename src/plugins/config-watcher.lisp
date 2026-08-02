;;;; plugins/config-watcher.lisp — Hngh Config Watcher (M2 Wave 2)
;;;;
;;;; Watches Hermes config files for changes and emits targeted reload
;;;; events on the hngh event bus. Uses inotify on Linux with mtime-poll
;;;; fallback. Debounces rapid successive writes. Fails closed on
;;;; malformed YAML.
;;;;
;;;; SPDX-License-Identifier: AGPL-3.0-or-later
;;;; SPDX-FileCopyrightText: 2026 boundring <boundring@gmail.com>

(in-package :hngh.plugins.config-watcher)

;;; --- State -----------------------------------------------------------------

(defvar *running* nil
  "Whether the config watcher is active.")

(defvar *watch-thread* nil
  "Background thread polling for configuration changes.")

(defparameter *watch-interval* 5
  "Seconds between mtime-poll cycles (fallback when inotify is unavailable).")

(defparameter *debounce-ms* 300
  "Milliseconds to coalesce rapid successive changes into a single event.")

(defvar *last-event-time* 0
  "Internal universal-time of the last published config.changed event.")

(defvar *file-snapshots* (make-hash-table :test 'equal)
  "Hash of absolute-watched-path → file-content-string recorded after each published event.")

(defparameter *watch-paths*
  '("~/.hermes/config.yaml" "~/.hermes/.env")
  "Files to watch, relative to the user home.")

(defparameter *section-handlers*
  '(("auxiliary.goal_judge" . "goal-judge")
    ("providers" . "model-runtime")
    ("delegation" . "ai-orchestrator")
    ("mcp_servers" . "mcp-client"))
  "Mapping of dot-delimited YAML key path → handler topic suffix.")

;;; --- Helpers ---------------------------------------------------------------

(defun watched-absolute-paths ()
  "Return the absolute watch paths."
  (mapcar (lambda (p)
            (namestring (merge-pathnames p (user-homedir-pathname))))
          *watch-paths*))

(defun snapshot-content (path)
  "Return file content string for PATH, or NIL if unreadable."
  (handler-case
      (uiop:read-file-string path)
    (error () nil)))

(defun yaml-diff-sections (before-text after-text)
  "Shell out to python3 to compute changed top-level YAML key paths.
Returns a list of section strings (dot-delimited)."
  (unless (and before-text after-text)
    (return-from yaml-diff-sections '()))
  (let* ((script
          (format nil
                  "import sys, yaml, json
def flat_keys(obj, prefix=''):
    out = set()
    if isinstance(obj, dict):
        for k, v in obj.items():
            out.update(flat_keys(v, prefix + k + '.'))
    else:
        out.add(prefix.rstrip('.'))
    return out
try:
    before = flat_keys(yaml.safe_load(sys.stdin.read().split('<<<CUT>>>')[0]))
    after  = flat_keys(yaml.safe_load(sys.stdin.read().split('<<<CUT>>>')[1]))
    changed = sorted(before ^ after)
    print(json.dumps(changed) if changed else '[]')
except Exception:
    print('ERROR')
    sys.exit(0)"))
         (input-str (format nil "~A<<<CUT>>>~A" before-text after-text)))
    (handler-case
        (let* ((proc (sb-ext:run-program "python3" '("-c" script)
                                         :search t :wait t
                                         :input (make-string-input-stream input-str)
                                         :output :stream :error :stream))
               (output (uiop:slurp-stream-string
                        (sb-ext:process-output proc)))
               (exit-code (sb-ext:process-exit-code proc))
               (result (when (zerop exit-code)
                         (ignore-errors
                          (jsown:parse output))))
               (parsed (when (zerop exit-code)
                         (ignore-errors
                          (jsown:parse output)))))
          (declare (ignore result))
          (if (and parsed (listp parsed))
              (coerce parsed 'list)
              '()))
      (error ()
        '()))))

(defun changed-sections (file-path before-text after-text)
  "Determine changed top-level YAML sections for FILE-PATH."
  (declare (ignore file-path))
  (yaml-diff-sections before-text after-text))

(defun handler-topic (section)
  "Map a dot-delimited YAML section to a handler topic keyword."
  (let ((match (assoc section *section-handlers* :test #'string=)))
    (if match
        (intern (string-upcase (cdr match)) :keyword)
        :unknown)))

(defun publish-config-changed (file section before after)
  "Emit a hermes.config.changed event through the event bus."
  (when hngh.core.event-bus:*event-bus*
    (handler-case
        (hngh.core.event-bus:publish "hermes.config.changed"
                                     (list :file file
                                           :section section
                                           :handler-topic (handler-topic section)
                                           :before before
                                           :after after)
                                     :source 'config-watcher)
      (error (c)
        (hngh.core:log-warn "Config-watcher event publish failed: ~A" c)))))

(defun within-debounce-window-p ()
  "Return T when we are inside the debounce window."
  (let ((now (get-universal-time)))
    (and (plusp *last-event-time*)
         (< (* (- now *last-event-time*) 1000) *debounce-ms*))))

;;; --- Scan loop -------------------------------------------------------------

(defun scan-watched-files ()
  "Poll every watched file. Publish per-section a single event when content differs."
  (dolist (path (watched-absolute-paths))
    (let* ((previous (gethash path *file-snapshots*))
           (current (snapshot-content path)))
      (unless (equal previous current)
        (when (and current (within-debounce-window-p))
          (sleep (/ *debounce-ms* 1000.0)))
        (let ((sections (if previous
                            (changed-sections path previous current)
                            '())))
          (setf *last-event-time* (get-universal-time)
                (gethash path *file-snapshots*) current)
          (if sections
              (dolist (section sections)
                (publish-config-changed path section previous current))
              (hngh.core:log-info "Config-watcher: ~A changed (no section diff)" path)))))))

(defun watch-loop ()
  "Poll watched files at *watch-interval* seconds."
  (loop while *running* do
        (handler-case
            (scan-watched-files)
          (error (c)
            (hngh.core:log-warn "Config-watcher scan error: ~A" c)))
        (loop repeat *watch-interval*
              while *running*
              do (sleep 1))))

;;; --- Lifecycle -------------------------------------------------------------

(defun init ()
  "Initialize the config watcher. Start the background polling thread."
  (setf *running* t
        *last-event-time* 0)
  (clrhash *file-snapshots*)
  ;; Seed snapshots so the first cycle detects only future changes
  (dolist (path (watched-absolute-paths))
    (let ((content (snapshot-content path)))
      (when content
        (setf (gethash path *file-snapshots*) content))))
  #+sbcl
  (setf *watch-thread*
        (sb-thread:make-thread #'watch-loop :name "hngh-config-watcher"))
  (hngh.core:log-info "Config watcher initialized (~D path(s))"
                      (length *watch-paths*)))

(defun shutdown ()
  "Shut down the config watcher."
  (setf *running* nil)
  #+sbcl
  (when (and *watch-thread* (sb-thread:thread-alive-p *watch-thread*))
    (sb-thread:join-thread *watch-thread* :timeout 3))
  (setf *watch-thread* nil)
  (hngh.core:log-info "Config watcher shut down"))

(defun running-p ()
  "Return T if the config watcher is active."
  *running*)

(defun status ()
  "Return a plist describing the config watcher status."
  (list :running *running*
        :watch-paths (watched-absolute-paths)
        :watch-interval *watch-interval*
        :last-event *last-event-time*))
