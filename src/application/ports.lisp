(in-package #:hngh.application)

(defun nonempty-label-p (value)
  (and (stringp value) (plusp (length value))))

(defun copy-labels (labels name)
  (unless (and (listp labels) (every #'nonempty-label-p labels))
    (error "~A must be a list of nonempty strings" name))
  (mapcar #'copy-seq labels))

(defstruct (application-result
            (:constructor %make-application-result
                (status run receipt facts labels))
            (:conc-name %application-result-))
  (status nil :read-only t)
  (run nil :read-only t)
  (receipt nil :read-only t)
  (facts nil :read-only t)
  (labels nil :read-only t))

(defun application-result-status (result)
  (%application-result-status result))

(defun application-result-run (result)
  (%application-result-run result))

(defun application-result-receipt (result)
  (%application-result-receipt result))

(defun application-result-facts (result)
  (copy-labels (%application-result-facts result) "application result facts"))

(defun application-result-labels (result)
  (copy-labels (%application-result-labels result) "application result labels"))

(defun make-application-result (status &key run receipt facts labels)
  (unless (member status '(:accepted :refused :invalid :conflict))
    (error "unknown application status: ~S" status))
  (if (eq status :accepted)
      (unless (and run receipt)
        (error "accepted application result requires a run and receipt"))
      (when (or run receipt)
        (error "non-accepted application result cannot carry a run or receipt")))
  (%make-application-result status run receipt
                            (copy-labels facts "application result facts")
                            (copy-labels labels "application result labels")))

(defun ensure-callback (callback name)
  (unless (functionp callback)
    (error "~A must be a function" name))
  callback)

(defstruct (run-creation-ports
            (:constructor %make-run-creation-ports
                (next-identifier clock-now record-run))
            (:conc-name %run-creation-ports-))
  (next-identifier nil :read-only t)
  (clock-now nil :read-only t)
  (record-run nil :read-only t))

(defun make-run-creation-ports (&key next-identifier clock-now record-run)
  (%make-run-creation-ports
   (ensure-callback next-identifier "next identifier callback")
   (ensure-callback clock-now "clock callback")
   (ensure-callback record-run "record callback")))

(defparameter +admission-statuses+ '(:confirmed :unknown :refused))

(defun ensure-admission-status (status name)
  (unless (member status +admission-statuses+)
    (error "~A must be a known admission status" name))
  status)

(defstruct (admission-facts
            (:constructor %make-admission-facts
                (authority ledger loadout exclusive-write))
            (:conc-name %admission-facts-))
  (authority nil :read-only t)
  (ledger nil :read-only t)
  (loadout nil :read-only t)
  (exclusive-write nil :read-only t))

(defun make-admission-facts (&key authority ledger loadout exclusive-write)
  (%make-admission-facts
   (ensure-admission-status authority "authority")
   (ensure-admission-status ledger "ledger")
   (ensure-admission-status loadout "loadout")
   (ensure-admission-status exclusive-write "exclusive write")))

(defun admission-facts-authority (facts)
  (%admission-facts-authority facts))

(defun admission-facts-ledger (facts)
  (%admission-facts-ledger facts))

(defun admission-facts-loadout (facts)
  (%admission-facts-loadout facts))

(defun admission-facts-exclusive-write (facts)
  (%admission-facts-exclusive-write facts))

(defstruct (run-admission-ports
            (:constructor %make-run-admission-ports
                (admission-facts record-run))
            (:conc-name %run-admission-ports-))
  (admission-facts nil :read-only t)
  (record-run nil :read-only t))

(defun make-run-admission-ports (&key admission-facts record-run)
  (%make-run-admission-ports
   (ensure-callback admission-facts "admission facts callback")
   (ensure-callback record-run "record callback")))

(defstruct (run-start-ports
            (:constructor %make-run-start-ports (record-run))
            (:conc-name %run-start-ports-))
  (record-run nil :read-only t))

(defun make-run-start-ports (&key record-run)
  (%make-run-start-ports
   (ensure-callback record-run "record callback")))

(defparameter +verification-statuses+ '(:passed :failed :unknown))
(defparameter +manifest-statuses+ '(:complete :incomplete :unknown))

(defun ensure-result-status (status statuses name)
  (unless (member status statuses)
    (error "~A must be a known status" name))
  status)

(defun ensure-evidence-labels (labels name)
  (unless (and (consp labels) (every #'nonempty-label-p labels))
    (error "~A must be a nonempty list of nonempty strings" name))
  (mapcar #'copy-seq labels))

(defstruct (verification-result
            (:constructor %make-verification-result (status labels))
            (:conc-name %verification-result-))
  (status nil :read-only t)
  (labels nil :read-only t))

(defun make-verification-result (&key status labels)
  (%make-verification-result
   (ensure-result-status status +verification-statuses+ "verification status")
   (ensure-evidence-labels labels "verification labels")))

(defun verification-result-status (result)
  (%verification-result-status result))

(defun verification-result-labels (result)
  (ensure-evidence-labels (%verification-result-labels result) "verification labels"))

(defstruct (manifest-result
            (:constructor %make-manifest-result (status labels))
            (:conc-name %manifest-result-))
  (status nil :read-only t)
  (labels nil :read-only t))

(defun make-manifest-result (&key status labels)
  (%make-manifest-result
   (ensure-result-status status +manifest-statuses+ "manifest status")
   (ensure-evidence-labels labels "manifest labels")))

(defun manifest-result-status (result)
  (%manifest-result-status result))

(defun manifest-result-labels (result)
  (ensure-evidence-labels (%manifest-result-labels result) "manifest labels"))

(defun domain-run-p (value)
  (handler-case
      (progn (hngh.domain:run-state value) t)
    (error () nil)))

(defstruct (checkpoint-request
            (:constructor %make-checkpoint-request (run))
            (:conc-name %checkpoint-request-))
  (run nil :read-only t))

(defun make-checkpoint-request (&key run)
  (unless (domain-run-p run)
    (error "checkpoint request requires a run"))
  (%make-checkpoint-request run))

(defun checkpoint-request-run (request)
  (%checkpoint-request-run request))

(defstruct (run-checkpoint-ports
            (:constructor %make-run-checkpoint-ports
                (tool-executor repository-inspector record-run))
            (:conc-name %run-checkpoint-ports-))
  (tool-executor nil :read-only t)
  (repository-inspector nil :read-only t)
  (record-run nil :read-only t))

(defun make-run-checkpoint-ports (&key tool-executor repository-inspector record-run)
  (%make-run-checkpoint-ports
   (ensure-callback tool-executor "tool executor callback")
   (ensure-callback repository-inspector "repository inspector callback")
   (ensure-callback record-run "record callback")))

(defparameter +close-targets+ '(:cancelled :evacuated :dead))

(defun ensure-close-target (target)
  (unless (member target +close-targets+)
    (error "~A is not a close target" target))
  target)

(defun domain-proposal-p (value)
  (handler-case
      (progn (hngh.domain:policy-proposal-class value) t)
    (error () nil)))

(defstruct (close-request
            (:constructor %make-close-request (run target proposal))
            (:conc-name %close-request-))
  (run nil :read-only t)
  (target nil :read-only t)
  (proposal nil :read-only t))

(defun make-close-request (&key run target proposal)
  (unless (and (domain-run-p run) (domain-proposal-p proposal))
    (error "close request requires a domain run and a policy proposal"))
  (%make-close-request run (ensure-close-target target) proposal))

(defun close-request-run (request)
  (%close-request-run request))

(defun close-request-target (request)
  (%close-request-target request))

(defun close-request-proposal (request)
  (%close-request-proposal request))

(defstruct (run-close-ports
            (:constructor %make-run-close-ports (record-run))
            (:conc-name %run-close-ports-))
  (record-run nil :read-only t))

(defun make-run-close-ports (&key record-run)
  (%make-run-close-ports
   (ensure-callback record-run "record callback")))
