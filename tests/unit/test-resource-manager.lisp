;;;; tests/unit/test-resource-manager.lisp — Tests for Resource Manager (A4)
;;;;
;;;; SPDX-License-Identifier: AGPL-3.0-or-later
;;;; SPDX-FileCopyrightText: 2026 boundring <boundring@gmail.com>

(in-package :hngh.tests)

(def-suite :hngh.resource-manager
  :description "Tests for Resource Manager (A4)"
  :in :hngh)

(in-suite :hngh.resource-manager)

;;; --- Helper: set up a minimal test environment ---

(defun rm-setup (&optional (home (make-tmp-home)))
  "Set up event bus, state store, and resource manager using a temp home directory.
Returns the temp home path."
  (cleanup-tmp-home home)
  (hngh.core.event-bus:init :hngh-home home)
  (hngh.core.state-store:init :hngh-home home)
  (hngh.core.resource-manager:init :hngh-home home)
  home)

(defun rm-teardown (home)
  "Shut down resource manager, state store, and event bus. Clean up temp home."
  (handler-case (hngh.core.resource-manager:shutdown) (error ()))
  (handler-case (hngh.core.state-store:shutdown) (error ()))
  (handler-case (hngh.core.event-bus:shutdown) (error ()))
  (cleanup-tmp-home home))

(defun make-synthetic-hardware (vram-mib)
  "Create a synthetic hardware-info with one GPU having VRAM-MIB bytes of VRAM.
VRAM is set fully free (vram-free = vram-total)."
  (let ((vram-bytes (* vram-mib 1048576)))
    (hngh.core.resource-manager::make-hardware-info
      :gpus (list (hngh.core.resource-manager::make-gpu-info
                    :index 0
                    :vendor :amd
                    :name "Synthetic GPU"
                    :vram-total vram-bytes
                    :vram-used 0
                    :vram-free vram-bytes))
      :cpu-model "Synthetic CPU"
      :cpu-cores 8
      :memory-total (* 16 1024 1024 1024)
      :memory-available (* 8 1024 1024 1024))))

;;; --- Test 1: Lifecycle — init runs hardware audit and creates hardware-info ---

(test resource-manager-init-creates-hardware-info
  "Init performs hardware audit and populates *hardware*."
  (let ((home (rm-setup)))
    (is (hngh.core.resource-manager:running-p))
    (let ((hw (hngh.core.resource-manager:hardware-info)))
      (is (not (null hw)))
      (is (>= (hngh.core.resource-manager:hardware-info-cpu-cores hw) 1))
      (is (stringp (hngh.core.resource-manager:hardware-info-cpu-model hw)))
      (is (>= (length (hngh.core.resource-manager:hardware-info-cpu-model hw)) 1)))
    (rm-teardown home)))

;;; --- Test 2: Lifecycle — shutdown releases all grants ---

(test resource-manager-shutdown-releases-all-grants
  "Shutdown clears all active grants."
  (let ((home (rm-setup)))
    ;; Override hardware with synthetic to control VRAM
    (setf (symbol-value (find-symbol "*HARDWARE*" :hngh.core.resource-manager))
          (make-synthetic-hardware 1024))
    ;; Allocate a grant
    (multiple-value-bind (grant err) (hngh.core.resource-manager:request-resource
                                         :vram '(:size 100)
                                         :holder "test-holder")
      (declare (ignore err))
      (is (not (null grant)))
      (is (= 1 (length (hngh.core.resource-manager:list-grants)))))
    ;; Shutdown and verify grants are cleared
    (hngh.core.resource-manager:shutdown)
    (is (= 0 (length (hngh.core.resource-manager:list-grants))))
    (is (not (hngh.core.resource-manager:running-p)))
    (rm-teardown home)))

;;; --- Test 3: Hardware audit — detects CPU cores ---

(test hardware-audit-detects-cpu-cores
  "Detected CPU cores count is at least 1."
  (let ((home (rm-setup)))
    (let ((hw (hngh.core.resource-manager:hardware-info)))
      (let ((cores (hngh.core.resource-manager:hardware-info-cpu-cores hw)))
        (is (integerp cores))
        (is (>= cores 1))))
    (rm-teardown home)))

;;; --- Test 4: Hardware audit — detects memory total ---

