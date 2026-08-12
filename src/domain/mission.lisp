(in-package #:hngh.domain)

(defun ensure-nonempty-string (value name)
  (unless (and (stringp value) (plusp (length value)))
    (error "~A must be a nonempty string" name))
  (copy-seq value))

(defun ensure-label-list (value name)
  (unless (and (listp value)
               (every (lambda (item)
                        (and (stringp item) (plusp (length item))))
                      value)
               (= (length value) (length (remove-duplicates value :test #'string=))))
    (error "~A must be a duplicate-free list of nonempty strings" name))
  (mapcar #'copy-seq value))

(defstruct (mission
            (:constructor %make-mission
                (objective non-objectives source-references acceptance-criteria
                 writable-scopes verification evacuation-condition))
            (:conc-name %mission-))
  (objective nil :read-only t)
  (non-objectives nil :read-only t)
  (source-references nil :read-only t)
  (acceptance-criteria nil :read-only t)
  (writable-scopes nil :read-only t)
  (verification nil :read-only t)
  (evacuation-condition nil :read-only t))

(defun mission-objective (mission)
  (copy-seq (%mission-objective mission)))

(defun mission-writable-scopes (mission)
  (mapcar #'copy-seq (%mission-writable-scopes mission)))

(defun make-mission (&key objective non-objectives source-references
                           acceptance-criteria writable-scopes verification
                           evacuation-condition)
  (%make-mission
   (ensure-nonempty-string objective "objective")
   (ensure-label-list non-objectives "non-objectives")
   (ensure-label-list source-references "source references")
   (ensure-label-list acceptance-criteria "acceptance criteria")
   (ensure-label-list writable-scopes "writable scopes")
   (ensure-nonempty-string verification "verification")
   (ensure-nonempty-string evacuation-condition "evacuation condition")))

(defstruct (role-template
            (:constructor %make-role-template
                (name capabilities required-review-role permitted-loadout-classes))
            (:conc-name %role-template-))
  (name nil :read-only t)
  (capabilities nil :read-only t)
  (required-review-role nil :read-only t)
  (permitted-loadout-classes nil :read-only t))

(defun role-template-name (role-template)
  (copy-seq (%role-template-name role-template)))

(defun make-role-template (&key name capabilities required-review-role
                                permitted-loadout-classes)
  (%make-role-template
   (ensure-nonempty-string name "role name")
   (ensure-label-list capabilities "capabilities")
   (ensure-nonempty-string required-review-role "required review role")
   (ensure-label-list permitted-loadout-classes "permitted loadout classes")))
