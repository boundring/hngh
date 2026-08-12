(asdf:defsystem #:hngh
  :description "A compact local control kernel."
  :version "0.1.0"
  :serial t
  :components ((:file "src/packages")
               (:file "src/domain/profile")
               (:file "src/domain/mission")
               (:file "src/domain/loadout")
               (:file "src/domain/run")
               (:file "src/domain/outcome")))
