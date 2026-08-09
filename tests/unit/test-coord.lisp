;;;; tests/unit/test-coord.lisp — hngh-coord (card 101) behavior tests.
;;;;
;;;; Two faces, one store: post → journal persist → inbox routing →
;;;; coord-view. Uses a temp store (state-store init with a scratch home)
;;;; so tests don't touch the real ~/.hngh journal.

(in-package :hngh.tests)

(def-suite :hngh.coord
  :description "hngh-coord squad coordination plane (card 101)")

(in-suite :hngh.coord)

(defvar *coord-tmp-home* nil)

(defun %coord-with-temp-store (thunk)
  "Run THUNK with state-store pointed at a fresh temp home, then restore
the core default home (hngh:*hngh-home*). Deliberately does NOT delete
the temp dir nor call state-store:shutdown — other suites' background
threads (e.g. the ACP client's reader) hold descriptors into shared
state; unlinking dirs under them breaks the whole image mid-run.
Binds *coord-tmp-home* so tests can re-init to the same scratch store."
  (let ((dir (merge-pathnames
              (format nil "hngh-coord-test-~D/" (random 1000000))
              (uiop:temporary-directory))))
    (ensure-directories-exist dir)
    (unwind-protect
         (progn
           (setf *coord-tmp-home* dir)
           (hngh.core.state-store:init :hngh-home dir)
           (hngh.plugins.hngh-coord:init)
           (funcall thunk))
      (hngh.plugins.hngh-coord:shutdown)
      (setf *coord-tmp-home* nil)
      ;; restore to the core default; the stores' own home is bound at
      ;; the daemon level (hngh:*hngh-home*), not read via internals.
      (hngh.core.state-store:init :hngh-home hngh:*hngh-home*))))

(test coord-post-and-routing
  (%coord-with-temp-store
   (lambda ()
     (hngh.plugins.hngh-coord:post-message "A" "B" "question" "hello from A")
     (hngh.plugins.hngh-coord:post-message "B" "A" "note" "ack")
     (hngh.plugins.hngh-coord:post-message "C" "*" "state" "broadcast")
     ;; A's inbox: from B + broadcast C; NOT from A's own post to B
     (let ((inbox-a (hngh.plugins.hngh-coord:read-inbox "A")))
       (is (= 2 (length inbox-a)))
       (is (some (lambda (e) (search "ack" (getf e :body))) inbox-a))
       (is (some (lambda (e) (search "broadcast" (getf e :body))) inbox-a))
       (is (notany (lambda (e) (search "hello from A" (getf e :body))) inbox-a))))))

(test coord-view-shows-agents-and-count
  (%coord-with-temp-store
   (lambda ()
     (hngh.plugins.hngh-coord:post-message "A" "B" "question" "q1")
     (hngh.plugins.hngh-coord:post-message "A" "B" "question" "q2")
     (let ((view (hngh.plugins.hngh-coord:coord-view)))
       (is (search "A: 2 msgs" view))
       (is (search "messages: 2" view))))))

(test coord-journal-persists
  (%coord-with-temp-store
   (lambda ()
     (hngh.plugins.hngh-coord:post-message "A" "B" "note" "persisted")
     ;; simulate a restart: re-init to the SAME scratch home (journal file
     ;; persists across the coordinator's own init cycle)
     (hngh.plugins.hngh-coord:shutdown)
     (hngh.core.state-store:init :hngh-home *coord-tmp-home*)
     (hngh.plugins.hngh-coord:init)
     (let ((inbox-b (hngh.plugins.hngh-coord:read-inbox "B")))
       (is (= 1 (length inbox-b)))
       (is (search "persisted" (getf (car inbox-b) :body)))))))

(test coord-steer-kind
  (%coord-with-temp-store
   (lambda ()
     (hngh.plugins.hngh-coord:post-message "coordinator" "B" "steer"
                                           "reorient to card 99")
     (let ((inbox-b (hngh.plugins.hngh-coord:read-inbox "B")))
       (is (= 1 (length inbox-b)))
       (is (equal "steer" (getf (car inbox-b) :kind)))))))