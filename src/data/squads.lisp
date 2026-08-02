;;;; data/squads.lisp — declarative local squad definitions
;;;;
;;;; This file is data, not executable code. The mission-control plugin reads it
;;;; with *read-eval* bound to NIL. Keep model values local/free by default.
;;;;
;;;; SPDX-License-Identifier: AGPL-3.0-or-later
;;;; SPDX-FileCopyrightText: 2026 boundring

'(("day-queue"
   :description "Queue manager with two local workers"
   :roles
   (("manager"
     :harness "opencode"
     :model "unsloth-local/unsloth/gemma-4-12b-it-qat-GGUF"
     :cwd "~/Projects/etc"
     :prompt-template "coordinator-base"
     :budget-cap-cents 0)
    ("worker-a"
     :harness "hermes"
     :model "unsloth/gemma-4-12b-it-qat-GGUF"
     :cwd "~/Projects/etc"
     :prompt-template "worker-base"
     :budget-cap-cents 0)
    ("worker-b"
     :harness "opencode"
     :model "unsloth-local/unsloth/gemma-4-12b-it-qat-GGUF"
     :cwd "~/Projects/etc"
     :prompt-template "worker-base"
     :budget-cap-cents 0)))
  ("night-ralph"
   :description "Long-running local queue processor"
   :roles
   (("manager"
     :harness "hermes"
     :model "unsloth/gemma-4-12b-it-qat-GGUF"
     :cwd "~/Projects/etc"
     :prompt-template "coordinator-base"
     :budget-cap-cents 0)
    ("processor"
     :harness "opencode"
     :model "unsloth-local/unsloth/gemma-4-12b-it-qat-GGUF"
     :cwd "~/Projects/etc"
     :prompt-template "worker-base"
     :budget-cap-cents 0))))
