;;;; src/plugins/prompt-lint.lisp — procedural agent-request guard (card 103).
;;;;
;;;; No model calls, network access, or telemetry. Findings are deterministic
;;;; and fail closed for errors; card 106 wires the guard into seat-up before
;;;; tmux/Hermes spawn.

(in-package #:hngh.plugins.prompt-lint)

(defun %object (&rest pairs)
  (let ((object (make-hash-table :test #'equal)))
    (loop for (key value) on pairs by #'cddr
          do (setf (gethash key object) value))
    object))

(defun %producer ()
  (%object "agent" (or (uiop:getenv "HNGH_PROMPT_LINT_AGENT")
                       "unknown-agent")
           "model" (or (uiop:getenv "HNGH_PROMPT_LINT_MODEL")
                        "unknown-model")
           "harness" (or (uiop:getenv "HNGH_PROMPT_LINT_HARNESS")
                          "hngh prompt-lint")))

(defun %finding (level category fragment suggested-fix producer &optional gate)
  (let ((finding (%object "level" level
                          "category" category
                          "fragment" fragment
                          "suggested-fix" suggested-fix
                          "producer" producer)))
    (when gate
      (setf (gethash "human-gate-ref" finding) gate))
    finding))

(defmacro %push-finding (findings level category fragment suggested-fix producer
                         &optional gate)
  `(push (%finding ,level ,category ,fragment ,suggested-fix ,producer ,gate)
         ,findings))

(defun %nonempty-words (line)
  (remove-if (lambda (word) (zerop (length word)))
             (uiop:split-string line :separator (list #\Space #\Tab))))

(defun %clean-token (token)
  (string-right-trim (list #\. #\, #\; #\: #\! #\? #\) #\] #\}
                           #\Return #\Newline)
                    token))

(defun %model-refs (text)
  (let ((refs nil))
    (dolist (line (uiop:split-string text :separator (list #\Newline)))
      (let ((words (%nonempty-words line)))
        (loop for index from 0 below (length words)
              for word = (nth index words)
              do (cond
                   ((or (string= word "-m") (string= word "--model"))
                    (when (< (1+ index) (length words))
                      (push (%clean-token (nth (1+ index) words)) refs)))
                   ((uiop:string-prefix-p "--model=" word)
                    (push (%clean-token (subseq word 8)) refs))
                   ((string= word "model:")
                    (when (< (1+ index) (length words))
                      (push (%clean-token (nth (1+ index) words)) refs)))
                   ((uiop:string-prefix-p "model:" word)
                    (push (%clean-token (subseq word 6)) refs))))))
    (remove-if #'(lambda (ref) (zerop (length ref))) (nreverse refs))))

(defun %route-models ()
  "Return models from the loaded route data, without duplicating the list."
  (when (boundp 'hngh.plugins.model-routes:*routes*)
    (remove nil
            (mapcar (lambda (route) (getf route :model))
                    hngh.plugins.model-routes:*routes*))))

(defun %configured-models (&optional config-path)
  (let ((path (or config-path
                  (uiop:getenv "HNGH_PROMPT_LINT_CONFIG")
                  (namestring (merge-pathnames ".hngh/config/hngh.lisp"
                                                (user-homedir-pathname))))))
    (if (probe-file path)
        (let ((models nil)
              (text (uiop:read-file-string path)))
          (dolist (line (uiop:split-string text :separator (list #\Newline)))
            (let ((words (%nonempty-words line)))
              (loop for index from 0 below (length words)
                    for word = (nth index words)
                    when (or (string= word "model:")
                             (string= word "default:"))
                      do (when (< (1+ index) (length words))
                           (push (%clean-token (nth (1+ index) words)) models)))))
          (values (remove-duplicates (append models (%route-models))
                                     :test #'string=)
                  t path))
        (let ((route-models (%route-models)))
          (values route-models (not (null route-models)) path)))))

(defun %common-prefix-length (left right)
  (loop for index from 0 below (min (length left) (length right))
        while (char-equal (char left index) (char right index))
        finally (return index)))

(defun %model-suggestion (model known)
  (let ((best (first known))
        (best-score -1))
    (dolist (candidate known)
      (let ((score (%common-prefix-length model candidate)))
        (when (> score best-score)
          (setf best candidate
                best-score score))))
    (if best
        (format nil "Use configured model id ~A instead." best)
        "Attach a config containing the exact model id before forwarding.")))

(defun %path-fragments (text)
  (remove-duplicates
   (remove-if (lambda (path)
                (or (uiop:string-prefix-p "//" path)
                    (and (> (length path) 1)
                         (digit-char-p (char path 1)))
                    (search "://" path)))
              (mapcar #'%clean-token
                      (cl-ppcre:all-matches-as-strings
                       "(?:~|/|\\./|\\.\\./)\\S+"
                       text)))
   :test #'string=))

(defun %match-fragment (pattern text)
  (multiple-value-bind (start end)
      (cl-ppcre:scan pattern (string-downcase text))
    (when start
      (subseq text start end))))

(defun %assumption-fragments (text)
  (let ((patterns '("card\\s+[0-9]+\\s+(?:lands?|done|closed)"
                    "make\\s+(?:test|check)\\s+(?:is\\s+)?green"
                    "model\\s+\\S+\\s+(?:serving|active|live)"
                    "(?:probe|tests?)\\s+(?:passed|green)"
                    "(?:commit|change)\\s+(?:landed|merged|done)")))
    (remove nil (mapcar (lambda (pattern) (%match-fragment pattern text))
                        patterns))))

(defun %dangerous-fragments (text)
  (let ((patterns '("rm\\s+-rf"
                    "git\\s+reset\\s+--hard"
                    "jailbreak"
                    "ignore\\s+(?:all\\s+)?(?:safety|safeguards?)"
                    "(?:disable|bypass)\\s+[^.\n]{0,24}(?:gate|safety|approval)"
                    "immutable\\s+edit"
                    "(?:exfiltrat|dump|print|show|send|post)[^.\n]{0,40}(?:secret|api[ _-]?key|token|password|credential)")))
    (remove nil (mapcar (lambda (pattern) (%match-fragment pattern text))
                        patterns))))

(defun %error-count (findings)
  (count "error" findings :key (lambda (finding) (gethash "level" finding))
         :test #'string=))

(defun %summary (findings)
  (%object "errors" (%error-count findings)
           "warnings" (count "warn" findings
                              :key (lambda (finding) (gethash "level" finding))
                              :test #'string=)
           "info" (count "info" findings
                          :key (lambda (finding) (gethash "level" finding))
                          :test #'string=)
           "total" (length findings)))

(defun %report (file findings producer)
  (%object "file" file
           "producer" producer
           "findings" (coerce findings 'vector)
           "summary" (%summary findings)))

(defun lint-text (text &key config-path)
  "Return deterministic prompt findings for TEXT.

Each finding contains level, category, fragment, suggested-fix, and producer.
The optional CONFIG-PATH overrides the Hermes model configuration source."
  (let ((findings nil)
        (producer (%producer))
        (models nil)
        (config-available nil)
        (model-refs (%model-refs text)))
    (multiple-value-setq (models config-available)
      (%configured-models config-path))
    (when model-refs
      (unless config-available
        (%push-finding findings "error" "model-config"
                       (or config-path "~/.hermes/config.yaml")
                       "Provide a readable model configuration before forwarding."
                       producer))
      (dolist (model model-refs)
        (unless (member model models :test #'string=)
          (%push-finding findings "error" "model-id" model
                         (%model-suggestion model models) producer))))
    (dolist (path (%path-fragments text))
      (let ((resolved (if (uiop:string-prefix-p "~/" path)
                          (merge-pathnames (subseq path 2)
                                           (user-homedir-pathname))
                          path)))
        (unless (probe-file resolved)
          (%push-finding findings "error" "path" path
                         "Verify the path exists or correct it before forwarding."
                         producer))))
    (dolist (fragment (%dangerous-fragments text))
      (%push-finding findings "error" "dangerous-action" fragment
                     "Refuse the request and obtain human approval through operation-gate."
                     producer "operation-gate"))
    (unless (or (null (%assumption-fragments text))
                (cl-ppcre:scan "(?:sha|commit|[0-9]+/[0-9]+|evidence|verified|footer|probe)"
                               (string-downcase text)))
      (dolist (fragment (%assumption-fragments text))
        (%push-finding findings "warn" "assumption" fragment
                       "Attach evidence: a SHA, exact test count, or verified model/footer output."
                       producer)))
    (dolist (tag '("STATE:" "STEER:" "ANSWER:"))
      (unless (search tag text :test #'char-equal)
        (%push-finding findings "warn" "structure" tag
                       (format nil "Include a ~A coordination entry before forwarding." tag)
                       producer)))
    (unless (cl-ppcre:scan "(?:acceptance|verify|verification|test|expected|exit\\s+[01])"
                           (string-downcase text))
      (%push-finding findings "warn" "structure" "acceptance criteria"
                     "Add explicit acceptance or verification criteria."
                     producer))
    (nreverse findings)))

(defun %emit (report)
  (yason:encode report *standard-output*)
  (terpri)
  (finish-output)
  report)

(defun run-file (file)
  "Lint FILE, print one structured JSON report, and return a process status."
  (handler-case
      (let* ((text (uiop:read-file-string file))
             (findings (lint-text text))
             (report (%report file findings (%producer))))
        (%emit report)
        (if (plusp (%error-count findings)) 1 0))
    (error (condition)
      (%emit (%report file
                      (list (%finding "error" "input" file
                                      (format nil "Unable to read input: ~A" condition)
                                      "Provide a readable UTF-8 prompt file."
                                      (%producer)))
                      (%producer)))
      1)))
