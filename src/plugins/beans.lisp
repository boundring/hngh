;;;; plugins/beans.lisp — Bean Lifecycle (Wave 4)
;;;; Reuses helpers from squad-dispatch via package-qualified calls.
;;;; SPDX-License-Identifier: AGPL-3.0-or-later
;;;; SPDX-FileCopyrightText: 2026 boundring <boundring@gmail.com>
;;;; Coder — glm-5.2, Hermes harness.

(in-package :hngh.plugins.beans)

;;; --- State -----------------------------------------------------------------

(defvar *running* nil
  "Whether the beans plugin is active (no daemon in Wave 4).")

;;; --- Constants: bean types and membranes -----------------------------------

(defparameter *bean-types*
  '(:message :task :status :resource :context :review :spore)
  "The seven bean types.")

(defparameter *membrane-directives*
  '(:ingest :chew :extract :ferment)
  "Membrane processing directives.")

(defparameter *type-required-fields*
  '(:message (:priority :reply-to)
    :task (:task-id :title :acceptance :blocked-by :files)
    :status (:role :state :task-ref)
    :resource (:kind :allocation :grant-id :split)
    :context (:scope :source)
    :review (:artifact :verdict :severity :annotations)
    :spore (:spore-id :propagation-limit :sub-bean-types :parent-spore))
  "Required husk fields per bean type (only the mandatory ones are
actually enforced; the rest are optional).")

(defparameter *type-mandatory-fields*
  '(:message ()
    :task (:task-id :title :acceptance)
    :status (:role :state)
    :resource (:kind)
    :context (:scope)
    :review (:artifact :verdict)
    :spore (:spore-id :propagation-limit :sub-bean-types))
  "Fields that MUST be present for each type (hard errors).")

(defparameter *type-default-membrane*
  '(:message :ingest
    :task :chew
    :status :ingest
    :resource :extract
    :context :ingest
    :review :chew
    :spore :ferment)
  "Default membrane directive per bean type.")

;;; --- Helpers (delegating to squad-dispatch internals) ----------------------

(defun %sd (symbol)
  "Find a symbol in the squad-dispatch package."
  (find-symbol (string symbol) :hngh.plugins.squad-dispatch))

(defmacro %sd-call (symbol &rest args)
  "Call a squad-dispatch internal function."
  `(funcall (coerce ,symbol 'function) ,@args))

(defun %git (args squad-root)
  "Delegate git to squad-dispatch."
  (funcall (find-symbol "%GIT" :hngh.plugins.squad-dispatch) args squad-root))

(defun %git-or-die (args squad-root action)
  "Delegate git-or-die to squad-dispatch."
  (funcall (find-symbol "%GIT-OR-DIE" :hngh.plugins.squad-dispatch) args squad-root action))

(defun %git-commit-sha (squad-root)
  "Delegate commit-sha to squad-dispatch."
  (funcall (find-symbol "%GIT-COMMIT-SHA" :hngh.plugins.squad-dispatch) squad-root))

(defun %atomic-write (path content)
  "Delegate atomic-write to squad-dispatch."
  (funcall (find-symbol "%ATOMIC-WRITE" :hngh.plugins.squad-dispatch) path content))

(defun %format-timestamp ()
  "Delegate timestamp formatting to squad-dispatch."
  (funcall (find-symbol "%FORMAT-TIMESTAMP" :hngh.plugins.squad-dispatch)))

(defun %inbox-path (squad-root role)
  "Delegate inbox path to squad-dispatch."
  (funcall (find-symbol "%INBOX-PATH" :hngh.plugins.squad-dispatch) squad-root role))

(defun %role-dir (squad-root role)
  "Delegate role dir to squad-dispatch."
  (funcall (find-symbol "%ROLE-DIR" :hngh.plugins.squad-dispatch) squad-root role))

(defun %dispatch-path (squad-root)
  "Delegate dispatch path to squad-dispatch."
  (funcall (find-symbol "%DISPATCH-PATH" :hngh.plugins.squad-dispatch) squad-root))

(defun %parse-dispatch-md (squad-root)
  "Delegate dispatch.md parsing to squad-dispatch."
  (funcall (find-symbol "%PARSE-DISPATCH-MD" :hngh.plugins.squad-dispatch) squad-root))

(defun %rewrite-dispatch-md (squad-root parsed)
  "Delegate dispatch.md rewriting to squad-dispatch."
  (funcall (find-symbol "%REWRITE-DISPATCH-MD" :hngh.plugins.squad-dispatch) squad-root parsed))

(defun %get-lock (squad-root)
  "Delegate lock acquisition to squad-dispatch."
  (funcall (find-symbol "%GET-LOCK" :hngh.plugins.squad-dispatch) squad-root))

(defmacro with-squad-lock ((squad-root) &body body)
  "Execute BODY while holding the per-squad mutex."
  `(bt:with-lock-held ((%get-lock ,squad-root))
     ,@body))

