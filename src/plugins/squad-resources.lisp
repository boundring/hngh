;;;; plugins/squad-resources.lisp — Squad resource gate and grants (C2)
;;;;
;;;; Resource-aware squad sizing: checks VRAM headroom before launch via the
;;;; core resource-manager, estimates per-member VRAM from a static model
;;;; table, and acquires/releases resource-manager grants across the squad
;;;; lifecycle. Additive — does not change existing preflight semantics.
;;;;
;;;; SPDX-License-Identifier: AGPL-3.0-or-later
;;;; SPDX-FileCopyrightText: 2026 boundring <boundring@gmail.com>

(in-package :hngh.plugins.squad-resources)

(defvar *running* nil
  "Whether the squad-resources plugin is active.")

(defparameter *model-vram-mb*
  '(("gemma-4-12b" . 8192)
    ("gemma-3-27b" . 24576)
    ("qwythos-9b" . 12288)
    ("qwen3-6b" . 8192)
    ("deepseek-v4" . 0)
    ("glm-5.2" . 0)
    ("qwen3.7" . 0)
    ("gpt-5.6" . 0))
  "Estimated VRAM in MB per model (0 = remote, no local VRAM).
Keys are substrings; the first matching key wins.")

(defun model-vram-mb (model)
  "Estimated local VRAM in MB for MODEL, or 0 for remote models."
  (let ((needle (string-downcase (or model ""))))
    (or (loop for (pattern . mb) in *model-vram-mb*
              when (search pattern needle)
                return mb)
        0)))

(defun local-model-p (model)
  "Return T when MODEL runs on local VRAM (a known local model name)."
  (plusp (model-vram-mb model)))

(defun estimate-squad-vram (members)
  "Sum estimated VRAM in MB across MEMBERS (plists with a :model key)."
  (loop for member in members
        sum (model-vram-mb (getf member :model))))

(defun free-vram-mb ()
  "Current free VRAM in MB from the core resource manager, or NIL if the
resource manager is unavailable (in which case the gate is skipped, not
failed — absence of telemetry must not make squads worse than baseline)."
  (when (and (find-package :hngh.core.resource-manager)
             (fboundp 'hngh.core.resource-manager:running-p)
             (hngh.core.resource-manager:running-p))
    (handler-case
        (let* ((status (hngh.core.resource-manager:status))
               (free (getf status :free-vram)))
          (when (and free (plusp free))
            (floor free 1048576)))
      (error () nil))))

(defun drop-reviewers (members)
  "Return MEMBERS without :role \"reviewer\" members (the documented
reduction rule — drop the reviewer first when VRAM is contended)."
  (remove-if (lambda (member)
               (string= (or (getf member :role) "") "reviewer"))
             members))

(defun check-resource-gate (members &key (vram-mb-per-member nil)
                                       (max-members-if-shared nil)
                                       (fallback-tier nil)
                                       (quota-cents-allowed 0)
                                       (free-vram-mb nil))
  "Check VRAM headroom for MEMBERS before squad launch.

Returns (values decision reason &optional payload) where DECISION is one of:
  :pass     — fits in free VRAM
  :reduced  — full squad does not fit; dropping reviewer roles does
  :fallback — even reduced does not fit locally, but FALLBACK-TIER models
              (or remote spend within QUOTA-CENTS-ALLOWED) would
  :reject   — cannot fit locally and no fallback is permitted

FREE-VRAM-MB overrides the live resource-manager query (test seam)."
  (let* ((free (or free-vram-mb (free-vram-mb)))
         (per-member (or vram-mb-per-member
                         (if members
                             (/ (estimate-squad-vram members)
                                (length members))
                             0)))
         (max-members (or max-members-if-shared (length members)))
         (count (min (length members) max-members))
         (needed (* count per-member)))
    (cond
      ((null free)
       (values :pass "resource manager unavailable; gate skipped" nil))
      ((<= needed free)
       (values :pass (format nil "~D MB needed, ~D MB free" needed free) nil))
      (t
       (let ((reduced (drop-reviewers members)))
         (if (< (length reduced) (length members))
             (let ((reduced-needed (* (min (length reduced) max-members)
                                      per-member)))
               (if (<= reduced-needed free)
                   (values :reduced
                           (format nil "~D MB needed; dropping reviewer roles frees headroom (~D MB free)"
                                   needed free)
                           reduced)
                   (fallback-or-reject fallback-tier quota-cents-allowed needed free)))
             (fallback-or-reject fallback-tier quota-cents-allowed needed free)))))))