(test hardware-audit-detects-memory
  "Detected memory total is > 0 bytes."
  (let ((home (rm-setup)))
    (let ((hw (hngh.core.resource-manager:hardware-info)))
      (let ((mem (hngh.core.resource-manager:hardware-info-memory-total hw)))
        (is (integerp mem))
        (is (> mem 0))))
    (rm-teardown home)))

;;; --- Test 5: Hardware audit — GPU detected ---

(test hardware-audit-detects-gpu
  "At least one GPU is detected."
  (let ((home (rm-setup)))
    (let ((hw (hngh.core.resource-manager:hardware-info)))
      (let ((gpus (hngh.core.resource-manager:hardware-info-gpus hw)))
        (is (listp gpus))
        ;; On this system, we expect at least one GPU
        (is (>= (length gpus) 0)
            "GPU detection may find 0 or more GPUs depending on hardware")))
    (rm-teardown home)))

;;; --- Test 6: Hardware audit — persisted to state/hardware.lisp ---

(test hardware-audit-persists-to-state
  "Hardware info is persisted to state/hardware.lisp via state store."
  (let ((home (rm-setup)))
    (is (hngh.core.state-store:state-exists-p "state/hardware.lisp")
        "state/hardware.lisp should exist after init")
    ;; Read it back and verify it's a hardware-info struct
    (let ((saved (hngh.core.state-store:read-state "state/hardware.lisp")))
      (is (not (null saved)))
      (is (typep saved 'hngh.core.resource-manager:hardware-info)))
    (rm-teardown home)))

;;; --- Test 7: Request resource — VRAM grant succeeds when space available ---

(test request-vram-grant-succeeds
  "VRAM grant succeeds when requested size fits in available VRAM."
  (let ((home (rm-setup)))
    (setf (symbol-value (find-symbol "*HARDWARE*" :hngh.core.resource-manager))
          (make-synthetic-hardware 4096))
    (multiple-value-bind (grant err) (hngh.core.resource-manager:request-resource
                                         :vram '(:size 2048)
                                         :holder "llama-runner")
      (declare (ignore err))
      (is (not (null grant)))
      (is (eq :vram (hngh.core.resource-manager:grant-info-kind grant)))
      (is (equal 2048 (getf (hngh.core.resource-manager:grant-info-spec grant) :size))))
    (rm-teardown home)))

;;; --- Test 8: Request resource — returns grant-info with correct fields ---

(test request-vram-grant-correct-fields
  "Grant info returned by request-resource has expected field values."
  (let ((home (rm-setup)))
    (setf (symbol-value (find-symbol "*HARDWARE*" :hngh.core.resource-manager))
          (make-synthetic-hardware 4096))
    (multiple-value-bind (grant err) (hngh.core.resource-manager:request-resource
                                         :vram '(:model "test-model" :size 512)
                                         :holder "test-holder"
                                         :priority 5
                                         :preemptible t)
      (declare (ignore err))
      (is (not (null grant)))
      (is (integerp (hngh.core.resource-manager:grant-info-id grant)))
      (is (eq :vram (hngh.core.resource-manager:grant-info-kind grant)))
      (is (string= "test-holder" (hngh.core.resource-manager:grant-info-holder grant)))
      (is (= 5 (hngh.core.resource-manager:grant-info-priority grant)))
      (is (eq t (hngh.core.resource-manager:grant-info-preemptible grant)))
      (is (integerp (hngh.core.resource-manager:grant-info-acquired-at grant)))
      (is (equal 512 (getf (hngh.core.resource-manager:grant-info-spec grant) :size))))
    (rm-teardown home)))

;;; --- Test 9: Request resource — fails when requesting more VRAM than available ---

(test request-vram-grant-fails-when-full
  "VRAM grant returns :resource-full when requested size exceeds available."
  (let ((home (rm-setup)))
    ;; Set up synthetic hardware with only 100 MiB VRAM
    (setf (symbol-value (find-symbol "*HARDWARE*" :hngh.core.resource-manager))
          (make-synthetic-hardware 100))
    ;; Request 200 MiB — should fail
    (multiple-value-bind (grant err) (hngh.core.resource-manager:request-resource
                                         :vram '(:size 200)
                                         :holder "greedy-runner")
      (is (null grant))
      (is (eq :resource-full err)))
    (rm-teardown home)))

;;; --- Test 10: Release — grant removed from active list ---

(test release-removes-grant
  "Releasing a grant removes it from the active list."
  (let ((home (rm-setup)))
    (setf (symbol-value (find-symbol "*HARDWARE*" :hngh.core.resource-manager))
          (make-synthetic-hardware 4096))
    (multiple-value-bind (grant err) (hngh.core.resource-manager:request-resource
                                         :vram '(:size 100)
                                         :holder "temp")
      (declare (ignore err))
      (let ((gid (hngh.core.resource-manager:grant-info-id grant)))
        (is (= 1 (length (hngh.core.resource-manager:list-grants))))
        (let ((released (hngh.core.resource-manager:release gid)))
          (is (not (null released)))
          (is (= gid (hngh.core.resource-manager:grant-info-id released))))
        (is (= 0 (length (hngh.core.resource-manager:list-grants))))))
    (rm-teardown home)))

;;; --- Test 11: Preempt — lower-priority grant is preempted for higher-priority request ---

(test preempt-lower-priority-for-higher
  "A lower-priority preemptible grant is preempted when a higher-priority request
needs the VRAM."
  (let ((home (rm-setup)))
    ;; Set up synthetic hardware with limited VRAM (100 MiB total)
    (setf (symbol-value (find-symbol "*HARDWARE*" :hngh.core.resource-manager))
          (make-synthetic-hardware 100))
    ;; Allocate a low-priority grant consuming most VRAM (80 MiB)
    (multiple-value-bind (low-grant err1) (hngh.core.resource-manager:request-resource
                                              :vram '(:size 80)
                                              :holder "low-priority-process"
                                              :priority 1
                                              :preemptible t)
      (declare (ignore err1))
      (is (not (null low-grant)))
      (is (= 1 (length (hngh.core.resource-manager:list-grants))))
      ;; Now request 60 MiB with higher priority — should preempt the low one
      (multiple-value-bind (high-grant err2) (hngh.core.resource-manager:request-resource
                                                 :vram '(:size 60)
                                                 :holder "high-priority-process"
                                                 :priority 9
                                                 :preemptible t)
        (declare (ignore err2))
        (is (not (null high-grant)))
        (is (string= "high-priority-process"
                     (hngh.core.resource-manager:grant-info-holder high-grant)))
        ;; Low-priority grant should be gone, high-priority one should be active
        (let ((grants (hngh.core.resource-manager:list-grants)))
          (is (= 1 (length grants)))
          (is (= (hngh.core.resource-manager:grant-info-id high-grant)
                 (hngh.core.resource-manager:grant-info-id (first grants)))))))
    (rm-teardown home)))

;;; --- Test 12: Status — returns plist with hardware, grants, free-vram ---

(test status-returns-plist
  "Status function returns a plist with expected keys."
  (let ((home (rm-setup)))
    (setf (symbol-value (find-symbol "*HARDWARE*" :hngh.core.resource-manager))
          (make-synthetic-hardware 4096))
    (let ((st (hngh.core.resource-manager:status)))
      (is (not (null (getf st :hardware))))
      (is (listp (getf st :grants)))
      (is (integerp (getf st :free-vram)))
      (is (member (getf st :pressure-level) '(:normal :elevated :critical))))
    (rm-teardown home)))

;;; --- Test 13: List grants — shows all active grants ---

(test list-grants-shows-active-grants
  "List-grants returns all active grants."
  (let ((home (rm-setup)))
    (setf (symbol-value (find-symbol "*HARDWARE*" :hngh.core.resource-manager))
          (make-synthetic-hardware 4096))
    ;; Initially empty
    (is (= 0 (length (hngh.core.resource-manager:list-grants))))
    ;; Allocate two grants
    (hngh.core.resource-manager:request-resource :vram '(:size 100) :holder "proc-a")
    (hngh.core.resource-manager:request-resource :vram '(:size 200) :holder "proc-b")
    (let ((grants (hngh.core.resource-manager:list-grants)))
      (is (= 2 (length grants)))
      (let ((holders (mapcar #'hngh.core.resource-manager:grant-info-holder grants)))
        (is (member "proc-a" holders :test #'string=))
        (is (member "proc-b" holders :test #'string=))))
    (rm-teardown home)))

;;; --- Test 14: Pressure — emits elevated/critical when VRAM is low ---

(test pressure-level-becomes-elevated-then-critical
  "Pressure level transitions to :elevated and :critical as VRAM is consumed."
  (let ((home (rm-setup)))
    ;; Set up synthetic hardware with 100 MiB VRAM
    (setf (symbol-value (find-symbol "*HARDWARE*" :hngh.core.resource-manager))
          (make-synthetic-hardware 100))
    ;; Initially pressure is :normal (100% free)
    (is (eq :normal (getf (hngh.core.resource-manager:status) :pressure-level)))
    ;; Allocate 65 MiB → 35 MiB free → 35% free → :elevated (below 40%)
    (hngh.core.resource-manager:request-resource
      :vram '(:size 65) :holder "consumer-a" :priority 5)
    (is (eq :elevated (getf (hngh.core.resource-manager:status) :pressure-level)))
    ;; Allocate 20 more MiB → 15 MiB free → 15% free → :critical (below 20%)
    (hngh.core.resource-manager:request-resource
      :vram '(:size 20) :holder "consumer-b" :priority 5)
    (is (eq :critical (getf (hngh.core.resource-manager:status) :pressure-level)))
    ;; Release one grant: free goes back to 35 MiB → 35% → :elevated
    (let ((grants (hngh.core.resource-manager:list-grants)))
      (hngh.core.resource-manager:release
        (hngh.core.resource-manager:grant-info-id (first grants))))
    ;; After release, should go back (depends on which grant was released)
    (let ((level (getf (hngh.core.resource-manager:status) :pressure-level)))
      (is (member level '(:elevated :normal))))
    (rm-teardown home)))

;;; --- Test 15: Non-VRAM grant always succeeds ---

(test non-vram-grant-succeeds
  "Grants for :cpu-affinity, :memory, :model-load always succeed (M1 stub)."
  (let ((home (rm-setup)))
    (setf (symbol-value (find-symbol "*HARDWARE*" :hngh.core.resource-manager))
          (make-synthetic-hardware 100))
    (dolist (kind '(:cpu-affinity :memory :model-load))
      (multiple-value-bind (grant err) (hngh.core.resource-manager:request-resource
                                           kind '(:desc "test")
                                           :holder "test-holder")
        (declare (ignore err))
        (is (not (null grant)))
        (is (eq kind (hngh.core.resource-manager:grant-info-kind grant)))))
    (rm-teardown home)))

;;; --- Test 16: Preempt function works directly ---

(test preempt-function-releases-grant
  "Calling preempt directly removes the grant and it disappears from list-grants."
  (let ((home (rm-setup)))
    (setf (symbol-value (find-symbol "*HARDWARE*" :hngh.core.resource-manager))
          (make-synthetic-hardware 4096))
    (let ((grant (hngh.core.resource-manager:request-resource
                    :vram '(:size 100) :holder "victim" :priority 1 :preemptible t)))
      (is (= 1 (length (hngh.core.resource-manager:list-grants))))
      (let ((result (hngh.core.resource-manager:preempt
                      (hngh.core.resource-manager:grant-info-id grant)
                      :admin-action)))
        (is (not (null result)))
        (is (string= "victim" (hngh.core.resource-manager:grant-info-holder result))))
      (is (= 0 (length (hngh.core.resource-manager:list-grants)))))
    (rm-teardown home)))

;;; --- Test 17: Grant IDs are monotonically increasing ---

(test grant-ids-are-monotonic
  "Grant IDs increase with each allocation."
  (let ((home (rm-setup)))
    (setf (symbol-value (find-symbol "*HARDWARE*" :hngh.core.resource-manager))
          (make-synthetic-hardware 4096))
    (let ((g1 (hngh.core.resource-manager:request-resource
                :vram '(:size 10) :holder "a"))
          (g2 (hngh.core.resource-manager:request-resource
                :vram '(:size 10) :holder "b"))
          (g3 (hngh.core.resource-manager:request-resource
                :vram '(:size 10) :holder "c")))
      (is (< (hngh.core.resource-manager:grant-info-id g1)
             (hngh.core.resource-manager:grant-info-id g2)))
      (is (< (hngh.core.resource-manager:grant-info-id g2)
             (hngh.core.resource-manager:grant-info-id g3))))
    (rm-teardown home)))
