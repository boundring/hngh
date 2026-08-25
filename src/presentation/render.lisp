(in-package #:hngh.presentation)

;;; Rung 7: operator-visible presentation. Pure renderers turn application
;;; results, domain runs and governance values, and installed adapter results
;;; into plain human-readable factual strings. Rendering never mutates a
;;; canonical value, refusals stay literal refusals, and the optional
;;; reference lexicon applies display copy only at a named surface; it can
;;; never carry or replace canonical control state. This package imports no
;;; adapter: it only consumes their immutable result values.

(defparameter +reference-entry-keys+
  '(:surface :original :reference :provenance))

(defun flat-plist-p (value)
  (and (listp value)
       (evenp (length value))
       (loop for key in value by #'cddr
             always (keywordp key))))

(defun reference-entry-p (entry)
  (and (flat-plist-p entry)
       (equal (loop for key in entry by #'cddr collect key)
              +reference-entry-keys+)
       (keywordp (getf entry :surface))
       (stringp (getf entry :original))
       (stringp (getf entry :reference))
       (stringp (getf entry :provenance))))

(defun reference-lexicon-p (lexicon)
  "True when LEXICON is a renderer-only reference pack: a flat plist whose
only key is :render, holding a list of four-field reference entries. The
pack never carries canonical control fields."
  (and (flat-plist-p lexicon)
       (equal (loop for key in lexicon by #'cddr collect key) '(:render))
       (listp (getf lexicon :render))
       (every #'reference-entry-p (getf lexicon :render))))

(defun render-with-lexicon (lexicon surface original)
  "Return the reference display copy for SURFACE when the pack carries one,
else ORIGINAL. The canonical value is never replaced: this entry point
returns display copy only."
  (unless (reference-lexicon-p lexicon)
    (error "reference lexicon is malformed"))
  (let ((entry (find surface (getf lexicon :render)
                     :test #'eq :key (lambda (candidate)
                                       (getf candidate :surface)))))
    (if entry (getf entry :reference) original)))

(defun render-status-label (state &optional lexicon)
  "Quiet display label for a run state. Without a pack this is the canonical
state term; with one, the optional reference copy. The stored state never
changes."
  (let ((original (format nil "~(~A~)" state)))
    (if lexicon (render-with-lexicon lexicon :status original) original)))

;;; Renderers ---------------------------------------------------------------

(defun render-run (run)
  (format nil "run ~A state=~(~A~) role=~A loadout=~(~A~) mission=~A"
          (hngh.domain:run-identifier run)
          (hngh.domain:run-state run)
          (hngh.domain:role-template-name (hngh.domain:run-role run))
          (hngh.domain:loadout-route-label (hngh.domain:run-loadout run))
          (hngh.domain:mission-objective (hngh.domain:run-mission run))))

(defun render-receipt (receipt)
  (format nil "receipt kind=~(~A~) facts=~{~A~^; ~}"
          (hngh.domain:receipt-kind receipt)
          (hngh.domain:receipt-facts receipt)))

(defun render-evidence-fact (fact)
  (format nil "evidence kind=~(~A~) fingerprint=~A state=~(~A~)"
          (hngh.domain:evidence-fact-kind fact)
          (hngh.domain:evidence-fact-fingerprint fact)
          (hngh.domain:evidence-fact-state fact)))

(defun render-source-manifest-entry (entry)
  (format nil "manifest-entry path=~A hash=~A role=~A"
          (hngh.domain:source-manifest-entry-relative-path entry)
          (hngh.domain:source-manifest-entry-content-hash entry)
          (hngh.domain:source-manifest-entry-source-role entry)))

(defun render-principle-result (result)
  (format nil "principle ~(~A~) state=~(~A~)"
          (hngh.domain:principle-result-principle result)
          (hngh.domain:principle-result-state result)))

(defun render-policy-verdict (verdict)
  (format nil "verdict state=~(~A~) principles=~D~%~{~A~%~}reasons=~@[~{~A~^; ~}~]"
          (hngh.domain:policy-verdict-state verdict)
          (length (hngh.domain:policy-verdict-principle-results verdict))
          (mapcar #'render-principle-result
                  (hngh.domain:policy-verdict-principle-results verdict))
          (let ((reasons (hngh.domain:policy-verdict-reason-labels verdict)))
            (if reasons reasons (list "none")))))

(defun render-candidate-certificate (certificate)
  (format nil "certificate action=~(~A~) repository=~A base=~A paths=~{~A~^,~} ~
content-hash=~A evidence-hashes=~{~A~^,~} verdicts=~D findings=~{~A~^,~} ~
manifest=~D policy-profile=~A expiry=~A"
          (hngh.domain:candidate-certificate-action certificate)
          (hngh.domain:candidate-certificate-repository-identity certificate)
          (hngh.domain:candidate-certificate-base-revision certificate)
          (hngh.domain:candidate-certificate-candidate-paths certificate)
          (hngh.domain:candidate-certificate-content-hash certificate)
          (hngh.domain:candidate-certificate-evidence-hashes certificate)
          (length (hngh.domain:candidate-certificate-principle-verdicts certificate))
          (hngh.domain:candidate-certificate-review-findings certificate)
          (length (hngh.domain:candidate-certificate-source-manifest certificate))
          (hngh.domain:candidate-certificate-policy-profile certificate)
          (hngh.domain:candidate-certificate-expiry certificate)))

(defun render-application-result (result)
  (case (hngh.application:application-result-status result)
    (:accepted
     (format nil "accepted~%~A~%~A~%~@[facts=~{~A~^; ~}~]~@[ labels=~{~A~^; ~}~]"
             (render-run (hngh.application:application-result-run result))
             (render-receipt (hngh.application:application-result-receipt result))
             (hngh.application:application-result-facts result)
             (hngh.application:application-result-labels result)))
    (otherwise
     (format nil "~(~A~)~@[ labels=~{~A~^; ~}~]"
             (hngh.application:application-result-status result)
             (hngh.application:application-result-labels result)))))

(defun render-evidence-result (result)
  (case (hngh.adapters.evidence:evidence-result-status result)
    (:complete
     (format nil "evidence-bundle status=complete~%facts:~%~{~A~%~}manifest:~%~{~A~%~}"
             (mapcar #'render-evidence-fact
                     (hngh.adapters.evidence:evidence-result-facts result))
             (mapcar #'render-source-manifest-entry
                     (hngh.adapters.evidence:evidence-result-manifest result))))
    (otherwise
     (format nil "evidence-bundle status=~(~A~) labels=~{~A~^; ~}"
             (hngh.adapters.evidence:evidence-result-status result)
             (hngh.adapters.evidence:evidence-result-refusal-labels result)))))

(defun render-verification-result (result)
  (format nil "verification status=~(~A~) labels=~{~A~^; ~}"
          (hngh.application:verification-result-status result)
          (hngh.application:verification-result-labels result)))

(defun render-manifest-result (result)
  (format nil "manifest status=~(~A~) labels=~{~A~^; ~}"
          (hngh.application:manifest-result-status result)
          (hngh.application:manifest-result-labels result)))

(defun render-mutation-result (result)
  (format nil "mutation status=~(~A~)~@[ action=~(~A~)~]~@[ command=~S~]~@[ exit=~A~]~@[ labels=~{~A~^; ~}~]~@[ stderr=~A~]"
          (hngh.adapters.mutation:mutation-result-status result)
          (hngh.adapters.mutation:mutation-result-action result)
          (hngh.adapters.mutation:mutation-result-command result)
          (hngh.adapters.mutation:mutation-result-exit-code result)
          (hngh.adapters.mutation:mutation-result-refusal-labels result)
          (let ((stderr (hngh.adapters.mutation:mutation-result-stderr result)))
            (and stderr (plusp (length stderr)) stderr))))

(defun render-review-finding (finding)
  (format nil "finding label=~A citation=~A"
          (hngh.adapters.review:review-finding-label finding)
          (hngh.adapters.review:review-finding-citation finding)))

(defun render-review-result (result)
  (case (hngh.adapters.review:review-result-status result)
    (:complete
     (format nil "review status=complete findings=~D~%~{~A~%~}fact=~A"
             (length (hngh.adapters.review:review-result-findings result))
             (mapcar #'render-review-finding
                     (hngh.adapters.review:review-result-findings result))
             (render-evidence-fact (hngh.adapters.review:review-result-fact result))))
    (otherwise
     (format nil "review status=~(~A~) labels=~{~A~^; ~}"
             (hngh.adapters.review:review-result-status result)
             (hngh.adapters.review:review-result-refusal-labels result)))))

(defun render-operator-result (result)
  (case (hngh.adapters.terminal:operator-result-status result)
    (:complete
     (format nil "operator status=complete statement=~A fact=~A"
             (hngh.adapters.terminal:operator-result-statement result)
             (render-evidence-fact (hngh.adapters.terminal:operator-result-fact result))))
    (otherwise
     (format nil "operator status=~(~A~) labels=~{~A~^; ~}"
             (hngh.adapters.terminal:operator-result-status result)
             (hngh.adapters.terminal:operator-result-refusal-labels result)))))

(defun render-federation-result (result)
  (case (hngh.adapters.federation:federation-result-status result)
    (:complete
     (format nil "federation status=complete facts=~D~%~{~A~%~}"
             (length (hngh.adapters.federation:federation-result-facts result))
             (mapcar #'render-evidence-fact
                     (hngh.adapters.federation:federation-result-facts result))))
    (otherwise
     (format nil "federation status=~(~A~) labels=~{~A~^; ~}"
             (hngh.adapters.federation:federation-result-status result)
             (hngh.adapters.federation:federation-result-refusal-labels result)))))

(defun render-attestation-result (result)
  (case (hngh.adapters.federation:attestation-result-status result)
    (:verified
     (format nil "attestation status=verified key=~A fact=~A"
             (hngh.adapters.federation:attestation-result-key-identifier result)
             (render-evidence-fact
              (hngh.adapters.federation:attestation-result-fact result))))
    (otherwise
     (format nil "attestation status=~(~A~) labels=~{~A~^; ~}"
             (hngh.adapters.federation:attestation-result-status result)
             (hngh.adapters.federation:attestation-result-refusal-labels result)))))

;;; Dispatch, reports, and fallback ------------------------------------------

(defun render (value)
  "Render any known application, domain, or adapter value to a single
factual string. Unknown values render as their printed representation."
  (cond
    ((hngh.application:application-result-p value)
     (render-application-result value))
    ((typep value 'hngh.domain:run)
     (render-run value))
    ((typep value 'hngh.domain:receipt)
     (render-receipt value))
    ((typep value 'hngh.domain:evidence-fact)
     (render-evidence-fact value))
    ((typep value 'hngh.domain:source-manifest-entry)
     (render-source-manifest-entry value))
    ((typep value 'hngh.domain:principle-result)
     (render-principle-result value))
    ((hngh.domain:policy-verdict-p value)
     (render-policy-verdict value))
    ((hngh.domain:candidate-certificate-p value)
     (render-candidate-certificate value))
    ((typep value 'hngh.application:verification-result)
     (render-verification-result value))
    ((typep value 'hngh.application:manifest-result)
     (render-manifest-result value))
    ((hngh.adapters.evidence:evidence-result-p value)
     (render-evidence-result value))
    ((hngh.adapters.mutation:mutation-result-p value)
     (render-mutation-result value))
    ((hngh.adapters.review:review-result-p value)
     (render-review-result value))
    ((hngh.adapters.review:review-finding-p value)
     (render-review-finding value))
    ((hngh.adapters.terminal:operator-result-p value)
     (render-operator-result value))
    ((hngh.adapters.federation:federation-result-p value)
     (render-federation-result value))
    ((hngh.adapters.federation:attestation-result-p value)
     (render-attestation-result value))
    (t (format nil "~S" value))))

(defun render-report (&rest values)
  (format nil "~{~A~^~%~}" (mapcar #'render values)))
