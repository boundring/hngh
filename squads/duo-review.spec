(squad
  :name "duo-review"
  :version 1
  :description "Two-agent code review: opencode + hermes review AGENTS.md files across projects"
  :layout :vertical
  :preflight
    ((require-mcp :all)
     (require-systemd :units ("unsloth-studio"))
     (require-model :endpoint "http://127.0.0.1:8888/v1" :model "gemma-4-12b")
     (quota-gate :max-remote-cents 50))
  :members
  ((:role "coordinator"
    :cli "opencode"
    :model "unsloth-local/unsloth/gemma-4-12b-it-qat-GGUF"
    :cwd "~/Projects/etc"
    :wake-template "coordinator-review-duo"
    :mcp-servers ("filesystem" "github"))
   (:role "reviewer"
    :cli "hermes"
    :model "unsloth/gemma-4-12b-it-qat-GGUF"
    :cwd "~/Projects/etc"
    :wake-template "reviewer-agents-md"
    :mcp-servers ("filesystem" "github")))
  :journal
    ((:projected-path "hngh/journal/squads/{{squad}}-{{timestamp}}-projected.md")
     (:actual-path "hngh/journal/squads/{{squad}}-{{timestamp}}-actual.md")))
