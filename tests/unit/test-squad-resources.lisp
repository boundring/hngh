;;;; tests/unit/test-squad-resources.lisp — Tests for squad resource gate (C2)
;;;;
;;;; SPDX-License-Identifier: AGPL-3.0-or-later
;;;; SPDX-FileCopyrightText: 2026 boundring <boundring@gmail.com>

(in-package :hngh.tests)

(def-suite :hngh.squad-resources
  :description "Tests for squad resource gate and grants (C2)"
  :in :hngh)

(in-suite :hngh.squad-resources)

;;; --- Fixtures ---------------------------------------------------------------

(defun %sq-members (&key (count 3) (model "unsloth/gemma-4-12b-it-qat-GGUF"))
  "Build COUNT squad member plists. Reviewer roles are at the end, so
dropping reviewers leaves the first members intact."
  (loop for i from 0 below count
        collect (list :role (if (zerop i) "coordinator"
                                (if (= i (1- count)) "reviewer"
                                    (format nil "worker-~A" i)))
                      :cli (if (evenp i) "hermes" "opencode")
                      :model model
                      :cwd "~/Projects/etc"
                      :wake-template "worker-base")))

(defun %sq-tmp-dir ()
  "Return a fresh temporary directory for fragment-journal tests."
  (merge-pathnames (format nil "hngh-squad-resources-test-~D/" (random 1000000))
                   (uiop:temporary-directory)))

;;; --- model-vram-mb ----------------------------------------------------------

(test squad-resources-model-vram-estimates
  "Local models estimate nonzero VRAM; remote models estimate zero."
  (is (= 8192 (hngh.plugins.squad-resources:model-vram-mb
               "unsloth/gemma-4-12b-it-qat-GGUF")))
  (is (= 12288 (hngh.plugins.squad-resources:model-vram-mb
                "qwythos-9b-1m")))
  (is (= 0 (hngh.plugins.squad-resources:model-vram-mb "kimi-k3")))
  (is (= 0 (hngh.plugins.squad-resources:model-vram-mb nil))))

(test squad-resources-local-model-p
  "local-model-p is true for local names, false for remote."
  (is-true (hngh.plugins.squad-resources:local-model-p
            "unsloth/gemma-4-12b-it-qat-GGUF"))
  (is-false (hngh.plugins.squad-resources:local-model-p "kimi-k3")))

(test squad-resources-estimate-squad-vram
  "estimate-squad-vram sums per-member estimates."
  (is (= 24576 (hngh.plugins.squad-resources:estimate-squad-vram
                (%sq-members :count 3 :model "unsloth/gemma-4-12b-it-qat-GGUF"))))
  (is (= 0 (hngh.plugins.squad-resources:estimate-squad-vram
            (%sq-members :count 2 :model "kimi-k3")))))

;;; --- check-resource-gate ----------------------------------------------------

(test squad-resources-gate-passes-when-sufficient
  "Gate passes when per-member estimate * count fits in free VRAM."
  (multiple-value-bind (decision reason)
      (hngh.plugins.squad-resources:check-resource-gate
       (%sq-members :count 3) :free-vram-mb 32768)
    (is (eq decision :pass))
    (is (search "32768 MB free" reason))))

(test squad-resources-gate-rejects-when-insufficient
  "Gate rejects when even a single coordinator cannot fit and no fallback
exists."
  (multiple-value-bind (decision reason)
      (hngh.plugins.squad-resources:check-resource-gate
       (%sq-members :count 3) :free-vram-mb 4096)
    (is (eq decision :reject))
    (is (search "no fallback" reason))))

(test squad-resources-gate-reduces-by-dropping-reviewer
  "Gate reduces when dropping the reviewer role frees enough headroom."
  (multiple-value-bind (decision reason reduced)
      (hngh.plugins.squad-resources:check-resource-gate
       (%sq-members :count 3) :free-vram-mb 16384)
    (is (eq decision :reduced))
    (is (= 2 (length reduced)))
    (is (every (lambda (m) (not (string= (getf m :role) "reviewer")))
               reduced))))

(test squad-resources-gate-falls-back-to-tier
  "Gate falls back to :fallback-tier when local VRAM is insufficient."
  (multiple-value-bind (decision reason tier)
      (hngh.plugins.squad-resources:check-resource-gate
       (%sq-members :count 3) :free-vram-mb 4096
       :fallback-tier :budget-50)
    (is (eq decision :fallback))
    (is (eq tier :budget-50))))

