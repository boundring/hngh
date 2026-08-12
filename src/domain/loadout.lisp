(in-package #:hngh.domain)

(defun ensure-nonnegative-integer (value name)
  (unless (and (integerp value) (not (minusp value)))
    (error "~A must be a nonnegative integer" name))
  value)

(defun ensure-keyword (value name)
  (unless (keywordp value)
    (error "~A must be a keyword" name))
  value)

(defstruct (loadout
            (:constructor %make-loadout
                (route-label context-limit token-limit cost-limit time-limit
                 tool-labels network-labels writable-scopes))
            (:conc-name %loadout-))
  (route-label nil :read-only t)
  (context-limit nil :read-only t)
  (token-limit nil :read-only t)
  (cost-limit nil :read-only t)
  (time-limit nil :read-only t)
  (tool-labels nil :read-only t)
  (network-labels nil :read-only t)
  (writable-scopes nil :read-only t))

(defun loadout-route-label (loadout)
  (%loadout-route-label loadout))

(defun loadout-time-limit (loadout)
  (%loadout-time-limit loadout))

(defun make-loadout (&key route-label context-limit token-limit cost-limit
                          time-limit tool-labels network-labels writable-scopes)
  (%make-loadout
   (ensure-keyword route-label "route label")
   (ensure-nonnegative-integer context-limit "context limit")
   (ensure-nonnegative-integer token-limit "token limit")
   (ensure-nonnegative-integer cost-limit "cost limit")
   (ensure-nonnegative-integer time-limit "time limit")
   (ensure-label-list tool-labels "tool labels")
   (ensure-label-list network-labels "network labels")
   (ensure-label-list writable-scopes "writable scopes")))
