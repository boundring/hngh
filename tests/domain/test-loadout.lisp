(in-package :hngh.tests)

(let* ((objective (copy-seq "Publish the run contract"))
       (scope (copy-seq "repository"))
       (scopes (list scope))
       (mission (hngh.domain:make-mission
                 :objective objective
                 :non-objectives '("Persist no state")
                 :source-references '("docs/project/roadmap.md")
                 :acceptance-criteria '("make test passes")
                 :writable-scopes scopes
                 :verification "make test"
                 :evacuation-condition "Contract is reviewed")))
  (setf (char objective 0) #\X)
  (setf (char scope 0) #\X)
  (setf (first scopes) "changed")
  (check (equal "Publish the run contract" (hngh.domain:mission-objective mission))
         "mission copies caller-owned objective text")
  (check (equal '("repository") (hngh.domain:mission-writable-scopes mission))
         "mission copies caller-owned writable scopes")
  (let ((reported-objective (hngh.domain:mission-objective mission))
        (reported-scopes (hngh.domain:mission-writable-scopes mission)))
    (setf (char reported-objective 0) #\X)
    (setf (first reported-scopes) "changed")
    (check (equal "Publish the run contract" (hngh.domain:mission-objective mission))
           "mission copies its public objective")
    (check (equal '("repository") (hngh.domain:mission-writable-scopes mission))
           "mission copies its public writable scopes")))

(let ((role (hngh.domain:make-role-template
             :name "builder"
             :capabilities '("edit" "test")
             :required-review-role "reviewer"
             :permitted-loadout-classes '("manual"))))
  (check (equal "builder" (hngh.domain:role-template-name role))
         "role template preserves its name"))

(let ((loadout (hngh.domain:make-loadout
                :route-label :local
                :context-limit 1
                :token-limit 2
                :cost-limit 3
                :time-limit 4
                :tool-labels '("make-test")
                :network-labels '("none")
                :writable-scopes '("repository"))))
  (check (eql :local (hngh.domain:loadout-route-label loadout))
         "loadout preserves its opaque route label")
  (check (= 4 (hngh.domain:loadout-time-limit loadout))
         "loadout preserves its time limit"))

(check (signals-error-p
        (lambda ()
          (hngh.domain:make-mission
           :objective "Write outside"
           :non-objectives '("None")
           :source-references '("docs/project/roadmap.md")
           :acceptance-criteria '("No path values")
           :writable-scopes (list #p"/tmp/outside")
           :verification "make test"
           :evacuation-condition "Stop")))
       "mission rejects a pathname")

(check (signals-error-p
        (lambda ()
          (hngh.domain:make-loadout
           :route-label :local
           :context-limit 1
           :token-limit 2
           :cost-limit 3
           :time-limit -1
           :tool-labels '("make-test")
           :network-labels '("none")
           :writable-scopes '("repository"))))
       "loadout rejects a negative limit")

(check (signals-error-p
        (lambda ()
          (hngh.domain:make-loadout
           :route-label :local
           :context-limit 1
           :token-limit 2
           :cost-limit 3
           :time-limit 4
           :tool-labels '("make-test" "make-test")
           :network-labels '("none")
           :writable-scopes '("repository"))))
       "loadout rejects duplicate labels")

(check (signals-error-p
        (lambda ()
          (hngh.domain:make-loadout
           :route-label (make-hash-table)
           :context-limit 1
           :token-limit 2
           :cost-limit 3
           :time-limit 4
           :tool-labels '("make-test")
           :network-labels '("none")
           :writable-scopes '("repository"))))
       "loadout rejects a provider-shaped hash table")

(check (signals-error-p
        (lambda ()
          (hngh.domain:make-loadout
           :route-label :local
           :context-limit 1
           :token-limit 2
           :cost-limit 3
           :time-limit 4
           :tool-labels (list *standard-output*)
           :network-labels '("none")
           :writable-scopes '("repository"))))
       "loadout rejects a stream")
