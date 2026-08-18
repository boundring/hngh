(asdf:defsystem #:hngh
  :description "A compact local control kernel."
  :version "0.1.0"
  :serial t
  :components ((:file "src/packages")
               (:file "src/domain/profile")
               (:file "src/domain/mission")
               (:file "src/domain/loadout")
               (:file "src/domain/run")
               (:file "src/domain/outcome")
               (:file "src/domain/governance")
               (:file "src/application/ports")
               (:file "src/application/create-run")
               (:file "src/application/arm-run")
               (:file "src/application/start-run")
               (:file "src/application/checkpoint")
               (:file "src/application/close-run")
               (:file "src/adapter/evidence")
               (:file "src/adapter/mutation")
               (:file "src/adapter/review")))
