;;;; plugins/knowledge-base.lisp — Hngh Knowledge Base (B12)
;;;;
;;;; Curated article/decision/pattern storage with deterministic keyword/tag query.
;;;; Data is persisted as Lisp plists under the Hngh state tree:
;;;;   knowledge-base/articles/
;;;;   knowledge-base/decisions/
;;;;   knowledge-base/learned-patterns/<category>/
;;;;
;;;; SPDX-License-Identifier: AGPL-3.0-or-later
;;;; SPDX-FileCopyrightText: 2026 boundring <boundring@gmail.com>

(in-package :hngh.plugins.knowledge-base)

;;; --- State -----------------------------------------------------------------

(defvar *running* nil
  "Whether the Knowledge Base plugin is active.")

(defvar *hngh-home* nil
  "The Hngh state directory (set during initialization).")

(defparameter *articles-dir* "knowledge-base/articles/"
  "State-store relative directory for article files.")

(defparameter *decisions-dir* "knowledge-base/decisions/"
  "State-store relative directory for decision files.")

(defparameter *patterns-root-dir* "knowledge-base/learned-patterns/"
  "State-store relative root directory for learned pattern files.")

(defparameter *pattern-categories* '("threats" "optimizations" "workflows")
  "Known learned-pattern categories for v0.1 query/search.")

(defparameter *lock-holder* "knowledge-base"
  "State-store lock holder name used by Knowledge Base writes.")

;;; --- Helpers: filesystem + persistence -------------------------------------

(defun state-store-running-p ()
  "Return T when the state store is initialized."
  (and (find-package :hngh.core.state-store)
       (fboundp (find-symbol "RUNNING-P" :hngh.core.state-store))
       (funcall (find-symbol "RUNNING-P" :hngh.core.state-store))))

(defun ensure-kb-directories ()
  "Ensure knowledge-base directories exist under *hngh-home*."
  (when *hngh-home*
    (ensure-directories-exist (merge-pathnames *articles-dir* *hngh-home*))
    (ensure-directories-exist (merge-pathnames *decisions-dir* *hngh-home*))
    (dolist (category *pattern-categories*)
      (ensure-directories-exist
       (merge-pathnames
        (format nil "~A~A/" *patterns-root-dir* category)
        *hngh-home*)))))

(defun string-of (value)
  "Convert VALUE to a lowercase-safe string representation."
  (cond
    ((null value) "")
    ((stringp value) value)
    ((symbolp value) (symbol-name value))
    (t (princ-to-string value))))

(defun normalize-string (value)
  "Normalize VALUE to a trimmed lowercase string."
  (string-downcase
   (string-trim '(#\Space #\Tab #\Newline #\Return)
                (string-of value))))