(defun fallback-or-reject (fallback-tier quota-cents-allowed needed free)
  "Decide :fallback vs :reject once local VRAM is insufficient."
  (cond
    (fallback-tier
     (values :fallback
             (format nil "~D MB needed, ~D MB free; falling back to tier ~S"
                     needed free fallback-tier)
             fallback-tier))
    ((plusp quota-cents-allowed)
     (values :fallback
             (format nil "~D MB needed, ~D MB free; remote budget (~D cents) allows fallback"
                     needed free quota-cents-allowed)
             :remote))
    (t
     (values :reject
             (format nil "~D MB needed, ~D MB free, no fallback tier and no remote budget"
                     needed free)
             nil))))

(defun acquire-squad-grants (squad-name members &key (preemptible t))
  "Acquire a VRAM grant for each local-model MEMBER from the core resource
manager. HOLDER is \"squad:<name>:<role>\". Returns the list of grant IDs
acquired (empty when the resource manager is unavailable)."
  (loop for member in members
        for role = (getf member :role)
        for model = (getf member :model)
        for mb = (model-vram-mb model)
        when (and (plusp mb)
                  (find-package :hngh.core.resource-manager)
                  (fboundp 'hngh.core.resource-manager:request-resource)
                  (hngh.core.resource-manager:running-p))
          collect (handler-case
                      (multiple-value-bind (grant error)
                          (hngh.core.resource-manager:request-resource
                           :vram (list :size mb :model model)
                           :holder (format nil "squad:~A:~A" squad-name role)
                           :preemptible preemptible)
                        (if (and grant (null error))
                            (hngh.core.resource-manager:grant-info-id grant)
                            (progn
                              (hngh.core:log-warn
                               "Squad ~A role ~A: VRAM grant failed: ~A"
                               squad-name role error)
                              nil)))
                    (error (condition)
                      (hngh.core:log-warn
                       "Squad ~A role ~A: VRAM grant error: ~A"
                       squad-name role condition)
                      nil))))

(defun release-squad-grants (grant-ids)
  "Release each GRANT-ID back to the core resource manager."
  (when (and (find-package :hngh.core.resource-manager)
             (fboundp 'hngh.core.resource-manager:release))
    (dolist (id grant-ids)
      (when id
        (handler-case
            (hngh.core.resource-manager:release id)
          (error (condition)
            (hngh.core:log-warn "Could not release VRAM grant ~D: ~A"
                                id condition)))))))

(defun reject-with-fragment (squad-name reason value location resume-hint
                             &key attribution)
  "Write a blocker fragment journal for a rejected squad and return its path.
Used by the squad-up path when the resource gate returns :reject, so the
rejection is breadcrumbed (C5) instead of silently dropped."
  (let ((path (hngh.plugins.fragment-journal:write-fragment-journal
               squad-name
               (format nil "rejected at launch: ~A" reason)
               value
               location
               resume-hint
               (or attribution "squad-resources gate — local, $0"))))
    (hngh.core:log-warn "Squad ~A rejected by resource gate; fragment: ~A"
                        squad-name path)
    path))

;;; --- Plugin lifecycle -------------------------------------------------------

(defun init (&key (hngh-home hngh:*hngh-home*))
  "Initialize the squad-resources plugin. Stateless — gates and grants are
on-demand against the core resource manager."
  (declare (ignore hngh-home))
  (setf *running* t)
  (hngh.core:log-info "Squad-resources plugin initialized")
  t)

(defun shutdown ()
  "Shut down the squad-resources plugin."
  (setf *running* nil)
  (hngh.core:log-info "Squad-resources plugin shut down")
  t)

(defun status ()
  "Return a plist with the plugin's current state."
  (list :running *running*
        :free-vram-mb (free-vram-mb)))
