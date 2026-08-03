;;;; plugins/agents-md.lisp — AGENTS.md discovery, merge, and extraction (C1)
;;;;
;;;; Implements the AGENTS.md-oriented squad context capability from
;;;; docs/design/squad-autonomy.md §3. Pure filesystem/text functions — no
;;;; squad launch, hngh-up, or journal code paths are touched here.
;;;;
;;;; SPDX-License-Identifier: AGPL-3.0-or-later
;;;; SPDX-FileCopyrightText: 2026 boundring <boundring@gmail.com>

(in-package :hngh.plugins.agents-md)

;;; --- Discovery ---------------------------------------------------------

(defun root-p (dir)
  "Return T if DIR is the filesystem root (\"/\")."
  (let ((dir-str (namestring (truename dir))))
    (string= dir-str "/")))

(defun parent-dir (dir)
  "Return the parent directory pathname of DIR, or NIL if DIR has no parent."
  (let* ((truename (truename dir))
         (dir-str (namestring truename)))
    (if (string= dir-str "/")
        nil
        (let ((trimmed (string-right-trim "/" dir-str)))
          (let ((slash-pos (position #\/ trimmed :from-end t)))
            (if (and slash-pos (> slash-pos 0))
                (pathname (concatenate 'string (subseq trimmed 0 slash-pos) "/"))
                (pathname "/")))))))

(defun discover-agents-md (start-dir)
  "Walk from START-DIR up to the filesystem root, collecting every AGENTS.md
found along the way. Returns a nearest-first list of pathnames — the
directory's own AGENTS.md (if present) comes first, then each ancestor's,
stopping at the filesystem root."
  (let ((results '())
        (dir (truename start-dir)))
    (loop
      (let ((candidate (merge-pathnames "AGENTS.md" dir)))
        (when (probe-file candidate)
          (push candidate results)))
      (when (root-p dir)
        (return))
      (let ((parent (parent-dir dir)))
        (unless parent
          (return))
        (setf dir parent)))
    (nreverse results)))

;;; --- Extraction helpers --------------------------------------------------

(defun extract-section-headers (text)
  "Return a list of (header . body) conses for each Markdown ## section in
TEXT. Body is the raw text between one header and the next (or end of
file), with leading/trailing whitespace trimmed."
  (let ((lines (split-lines text))
        (sections '())
        (current-header nil)
        (current-body '()))
    (flet ((flush ()
             (when current-header
               (push (cons current-header
                           (string-trim '(#\Space #\Tab #\Newline #\Return)
                                        (format nil "~{~A~^~%~}" (nreverse current-body))))
                     sections))))
      (dolist (line lines)
        (if (and (>= (length line) 3)
                 (string= (subseq line 0 3) "## "))
            (progn
              (flush)
              (setf current-header (string-trim '(#\Space #\Tab) (subseq line 3)))
              (setf current-body '()))
            (when current-header
              (push line current-body))))
      (flush))
    (nreverse sections)))

(defun split-lines (text)
  "Split TEXT into a list of lines on #\\Newline."
  (let ((lines '())
        (start 0))
    (loop
      (let ((pos (position #\Newline text :start start)))
        (if pos
            (progn
              (push (subseq text start pos) lines)
              (setf start (1+ pos)))
            (progn
              (push (subseq text start) lines)
              (return)))))
    (nreverse lines)))

(defun extract-fenced-code-blocks (text)
  "Return a list of strings, one per fenced code block (```...```) in TEXT,
in document order. Used to surface literal commands (e.g. `make test`)."
  (let ((lines (split-lines text))
        (blocks '())
        (in-block nil)
        (current '()))
    (dolist (line lines)
      (let ((trimmed (string-trim '(#\Space #\Tab) line)))
        (cond
          ((and (>= (length trimmed) 3) (string= (subseq trimmed 0 3) "```"))
           (if in-block
               (progn
                 (push (format nil "~{~A~^~%~}" (nreverse current)) blocks)
                 (setf current '())
                 (setf in-block nil))
               (setf in-block t)))
          (in-block
           (push line current)))))
    (nreverse blocks)))

(defun extract-freshness-date (text)
  "Return the date string found in a \"Current state (YYYY-MM-DD)\"-style
header within TEXT, or NIL if no such header exists."
  (let ((pos (search "Current state" text)))
    (when pos
      (let ((paren-start (position #\( text :start pos)))
        (when paren-start
          (let ((paren-end (position #\) text :start paren-start)))
            (when paren-end
              (subseq text (1+ paren-start) paren-end))))))))

(defun extract-bullet-facts (text)
  "Return an alist of (key . value) for every line in TEXT matching the
pattern `- **Key**: value`."
  (let ((facts '()))
    (dolist (line (split-lines text))
      (let ((trimmed (string-left-trim '(#\Space #\Tab) line)))
        (when (and (>= (length trimmed) 2)
                   (string= (subseq trimmed 0 2) "- ")
                   (>= (length trimmed) 5)
                   (string= (subseq trimmed 2 4) "**"))
          (let* ((rest (subseq trimmed 4))
                 (close-pos (search "**" rest)))
            (when close-pos
              (let ((key (subseq rest 0 close-pos))
                    (after (subseq rest (+ close-pos 2))))
                (let ((colon-pos (position #\: after)))
                  (when colon-pos
                    (let ((value (string-trim '(#\Space #\Tab)
                                               (subseq after (1+ colon-pos)))))
                      (push (cons key value) facts))))))))))
    (nreverse facts)))

;;; --- Merge ----------------------------------------------------------------

(defun read-file-text (path)
  "Read the full contents of PATH as a string."
  (with-open-file (stream path :direction :input)
    (let ((contents (make-string (file-length stream))))
      (let ((read-count (read-sequence contents stream)))
        (subseq contents 0 read-count)))))

(defun merge-agents-md (paths)
  "Read each file in PATHS (nearest-first order, as returned by
DISCOVER-AGENTS-MD) and merge their ## sections by header. Nearest file
wins on header conflict; sections are additive across files — a subdir
AGENTS.md doesn't need to restate machine-wide sections found further up
the chain.

Returns a plist:
  :sections   — alist of (header . body), nearest-file version per header
  :commands   — list of fenced code block strings, nearest file first
  :freshness  — the first freshness date string found, or NIL
  :facts      — alist of (key . value) bullet facts, nearest file wins
                on duplicate keys
  :sources    — the PATHS list, as given"
  (let ((sections '())
        (seen-headers '())
        (commands '())
        (freshness nil)
        (facts '())
        (seen-fact-keys '()))
    (dolist (path paths)
      (let ((text (read-file-text path)))
        (dolist (entry (extract-section-headers text))
          (unless (member (car entry) seen-headers :test #'string=)
            (push (car entry) seen-headers)
            (push entry sections)))
        (dolist (cmd (extract-fenced-code-blocks text))
          (push cmd commands))
        (unless freshness
          (setf freshness (extract-freshness-date text)))
        (dolist (fact (extract-bullet-facts text))
          (unless (member (car fact) seen-fact-keys :test #'string=)
            (push (car fact) seen-fact-keys)
            (push fact facts)))))
    (list :sections (nreverse sections)
          :commands (nreverse commands)
          :freshness freshness
          :facts (nreverse facts)
          :sources paths)))

;;; --- Plugin lifecycle -------------------------------------------------------

(defvar *running* nil
  "Whether the agents-md plugin is active.")

(defun init (&key (hngh-home hngh:*hngh-home*))
  "Initialize the agents-md plugin. Stateless — discovery/merge are pure
functions of the filesystem, called on demand."
  (declare (ignore hngh-home))
  (setf *running* t)
  (hngh.core:log-info "Agents-md plugin initialized")
  t)

(defun shutdown ()
  "Shut down the agents-md plugin."
  (setf *running* nil)
  (hngh.core:log-info "Agents-md plugin shut down")
  t)

(defun running-p ()
  "Return T if the plugin is active."
  *running*)

(defun status ()
  "Return a plist with plugin status."
  (list :running *running*))
