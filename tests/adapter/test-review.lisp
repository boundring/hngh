(in-package :hngh.tests)

;;; Rung 6 bounded model-review adapter tests. Every reviewer outcome runs
;;; on fixture JSON through the injected fake transport; no test contacts a
;;; provider, subprocess, or network.

(defun review-symbol (name)
  (let ((package (find-package :hngh.adapters.review)))
    (unless package
      (error "review adapter package is unavailable"))
    (multiple-value-bind (symbol status) (find-symbol name package)
      (unless (and symbol (eq status :external))
        (error "review symbol is unavailable: ~A" name))
      symbol)))

(defun review-function (name)
  (let ((symbol (review-symbol name)))
    (unless (fboundp symbol)
      (error "review function is unavailable: ~A" name))
    (symbol-function symbol)))

(defun review-call (name &rest arguments)
  (apply (review-function name) arguments))

(defun make-review-request (&rest arguments)
  (apply #'review-call "MAKE-REVIEW-REQUEST" arguments))

(defun make-review-ports (runner)
  (review-call "MAKE-REVIEW-PORTS" :invoke-reviewer runner))

(defun request-review (request ports)
  (review-call "REQUEST-REVIEW" request ports))

(defun result-status (result)
  (review-call "REVIEW-RESULT-STATUS" result))

(defun result-findings (result)
  (review-call "REVIEW-RESULT-FINDINGS" result))

(defun result-fact (result)
  (review-call "REVIEW-RESULT-FACT" result))

(defun result-refusals (result)
  (review-call "REVIEW-RESULT-REFUSAL-LABELS" result))

(defun finding-label (finding)
  (review-call "REVIEW-FINDING-LABEL" finding))

(defun finding-citation (finding)
  (review-call "REVIEW-FINDING-CITATION" finding))

(defun fact-state (fact)
  (hngh.domain:evidence-fact-state fact))

(defun fact-kind (fact)
  (hngh.domain:evidence-fact-kind fact))

(defun fact-fingerprint (fact)
  (hngh.domain:evidence-fact-fingerprint fact))

(defun request-paths (request)
  (review-call "REVIEW-REQUEST-CANDIDATE-PATHS" request))

(defun request-hash (request)
  (review-call "REVIEW-REQUEST-CONTENT-HASH" request))

(defun request-context (request)
  (review-call "REVIEW-REQUEST-POLICY-CONTEXT" request))

(defun make-standard-request (&key (paths '("src/a.lisp" "src/b.lisp"))
                               (hash "deadbeef") (context '("fail-closed")))
  (make-review-request :candidate-paths paths
                       :content-hash hash
                       :policy-context context))

(defun one-review-fake (responses)
  (make-review-ports-fake :responses responses))

(defun valid-output (labels-and-citations)
  (format nil "{\"findings\":[~{~A~^,~}]}"
          (mapcar (lambda (pair)
                    (destructuring-bind (label citation) pair
                      (format nil "{\"label\":\"~A\",\"citation\":\"~A\"}"
                              label citation)))
                  labels-and-citations)))

;;; Closed request construction --------------------------------------------

(let ((request (make-standard-request)))
  (check (equal '("src/a.lisp" "src/b.lisp") (request-paths request))
         "review request preserves its candidate paths")
  (check (equal "deadbeef" (request-hash request))
         "review request preserves its content hash")
  (check (equal '("fail-closed") (request-context request))
         "review request preserves its policy context"))

(let ((source (list "src/a.lisp" "src/b.lisp")))
  (let ((request (make-review-request
                  :candidate-paths source
                  :content-hash "hash"
                  :policy-context '("ctx"))))
    (setf (first source) "src/evil.lisp")
    (check (equal '("src/a.lisp" "src/b.lisp") (request-paths request))
           "review request copies its candidate paths")))

(dolist (arguments (list '()
                         (list :content-hash "hash" :policy-context '("ctx"))
                         (list :candidate-paths '("src/a.lisp") :policy-context '("ctx"))
                         (list :candidate-paths '("src/a.lisp") :content-hash "hash")
                         (list :candidate-paths nil :content-hash "hash"
                               :policy-context '("ctx"))
                         (list :candidate-paths '() :content-hash "hash"
                               :policy-context '("ctx"))
                         (list :candidate-paths "src/a.lisp" :content-hash "hash"
                               :policy-context '("ctx"))
                         (list :candidate-paths '("src/a.lisp") :content-hash nil
                               :policy-context '("ctx"))
                         (list :candidate-paths '("src/a.lisp") :content-hash 42
                               :policy-context '("ctx"))
                         (list :candidate-paths '("src/a.lisp") :content-hash ""
                               :policy-context '("ctx"))
                         (list :candidate-paths '("src/a.lisp") :content-hash "hash"
                               :policy-context nil)
                         (list :candidate-paths '("src/a.lisp") :content-hash "hash"
                               :policy-context '())
                         (list :candidate-paths '("src/a.lisp") :content-hash "hash"
                               :policy-context "ctx")
                         (list :candidate-paths '("src/a.lisp") :content-hash "hash"
                               :policy-context '(""))))
  (check (signals-error-p
          (lambda () (apply #'make-review-request arguments)))
         "malformed review request fields fail closed"))

(dolist (path (list "/etc/passwd"
                    "../escape"
                    "src/../../escape.lisp"
                    "-n"
                    "-"
                    "~/.ssh/id_rsa"
                    "src/./x.lisp"
                    "src//x.lisp"
                    "src/x.lisp/"
                    "src\\x.lisp"
                    (format nil "src/~Cx.lisp" #\Newline)))
  (check (signals-error-p
          (lambda ()
            (make-review-request :candidate-paths (list path)
                                 :content-hash "hash"
                                 :policy-context '("ctx"))))
         "an escaping or option-like candidate path refuses closed"))

(check (signals-error-p
        (lambda ()
          (make-review-request :candidate-paths '("src/a.lisp" "src/a.lisp")
                               :content-hash "hash"
                               :policy-context '("ctx"))))
       "duplicate candidate paths refuse closed")

(check (signals-error-p
        (lambda ()
          (make-review-request :candidate-paths '("src/a.lisp")
                               :content-hash "hash"
                               :policy-context '("ctx" "ctx"))))
       "duplicate policy context labels refuse closed")

;;; Ports construction ------------------------------------------------------

(check (signals-error-p (lambda () (make-review-ports nil)))
       "review ports require an invoke-reviewer callback")

;;; Type-checked entry ------------------------------------------------------

(let ((ports (make-review-ports (lambda (prompt)
                                  (declare (ignore prompt))
                                  (values 0 "{}" "")))))
  (check (signals-error-p (lambda () (request-review nil ports)))
         "request-review requires a review request")
  (check (signals-error-p (lambda () (request-review (make-standard-request) nil)))
         "request-review requires review ports"))

;;; Successful structured output ----------------------------------------------

(let* ((result (request-review
                (make-standard-request)
                (one-review-fake
                 (list (list :return 0
                             (valid-output '(("strict" "src/a.lisp")
                                             ("grounded" "src/b.lisp")))
                             ""))))))
  (check (eq :complete (result-status result))
         "valid reviewer output completes")
  (check (null (result-refusals result))
         "complete review result carries no refusal labels")
  (let ((findings (result-findings result)))
    (check (= 2 (length findings))
           "valid review preserves the finding count")
    (check (equal "strict" (finding-label (first findings)))
           "review preserves the first finding label")
    (check (equal "src/a.lisp" (finding-citation (first findings)))
           "review preserves the first finding citation")
    (check (equal "grounded" (finding-label (second findings)))
           "review preserves the second finding label"))
  (let ((fact (result-fact result)))
    (check (eql :review (fact-kind fact))
           "review fact is an evidence fact with the review kind")
    (check (eql :current (fact-state fact))
           "valid review fact is current")
    (check (equal "deadbeef|grounded,strict" (fact-fingerprint fact))
           "review fingerprint binds the hash to the sorted findings")))

;;; Deterministic fingerprint and prompt hygiene -----------------------------

(let ((result-a (request-review
                 (make-standard-request)
                 (one-review-fake
                  (list (list :return 0
                              (valid-output '(("x" "src/a.lisp"))) "")))))
      (result-b (request-review
                 (make-standard-request)
                 (one-review-fake
                  (list (list :return 0
                              (valid-output '(("x" "src/a.lisp"))) ""))))))
  (check (equal (fact-fingerprint (result-fact result-a))
                (fact-fingerprint (result-fact result-b)))
         "identical reviews produce identical fingerprints"))

(let ((prompts '()))
  (let ((ports (make-review-ports
                (lambda (prompt)
                  (push prompt prompts)
                  (values 0 (valid-output '(("x" "src/a.lisp"))) "")))))
    (request-review (make-standard-request) ports))
  (let ((prompt (first prompts)))
    (check (search "\"content-hash\":\"deadbeef\"" prompt)
           "review prompt carries the content hash")
    (check (search "\"candidate-paths\":[\"src/a.lisp\",\"src/b.lisp\"]"
                   prompt)
           "review prompt carries the candidate paths")
    (check (search "\"policy-context\":[\"fail-closed\"]" prompt)
           "review prompt carries the policy context")
    (check (search "\"output\"" prompt)
           "review prompt names the closed output contract")
    (check (search "\"findings\"" prompt)
           "review prompt fixes the structured output schema")))

;;; Empty findings are a valid review ----------------------------------------

(let ((result (request-review
               (make-standard-request)
               (one-review-fake '((:return 0 "{\"findings\":[]}" ""))))))
  (check (eq :complete (result-status result))
         "empty findings still complete the review")
  (check (null (result-findings result))
         "empty findings list produces no findings")
  (check (equal "deadbeef|" (fact-fingerprint (result-fact result)))
         "empty review fingerprint is the hash plus an empty finding set"))

;;; Reviewer failure becomes unverifiable evidence -----------------------------

(let ((review (request-review
               (make-standard-request)
               (one-review-fake '((:return 1 "" "upstream error"))))))
  (check (eq :complete (result-status review))
         "reviewer failure still completes the bundle")
  (let ((fact (result-fact review)))
    (check (eql :unverifiable (fact-state fact))
           "failed review evidence is unverifiable")
    (check (equal "unavailable" (fact-fingerprint fact))
           "failed review evidence carries the stable unavailable fingerprint"))
  (check (null (result-findings review))
         "failed review evidence carries no findings"))

;;; Transport faults -----------------------------------------------------------

(let ((review (request-review
               (make-standard-request)
               (one-review-fake '((:error "transport blew up"))))))
  (check (eq :refused (result-status review))
         "thrown transport fault refuses")
  (check (equal '("transport-fault") (result-refusals review))
         "transport fault names its closed refusal")
  (check (null (result-findings review))
         "transport fault carries no findings")
  (check (null (result-fact review))
         "transport fault carries no fact"))

(let ((review (request-review
               (make-standard-request)
               (make-review-ports
                (lambda (prompt)
                  (declare (ignore prompt))
                  (values nil nil nil))))))
  (check (eq :refused (result-status review))
         "malformed transport return refuses")
  (check (equal '("transport-fault") (result-refusals review))
         "malformed transport return names transport-fault"))

;;; Malformed output fails closed ---------------------------------------------

(dolist (text (list ""
                    "not json"
                    "{"
                    "{\"findings\":"
                    "[}"
                    "[]"
                    "{}"
                    "42"
                    "null"
                    "\"str\""
                    "{\"findings\":[]}garbage"
                    "{findings:[]}"
                    "{\"findings\": [{\"label\": \"x\"}]"
                    "{\"label\":\"x\",\"citation\":\"src/a\"}"))
  (let ((review (request-review
                 (make-standard-request)
                 (one-review-fake (list (list :return 0 text ""))))))
    (check (eq :refused (result-status review))
           "malformed reviewer output refuses")
    (check (member "malformed-output" (result-refusals review) :test #'string=)
           "malformed output names the closed refusal")
    (check (null (result-findings review))
           "malformed output carries no findings")
    (check (null (result-fact review))
           "malformed output carries no fact")))

;;; Schema refusals --------------------------------------------------------------

(dolist (text (list
               ;; unknown top-level field
               "{\"summary\":\"hi\",\"findings\":[]}"
               ;; missing label
               "{\"findings\":[{\"citation\":\"src/a.lisp\"}]}"
               ;; missing citation
               "{\"findings\":[{\"label\":\"x\"}]}"
               ;; unknown finding field
               "{\"findings\":[{\"label\":\"x\",\"citation\":\"p\",\"extra\":1}]}"
               ;; non-string label
               "{\"findings\":[{\"label\":1,\"citation\":\"p\"}]}"
               ;; non-string citation
               "{\"findings\":[{\"label\":\"x\",\"citation\":7}]}"
               ;; finding is not an object
               "{\"findings\":[\"x\"]}"
               ;; label with control characters
               (format nil "{\"findings\":[{\"label\":\"a~Cb\",\"citation\":\"p\"}]}"
                    #\Newline)
               ;; label too long
               (format nil "{\"findings\":[{\"label\":\"~A\",\"citation\":\"p\"}]}"
                       (make-string 201 :initial-element #\x))
               ;; citation too long
               (format nil "{\"findings\":[{\"label\":\"x\",\"citation\":\"~A\"}]}"
                       (make-string 201 :initial-element #\x))
               ;; duplicate finding labels
               "{\"findings\":[{\"label\":\"x\",\"citation\":\"a\"},{\"label\":\"x\",\"citation\":\"b\"}]}"
               ;; duplicate object keys
               "{\"findings\":[{\"label\":\"x\",\"label\":\"y\",\"citation\":\"p\"}]}"))
  (let ((review (request-review
                 (make-standard-request)
                 (one-review-fake (list (list :return 0 text ""))))))
    (check (eq :refused (result-status review))
           "schema-violating reviewer output refuses")
    (check (null (result-findings review))
           "schema-violating output carries no findings")
    (check (null (result-fact review))
           "schema-violating output carries no fact")))

;;; Bound refusals -------------------------------------------------------------

(let ((too-many (format nil "{\"findings\":[~{~a~^,~}]}"
                        (loop for i below 33
                              collect (format nil
                                              "{\"label\":\"x~A\",\"citation\":\"p\"}"
                                              i)))))
(let ((review (request-review
                 (make-standard-request)
                 (one-review-fake (list (list :return 0 too-many ""))))))
    (check (eq :refused (result-status review))
           "finding count beyond the bound refuses")
    (check (member "too-many-findings" (result-refusals review) :test #'string=)
           "oversized finding set names too-many-findings")))

(let ((large (concatenate 'string
                          "{\"findings\":[{\"label\":\""
                          (make-string 65530 :initial-element #\x)
                          "\",\"citation\":\"c\"}]}")))
  (let ((review (request-review
                 (make-standard-request)
                 (one-review-fake (list (list :return 0 large ""))))))
    (check (eq :refused (result-status review))
           "oversized reviewer output refuses")
    (check (member "output-too-large" (result-refusals review) :test #'string=)
           "oversized output names output-too-large")))

;;; Reviewer behavior is fixture-backed only ----------------------------------

(let ((review (request-review
               (make-standard-request)
               (one-review-fake
                (list (list :return 0
                            "{\"findings\":[{\"label\":\"ok\",\"citation\":\"src/a.lisp\"}]}"
                            ""))))))
  (check (eq :complete (result-status review))
         "reviewer runs entirely on the injected fake transport"))

;;; Escaped unicode handling ---------------------------------------------------

(let ((review (request-review
               (make-standard-request)
               (one-review-fake
                (list (list :return 0
                            "{\"findings\":[{\"label\":\"\\u006f\\u006b\",\"citation\":\"src/a.lisp\"}]}"
                            ""))))))
  (check (eq :complete (result-status review))
         "valid unicode escapes complete")
  (check (equal "ok" (finding-label (first (result-findings review))))
         "unicode escapes decode to the finding label"))

(dolist (escape (list "\\uD800" "\\uDFFF" "\\uZZZZ" "\\u12" "\\uD800bad"))
  (let ((text (format nil
                      "{\"findings\":[{\"label\":\"~A\",\"citation\":\"src/a.lisp\"}]}"
                      escape)))
    (let ((review (request-review
                   (make-standard-request)
                   (one-review-fake (list (list :return 0 text ""))))))
      (check (eq :refused (result-status review))
             "invalid unicode escapes refuse")
      (check (member "malformed-output" (result-refusals review)
                     :test #'string=)
             "invalid unicode escapes name the closed refusal"))))