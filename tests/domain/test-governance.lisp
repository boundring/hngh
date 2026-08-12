(in-package :hngh.tests)

(let* ((path (copy-seq "src/domain/mission.lisp"))
       (hash (copy-seq "hash-1"))
       (role (copy-seq "domain source"))
       (entry (hngh.domain:make-source-manifest-entry
               :relative-path path :content-hash hash :source-role role)))
  (setf (char path 0) #\X)
  (setf (char hash 0) #\X)
  (setf (char role 0) #\X)
  (check (equal "src/domain/mission.lisp"
                (hngh.domain:source-manifest-entry-relative-path entry))
         "manifest entry copies caller-owned path")
  (check (equal "hash-1"
                (hngh.domain:source-manifest-entry-content-hash entry))
         "manifest entry copies caller-owned hash")
  (check (equal "domain source"
                (hngh.domain:source-manifest-entry-source-role entry))
         "manifest entry copies caller-owned role"))

(let* ((entry (hngh.domain:make-source-manifest-entry
               :relative-path "src/domain/mission.lisp"
               :content-hash "hash-1"
               :source-role "domain source"))
       (path (hngh.domain:source-manifest-entry-relative-path entry))
       (hash (hngh.domain:source-manifest-entry-content-hash entry))
       (role (hngh.domain:source-manifest-entry-source-role entry)))
  (setf (char path 0) #\X)
  (setf (char hash 0) #\X)
  (setf (char role 0) #\X)
  (check (and (equal "src/domain/mission.lisp"
                    (hngh.domain:source-manifest-entry-relative-path entry))
              (equal "hash-1"
                     (hngh.domain:source-manifest-entry-content-hash entry))
              (equal "domain source"
                     (hngh.domain:source-manifest-entry-source-role entry)))
         "manifest entry isolates every public string reader result"))

(let ((fact (hngh.domain:make-evidence-fact
             :kind :fixture :fingerprint "fp-1" :state :current)))
  (check (and (eql :fixture (hngh.domain:evidence-fact-kind fact))
              (equal "fp-1" (hngh.domain:evidence-fact-fingerprint fact))
              (eql :current (hngh.domain:evidence-fact-state fact)))
         "evidence fact preserves its closed values"))

(let ((input (copy-seq "fp-1"))
      (fact nil))
  (setf fact (hngh.domain:make-evidence-fact
              :kind :fixture :fingerprint input :state :current))
  (setf (char input 0) #\X)
  (let ((reported (hngh.domain:evidence-fact-fingerprint fact)))
    (setf (char reported 0) #\X)
    (check (equal "fp-1" (hngh.domain:evidence-fact-fingerprint fact))
           "evidence fingerprint is isolated from input and reader mutation")))

(let ((result (hngh.domain:make-principle-result
               :principle :closed-authority
               :state :passed
               :evidence-fingerprints '("fp-1" "fp-2"))))
  (check (and (eql :closed-authority
                   (hngh.domain:principle-result-principle result))
              (eql :passed (hngh.domain:principle-result-state result))
              (equal '("fp-1" "fp-2")
                     (hngh.domain:principle-result-evidence-fingerprints result)))
         "principle result preserves validated values"))

(let ((input (list (copy-seq "fp-1")))
      (result nil))
  (setf result (hngh.domain:make-principle-result
                :principle :closed-authority :state :passed
                :evidence-fingerprints input))
  (setf (char (first input) 0) #\X)
  (let ((reported (hngh.domain:principle-result-evidence-fingerprints result)))
    (setf (char (first reported) 0) #\X)
    (check (equal '("fp-1")
                  (hngh.domain:principle-result-evidence-fingerprints result))
           "principle evidence fingerprints isolate input and reader mutation")))

(let ((verdict (hngh.domain:make-policy-verdict
                :state :admitted
                :principle-results
                (list (hngh.domain:make-principle-result
                       :principle :closed-authority
                       :state :passed
                       :evidence-fingerprints '("fp-1")))
                :reason-labels '("all required principles passed"))))
  (check (and (eql :admitted (hngh.domain:policy-verdict-state verdict))
              (= 1 (length (hngh.domain:policy-verdict-principle-results verdict)))
              (equal '("all required principles passed")
                     (hngh.domain:policy-verdict-reason-labels verdict)))
         "policy verdict preserves validated values"))

(dolist (case '((hngh.domain:validate-proposal-class :unknown)
                (hngh.domain:validate-principle-identifier :unknown)
                (hngh.domain:validate-failure-category :unknown)
                (hngh.domain:validate-failure-disposition :unknown)))
  (check (signals-error-p (lambda () (apply #'funcall case)))
         "unknown governance vocabulary refuses"))

(check (signals-error-p
        (lambda ()
          (hngh.domain:make-evidence-fact
           :kind :fixture :fingerprint "" :state :current)))
       "malformed evidence refuses")
(dolist (state '(:unknown :invalid))
  (check (signals-error-p
          (lambda ()
            (hngh.domain:make-evidence-fact
             :kind :fixture :fingerprint "fp" :state state)))
         "unknown evidence state refuses"))
(dolist (state '(:unknown :invalid))
  (check (signals-error-p
          (lambda ()
            (hngh.domain:make-principle-result
             :principle :closed-authority :state state
             :evidence-fingerprints '("fp"))))
         "unknown principle result state refuses"))
(dolist (state '(:unknown :invalid))
  (check (signals-error-p
          (lambda ()
            (hngh.domain:make-policy-verdict
             :state state :principle-results '() :reason-labels '("reason"))))
         "unknown policy verdict state refuses"))
(dolist (arguments '((:content-hash "hash" :source-role "role")
                     (:relative-path "path" :source-role "role")
                     (:relative-path "path" :content-hash "hash")))
  (check (signals-error-p
          (lambda ()
            (apply #'hngh.domain:make-source-manifest-entry arguments)))
         "missing source manifest field refuses"))
(dolist (arguments '((:relative-path "" :content-hash "hash" :source-role "role")
                     (:relative-path "path" :content-hash "" :source-role "role")
                     (:relative-path "path" :content-hash "hash" :source-role "")))
  (check (signals-error-p
          (lambda () (apply #'hngh.domain:make-source-manifest-entry arguments)))
         "malformed source manifest field refuses"))
(dolist (arguments '((:principle nil :state :passed :evidence-fingerprints '("fp"))
                     (:principle :closed-authority :state nil :evidence-fingerprints '("fp"))
                     (:principle :closed-authority :state :passed
                      :evidence-fingerprints 'not-a-list)))
  (check (signals-error-p
          (lambda () (apply #'hngh.domain:make-principle-result arguments)))
         "missing principle result field refuses"))
(check (signals-error-p
        (lambda ()
          (hngh.domain:make-principle-result
           :principle :closed-authority
           :state :passed
           :evidence-fingerprints '("fp-1" "fp-1"))))
       "duplicate evidence fingerprints refuse")
(let ((first-result (hngh.domain:make-principle-result
                     :principle :closed-authority :state :passed
                     :evidence-fingerprints '("fp-1")))
      (second-result (hngh.domain:make-principle-result
                      :principle :closed-authority :state :refused
                      :evidence-fingerprints '("fp-2"))))
  (check (signals-error-p
          (lambda ()
            (hngh.domain:make-policy-verdict
             :state :refused :principle-results (list first-result second-result)
             :reason-labels '("reason"))))
         "duplicate principle results refuse"))
(check (signals-error-p
        (lambda ()
          (hngh.domain:make-policy-verdict
           :state :refused :principle-results '()
           :reason-labels '("reason" "reason"))))
       "duplicate reason labels refuse")
(check (signals-error-p
        (lambda ()
          (hngh.domain:make-policy-verdict
           :state nil :principle-results '() :reason-labels '())))
       "missing policy verdict fields refuse")

(let* ((labels (list "reason"))
       (results (list (hngh.domain:make-principle-result
                       :principle :least-authority :state :refused
                       :evidence-fingerprints '("fp"))))
       (verdict (hngh.domain:make-policy-verdict
                 :state :refused :principle-results results
                 :reason-labels labels)))
  (setf (first labels) "changed")
  (setf (first results) nil)
  (check (equal '("reason")
                (hngh.domain:policy-verdict-reason-labels verdict))
         "policy verdict copies caller-owned labels")
  (check (not (null (first (hngh.domain:policy-verdict-principle-results verdict))))
         "policy verdict copies caller-owned results")
  (let ((reported (hngh.domain:policy-verdict-reason-labels verdict)))
    (setf (first reported) "changed")
    (check (equal '("reason")
                  (hngh.domain:policy-verdict-reason-labels verdict))
           "policy verdict defensively copies public labels")))

(dolist (name '("SOURCE-MANIFEST-ENTRY-ACTION" "POLICY-VERDICT-AUTHORITY"
                "PRINCIPLE-RESULT-CERTIFICATE"))
  (check (null (find-symbol name :hngh.domain))
         "governance value exposes no action authority or certificate field"))
