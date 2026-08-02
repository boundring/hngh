(squad
  :name "day-queue"
  :version 1
  :description "Queue manager with two local workers"
  :layout :tiled
  :preflight
    ((require-systemd :units ("unsloth-studio"))
     (require-model :endpoint "http://127.0.0.1:8888/v1" :model "gemma-4-12b")
     (quota-gate :max-remote-cents 0))
  :members
  ((:role "manager"
    :cli "opencode"
    :model "unsloth-local/unsloth/gemma-4-12b-it-qat-GGUF"
    :cwd "~/Projects/etc"
    :wake-template "coordinator-base")
   (:role "worker-a"
    :cli "hermes"
    :model "unsloth/gemma-4-12b-it-qat-GGUF"
    :cwd "~/Projects/etc"
    :wake-template "worker-base")
   (:role "worker-b"
    :cli "opencode"
    :model "unsloth-local/unsloth/gemma-4-12b-it-qat-GGUF"
    :cwd "~/Projects/etc"
    :wake-template "worker-base")))
  :journal
    ((:projected-path "hngh/journal/squads/{{squad}}-{{timestamp}}-projected.md")
     (:actual-path "hngh/journal/squads/{{squad}}-{{timestamp}}-actual.md")))
