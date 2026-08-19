(in-package #:hngh.domain)

(defparameter +run-states+
  '(:created :armed :running :checkpointed :cancelled :evacuated :dead
    :afterlife :scored :archived))

(defparameter +legal-run-successors+
  '((:created :armed :cancelled :dead)
    (:armed :running :cancelled :dead)
    (:running :checkpointed :cancelled :evacuated :dead)
    (:checkpointed :running :cancelled :evacuated :dead)
    (:cancelled :afterlife)
    (:evacuated :afterlife)
    (:dead :afterlife)
    (:afterlife :scored)
    (:scored :archived)
    (:archived)))

(define-condition invalid-run-transition (error)
  ((source :initarg :source :reader invalid-run-transition-source)
   (target :initarg :target :reader invalid-run-transition-target))
  (:report (lambda (condition stream)
             (format stream "invalid run transition: ~S -> ~S"
                     (invalid-run-transition-source condition)
                     (invalid-run-transition-target condition)))))

(defstruct (run
            (:constructor %make-run (identifier mission role loadout state))
            (:conc-name %run-))
  (identifier nil :read-only t)
  (mission nil :read-only t)
  (role nil :read-only t)
  (loadout nil :read-only t)
  (state nil :read-only t))

(defun run-state (run)
  (%run-state run))

(defun run-identifier (run)
  (copy-seq (%run-identifier run)))

(defun run-mission (run)
  (%run-mission run))

(defun run-role (run)
  (%run-role run))

(defun run-loadout (run)
  (%run-loadout run))

(defun make-run (&key identifier mission role loadout)
  (unless (and (stringp identifier) (plusp (length identifier)))
    (error "run identifier must be a nonempty string"))
  (unless (mission-p mission)
    (error "run mission must be a mission"))
  (unless (role-template-p role)
    (error "run role must be a role template"))
  (unless (loadout-p loadout)
    (error "run loadout must be a loadout"))
  (%make-run (copy-seq identifier) mission role loadout :created))

(defun allowed-transition-p (source target)
  (and (not (null (member source +run-states+)))
       (not (null (member target (rest (assoc source +legal-run-successors+)))))))

(defun advance-run (run target)
  (unless (run-p run)
    (error "run transition requires a run"))
  (unless (allowed-transition-p (run-state run) target)
    (error 'invalid-run-transition :source (run-state run) :target target))
  (%make-run (%run-identifier run)
             (%run-mission run)
             (%run-role run)
             (%run-loadout run)
             target))
