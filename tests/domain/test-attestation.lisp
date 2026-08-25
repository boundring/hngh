(in-package :hngh.tests)

(let* ((pin (hngh.domain:make-key-pin
             :key-identifier "peer-1"
             :key-path #P"/tmp/hngh-peer-1.pub"))
       (identifier (hngh.domain:key-pin-key-identifier pin))
       (path (hngh.domain:key-pin-key-path pin)))
  (setf (char identifier 0) #\X)
  (setf (char path 0) #\X)
  (check (and (hngh.domain:key-pin-p pin)
              (equal "peer-1" (hngh.domain:key-pin-key-identifier pin))
              (equal "/tmp/hngh-peer-1.pub"
                     (hngh.domain:key-pin-key-path pin)))
         "valid key pin preserves isolated identifier and absolute path"))

(check (signals-error-p
        (lambda ()
          (hngh.domain:make-key-pin
           :key-identifier "peer-1"
           :key-path "/tmp/-malformed.pub")))
       "option-like key path refuses")
(check (signals-error-p
        (lambda ()
          (hngh.domain:make-key-pin
           :key-identifier "peer-1"
           :key-path "relative/key.pub")))
       "relative key path refuses")

(let* ((first (hngh.domain:make-key-pin
              :key-identifier "peer-1" :key-path "/tmp/peer-1.pub"))
       (second (hngh.domain:make-key-pin
               :key-identifier "peer-2" :key-path "/tmp/peer-2.pub"))
       (pins (list first second))
       (registry (hngh.domain:make-key-pin-registry pins)))
  (setf (first pins) second)
  (check (and (eq first (hngh.domain:lookup-key-pin registry "peer-1"))
              (eq second (hngh.domain:lookup-key-pin registry "peer-2"))
              (null (hngh.domain:lookup-key-pin registry "missing-peer")))
         "registry lookup isolates source list and handles hit and miss")
  (let ((reported (hngh.domain:key-pin-registry-pins registry)))
    (setf (first reported) nil)
    (check (eq first (hngh.domain:lookup-key-pin registry "peer-1"))
           "registry pin reader returns a defensive list copy")))

(check (signals-error-p
        (lambda ()
          (hngh.domain:make-key-pin-registry
           (list (hngh.domain:make-key-pin
                  :key-identifier "peer-1" :key-path "/tmp/one.pub")
                 (hngh.domain:make-key-pin
                  :key-identifier "peer-1" :key-path "/tmp/two.pub")))))
       "duplicate key identifiers refuse")

;;; Rung 14: the key algorithm is a closed vocabulary on every pin --------

(check (member :ed25519 hngh.domain:+key-algorithms+)
       "ed25519 is a closed key algorithm")
(check (member :rsa-sha256 hngh.domain:+key-algorithms+)
       "rsa-sha256 is a closed key algorithm")

(let* ((pin (hngh.domain:make-key-pin
             :key-identifier "peer-1" :key-path "/tmp/peer-1.pub"
             :algorithm :ed25519)))
  (check (and (hngh.domain:key-pin-p pin)
              (eql :ed25519 (hngh.domain:key-pin-algorithm pin)))
         "a key pin carries its explicit algorithm"))

(check (eql :rsa-sha256
            (hngh.domain:key-pin-algorithm
                 (hngh.domain:make-key-pin
              :key-identifier "peer-1" :key-path "/tmp/peer-1.pub")))
       "a key pin defaults to rsa-sha256")

(dolist (bad '(:bogus "ed25519" nil 42))
(check (signals-error-p
        (lambda ()
                 (hngh.domain:make-key-pin
             :key-identifier "peer-1" :key-path "/tmp/peer-1.pub"
             :algorithm bad)))
         (format nil "an unknown key algorithm refuses: ~S" bad)))