(defun %parse-bean-section (section-text)
  "Parse a bean section (text between --- delimiters) into a plist.
Extends squad-dispatch's parser with membrane, expires, lifecycle, and
type-specific fields."
  (let* ((lines (cl-ppcre:split "\\r?\\n" section-text))
         (husk-lines '())
         (body-lines '())
         (in-husk t))
    (loop for line in lines
          do
          (if in-husk
              (if (string= line "")
                  (progn
                    (setf in-husk nil)
                    (push line body-lines))
                  (push line husk-lines))
              (push line body-lines)))
    (setf husk-lines (nreverse husk-lines)
          body-lines (nreverse body-lines))
    ;; Parse husk key: value pairs — collect known fields and type-fields
    (let ((bean nil)
          (from nil)
          (to nil)
          (planted nil)
          (type nil)
          (status nil)
          (expires nil)
          (membrane nil)
          (lifecycle nil)
          (type-fields '())
          (known-keys '("bean" "from" "to" "planted" "type" "status"
                        "expires" "membrane" "lifecycle"))
          (multiline-key nil)
          (multiline-lines '()))
      (flet ((flush-multiline ()
               (when (and multiline-key multiline-lines)
                 (let ((ml-val (format nil "~{~A~^~%~}" (nreverse multiline-lines))))
                   (setf (getf type-fields
                              (intern (string-upcase multiline-key) :keyword))
                         ml-val)))
               (setf multiline-key nil
                     multiline-lines '())))
        (dolist (hl husk-lines)
          (cond
            ;; Multi-line value continuation (we're inside a | block)
            ((and multiline-key
                  (or (string= hl "")
                      (and (> (length hl) 0)
                           (char= (char hl 0) #\Space))))
             (push (string-trim '(#\Space #\Tab) hl) multiline-lines))
            ;; key: value line
            (t
             (when multiline-key
               (flush-multiline))
             (let ((colon-pos (position #\: hl)))
               (when (and colon-pos (> (length hl) colon-pos))
                 (let* ((key (string-trim '(#\Space #\Tab) (subseq hl 0 colon-pos)))
                        (val (string-trim '(#\Space #\Tab) (subseq hl (1+ colon-pos)))))
                   (cond
                     ((string= val "|")
                      ;; Start multi-line block
                      (setf multiline-key key))
                     ((string= key "bean") (setf bean val))
                     ((string= key "from") (setf from val))
                     ((string= key "to") (setf to val))
                     ((string= key "planted") (setf planted val))
                     ((string= key "type") (setf type val))
                     ((string= key "status") (setf status val))
                     ((string= key "lifecycle") (setf lifecycle val))
                     ((string= key "expires")
                      (setf expires (unless (string= val "") val)))
                     ((string= key "membrane")
                      (setf membrane (unless (string= val "") val)))
                     ((member key known-keys :test #'string=))
                     (t
                      ;; Type-specific field
                      (setf (getf type-fields
                                 (intern (string-upcase key) :keyword))
                            val)))))))))
        (when multiline-key
          (flush-multiline)))
      ;; Body content: skip leading empty lines
      (let ((body-start 0))
        (loop for line in body-lines
              while (string= line "")
              do (incf body-start))
        (let ((content
               (with-output-to-string (out)
                 (loop for line in (nthcdr body-start body-lines)
                       for first = t then nil
                       do (if first
                              (write-string line out)
                              (progn (write-char #\Newline out)
                                    (write-string line out)))))))
          (list :bean bean
                :from from
                :to to
                :planted planted
                :type type
                :status (or status lifecycle)
                :expires expires
                :membrane membrane
                :content content
                :type-fields type-fields))))))

(defun %parse-inbox (content)
  "Parse inbox.md content into a list of bean plists."
  (let* ((sections (cl-ppcre:split "\\n---\\n" content))
         (beans '()))
    (let ((start-idx (if (and sections (string= (first sections) ""))
                         1 0)))
      (loop for i from start-idx below (length sections) by 2
            for husk = (nth i sections)
            for body = (nth (1+ i) sections)
            when husk
              do
              (let ((bean-plist (%parse-bean-section
                                 (if body
                                     (format nil "~A~%~A" husk body)
                                     husk))))
                (push bean-plist beans))))
    (nreverse beans)))

(defun %format-bean-husk (bean-plist)
  "Format a bean plist as a markdown bean section for inbox.md.
Writes husk (front matter between --- delimiters) + core (body)."
  (with-output-to-string (out)
    ;; Opening delimiter
    (write-string "---" out)
    (write-char #\Newline out)
    ;; Common husk fields
    (format out "bean: ~A~%" (or (getf bean-plist :bean) ""))
    (format out "from: ~A~%" (or (getf bean-plist :from) ""))
    (format out "to: ~A~%" (or (getf bean-plist :to) ""))
    (format out "planted: ~A~%" (or (getf bean-plist :planted) ""))
    (format out "type: ~A~%" (or (getf bean-plist :type) ""))
    (format out "status: ~A~%" (or (getf bean-plist :status) "planted"))
    ;; lifecycle alias
    (format out "lifecycle: ~A~%" (or (getf bean-plist :status) "planted"))
    ;; expires (if present)
    (when (getf bean-plist :expires)
      (format out "expires: ~A~%" (getf bean-plist :expires)))
    ;; membrane (if present)
    (when (getf bean-plist :membrane)
      (format out "membrane: ~A~%" (getf bean-plist :membrane)))
    ;; Type-specific fields
    (let ((tf (getf bean-plist :type-fields)))
      (loop for (key val) on tf by #'cddr
            do
            (format out "~A: ~A~%"
                    (string-downcase key)
                    (if (stringp val) val (princ-to-string val)))))
    ;; Closing delimiter
    (write-string "---" out)
    (write-char #\Newline out)
    (write-char #\Newline out)
    ;; Core body
    (write-string (or (getf bean-plist :content) "") out)
    (write-char #\Newline out)))

(defun %rewrite-inbox-section (inbox-path bean-name new-status
                                &optional extra-fields)
  "Read inbox.md, find the bean matching bean-name, update its status
(and any extra-fields), rewrite the file atomically. Returns the
updated bean plist."
  (let* ((content (handler-case
                      (uiop:read-file-string inbox-path)
                    (error () "")))
         (beans (%parse-inbox content))
         (target-bean
          (find bean-name beans
                :key (lambda (b) (getf b :bean))
                :test #'string=)))
    (unless target-bean
      (return-from %rewrite-inbox-section nil))
    (setf (getf target-bean :status) new-status)
    (when extra-fields
      (loop for (key val) on extra-fields by #'cddr
            do (setf (getf target-bean key) val)))
    ;; Rebuild inbox content
    (let ((new-content
           (with-output-to-string (out)
             (dolist (bean beans)
               (if (string= (getf bean :bean) bean-name)
                   (write-string (%format-bean-husk target-bean) out)
                   (write-string (%format-bean-husk bean) out))))))
      (%atomic-write inbox-path new-content))
    target-bean))

(defun %update-dispatch-comm-status (squad-root bean-name role new-status)
  "Update the Communications table in dispatch.md for a specific bean."
  (let ((parsed (%parse-dispatch-md squad-root)))
    (setf (getf parsed :communications)
          (loop for c in (getf parsed :communications)
                collect (if (and (string= (getf c :bean) bean-name)
                                 (string= (getf c :to)
                                          (string-downcase role)))
                            (progn
                              (setf (getf c :status) new-status)
                              c)
                            c)))
    (%rewrite-dispatch-md squad-root parsed)))

(defun %remove-dispatch-comm (squad-root bean-name role)
  "Remove a bean's row from the Communications table in dispatch.md."
  (let ((parsed (%parse-dispatch-md squad-root)))
    (setf (getf parsed :communications)
          (remove-if (lambda (c)
                       (and (string= (getf c :bean) bean-name)
                            (string= (getf c :to)
                                     (string-downcase role))))
                     (getf parsed :communications)))
    (%rewrite-dispatch-md squad-root parsed)))

(defun %find-role-dirs (squad-root)
  "Return list of role keywords for all role directories under squad-root."
  (let ((dirs '()))
    (uiop:collect-sub*directories
     squad-root t nil
     (lambda (dir)
       ;; A role dir has inbox.md in it
       (when (probe-file (merge-pathnames "inbox.md" dir))
         (let* ((name (car (last (pathname-directory dir))))
                (kw (when name (intern (string-upcase name) :keyword))))
           (when kw
             (push kw dirs))))))
    (nreverse dirs)))

(defun %parse-iso-8601 (str)
  "Parse a minimal ISO-8601 timestamp like 2026-08-03T12:30:00.
Returns a universal-time integer, or nil if unparseable."
  (when (and str (> (length str) 0))
    (multiple-value-bind (match groups)
        (cl-ppcre:scan-to-strings
         "^(\\d{4})-(\\d{2})-(\\d{2})T(\\d{2}):(\\d{2}):(\\d{2})"
         str)
      (declare (ignore match))
      (when groups
        (handler-case
            (let ((y (parse-integer (aref groups 0) :junk-allowed t))
                  (mo (parse-integer (aref groups 1) :junk-allowed t))
                  (d (parse-integer (aref groups 2) :junk-allowed t))
                  (h (parse-integer (aref groups 3) :junk-allowed t))
                  (mi (parse-integer (aref groups 4) :junk-allowed t))
                  (s (parse-integer (aref groups 5) :junk-allowed t)))
              (encode-universal-time s mi h d mo y))
          (error () nil))))))

(defun %keyword-to-string-downcase (kw)
  "Convert a keyword to a downcased string."
  (string-downcase (string kw)))

;;; --- Validation helpers ---------------------------------------------------

(defun %validate-bean-type (type)
  "Validate TYPE is one of the 7 known types."
  (unless (member type *bean-types*)
    (error "Unknown bean type: ~A" type)))

(defun %validate-membrane (membrane)
  "Validate MEMBRANE is one of the known directives."
  (unless (member membrane *membrane-directives*)
    (error "Unknown membrane: ~A" membrane)))

(defun %validate-type-fields (type type-fields)
  "Validate that type-fields contains the mandatory fields for TYPE."
  (let ((mandatory (getf *type-mandatory-fields* type)))
    (dolist (field mandatory)
      (unless (getf type-fields field)
        (error "Bean type ~A requires field ~A" type field)))))

(defun %validate-spore-fields (type-fields)
  "Validate spore-specific constraints. Logs warning for high limits."
  (let* ((limit-val (getf type-fields :propagation-limit))
         (limit (if (stringp limit-val)
                    (or (parse-integer limit-val :junk-allowed t) 0)
                    limit-val)))
    (cond
      ((null limit)
       (error "Bean type ~A requires field ~A" :spore :propagation-limit))
      ((not (integerp limit))
       (error "Spore propagation-limit must be a positive integer"))
      ((<= limit 0)
       (error "Spore propagation-limit must be a positive integer"))
      ((> limit 10)
       (hngh.core:log-warn
        "spore propagation-limit > 10 is dangerous")))))

;;; --- Spore sub-bean specification parser ---------------------------------

(defun %parse-spore-block (output)
  "Parse a ```spore ... ``` code block from OUTPUT.
Returns a list of plists, each with :bean, :to, :type, :content,
:membrane, :type-fields."
  (let ((start (cl-ppcre:scan "```spore" output)))
    (unless start
      (return-from %parse-spore-block nil))
    (let* ((after-start (+ start (length "```spore")))
           (end (cl-ppcre:scan "```" output :start after-start)))
      (unless end
        (return-from %parse-spore-block nil))
      (let ((block-text (subseq output after-start end))
            (specs '())
            (current-spec nil)
            (in-type-fields nil))
        (dolist (line (cl-ppcre:split "\\r?\\n" block-text))
          (cond
            ;; Start of a new spec entry
            ((cl-ppcre:scan "^-\\s+" line)
             (when current-spec
               (push current-spec specs))
             (setf current-spec nil
                   in-type-fields nil)
             (let ((rest (cl-ppcre:regex-replace "^-\\s+" line "")))
               (setf current-spec (%parse-kv-line rest))))
            ;; Inside type-fields (indented under a type-fields: header)
            ((and in-type-fields
                  (or (= (length line) 0)
                      (and (> (length line) 0)
                           (char= (char line 0) #\Space))))
             (when (> (length line) 0)
               (let ((kv (%parse-kv-line (string-trim '(#\Space #\Tab) line))))
                 (when kv
                   (let ((key (first kv))
                         (val (second kv)))
                     (setf (getf (getf current-spec :type-fields)
                                (intern (string-upcase key) :keyword))
                           val))))))
            ;; key: value line (could be start of type-fields section)
            ((and current-spec
                  (cl-ppcre:scan "^\\s*\\w[\\w-]*:\\s" line))
             (let ((kv (%parse-kv-line (string-trim '(#\Space #\Tab) line))))
               (when kv
                 (let ((key (first kv))
                       (val (second kv)))
                   (cond
                     ((string= key "type-fields")
                      (setf in-type-fields t))
                     (t
                      (setf in-type-fields nil)
                      (setf (getf current-spec
                                 (intern (string-upcase key) :keyword))
                            val)))))))
            ;; Empty line or other — skip
            (t nil)))
        (when current-spec
          (push current-spec specs))
        (nreverse specs)))))

(defun %parse-kv-line (line)
  "Parse a 'key: value' line, returning (key value) or nil."
  (let ((colon-pos (position #\: line)))
    (when (and colon-pos (> (length line) (1+ colon-pos)))
      (let* ((key (string-trim '(#\Space #\Tab) (subseq line 0 colon-pos)))
             (val (string-trim '(#\Space #\Tab) (subseq line (1+ colon-pos)))))
        ;; Remove surrounding quotes from value
        (when (and (> (length val) 1)
                   (char= (char val 0) #\")
                   (char= (char val (1- (length val))) #\"))
          (setf val (subseq val 1 (1- (length val)))))
        (list key val)))))

;;; --- Internal: %ripen-bean ------------------------------------------------

(defun %ripen-bean (squad-root role bean-name)
  "Transition a growing bean to ripe. Internal, not exported."
  (let ((inbox-path (%inbox-path squad-root role)))
    (%rewrite-inbox-section inbox-path bean-name "ripe")))

;;; --- Internal: %propagate-spore --------------------------------------------

(defun %propagate-spore (squad-root role bean-name spore-fields output)
  "Parse the spore output for sub-bean specifications and plant them.
Returns propagation result plist."
  (let* ((spore-id (getf spore-fields :spore-id))
         (limit-val (getf spore-fields :propagation-limit))
         (limit (if (stringp limit-val)
                    (or (parse-integer limit-val :junk-allowed t) 0)
                    (or limit-val 0)))
         (sub-bean-types-str (getf spore-fields :sub-bean-types))
         (parent-spore (getf spore-fields :parent-spore))
         (sub-specs (%parse-spore-block output))
         (sub-bean-count (length sub-specs))
         (planted-beans '())
         (feral nil)
         (feral-reason nil))
    ;; Check propagation limit
    (when (> sub-bean-count limit)
      ;; Mark spore as feral
      (let ((inbox-path (%inbox-path squad-root role)))
        (%rewrite-inbox-section inbox-path bean-name "feral"))
      (%update-dispatch-comm-status squad-root bean-name role "feral")
      (%git-or-die (list "add" "-A") squad-root "stage")
      (%git-or-die (list "commit" "-m"
                         (format nil "[bean] ~A feral: ~A (propagation limit exceeded)"
                                 (string-downcase role) bean-name))
                   squad-root "commit")
      (error "Spore ~A exceeded propagation-limit of ~D (attempted ~D sub-beans)"
             spore-id limit sub-bean-count))
    ;; Parse sub-bean-types as a list
    (let ((allowed-types
           (when sub-bean-types-str
             (mapcar (lambda (s)
                       (intern (string-upcase
                                (string-trim '(#\Space) s))
                              :keyword))
                     (cl-ppcre:split "," sub-bean-types-str)))))
      ;; Check propagation depth
      (when parent-spore
        (let ((depth (%count-spore-depth squad-root parent-spore)))
          (when (> depth 5)
            (let ((inbox-path (%inbox-path squad-root role)))
              (%rewrite-inbox-section inbox-path bean-name "feral"))
            (%update-dispatch-comm-status squad-root bean-name role "feral")
            (setf feral t
                  feral-reason "chain depth exceeded 5"))))
      ;; Plant each sub-bean
      (unless feral
        (dolist (spec sub-specs)
          (let* ((sub-bean-name (getf spec :bean))
                 (sub-to (when (getf spec :to)
                           (intern (string-upcase (getf spec :to)) :keyword)))
                 (sub-type (when (getf spec :type)
                            (intern (string-upcase (getf spec :type)) :keyword)))
                 (sub-content (getf spec :content))
                 (sub-membrane (if (getf spec :membrane)
                                  (intern (string-upcase (getf spec :membrane)) :keyword)
                                  :ingest))
                 (sub-type-fields (getf spec :type-fields)))
            ;; Validate target role exists
            (unless (probe-file (%role-dir squad-root sub-to))
              (setf feral t
                    feral-reason (format nil "sub-bean ~A targets unknown role ~A"
                                         sub-bean-name sub-to))
              (return))
            ;; Validate type is in allowed list
            (when (and allowed-types
                       (not (member sub-type allowed-types)))
              (setf feral t
                    feral-reason (format nil "sub-bean ~A type ~A not in allowed types"
                                         sub-bean-name sub-type))
              (return))
            ;; Set parent-spore
            (setf (getf sub-type-fields :parent-spore) spore-id)
            ;; Plant the sub-bean
            (plant-bean squad-root role sub-to sub-bean-name
                        :type sub-type
                        :content sub-content
                        :membrane sub-membrane
                        :type-fields sub-type-fields)
            (push (list :bean sub-bean-name
                        :to sub-to
                        :type sub-type
                        :planted t)
                  planted-beans)))))
    ;; If feral was detected during planting, mark the spore
    (when feral
      (let ((inbox-path (%inbox-path squad-root role)))
        (%rewrite-inbox-section inbox-path bean-name "feral"))
      (%update-dispatch-comm-status squad-root bean-name role "feral"))
    (list :spore-id spore-id
          :sub-beans (nreverse planted-beans)
          :sub-bean-count (length planted-beans)
          :feral feral
          :feral-reason feral-reason)))

(defun %count-spore-depth (squad-root spore-id)
  "Count the depth of the spore propagation chain by following
parent-spore links. Returns integer depth (0 for root spores)."
  (let ((depth 0)
        (current-id spore-id))
    (loop
      (let ((parent nil))
        ;; Scan all inboxes for a bean with spore-id = current-id
        (dolist (role-kw (%find-role-dirs squad-root))
          (let* ((inbox-content
                  (handler-case
                      (uiop:read-file-string (%inbox-path squad-root role-kw))
                    (error () "")))
                 (beans (%parse-inbox inbox-content)))
            (dolist (bean beans)
              (let ((tf (getf bean :type-fields)))
                (when (and (getf tf :spore-id)
                           (string= (getf tf :spore-id) current-id))
                  (setf parent (getf tf :parent-spore)))))))
        (if (and parent (> (length parent) 0))
            (progn
              (setf current-id parent)
              (incf depth))
            (return))))
    depth))

;;; --- Internal: %track-spore-propagation ------------------------------------

(defun %track-spore-propagation (squad-root spore-id)
  "Track spore propagation across all role inboxes.
Returns propagation record plist."
  (let ((sub-beans '())
        (limit nil)
        (depth 0))
    (dolist (role-kw (%find-role-dirs squad-root))
      (let* ((inbox-content
              (handler-case
                  (uiop:read-file-string (%inbox-path squad-root role-kw))
                (error () "")))
             (beans (%parse-inbox inbox-content)))
        (dolist (bean beans)
          (let ((tf (getf bean :type-fields)))
            (when (and (getf tf :parent-spore)
                       (string= (getf tf :parent-spore) spore-id))
              (push (list :bean (getf bean :bean)
                          :role role-kw
                          :type (getf bean :type))
                    sub-beans))
            (when (and (getf tf :spore-id)
                       (string= (getf tf :spore-id) spore-id))
              (setf limit (getf tf :propagation-limit)))))))
    (setf depth (%count-spore-depth squad-root spore-id))
    (list :spore-id spore-id
          :sub-beans (nreverse sub-beans)
          :count (length sub-beans)
          :limit (or limit 10)
          :depth depth
          :exceeded-limit (and limit (> (length sub-beans) limit))
          :exceeded-depth (> depth 5))))

;;; --- Public API: plant-bean (extended) -------------------------------------

(defun plant-bean (squad-root from to bean-name &key
                                         (type :message)
                                         (content "")
                                         (membrane nil)
                                         (expires nil)
                                         (type-fields nil)
                                         (model-config nil))
  "Plant a bean in the recipient's inbox with type-awareness, membrane
directive, and lifecycle state. Returns plist.
Cross-role exchange: any role can plant in any other role's inbox."
  (declare (ignore model-config))
  ;; Validate
  (%validate-bean-type type)
  (let ((effective-membrane
           (or membrane (getf *type-default-membrane* type))))
      (%validate-membrane effective-membrane)
      (%validate-type-fields type type-fields)
      (when (eq type :spore)
        (%validate-spore-fields type-fields))
      (unless (probe-file squad-root)
        (error "Squad root does not exist: ~A" squad-root))
      (let ((recipient-dir (%role-dir squad-root to)))
        (unless (probe-file recipient-dir)
          (error "Unknown role: ~A" to)))
      (let* ((inbox-path (%inbox-path squad-root to))
             (timestamp (%format-timestamp))
             ;; Determine initial lifecycle state
             (initial-status (if (and content (> (length content) 0))
                                 "ripe"
                                 "growing")))
        ;; Build bean plist for formatting
        (let ((bean-plist
               (list :bean bean-name
                     :from (string-downcase from)
                     :to (string-downcase to)
                     :planted timestamp
                     :type (string-downcase type)
                     :status initial-status
                     :expires expires
                     :membrane (string-downcase effective-membrane)
                     :content content
                     :type-fields type-fields)))
          ;; Format and append to inbox
          (let ((bean-section (%format-bean-husk bean-plist))
                (existing-content
                 (handler-case
                     (uiop:read-file-string inbox-path)
                   (error () ""))))
            (%atomic-write inbox-path
                           (if (string= existing-content "")
                               bean-section
                               (concatenate 'string existing-content bean-section
                                            "\n"))))
          ;; Update dispatch.md Communications table
          (let ((parsed (%parse-dispatch-md squad-root)))
            (setf (getf parsed :communications)
                  (append (getf parsed :communications)
                          (list (list :from (string-downcase from)
                                     :to (string-downcase to)
                                     :bean bean-name
                                     :status initial-status))))
            (%rewrite-dispatch-md squad-root parsed))
          ;; Stage and commit
          (%git-or-die (list "add" "-A") squad-root "stage")
          (%git-or-die (list "commit" "-m"
                             (format nil "[bean] ~A -> ~A: ~A (~A)"
                                     (string-downcase from)
                                     (string-downcase to)
                                     bean-name
                                     (string-downcase type)))
                       squad-root "commit"))
        (list :squad-root squad-root
              :bean bean-name
              :from from
              :to to
              :type type
              :membrane effective-membrane
              :status initial-status
              :commit-sha (%git-commit-sha squad-root)))))
;;; --- Public API: harvest-bean (extended) -----------------------------------

(defun harvest-bean (squad-root role bean-name)
  "Harvest a bean from the role's inbox. Type-aware: reads membrane
and type-fields from the husk. Calls check-bean-staleness before
harvesting."
  (unless (probe-file squad-root)
    (error "Squad root does not exist: ~A" squad-root))
  (let ((role-dir (%role-dir squad-root role)))
    (unless (probe-file role-dir)
      (error "Unknown role: ~A" role)))
  (let ((inbox-path (%inbox-path squad-root role)))
    ;; Check staleness first
    (let ((staleness (check-bean-staleness squad-root role bean-name)))
      (when (getf staleness :stale)
        (error "Bean ~A is spoiled — cannot harvest. Run cull-spoiled-beans to clean up."
               bean-name)))
    (let* ((content (handler-case
                        (uiop:read-file-string inbox-path)
                      (error () "")))
           (beans (%parse-inbox content))
           (target-bean
            (find bean-name beans
                  :key (lambda (b) (getf b :bean))
                  :test #'string=)))
      (unless target-bean
        (error "Bean ~A not found in ~A inbox" bean-name role))
      (let ((status (getf target-bean :status)))
        (cond
          ((string= status "harvested")
           (error "Bean ~A already harvested" bean-name))
          ((string= status "growing")
           (error "Bean ~A is still growing — not yet ripe for harvest." bean-name))
          ((string= status "spoiled")
           (error "Bean ~A is spoiled — cannot harvest." bean-name))
          ((string= status "feral")
           (error "Bean ~A is feral — propagation halted." bean-name))))
      ;; Validate recipient
      (unless (string= (getf target-bean :to)
                       (string-downcase role))
        (error "Bean ~A is not addressed to ~A" bean-name role))
      ;; Mark as harvested
      (setf (getf target-bean :status) "harvested")
      (let ((new-content
             (with-output-to-string (out)
               (dolist (bean beans)
                 (write-string
                  (if (string= (getf bean :bean) bean-name)
                      (%format-bean-husk target-bean)
                      (%format-bean-husk bean))
                  out)))))
        (%atomic-write inbox-path new-content))
      ;; Update dispatch.md
      (%update-dispatch-comm-status squad-root bean-name role "harvested")
      ;; Stage and commit
      (%git-or-die (list "add" "-A") squad-root "stage")
      (%git-or-die (list "commit" "-m"
                         (format nil "[bean] ~A harvested: ~A"
                                 (string-downcase role) bean-name))
                   squad-root "commit")
      (list :squad-root squad-root
            :bean bean-name
            :role role
            :content (getf target-bean :content)
            :type (getf target-bean :type)
            :membrane (getf target-bean :membrane)
            :type-fields (getf target-bean :type-fields)
            :commit-sha (%git-commit-sha squad-root)))))

;;; --- Public API: digest-bean -----------------------------------------------

(defun digest-bean (squad-root role bean-name &key
                                       (output "")
                                       (output-path nil)
                                       (attribution ""))
  "Process a harvested bean. Marks digested, triggers husk-bean.
For spore beans, triggers spore propagation."
  (unless (probe-file squad-root)
    (error "Squad root does not exist: ~A" squad-root))
  (let ((inbox-path (%inbox-path squad-root role)))
    (let* ((content (handler-case
                        (uiop:read-file-string inbox-path)
                      (error () "")))
           (beans (%parse-inbox content))
           (target-bean
            (find bean-name beans
                  :key (lambda (b) (getf b :bean))
                  :test #'string=)))
      (unless target-bean
        (error "Bean ~A not found in ~A inbox" bean-name role))
      (let ((status (getf target-bean :status)))
        (cond
          ((string= status "digested")
           (error "Bean ~A already digested" bean-name))
          ((string= status "husked")
           (error "Bean ~A already husked" bean-name))
          ((not (string= status "harvested"))
           (error "Bean ~A must be harvested before digestion (current status: ~A)"
                  bean-name status))))
      ;; Mark as digested
      (%rewrite-inbox-section inbox-path bean-name "digested")
      (%update-dispatch-comm-status squad-root bean-name role "digested")
      ;; Write output to file if path provided
      (when output-path
        (%atomic-write output-path output))
      ;; Spore propagation
      (let ((spore-result nil))
        (when (string= (getf target-bean :type) "spore")
          (setf spore-result
                (%propagate-spore squad-root role bean-name
                                 (getf target-bean :type-fields)
                                 output)))
        ;; Call husk-bean
        (husk-bean squad-root role bean-name
                   :output output
                   :output-path output-path
                   :attribution attribution)
        ;; Stage and commit
        (%git-or-die (list "add" "-A") squad-root "stage")
        (let ((commit-msg
               (if (and spore-result (> (getf spore-result :sub-bean-count) 0))
                   (format nil "[bean] ~A digested: ~A (spore: ~D sub-beans)"
                           (string-downcase role) bean-name
                           (getf spore-result :sub-bean-count))
                   (format nil "[bean] ~A digested: ~A"
                           (string-downcase role) bean-name))))
          (%git-or-die (list "commit" "-m" commit-msg)
                       squad-root "commit"))
        (list :squad-root squad-root
              :bean bean-name
              :role role
              :output output
              :output-path output-path
              :spore-result spore-result
              :commit-sha (%git-commit-sha squad-root))))))

;;; --- Public API: husk-bean -------------------------------------------------

(defun husk-bean (squad-root role bean-name &key
                                       (output "")
                                       (output-path nil)
                                       (attribution ""))
  "Write the husk entry to journal/actual.md and mark bean as husked."
  (unless (probe-file squad-root)
    (error "Squad root does not exist: ~A" squad-root))
  (let ((inbox-path (%inbox-path squad-root role)))
    (let* ((content (handler-case
                        (uiop:read-file-string inbox-path)
                      (error () "")))
           (beans (%parse-inbox content))
           (target-bean
            (find bean-name beans
                  :key (lambda (b) (getf b :bean))
                  :test #'string=)))
      (unless target-bean
        (error "Bean ~A not found in ~A inbox" bean-name role))
      (let ((status (getf target-bean :status)))
        (cond
          ((string= status "husked")
           (error "Bean ~A already husked" bean-name))
          ((not (string= status "digested"))
           (error "Bean ~A must be digested before husking (current status: ~A)"
                  bean-name status))))
      ;; Format husk entry
      (let* ((timestamp (%format-timestamp))
             (output-summary
              (if (> (length output) 500)
                  (subseq output 0 500)
                  output))
             (husk-entry
              (with-output-to-string (out)
                (write-string "---" out)
                (write-char #\Newline out)
                (format out "bean: ~A~%" bean-name)
                (format out "type: ~A~%" (or (getf target-bean :type) ""))
                (format out "from: ~A~%" (or (getf target-bean :from) ""))
                (format out "to: ~A~%" (or (getf target-bean :to) ""))
                (format out "planted: ~A~%" (or (getf target-bean :planted) ""))
                (format out "digested: ~A~%" timestamp)
                (format out "membrane: ~A~%" (or (getf target-bean :membrane) ""))
                (format out "attribution: ~A~%" attribution)
                (format out "output-path: ~A~%"
                        (if output-path
                            (namestring output-path)
                            ""))
                (write-string "---" out)
                (write-char #\Newline out)
                (write-char #\Newline out)
                (format out "Digested ~A (~A bean from ~A). ~A~%"
                        bean-name
                        (or (getf target-bean :type) "")
                        (or (getf target-bean :from) "")
                        output-summary))))
        ;; Append to journal/actual.md
        (let ((journal-path (merge-pathnames "journal/actual.md" squad-root)))
          (ensure-directories-exist
           (make-pathname :directory (pathname-directory journal-path)))
          (let ((journal-content
                 (handler-case
                     (uiop:read-file-string journal-path)
                   (error () ""))))
            (%atomic-write journal-path
                          (if (string= journal-content "")
                              husk-entry
                              (concatenate 'string journal-content husk-entry))))
          ;; Mark bean as husked in inbox
          (%rewrite-inbox-section inbox-path bean-name "husked")
          (%update-dispatch-comm-status squad-root bean-name role "husked")
          (list :squad-root squad-root
                :bean bean-name
                :role role
                :journal-path journal-path
                :husk-entry husk-entry
                :commit-sha nil))))))

;;; --- Public API: read-bean -------------------------------------------------

(defun read-bean (squad-root role bean-name)
  "Read a bean from the role's inbox without changing its state.
Returns the full parsed bean plist."
  (unless (probe-file squad-root)
    (error "Squad root does not exist: ~A" squad-root))
  (let ((inbox-path (%inbox-path squad-root role)))
    (let* ((content (handler-case
                        (uiop:read-file-string inbox-path)
                      (error () "")))
           (beans (%parse-inbox content))
           (target-bean
            (find bean-name beans
                  :key (lambda (b) (getf b :bean))
                  :test #'string=)))
      (unless target-bean
        (error "Bean ~A not found in ~A inbox" bean-name role))
      target-bean)))

;;; --- Public API: check-bean-staleness --------------------------------------

(defun check-bean-staleness (squad-root role bean-name)
  "Check if a bean has expired. If expired, mark it as spoiled.
Returns plist: (:stale :reason :expires :commit-sha)."
  (unless (probe-file squad-root)
    (error "Squad root does not exist: ~A" squad-root))
  (let ((inbox-path (%inbox-path squad-root role)))
    (let* ((content (handler-case
                        (uiop:read-file-string inbox-path)
                      (error () "")))
           (beans (%parse-inbox content))
           (target-bean
            (find bean-name beans
                  :key (lambda (b) (getf b :bean))
                  :test #'string=)))
      (unless target-bean
        (return-from check-bean-staleness
          (list :stale nil :reason "bean not found")))
      (let ((status (getf target-bean :status))
            (expires (getf target-bean :expires)))
        ;; Already spoiled or feral
        (cond
          ((string= status "spoiled")
           (return-from check-bean-staleness
             (list :stale t :reason "already spoiled" :expires expires)))
          ((string= status "feral")
           (return-from check-bean-staleness
             (list :stale t :reason "already feral" :expires expires))))
        ;; Already consumed
        (when (or (string= status "digested")
                  (string= status "husked"))
          (return-from check-bean-staleness
            (list :stale nil)))
        ;; No expires field
        (unless expires
          (return-from check-bean-staleness
            (list :stale nil)))
        ;; Compare timestamps
        (let ((expires-ut (%parse-iso-8601 expires))
              (now (get-universal-time)))
          (cond
            ((null expires-ut)
             (return-from check-bean-staleness
               (list :stale nil :reason "unparseable expires")))
            ((> now expires-ut)
             ;; Bean is spoiled!
             (%rewrite-inbox-section inbox-path bean-name "spoiled")
             (%update-dispatch-comm-status squad-root bean-name role "spoiled")
             (%git-or-die (list "add" "-A") squad-root "stage")
             (%git-or-die (list "commit" "-m"
                                (format nil "[bean] ~A spoiled: ~A (expired ~A)"
                                        (string-downcase role) bean-name expires))
                          squad-root "commit")
             (list :stale t :reason "expired" :expires expires
                   :commit-sha (%git-commit-sha squad-root)))
            (t
             (list :stale nil))))))))

;;; --- Public API: cull-spoiled-beans ----------------------------------------

(defun cull-spoiled-beans (squad-root &key
                                        (role nil)
                                        (feral-only nil)
                                        (dry-run nil))
  "Identify and remove spoiled (or feral) beans from inboxes."
  (unless (probe-file squad-root)
    (error "Squad root does not exist: ~A" squad-root))
  (let* ((roles-to-scan (if role
                           (list role)
                           (%find-role-dirs squad-root)))
         (culled '()))
    (dolist (role-kw roles-to-scan)
      (let ((inbox-path (%inbox-path squad-root role-kw)))
        (when (probe-file inbox-path)
          ;; First, run staleness checks on all non-digested beans
          (let* ((content (handler-case
                              (uiop:read-file-string inbox-path)
                            (error () "")))
                 (beans (%parse-inbox content)))
            ;; Check staleness for each bean (unless feral-only)
            (unless feral-only
              (dolist (bean beans)
                (let ((status (getf bean :status)))
                  (unless (or (string= status "digested")
                              (string= status "husked")
                              (string= status "spoiled")
                              (string= status "feral"))
                    (check-bean-staleness squad-root role-kw
                                         (getf bean :bean))))))
            ;; Re-read inbox after staleness checks
            (setf content (handler-case
                              (uiop:read-file-string inbox-path)
                            (error () "")))
            (setf beans (%parse-inbox content))
            ;; Collect spoiled/feral beans
            (dolist (bean beans)
              (let ((status (getf bean :status)))
                (when (or (and (not feral-only) (string= status "spoiled"))
                          (string= status "feral"))
                  (push (list :role role-kw
                             :bean (getf bean :bean)
                             :type (getf bean :type)
                             :state status
                             :reason (if (string= status "spoiled")
                                        "expired"
                                        "feral"))
                        culled)))))
          ;; Remove culled beans from inbox (unless dry-run)
          (when (and culled (not dry-run))
            (let* ((content (handler-case
                               (uiop:read-file-string inbox-path)
                             (error () "")))
                   (beans (%parse-inbox content))
                   (culled-names (mapcar (lambda (c) (getf c :bean))
                                         (remove-if-not
                                          (lambda (c) (eq (getf c :role) role-kw))
                                          culled)))
                   (remaining
                    (remove-if (lambda (bean)
                                (member (getf bean :bean) culled-names
                                        :test #'string=))
                              beans)))
              (let ((new-content
                     (with-output-to-string (out)
                       (dolist (bean remaining)
                         (write-string (%format-bean-husk bean) out)))))
                (%atomic-write inbox-path new-content))
              ;; Remove from dispatch.md
              (dolist (bn culled-names)
                (%remove-dispatch-comm squad-root bn role-kw)))))))
    (setf culled (nreverse culled))
    (let ((count (length culled)))
      (when (and (> count 0) (not dry-run))
        (%git-or-die (list "add" "-A") squad-root "stage")
        (%git-or-die (list "commit" "-m"
                           (format nil "[bean] culled ~D spoiled bean~:P from ~A"
                                   count
                                   (if role
                                       (string-downcase role)
                                       "all inboxes")))
                     squad-root "commit")
        ;; Log warnings
        (dolist (c culled)
          (hngh.core:log-warn
           "Spoiled bean culled: ~A from ~A inbox (~A)"
           (getf c :bean) (getf c :role) (getf c :reason))))
      (list :squad-root squad-root
            :culled culled
            :count count
            :dry-run dry-run
            :commit-sha (if dry-run
                            nil
                            (%git-commit-sha squad-root))))))
;;; --- Plugin lifecycle ------------------------------------------------------

(defun init ()
  "Initialize the beans plugin. Stateless in Wave 4."
  (setf *running* t)
  (hngh.core:log-info "Beans plugin initialized")
  t)

(defun shutdown ()
  "Shut down the beans plugin."
  (setf *running* nil)
  (hngh.core:log-info "Beans plugin shut down")
  t)

(defun running-p ()
  "Return T when the beans plugin is active."
  *running*)

(defun status ()
  "Return a plist describing the plugin status."
  (list :running *running*
        :bean-types *bean-types*
        :membrane-directives *membrane-directives*))
