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

(defun scan-content (text &key adapter)
  "Content-safety verdict for TEXT (card 109 D1 boundary).

Returns a report object: {'verdict': 'ok'|'blocked', 'risk': 0..1,
'scanner': <name>, 'reason': <string>, 'fragments': [...]}.

Fail-closed: any error in any backend -> blocked with scanner named
'fail-closed'. The ADAPTER keyword selects the backend:
  nil / \"rules\"  — deterministic Lisp rule scanner (default; no deps)
  \"nemo\"        — NeMo Guardrails adapter (Python subprocess; only
                    used when installed per the plugin path)
Unknown adapters are treated as fail-closed blocked."
  (handler-case
      (let ((backend (or (and adapter (string-downcase adapter)) "rules")))
        (cond ((string= backend "rules") (%scan-rules text))
              ((string= backend "nemo") (%scan-nemo text))
              (t (error "unknown scan adapter: ~A" adapter))))
    (error (condition)
      (%object "verdict" "blocked"
               "risk" 1.0
               "scanner" "fail-closed"
               "reason" (format nil "scan backend error: ~A" condition)
               "fragments" #()))))

(defparameter *scan-hard-block-patterns*
  '((:injection . "ignore (?:all |any )?(?:previous |prior )?instructions")
    (:injection . "ignore (?:everything|all) (?:above|below)")
    (:injection . "system ?prompt")
    (:injection . "you are now (?:dan|developer mode)")
    (:injection . "do anything now")
    (:injection . "reveal (?:your|the) (?:system )?prompt")
    (:injection . "disregard (?:your|the) (?:guidelines|instructions|rules)")
    (:exfiltration . "(?:post|send|exfiltrat|upload)[^\\n]{0,40}(?:secret|api[ _-]?key|token|password|credential)")
    (:threat . "kill you|bomb|shoot (?:you|them)|terrorist")
    (:unsafe . "how (?:do|can) i (?:make|build) (?:a )?(?:bomb|explosive|weapon)")))

(defparameter *scan-risk-patterns*
  '((:injection . "prompt injection")
    (:injection . "override")
    (:misuse . "(?:access|read) (?:secret|private|internal) (?:files|data)")
    (:misuse . "delete (?:the )?(?:repo|repository|directory|database)")
    (:toxicity . "hate|idiot|stupid (?:you|user)|shut ?up")
    (:secrets . "(?:api[ _-]?key|password|secret)\\s*=")))

(defun %scan-rules (text)
  "Deterministic rule scanner. Hard-block patterns immediately block;
risk patterns accumulate a risk score. Best-effort content gate, not
a trust boundary (per D1 design)."
  (let ((down (string-downcase text))
        (hard nil)
        (risk 0.0)
        (hard-fragments nil)
        (risk-fragments nil))
    (dolist (pair *scan-hard-block-patterns*)
      (let ((fragment (%match-fragment (cdr pair) down)))
        (when fragment
          (setf hard t)
          (push (format nil "~A: ~A" (car pair) fragment) hard-fragments))))
    (dolist (pair *scan-risk-patterns*)
      (let ((fragment (%match-fragment (cdr pair) down)))
        (when fragment
          (incf risk 0.25)
          (push (format nil "~A: ~A" (car pair) fragment) risk-fragments))))
    (let ((risk (min 1.0 risk)))
      (if hard
          (%object "verdict" "blocked"
                   "risk" risk
                   "scanner" "rules"
                   "reason" "hard-block pattern matched"
                   "fragments" (coerce (nreverse hard-fragments) 'vector))
          (%object "verdict" (if (>= risk 0.75) "blocked" "ok")
                   "risk" risk
                   "scanner" "rules"
                   "reason" (if (>= risk 0.75)
                                "cumulative risk threshold"
                                "no content-safety hard-block")
                   "fragments" (coerce (nreverse risk-fragments) 'vector))))))

(defun %scan-nemo (text)
  "NeMo Guardrails adapter: shell out to a small Python helper that
returns a JSON verdict. Only reachable when :adapter \"nemo\" — the
plugin path (installed per the design brief). Fail-closed on error
propagates to scan-content's handler-case."
  (let ((helper (merge-pathnames
                 "scan_nemo.py"
                 (or (uiop:getenv "HNGH_SCAN_HELPER_DIR")
                     (uiop:getenv "HOME")))))
    (unless (probe-file helper)
      (error "NeMo helper not found: ~A" helper))
    (let ((output (uiop:run-program
                   (list "python3" (namestring helper) text)
                   :output :string :error-output :string)))
      (yason:parse output))))

(defun run-scan-file (file &key adapter)
  "Scan FILE, print one structured JSON verdict, return process status
(0 ok, 1 blocked, 2 error)."
  (handler-case
      (let* ((text (uiop:read-file-string file))
             (verdict (scan-content text :adapter adapter)))
        (%emit (%object "file" file "verdict" verdict))
        (if (string= (gethash "verdict" verdict) "ok") 0 1))
    (error (condition)
      (%emit (%object "file" file
                      "verdict" (%object "verdict" "blocked"
                                         "risk" 1.0
                                         "scanner" "fail-closed"
                                         "reason" (format nil "~A" condition)
                                         "fragments" #())))
      2)))

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