(test squad-resources-gate-falls-back-to-remote-with-quota
  "Gate falls back to remote when local VRAM is insufficient but remote
budget exists."
  (multiple-value-bind (decision reason tier)
      (hngh.plugins.squad-resources:check-resource-gate
       (%sq-members :count 3) :free-vram-mb 4096
       :quota-cents-allowed 50)
    (is (eq decision :fallback))
    (is (eq tier :remote))))

(test squad-resources-gate-skips-when-unavailable
  "Gate passes with a skip reason when no free-VRAM telemetry exists —
absence of telemetry must not make squads worse than baseline."
  (multiple-value-bind (decision reason)
      (hngh.plugins.squad-resources:check-resource-gate
       (%sq-members :count 3) :free-vram-mb nil)
    (is (eq decision :pass))
    (is (search "unavailable" reason))))

(test squad-resources-gate-respects-max-members
  "max-members-if-shared caps the member count used for the VRAM estimate."
  (multiple-value-bind (decision reason)
      (hngh.plugins.squad-resources:check-resource-gate
       (%sq-members :count 5) :free-vram-mb 16384
       :max-members-if-shared 2)
    ;; 2 members * 8GB = 16GB, fits exactly at 16384 MB.
    (is (eq decision :pass))
    (is (search "16384 MB needed" reason))))

;;; --- reject-with-fragment ---------------------------------------------------

(test squad-resources-reject-writes-fragment
  "A rejected squad writes a fragment journal breadcrumb (C5), not silence."
  (let ((dir (%sq-tmp-dir)))
    (unwind-protect
         (let ((path (hngh.plugins.squad-resources:reject-with-fragment
                      "squad-reject-fixture"
                      "24576 MB needed, 4096 MB free"
                      "fixture squad for gate rejection test"
                      "none"
                      "retry with fallback-tier or more VRAM"
                      :attribution "unit test — local, $0")))
           ;; Fragment written inside the fixture dir? No — the plugin writes
           ;; to journal/squads/ by default. Rebind is not available through
           ;; the public API, so assert it is a probe-file-able path instead.
           (is-true (probe-file path))
           (is (search "-fragment.md" (namestring path)))
           ;; Clean up the real journal dir artifact to keep the repo tidy.
           (ignore-errors (delete-file path)))
      (ignore-errors (uiop:delete-directory-tree dir :validate t)))))

;;; --- grant lifecycle (uses live resource manager with mocked hardware) ------

(test squad-resources-grant-roundtrip
  "acquire-squad-grants then release-squad-grants round-trips through the
core resource manager's grant table (mocked hardware via internal vars)."
  (let ((rm (find-package :hngh.core.resource-manager)))
    (when (and rm (fboundp 'hngh.core.resource-manager:init)
               (fboundp 'hngh.core.resource-manager:list-grants))
      ;; Mock the resource manager's hardware snapshot so request-resource
      ;; sees a fixed free-VRAM budget without touching real GPUs.
      (let ((*package* (find-package :cl)))
        (eval `(setf (symbol-value 'hngh.core.resource-manager::*running*) t
                     (symbol-value 'hngh.core.resource-manager::*grants*)
                     (make-hash-table :test 'eql)
                     (symbol-value 'hngh.core.resource-manager::*hardware*)
                     (hngh.core.resource-manager::make-hardware-info
                      :gpus (list (hngh.core.resource-manager::make-gpu-info
                                   :index 0 :vendor :amd :name "fixture gpu"
                                   :vram-total (* 24576 1048576)
                                   :vram-used 0
                                   :vram-free (* 24576 1048576)))
                      :cpu-model "fixture cpu" :cpu-cores 8
                      :memory-total (* 64 1073741824)
                      :memory-available (* 32 1073741824)))))
      (unwind-protect
           (let* ((before (length (hngh.core.resource-manager:list-grants)))
                  (grant-ids (hngh.plugins.squad-resources:acquire-squad-grants
                              "fixture-squad"
                              (%sq-members :count 3
                                           :model "unsloth/gemma-4-12b-it-qat-GGUF"))))
             (is (= 3 (length grant-ids)))
             (is (= (+ before 3)
                    (length (hngh.core.resource-manager:list-grants))))
             (hngh.plugins.squad-resources:release-squad-grants grant-ids)
             (is (= before
                    (length (hngh.core.resource-manager:list-grants)))))
        ;; Restore resource manager state so later suites see a clean slate.
        (let ((*package* (find-package :cl)))
          (eval `(setf (symbol-value 'hngh.core.resource-manager::*running*) nil
                       (symbol-value 'hngh.core.resource-manager::*grants*)
                       (make-hash-table :test 'eql)
                       (symbol-value 'hngh.core.resource-manager::*hardware*) nil)))))))
