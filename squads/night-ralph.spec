(squad
  :name "night-ralph"
  :version 1
  :description "Long-running local queue processor"
  :layout :vertical
  :preflight
    ((require-systemd :units ("unsloth-studio"))
     (require-model :endpoint "http://127.0.0.1:8888/v1" :model "gemma-4-12b")
     (quota-gate :max-remote-cents 0))
  :members
  ((:role "manager"
    :cli "hermes"
    :model "unsloth/gemma-4-12b-it-qat-GGUF"
    :cwd "~/Projects/etc"
    :wake-template "coordinator-base")
   (:role "processor"
    :cli "opencode"
    :model "unsloth-local/unsloth/gemma-4-12b-it-qat-GGUF"
    :cwd "~/Projects/etc"
    :wake-template "worker-base")))
  :journal
    ((:projected-path "hngh/journal/squads/{{squad}}-{{timestamp}}-projected.md")
     (:actual-path "hngh/journal/squads/{{squad}}-{{timestamp}}-actual.md")))
