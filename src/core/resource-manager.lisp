;;;; core/resource-manager.lisp — Hngh Resource Manager (A4)
;;;;
;;;; Hardware audit (GPU/CPU/memory) at startup, priority-based resource
;;;; arbitration with preemption, pressure-level monitoring.
;;;;
;;;; SPDX-License-Identifier: AGPL-3.0-or-later
;;;; SPDX-FileCopyrightText: 2026 boundring <boundring@gmail.com>

(in-package :hngh.core.resource-manager)

;;; --- Data structures ---

(defstruct hardware-info
  "Snapshot of hardware resources detected at init."
  gpus              ; list of gpu-info structs
  cpu-model         ; string (e.g. \"AMD Ryzen 7 7700X 8-Core Processor\")
  cpu-cores         ; integer (logical cores)
  memory-total      ; integer (bytes)
  memory-available) ; integer (bytes)

(defstruct gpu-info
  "Information about a single GPU."
  index             ; integer (0-based)
  vendor            ; :nvidia, :amd, or :intel
  name              ; string (e.g. \"Radeon RX 7900 XT\")
  vram-total        ; integer (bytes)
  vram-used         ; integer (bytes, snapshot at audit time)
  vram-free)        ; integer (bytes, snapshot at audit time)

(defstruct grant-info
  "A resource grant tracked by the resource manager."
  id                ; integer (unique, monotonically increasing)
  kind              ; :vram, :cpu-affinity, :memory, :model-load
  spec              ; plist with resource details
  holder            ; string (who requested the grant)
  priority          ; integer 0-9 (9 = highest)
  preemptible       ; boolean (can this grant be preempted?)
  acquired-at)      ; universal-time

;;; --- Internal state ---

(defvar *hardware* nil
  "Cached hardware-info struct from the last hardware audit.")

(defvar *grants* (make-hash-table :test 'eql)
  "Allocation map: grant ID -> grant-info struct.")

(defvar *grants-lock* (bt:make-lock "hngh-resource-manager-grants")
  "Mutex protecting *grants* and *next-grant-id*.")

(defvar *next-grant-id* 0
  "Counter for monotonically increasing grant IDs.")

(defvar *running* nil
  "Whether the resource manager is active.")

(defvar *pressure-level* :normal
  "Current pressure level: :normal, :elevated, or :critical.")

(defvar *udev-subscription-id* nil
  "Subscription ID for system.udev events.")

;;; --- Helper: run external command, return stdout as string ---

(defun run-command (program args)
  "Run PROGRAM with ARGS using sb-ext:run-program.
Capture stdout as a string. Returns NIL on failure."
  #+sbcl
  (handler-case
      (let* ((proc (sb-ext:run-program program args
                                       :output :stream
                                       :error nil
                                       :search t
                                       :wait t))
             (stream (sb-ext:process-output proc))
             (exit-code (sb-ext:process-exit-code proc)))
        (if stream
            (let ((output
                    (with-output-to-string (out)
                      (loop for char = (read-char stream nil nil)
                            while char
                            do (write-char char out)))))
              (if (zerop exit-code)
                  output
                  (progn
                    (hngh.core:log-warn "Command ~A exited with code ~D: ~A"
                                        program exit-code
                                        (subseq output 0 (min 200 (length output))))
                    output)))
            (progn
              (hngh.core:log-warn "Command ~A produced no output stream" program)
              nil)))
    (error (c)
      (hngh.core:log-warn "Error running ~A: ~A" program c)
      nil))
  #-sbcl
  (progn
    (hngh.core:log-warn "run-program not supported on this Lisp")
    nil))

(defun read-proc-file (path)
  "Read the entire contents of a /proc file as a string.
Uses character-by-character reading because /proc files report file-length 0."
  (handler-case
      (with-open-file (stream path :direction :input :element-type 'character
                                   :if-does-not-exist nil)
        (when stream
          (with-output-to-string (content)
            (loop for char = (read-char stream nil nil)
                  while char
                  do (write-char char content)))))
    (error (c)
      (hngh.core:log-warn "Error reading ~A: ~A" path c)
      nil)))

;;; --- Hardware audit: GPU detection ---

(defun parse-lspci-gpus (output)
  "Parse lspci output for VGA/3D controller lines.
Returns a list of plists: ((:vendor keyword :name string) ...)"
  (let ((gpus '()))
    (dolist (line (cl-ppcre:split "\\n" output))
      (when (or (search "VGA" line :test #'char-equal)
                (search "3D" line :test #'char-equal))
        (let ((vendor (cond
                        ((search "NVIDIA" line :test #'char-equal) :nvidia)
                        ((or (search "AMD" line :test #'char-equal)
                             (search "ATI" line :test #'char-equal))
                         :amd)
                        ((search "Intel" line :test #'char-equal) :intel)
                        (t :unknown)))
              (name (progn
                      ;; Extract the name portion after the colon-space-vendor pattern
                      (let* ((colon-pos (position #\: line :from-end t))
                             (bracket-pos (and colon-pos
                                               (position #\[ line :start colon-pos)))
                             (end-pos (or (and bracket-pos
                                               (position #\] line :start bracket-pos))
                                          (length line)))
                             (name-start (if colon-pos
                                             (1+ colon-pos)
                                             0)))
                        (string-trim " []()"
                                     (subseq line name-start end-pos))))))
          (push (list :vendor vendor :name name) gpus))))
    (nreverse gpus)))

(defun parse-rocm-smi-meminfo (output)
  "Parse rocm-smi --showmeminfo vram --json output.
Strips the WARNING line (if present) before the JSON.
Returns a list of (total-bytes . used-bytes) pairs, one per GPU."
  (let* ((json-start (or (position #\{ output) 0))
         (clean (subseq output json-start))
         (totals '())
         (useds '()))
    (cl-ppcre:do-register-groups (num)
        ("\"VRAM Total Memory \\(B\\)\":\\s*\"(\\d+)\"" clean)
      (push (parse-integer num) totals))
    (cl-ppcre:do-register-groups (num)
        ("\"VRAM Total Used Memory \\(B\\)\":\\s*\"(\\d+)\"" clean)
      (push (parse-integer num) useds))
    (loop for total in (nreverse totals)
          for used in (nreverse useds)
          collect (cons total used))))

(defun parse-nvidia-smi (output)
  "Parse nvidia-smi CSV output (no header, nounits, MiB values).
Columns: index,name,memory.total,memory.used,memory.free
Returns a list of (name total-bytes used-bytes free-bytes) per GPU."
  (loop for line in (cl-ppcre:split "\\n" output)
        for trimmed = (string-trim '(#\Space #\Newline #\Return) line)
        when (plusp (length trimmed))
        collect (let ((parts (cl-ppcre:split "," trimmed)))
                 (when (>= (length parts) 5)
                   (list (second parts)                          ; name
                         (* (parse-integer (third parts)) 1048576)  ; total
                         (* (parse-integer (fourth parts)) 1048576) ; used
                          (* (parse-integer (fifth parts)) 1048576))))))

(defun detect-gpus ()
  "Detect all GPUs using lspci and vendor-specific tools.
Returns a list of gpu-info structs."
  (let ((lspci-output (run-command "lspci" '())))
    (unless lspci-output
      (hngh.core:log-warn "Cannot run lspci — GPU detection disabled")
      (return-from detect-gpus nil))

    (let* ((lspci-gpus (parse-lspci-gpus lspci-output))
           (gpu-infos '())
           (amd-count 0)
           (nvidia-count 0))

      ;; --- AMD GPUs: try rocm-smi ---
      (let ((rocm-output (run-command "/opt/rocm/bin/rocm-smi"
                                       '("--showmeminfo" "vram" "--json"))))
        (if rocm-output
            (let ((meminfos (parse-rocm-smi-meminfo rocm-output)))
              (dolist (gpu lspci-gpus)
                (when (eq (getf gpu :vendor) :amd)
                  (let ((meminfo (nth amd-count meminfos)))
                    (push (make-gpu-info
                            :index (length gpu-infos)
                            :vendor :amd
                            :name (getf gpu :name)
                            :vram-total (or (car meminfo) 0)
                            :vram-used (or (cdr meminfo) 0)
                            :vram-free (- (or (car meminfo) 0)
                                          (or (cdr meminfo) 0)))
                          gpu-infos)
                    (incf amd-count)))))
            (progn
              (hngh.core:log-warn "rocm-smi not available — AMD GPU VRAM unknown")
              (dolist (gpu lspci-gpus)
                (when (eq (getf gpu :vendor) :amd)
                  (push (make-gpu-info
                          :index (length gpu-infos)
                          :vendor :amd
                          :name (getf gpu :name)
                          :vram-total 0 :vram-used 0 :vram-free 0)
                        gpu-infos)
                  (incf amd-count))))))

      ;; --- NVIDIA GPUs: try nvidia-smi ---
      (dolist (gpu lspci-gpus)
        (when (eq (getf gpu :vendor) :nvidia)
          (let* ((nvidia-output (run-command "nvidia-smi"
                                              '("--query-gpu=index,name,memory.total,memory.used,memory.free"
                                                "--format=csv,noheader,nounits")))
                 (entries (when nvidia-output (parse-nvidia-smi nvidia-output)))
                 (entry (nth nvidia-count entries)))
            (if entry
                (destructuring-bind (name total used free) entry
                  (declare (ignore name))
                  (push (make-gpu-info
                          :index (length gpu-infos)
                          :vendor :nvidia
                          :name (getf gpu :name)
                          :vram-total total
                          :vram-used used
                          :vram-free free)
                        gpu-infos))
                (progn
                  (hngh.core:log-warn "nvidia-smi not available — NVIDIA GPU VRAM unknown")
                  (push (make-gpu-info
                          :index (length gpu-infos)
                          :vendor :nvidia
                          :name (getf gpu :name)
                          :vram-total 0 :vram-used 0 :vram-free 0)
                        gpu-infos)))
            (incf nvidia-count))))

      ;; --- Intel GPUs: no VRAM ---
      (dolist (gpu lspci-gpus)
        (when (eq (getf gpu :vendor) :intel)
          (push (make-gpu-info
                  :index (length gpu-infos)
                  :vendor :intel
                  :name (getf gpu :name)
                  :vram-total 0 :vram-used 0 :vram-free 0)
                gpu-infos)))

      ;; --- Unknown vendor GPUs ---
      (dolist (gpu lspci-gpus)
        (when (eq (getf gpu :vendor) :unknown)
          (push (make-gpu-info
                  :index (length gpu-infos)
                  :vendor :unknown
                  :name (getf gpu :name)
                  :vram-total 0 :vram-used 0 :vram-free 0)
                gpu-infos)))

      (nreverse gpu-infos))))

;;; --- Hardware audit: CPU detection ---

(defun detect-cpu ()
  "Detect CPU cores and model from /proc/cpuinfo.
Returns (values cpu-cores cpu-model)."
  (let ((content (read-proc-file "/proc/cpuinfo")))
    (if content
        (let ((cores 0)
              (model "unknown"))
          (dolist (line (cl-ppcre:split "\\n" content))
            (when (cl-ppcre:scan "^processor\\s*:" line)
              (incf cores))
            (when (and (string= model "unknown")
                       (cl-ppcre:scan "^model name\\s*:" line))
              (let ((colon-pos (position #\: line)))
                (when colon-pos
                  (setf model (string-trim '(#\Space #\Tab)
                                           (subseq line (1+ colon-pos))))))))
          (values cores model))
        (values 0 "unknown"))))

;;; --- Hardware audit: memory detection ---

(defun detect-memory ()
  "Detect memory total and available from /proc/meminfo.
Returns (values memory-total memory-available) in bytes."
  (let ((content (read-proc-file "/proc/meminfo")))
    (if content
        (let ((total 0)
              (available 0))
          (dolist (line (cl-ppcre:split "\\n" content))
            (cond
              ((cl-ppcre:register-groups-bind (kb)
                   ("^MemTotal:\\s+(\\d+)" line)
                 (setf total (* (parse-integer kb) 1024))))
              ((cl-ppcre:register-groups-bind (kb)
                   ("^MemAvailable:\\s+(\\d+)" line)
                 (setf available (* (parse-integer kb) 1024))))))
          (values total available))
        (values 0 0))))

;;; --- Full hardware audit ---

(defun run-hardware-audit ()
  "Perform a full hardware audit and return a hardware-info struct."
  (hngh.core:log-info "Starting hardware audit...")
  (let ((gpus (detect-gpus)))
    (multiple-value-bind (cpu-cores cpu-model) (detect-cpu)
      (multiple-value-bind (mem-total mem-avail) (detect-memory)
        (let ((hw (make-hardware-info
                    :gpus gpus
                    :cpu-model cpu-model
                    :cpu-cores cpu-cores
                    :memory-total mem-total
                    :memory-available mem-avail)))
          (hngh.core:log-info "Hardware audit complete: ~D GPU(s), ~D CPU cores, ~D MB RAM"
                              (length gpus) cpu-cores (floor mem-total 1048576))
          (dolist (gpu gpus)
            (hngh.core:log-debug "GPU ~D: ~A (~A, ~D MB VRAM)"
                                 (gpu-info-index gpu)
                                 (gpu-info-name gpu)
                                 (gpu-info-vendor gpu)
                                 (floor (gpu-info-vram-total gpu) 1048576)))
          hw)))))

;;; --- Pressure calculation ---

(defun calculate-free-vram ()
  "Calculate total free VRAM across all GPUs considering active grants.
Returns the remaining VRAM in bytes."
  (if *hardware*
      (let ((total-free (loop for gpu in (hardware-info-gpus *hardware*)
                              sum (gpu-info-vram-free gpu))))
        (bt:with-lock-held (*grants-lock*)
          (loop for grant being the hash-values of *grants*
                when (eq (grant-info-kind grant) :vram)
                sum (let ((size-mib (getf (grant-info-spec grant) :size 0)))
                      (* size-mib 1048576))
                into allocated
                finally (return (- total-free allocated)))))
      0))

(defun calculate-total-vram ()
  "Calculate total VRAM across all GPUs."
  (if *hardware*
      (loop for gpu in (hardware-info-gpus *hardware*)
            sum (gpu-info-vram-total gpu))
      0))

(defun compute-pressure-level ()
  "Compute the current VRAM pressure level.
Returns :normal, :elevated, or :critical."
  (let ((total (calculate-total-vram)))
    (if (zerop total)
        :normal
        (let* ((free (calculate-free-vram))
               (ratio (/ free total)))
          (cond
            ((< ratio 0.20) :critical)
            ((< ratio 0.40) :elevated)
            (t :normal))))))

(defun check-and-emit-pressure ()
  "Check pressure level and emit event if it changed."
  (let ((new-level (compute-pressure-level)))
    (unless (eq new-level *pressure-level*)
      (setf *pressure-level* new-level)
      (when (and hngh.core.event-bus:*event-bus*
                 (not (eq new-level :normal)))
        (hngh.core.event-bus:publish
          "resource.pressure"
          (list :kind :vram :level new-level)
          :source 'resource-manager))
      (hngh.core:log-info "Resource pressure: ~A (free VRAM: ~D MB of ~D MB)"
                          new-level
                          (floor (calculate-free-vram) 1048576)
                          (floor (calculate-total-vram) 1048576)))))

;;; --- Lifecycle ---

(defun init (&key (hngh-home hngh:*hngh-home*))
  "Initialize the resource manager.
Performs hardware audit, persists to state/hardware.lisp,
subscribes to system.udev events."
  (declare (ignorable hngh-home))

  ;; Reset internal state
  (bt:with-lock-held (*grants-lock*)
    (setf *grants* (make-hash-table :test 'eql)
          *next-grant-id* 0))
  (setf *pressure-level* :normal
        *running* t)

  ;; Perform hardware audit
  (handler-case
      (let ((hw (run-hardware-audit)))
        (setf *hardware* hw)
        ;; Persist hardware info to state store
        (when (and hw (hngh.core.state-store:running-p))
          (handler-case
              (hngh.core.state-store:write-state "state/hardware.lisp" hw)
            (error (c)
              (hngh.core:log-warn "Could not persist hardware info: ~A" c)))))
    (error (c)
      (hngh.core:log-error "Hardware audit failed: ~A" c)
      ;; Try to restore from persisted state
      (when (hngh.core.state-store:running-p)
        (let ((saved (handler-case
                         (hngh.core.state-store:read-state "state/hardware.lisp")
                       (error () nil))))
          (when saved
            (setf *hardware* saved)
            (hngh.core:log-info "Restored hardware info from state/hardware.lisp"))))
      ;; If still no hardware info, create a minimal stub
      (unless *hardware*
        (setf *hardware* (make-hardware-info
                           :gpus nil
                           :cpu-model "unknown"
                           :cpu-cores 0
                           :memory-total 0
                           :memory-available 0)))))

  ;; Subscribe to system.udev events for hardware changes
  (when hngh.core.event-bus:*event-bus*
    (handler-case
        (setf *udev-subscription-id*
              (hngh.core.event-bus:subscribe
                "system.udev.*"
                (lambda (event)
                  (hngh.core:log-debug "Resource Manager: udev event: ~A (~A)"
                                       (hngh.core.event-bus:event-topic event)
                                       (hngh.core.event-bus:event-payload event)))
                :persistent nil))
      (error (c)
        (hngh.core:log-warn "Could not subscribe to system.udev: ~A" c))))

  (hngh.core:log-info "Resource Manager initialized"))

(defun shutdown ()
  "Shut down the resource manager.
Releases all grants, unsubscribes, clears state."
  ;; Release all grants (emit events)
  (let ((grant-ids '()))
    (bt:with-lock-held (*grants-lock*)
      (loop for id being the hash-keys of *grants*
            do (push id grant-ids)))
    (dolist (id grant-ids)
      (handler-case
          (release id)
        (error (c)
          (hngh.core:log-warn "Error releasing grant ~D during shutdown: ~A" id c)))))

  ;; Unsubscribe from udev
  (when (and *udev-subscription-id* hngh.core.event-bus:*event-bus*)
    (handler-case
        (hngh.core.event-bus:unsubscribe *udev-subscription-id*)
      (error (c)
        (hngh.core:log-warn "Error unsubscribing from udev: ~A" c)))
    (setf *udev-subscription-id* nil))

  ;; Clear state
  (bt:with-lock-held (*grants-lock*)
    (clrhash *grants*))
  (setf *hardware* nil
        *running* nil
        *pressure-level* :normal
        *next-grant-id* 0)

  (hngh.core:log-info "Resource Manager shut down"))

(defun running-p ()
  "Return T if the resource manager is active."
  *running*)

;;; --- Resource arbitration ---

(defun request-resource (kind spec &key (holder "unknown")
                                     (priority 3)
                                     (preemptible t))
  "Request a resource grant.
KIND: :vram, :cpu-affinity, :memory, or :model-load
SPEC: plist with resource details (e.g. (:model \"llama3.2-3b\" :size 2048) for :vram)
HOLDER: string identifying the requester
PRIORITY: integer 0-9 (9 = highest, default 3)
PREEMPTIBLE: whether this grant can be preempted (default T)
Returns (values grant-info nil) on success, (values nil :resource-full) on failure."
  (unless *running*
    (error "Resource manager not initialized"))

  (case kind
    (:vram
     ;; Calculate available VRAM
     (let* ((size-mib (getf spec :size 0))
            (size-bytes (* size-mib 1048576))
            (free-vram (calculate-free-vram)))
       (if (>= free-vram size-bytes)
           ;; Enough free VRAM — grant it
           (let ((grant (create-grant kind spec holder priority preemptible)))
             (emit-grant-event grant)
             (check-and-emit-pressure)
             (values grant nil))
           ;; Not enough VRAM — try preemption
           (let ((victim (find-preemption-victim priority)))
             (if victim
                 (progn
                   (hngh.core:log-info "Preempting grant ~D (holder: ~A, priority: ~D) for higher-priority request"
                                       (grant-info-id victim)
                                       (grant-info-holder victim)
                                       (grant-info-priority victim))
                   (do-preempt victim :higher-priority)
                   ;; Now try again
                   (let ((new-free (calculate-free-vram)))
                     (if (>= new-free size-bytes)
                         (let ((grant (create-grant kind spec holder priority preemptible)))
                           (emit-grant-event grant)
                           (check-and-emit-pressure)
                           (values grant nil))
                         ;; Still not enough even after preemption
                         (values nil :resource-full))))
                 ;; No preemption candidates
                 (values nil :resource-full))))))

    (otherwise
     ;; For cpu-affinity, memory, model-load — simple grant without capacity check
     (let ((grant (create-grant kind spec holder priority preemptible)))
       (emit-grant-event grant)
       (check-and-emit-pressure)
       (values grant nil)))))

(defun create-grant (kind spec holder priority preemptible)
  "Create a new grant-info struct and add it to the allocation map."
  (let ((grant (bt:with-lock-held (*grants-lock*)
                 (let ((id (incf *next-grant-id*)))
                   (setf (gethash id *grants*)
                         (make-grant-info
                           :id id
                           :kind kind
                           :spec spec
                           :holder holder
                           :priority priority
                           :preemptible preemptible
                           :acquired-at (get-universal-time)))))))
    (hngh.core:log-debug "Grant ~D allocated: kind=~A holder=~A priority=~D"
                         (grant-info-id grant) kind holder priority)
    grant))

(defun find-preemption-victim (request-priority)
  "Find the lowest-priority preemptible grant among active grants
with priority strictly less than REQUEST-PRIORITY.
Returns the grant-info struct or NIL."
  (bt:with-lock-held (*grants-lock*)
    (let ((victim nil)
          (victim-priority 999))
      (loop for grant being the hash-values of *grants*
            when (and (grant-info-preemptible grant)
                      (< (grant-info-priority grant) request-priority)
                      (< (grant-info-priority grant) victim-priority))
            do (setf victim grant
                     victim-priority (grant-info-priority grant)))
      victim)))

(defun emit-grant-event (grant)
  "Emit a resource.granted event for the given grant."
  (when hngh.core.event-bus:*event-bus*
    (hngh.core.event-bus:publish
      "resource.granted"
      (list :grant-id (grant-info-id grant)
            :kind (grant-info-kind grant)
            :spec (grant-info-spec grant)
            :holder (grant-info-holder grant))
      :source 'resource-manager)))

;;; --- Release ---

(defun release (grant-id)
  "Release a grant by ID.
Emits a resource.released event and recalculates pressure.
Returns the released grant-info if found, NIL otherwise."
  (let ((grant (bt:with-lock-held (*grants-lock*)
                 (let ((g (gethash grant-id *grants*)))
                   (when g
                     (remhash grant-id *grants*))
                   g))))
    (when grant
      (hngh.core:log-debug "Grant ~D released: kind=~A holder=~A"
                           grant-id (grant-info-kind grant) (grant-info-holder grant))
      (when hngh.core.event-bus:*event-bus*
        (hngh.core.event-bus:publish
          "resource.released"
          (list :grant-id grant-id
                :reason :explicit-release)
          :source 'resource-manager))
      (check-and-emit-pressure))
    grant))

;;; --- Preempt ---

(defun preempt (grant-id &optional (reason :higher-priority))
  "Force-release a grant by ID with the given REASON.
Emits a resource.preempted event.
Returns the preempted grant-info if found, NIL otherwise."
  (do-preempt (bt:with-lock-held (*grants-lock*)
                (gethash grant-id *grants*))
              reason))

(defun do-preempt (grant reason)
  "Internal preemption: remove grant, emit event, recalculate pressure."
  (when grant
    (let ((gid (grant-info-id grant)))
      (bt:with-lock-held (*grants-lock*)
        (remhash gid *grants*))
      (hngh.core:log-info "Grant ~D preempted: holder=~A reason=~A"
                          gid (grant-info-holder grant) reason)
      (when hngh.core.event-bus:*event-bus*
        (hngh.core.event-bus:publish
          "resource.preempted"
          (list :grant-id gid
                :holder (grant-info-holder grant)
                :reason reason)
          :source 'resource-manager))
      (check-and-emit-pressure)
      grant)))

;;; --- Status ---

(defun status ()
  "Return a plist with current resource status:
(:hardware <hardware-info> :grants <list> :free-vram <bytes> :pressure-level keyword)"
  (let ((grants (bt:with-lock-held (*grants-lock*)
                  (loop for grant being the hash-values of *grants*
                        collect grant))))
    (list :hardware *hardware*
          :grants grants
          :free-vram (calculate-free-vram)
          :pressure-level (compute-pressure-level))))

(defun hardware-info ()
  "Return the cached hardware-info struct."
  *hardware*)

(defun list-grants ()
  "Return a list of all active grant-info structs."
  (bt:with-lock-held (*grants-lock*)
    (loop for grant being the hash-values of *grants*
          collect grant)))
