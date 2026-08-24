(in-package #:hngh.tests)

;;; Governance property tests: totality over the closed vocabularies, and
;;; the in-toto monotonic principle (ignoring evidence never flips
;;; :refused to :admitted). Exhaustive over the closed kinds; every
;;; assertion is a check so failures surface immediately.

(defparameter +property-proposal-classes+
  '(:feature :scope-broadening :capability-request
    :failure-disposition :review-request :commit-request :push-request))

(defparameter +property-requirement-kinds+
  '(:purpose :caller :input-contract :output-contract :failure-contract
    :capability-set :capability-diff :static-source
    :closed-failure-disposition :claim-proof :base-revision
    :candidate-manifest :content-hash :reversion-or-containment
    :component-import :route :budget :token-limit :expiry
    :source-manifest :conclusion-link))

(defun prop-matrix ()
  "The ten closed matrix principles, in matrix order."
  (copy-list hngh.domain::+matrix-principles+))

(defun prop-fp (principle)
  "Deterministic fingerprint for PRINCIPLE."
  (format nil "fp-~(~A~)" principle))

(defun prop-req (principle kind supplied)
  "An evidence requirement for PRINCIPLE of KIND; with SUPPLIED the
required fingerprint is backed by one current fact, otherwise the
evidence is ignored: facts emptied, required fingerprints kept."
  (hngh.domain:make-evidence-requirement
   :principle principle
   :kind kind
   :required-fingerprints (list (prop-fp principle))
   :evidence-facts
   (when supplied
     (list (hngh.domain:make-evidence-fact
            :kind :fixture :fingerprint (prop-fp principle) :state :current)))))

(defun satisfied-requirements (kind &optional (principles (prop-matrix)))
  "One satisfied requirement per PRINCIPLES, all of KIND."
  (mapcar (lambda (principle)
            (prop-req principle kind t))
          principles))

(defun prop-requirements (kind ignored)
  "One requirement per matrix principle, all of KIND; requirements whose
principle is in IGNORED carry no evidence facts (required fingerprints
kept)."
  (mapcar (lambda (principle)
            (prop-req principle kind (not (member principle ignored))))
          (prop-matrix)))

(defun proposal-for-class (class requirements)
  "A valid proposal of CLASS carrying REQUIREMENTS."
  (hngh.domain:make-policy-proposal
   :class class :problem "property test" :outcome "verdict" :purpose "property"
   :caller "test" :input-contract "closed" :output-contract "verdict"
   :failure-contract "refusal" :declared-capabilities '("verify")
   :capability-diff "none"
   :source-manifest (list (hngh.domain:make-source-manifest-entry
                           :relative-path "property.md" :content-hash "phash"
                           :source-role "policy"))
   :risk-note "none" :dependency "domain" :evidence-trigger "test"
   :evidence-requirements requirements))

;;; Coverage: the two closed vocabularies are the sizes the loops assume.

(check (= 7 (length +property-proposal-classes+))
       "property tests cover all 7 proposal classes")
(check (= 21 (length +property-requirement-kinds+))
       "property tests cover all 21 evidence requirement kinds")
(check (= 10 (length (prop-matrix)))
       "property tests cover all 10 matrix principles")

;;; (a) Totality: 7 classes x 21 kinds, each admitted with one result
;;; per matrix principle.

(let ((combinations 0))
  (dolist (class +property-proposal-classes+)
    (dolist (kind +property-requirement-kinds+)
      (incf combinations)
      (let ((verdict (hngh.domain:evaluate-policy-proposal
                      (proposal-for-class
                       class (satisfied-requirements kind)))))
        (check (eql :admitted (hngh.domain:policy-verdict-state verdict))
               (format nil "totality admits ~S proposal with ~S requirement kind"
                       class kind))
        (check (= 10 (length (hngh.domain:policy-verdict-principle-results verdict)))
               (format nil "totality yields one result per principle for ~S with ~S"
                       class kind)))))
  (check (= combinations 147)
         "totality enumerates 7 classes x 21 kinds"))

;;; Total refusal: with one matrix principle absent, every class refuses
;;; with the missing-principle label, never an error.

(dolist (class +property-proposal-classes+)
  (handler-case
      (let ((verdict (hngh.domain:evaluate-policy-proposal
                      (proposal-for-class
                       class (satisfied-requirements :claim-proof
                                                     (rest (prop-matrix)))))))
        (check (eql :refused (hngh.domain:policy-verdict-state verdict))
               (format nil "an absent matrix principle refuses ~S" class))
        (check (member "missing-principle-result"
                (hngh.domain:policy-verdict-reason-labels verdict)
                :test #'string=)
               (format nil "an absent matrix principle is reported for ~S" class)))
    (error (condition)
      (check nil (format nil "an absent matrix principle must not error for ~S: ~A"
                         class condition)))))

;;; (b) Monotonicity: ignoring evidence never flips :refused to
;;; :admitted. Per class: an admitted baseline, refusal under
;;; single-ignore (one requirement's facts emptied), and refusal
;;; preserved under double-ignore (a second, different requirement).

(let ((principles (prop-matrix)))
  (dolist (class +property-proposal-classes+)
    (let ((baseline (hngh.domain:evaluate-policy-proposal
                     (proposal-for-class
                      class (satisfied-requirements :claim-proof)))))
      (check (eql :admitted (hngh.domain:policy-verdict-state baseline))
             (format nil "monotonicity baseline admits ~S" class)))
    (dolist (first principles)
      (let ((verdict (hngh.domain:evaluate-policy-proposal
                      (proposal-for-class
                       class (prop-requirements :claim-proof (list first))))))
        (check (eql :refused (hngh.domain:policy-verdict-state verdict))
               (format nil "ignoring ~(~A~) evidence refuses ~S" first class)))
      (dolist (second (remove first principles))
        (let ((verdict (hngh.domain:evaluate-policy-proposal
                        (proposal-for-class
                         class (prop-requirements
                                :claim-proof (list first second))))))
          (check (eql :refused (hngh.domain:policy-verdict-state verdict))
                 (format nil "ignoring ~(~A~) and ~(~A~) evidence keeps ~S refused"
                         first second class)))))))