(defun stable-string-hash-32 (value)
  "Return a deterministic 32-bit FNV-1a hash for VALUE."
  (loop with hash = 2166136261
        for ch across value do
          (setf hash (logand #xffffffff (logxor hash (char-code ch))))
          (setf hash (logand #xffffffff (* hash 16777619)))
        finally (return hash)))

(defun slugify (value)
  "Create a simple filesystem-safe slug from VALUE."
  (let* ((raw (normalize-string value))
         (chars
           (loop for ch across raw
                 collect (if (or (alphanumericp ch)
                                 (char= ch #\-)
                                 (char= ch #\_))
                             ch
                             #\-))))
    (let ((collapsed (coerce chars 'string))
          (trimmed nil))
      (setf trimmed (string-trim "-" collapsed))
      (if (zerop (length trimmed))
          (format nil "entry-~8,'0x" (stable-string-hash-32 raw))
          trimmed))))

(defun normalize-tag-list (tags)
  "Normalize TAGS into a list of lowercase strings."
  (loop for tag in (or tags '())
        for normalized = (normalize-string tag)
        unless (zerop (length normalized))
        collect normalized))

(defun article-state-path (article-id)
  "Return relative state-store path for ARTICLE-ID."
  (format nil "~A~A.lisp" *articles-dir* (slugify article-id)))

(defun decision-state-path (decision-id)
  "Return relative state-store path for DECISION-ID."
  (format nil "~A~A.lisp" *decisions-dir* (slugify decision-id)))

(defun normalize-pattern-category (category)
  "Normalize CATEGORY to a known category string.
Falls back to \"workflows\" when unknown."
  (let ((normalized (normalize-string category)))
    (if (member normalized *pattern-categories* :test #'string=)
        normalized
        (progn
          (hngh.core:log-warn "Unknown pattern category ~S; defaulting to workflows" category)
          "workflows"))))

(defun pattern-state-path (pattern-id category)
  "Return relative state-store path for PATTERN-ID in CATEGORY."
  (format nil "~A~A/~A.lisp"
          *patterns-root-dir*
          (normalize-pattern-category category)
          (slugify pattern-id)))

(defun safe-write-state (relative-path value)
  "Write VALUE to RELATIVE-PATH, returning T on success."
  (handler-case
      (progn
        (hngh.core.state-store:write-state relative-path value)
        t)
    (error (c)
      (hngh.core:log-warn "Knowledge Base write failed (~A): ~A" relative-path c)
      nil)))

(defun safe-read-state (relative-path)
  "Read and return the Lisp value at RELATIVE-PATH, or NIL on failure/miss."
  (handler-case
      (hngh.core.state-store:read-state relative-path)
    (error (c)
      (hngh.core:log-warn "Knowledge Base read failed (~A): ~A" relative-path c)
      nil)))

(defun read-lisp-file (path)
  "Read and return one Lisp form from PATH with *read-eval* disabled."
  (when (probe-file path)
    (handler-case
        (with-open-file (stream path :direction :input :element-type 'character)
          (let ((*read-eval* nil))
            (read stream nil nil)))
      (error (c)
        (hngh.core:log-warn "Knowledge Base read failed (~A): ~A" path c)
        nil))))

(defun list-lisp-files (relative-dir)
  "Return all .lisp files in RELATIVE-DIR under *hngh-home*."
  (unless *hngh-home*
    (return-from list-lisp-files '()))
  (let* ((dir (merge-pathnames relative-dir *hngh-home*))
         (pattern (merge-pathnames "*.lisp" dir)))
    (if (probe-file dir)
        (or (directory pattern) '())
        '())))

(defun load-entries-from-dir (relative-dir)
  "Load all plist entries from RELATIVE-DIR."
  (loop for file in (list-lisp-files relative-dir)
        for form = (read-lisp-file file)
        when (listp form)
        collect form))

(defun load-all-patterns ()
  "Load pattern plists across all known categories."
  (loop for category in *pattern-categories*
        nconc (load-entries-from-dir
               (format nil "~A~A/" *patterns-root-dir* category))))

;;; --- Helpers: matching/query -----------------------------------------------

(defun entry-tag-corpus (entry)
  "Return normalized tags/keywords for ENTRY."
  (remove-duplicates
   (append (normalize-tag-list (getf entry :tags))
           (normalize-tag-list (getf entry :keywords)))
   :test #'string=))

(defun entry-text-corpus (entry)
  "Return normalized searchable text for ENTRY."
  (normalize-string
   (with-output-to-string (s)
     (dolist (key '(:id :title :content :summary :description :outcome :rationale :context))
       (let ((value (getf entry key)))
         (when value
           (write-string (string-of value) s)
           (write-char #\Space s)))))))

(defun query-matches-p (entry query tags)
  "Return T when ENTRY matches QUERY and TAGS constraints."
  (let* ((query-norm (normalize-string query))
         (tag-filter (normalize-tag-list tags))
         (entry-tags (entry-tag-corpus entry))
         (entry-text (entry-text-corpus entry))
         (query-ok (or (zerop (length query-norm))
                       (search query-norm entry-text :test #'char-equal)
                       (member query-norm entry-tags :test #'string=)))
         (tags-ok (or (null tag-filter)
                      (every (lambda (tag)
                               (member tag entry-tags :test #'string=))
                             tag-filter))))
    (and query-ok tags-ok)))

(defun sort-by-updated-at-desc (entries)
  "Sort ENTRIES by :updated-at descending (fallback :created-at)."
  (sort (copy-list entries)
        #'>
        :key (lambda (entry)
               (or (getf entry :updated-at)
                   (getf entry :created-at)
                   0))))

(defun maybe-publish (topic payload)
  "Publish TOPIC with PAYLOAD if event bus is available."
  (when hngh.core.event-bus:*event-bus*
    (handler-case
        (hngh.core.event-bus:publish topic payload :source 'knowledge-base)
      (error (c)
        (hngh.core:log-warn "Knowledge Base event publish failed (~A): ~A" topic c)
        nil))))

(defun with-kb-lock (lock-id thunk &key (ttl 60))
  "Execute THUNK while holding LOCK-ID via state-store lock API.
Returns THUNK result when acquired, otherwise NIL."
  (if (hngh.core.state-store:acquire-lock lock-id :holder *lock-holder* :ttl ttl)
      (unwind-protect
           (funcall thunk)
        (ignore-errors
          (hngh.core.state-store:release-lock lock-id :holder *lock-holder*)))
      (progn
        (hngh.core:log-warn "Knowledge Base lock busy: ~A" lock-id)
        nil)))

;;; --- Public API: lifecycle -------------------------------------------------

(defun initialize-knowledge-base (&key (hngh-home hngh:*hngh-home*))
  "Initialize the Knowledge Base plugin.
Ensures required directories exist and marks the plugin ready."
  (setf *hngh-home* hngh-home)
  (ensure-kb-directories)
  (setf *running* (and *hngh-home* (state-store-running-p)))
  (maybe-publish "knowledge-base.initialized"
                 (list :hngh-home (when *hngh-home* (namestring *hngh-home*))))
  *running*)

(defun shutdown-knowledge-base ()
  "Shutdown the Knowledge Base plugin and clear in-memory lifecycle state."
  (setf *running* nil
        *hngh-home* nil)
  t)

(defun knowledge-base-ready-p ()
  "Return T if the knowledge base plugin is initialized and state-store ready."
  (and *running* *hngh-home* (state-store-running-p)))

;;; --- Public API: write/read/query ------------------------------------------

(defun kb-write-article (article-id title content &key tags keywords metadata)
  "Write an article plist under knowledge-base/articles and return it.
Returns NIL when the plugin is not ready or persistence fails."
  (unless (knowledge-base-ready-p)
    (return-from kb-write-article nil))
  (let* ((slug (slugify article-id))
         (path (format nil "~A~A.lisp" *articles-dir* slug))
         (lock-id (format nil "kb-article-~A" slug))
         (now (get-universal-time))
         (entry (list :kind :article
                       :id slug
                       :title (or title "")
                       :content (or content "")
                       :tags (normalize-tag-list tags)
                       :keywords (normalize-tag-list keywords)
                       :metadata (or metadata '())
                       :created-at now
                       :updated-at now)))
    (with-kb-lock
     lock-id
     (lambda ()
       (when (safe-write-state path entry)
         (maybe-publish "knowledge-base.article.written"
                        (list :id (getf entry :id)
                              :path path
                              :tags (getf entry :tags)
                              :keywords (getf entry :keywords)))
         entry)))))

(defun kb-get-article (article-id)
  "Return the article plist for ARTICLE-ID, or NIL if not found."
  (unless (knowledge-base-ready-p)
    (return-from kb-get-article nil))
  (safe-read-state (article-state-path article-id)))

(defun kb-get-decision (decision-id)
  "Return the decision plist for DECISION-ID, or NIL if not found."
  (unless (knowledge-base-ready-p)
    (return-from kb-get-decision nil))
  (safe-read-state (decision-state-path decision-id)))

(defun kb-get-pattern (pattern-id &key category)
  "Return a learned pattern plist by PATTERN-ID.
If CATEGORY is provided, only that category is searched; otherwise all are searched."
  (unless (knowledge-base-ready-p)
    (return-from kb-get-pattern nil))
  (if category
      (safe-read-state (pattern-state-path pattern-id category))
      (loop for cat in *pattern-categories*
            for found = (safe-read-state (pattern-state-path pattern-id cat))
            when found
              return found
            finally (return nil))))

(defun kb-query (query &key tags (limit 20))
  "Query the knowledge base via deterministic keyword/tag matching.
Searches articles, decisions, and learned patterns."
  (unless (knowledge-base-ready-p)
    (return-from kb-query '()))
  (let* ((pool (append (load-entries-from-dir *articles-dir*)
                       (load-entries-from-dir *decisions-dir*)
                       (load-all-patterns)))
         (matches (remove-if-not
                   (lambda (entry)
                     (query-matches-p entry query tags))
                   pool))
         (sorted (sort-by-updated-at-desc matches)))
    (if (and limit (plusp limit))
        (subseq sorted 0 (min limit (length sorted)))
        sorted)))

(defun kb-record-decision (decision-id title summary
                             &key tags context outcome rationale)
  "Record a decision plist under knowledge-base/decisions and return it.
Returns NIL when the plugin is not ready or persistence fails."
  (unless (knowledge-base-ready-p)
    (return-from kb-record-decision nil))
  (let* ((slug (slugify decision-id))
         (path (format nil "~A~A.lisp" *decisions-dir* slug))
         (lock-id (format nil "kb-decision-~A" slug))
         (now (get-universal-time))
         (entry (list :kind :decision
                       :id slug
                       :title (or title "")
                       :summary (or summary "")
                       :tags (normalize-tag-list tags)
                       :context context
                       :outcome outcome
                       :rationale rationale
                       :created-at now
                       :updated-at now)))
    (with-kb-lock
     lock-id
     (lambda ()
       (when (safe-write-state path entry)
         (maybe-publish "knowledge-base.decision.recorded"
                        (list :id (getf entry :id)
                              :path path
                              :tags (getf entry :tags)))
         entry)))))

(defun kb-record-pattern (pattern-id category title description
                            &key tags signals actions)
  "Record a learned pattern under category directory and return it.
CATEGORY is normalized to one of threats/optimizations/workflows."
  (unless (knowledge-base-ready-p)
    (return-from kb-record-pattern nil))
  (let* ((slug (slugify pattern-id))
         (normalized-category (normalize-pattern-category category))
         (path (format nil "~A~A/~A.lisp"
                       *patterns-root-dir*
                       normalized-category
                       slug))
         (lock-id (format nil "kb-pattern-~A-~A" normalized-category slug))
         (now (get-universal-time))
         (entry (list :kind :pattern
                       :id slug
                       :category normalized-category
                       :title (or title "")
                       :description (or description "")
                       :tags (normalize-tag-list tags)
                       :signals signals
                       :actions actions
                       :created-at now
                       :updated-at now)))
    (with-kb-lock
     lock-id
     (lambda ()
       (when (safe-write-state path entry)
         (maybe-publish "knowledge-base.pattern.recorded"
                        (list :id (getf entry :id)
                              :category normalized-category
                              :path path))
         entry)))))

(defun kb-status ()
  "Return a plist describing current Knowledge Base status." 
  (let ((articles (load-entries-from-dir *articles-dir*))
        (decisions (load-entries-from-dir *decisions-dir*))
        (patterns (load-all-patterns)))
    (list :running (knowledge-base-ready-p)
          :articles-count (length articles)
          :decisions-count (length decisions)
          :patterns-count (length patterns)
          :pattern-categories (copy-list *pattern-categories*))))
