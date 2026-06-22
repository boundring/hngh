;;;; core/plugin-host.lisp — Hngh Plugin Host (A1)
;;;;
;;; Loads, unloads, and manages the lifecycle of CL plugins.
;;; Plugin manifests are plists read from YAML-like Lisp data files.
;;; Each CL plugin loads into its own package (hngh.plugins.<name>)
;;; with explicit imports — package-level isolation (D11).
;;;
;;; Manifest format (Lisp plist, saved as .lisp file):
;;;   (:name "my-plugin"
;;;    :version "0.1.0"
;;;    :trust-tier :first-party
;;;    :language :cl
;;;    :load "my-plugin"           ; ASDF system or file to load
;;;    :package "hngh.plugins.my-plugin"
;;;    :init "my-plugin:init"      ; function called on load
;;;    :cleanup "my-plugin:cleanup" ; function called on unload
;;;    :reload "my-plugin:reload") ; optional hot-reload function
;;;
;;; SPDX-License-Identifier: AGPL-3.0-or-later
;;; SPDX-FileCopyrightText: 2026 boundring <boundring@gmail.com>

(in-package :hngh.core.plugin-host)

(defvar *loaded-plugins* (make-hash-table :test 'equal)
  "Registry of loaded plugins. Key: plugin name (string), value: plugin-info struct.")

(defstruct plugin-info
  "Information about a loaded plugin."
  name            ; string
  version         ; string
  trust-tier      ; :first-party, :signed-community, :user, :ai-generated
  language         ; :cl, :python, :wasm
  package         ; package object (for CL plugins)
  init-fn         ; function or nil
  cleanup-fn      ; function or nil
  reload-fn       ; function or nil
  loaded-at       ; universal-time
  manifest-path   ; pathname of the manifest file
  state           ; :loaded, :loading, :unloading, :error
  )

;;; --- Manifest parsing ---

(defun parse-manifest (path)
  "Read and parse a plugin manifest from PATH.
Returns a plist or signals an error if the file is invalid."
  (unless (probe-file path)
    (error "Manifest file not found: ~A" (namestring path)))
  (with-open-file (stream path :direction :input)
    (let ((form (read stream nil nil)))
      (unless (and (listp form)
                   (getf form :name)
                   (getf form :version))
        (error "Invalid manifest: missing required fields (:name, :version)"))
      form)))

(defun validate-manifest (manifest)
  "Validate a parsed manifest. Returns T or signals error."
  (let ((name (getf manifest :name))
        (version (getf manifest :version))
        (tier (getf manifest :trust-tier))
        (lang (getf manifest :language)))
    (unless (stringp name)
      (error "Manifest :name must be a string, got ~S" name))
    (unless (stringp version)
      (error "Manifest :version must be a string, got ~S" version))
    (unless (member tier '(:first-party :signed-community :user :ai-generated))
      (error "Manifest :trust-tier must be one of :first-party, :signed-community, :user, :ai-generated, got ~S" tier))
    (unless (member lang '(:cl :python :wasm))
      (error "Manifest :language must be :cl, :python, or :wasm, got ~S" lang)))
  t)

(defun resolve-fn (symbol-name package)
  "Resolve a function from SYMBOL-NAME in PACKAGE.
SYMBOL-NAME may be qualified (e.g. \"pkg:fn\") or bare (e.g. \"fn\").
Returns the function or NIL if not found."
  (when (and symbol-name package)
    ;; Strip package prefix if present (e.g. "pkg:fn" -> "fn")
    (let* ((colon-pos (position #\: symbol-name))
           (bare-name (if colon-pos
                          (subseq symbol-name (1+ colon-pos))
                          symbol-name))
           (sym (find-symbol (string-upcase bare-name) package)))
      (when (and sym (fboundp sym))
        (symbol-function sym)))))

;;; --- Plugin loading ---

(defun load-plugin (manifest-path &key (hngh-home hngh:*hngh-home*))
  "Load a plugin from the manifest at MANIFEST-PATH.
Returns the plugin-info struct on success, or signals an error."
  (let ((manifest (parse-manifest manifest-path)))
    (validate-manifest manifest)
    (let* ((name (getf manifest :name))
           (lang (getf manifest :language))
           (package-name (getf manifest :package
                               (intern (concatenate 'string "HNGH.PLUGINS."
                                                    (string-upcase name))
                                       :keyword)))
           (load-target (getf manifest :load))
           (existing (gethash name *loaded-plugins*)))
      ;; If already loaded, error (must unload first)
      (when existing
        (error "Plugin ~A is already loaded (version ~A)" name (plugin-info-version existing)))
      ;; Load by language
      (cond
        ;; CL plugins
        ((eq lang :cl)
         (cond
           ;; ASDF system
           ((and load-target (find-system-p load-target))
            (hngh.core:log-info "Loading plugin ~A (ASDF system: ~A)" name load-target)
            (asdf:load-system (intern (string-upcase load-target) :keyword)))
           ;; File
           (load-target
            (let* ((manifest-dir (make-pathname :directory (pathname-directory manifest-path)))
                   (file-path (merge-pathnames load-target manifest-dir)))
              (hngh.core:log-info "Loading plugin ~A (file: ~A)" name (namestring file-path))
              (load file-path :verbose nil :print nil))))
         ;; Get the package
         (let ((pkg (find-package (string-upcase package-name))))
           (unless pkg
            (error "Plugin ~A did not create package ~A" name package-name))
           ;; Create plugin-info
           (let ((info (make-plugin-info
                        :name name
                        :version (getf manifest :version)
                        :trust-tier (getf manifest :trust-tier)
                        :language lang
                        :package pkg
                        :init-fn (resolve-fn (getf manifest :init) pkg)
                        :cleanup-fn (resolve-fn (getf manifest :cleanup) pkg)
                        :reload-fn (resolve-fn (getf manifest :reload) pkg)
                        :loaded-at (get-universal-time)
                        :manifest-path manifest-path
                        :state :loaded)))
             ;; Call init function if present
             (when (plugin-info-init-fn info)
               (hngh.core:log-debug "Calling init for ~A" name)
               (funcall (plugin-info-init-fn info)))
             ;; Register
             (setf (gethash name *loaded-plugins*) info)
             (hngh.core:log-info "Plugin ~A v~A loaded" name (plugin-info-version info))
             info)))
        ;; Non-CL plugins (Python, WASM) — stub for now
        (t
         (hngh.core:log-warn "Plugin ~A: language ~A not yet supported" name lang)
         nil)))))

(defun find-system-p (name)
  "Check if an ASDF system named NAME is registered."
  (handler-case
      (asdf:find-system (intern (string-upcase name) :keyword) nil)
    (error () nil)))

;;; --- Plugin unloading ---

(defun unload-plugin (name)
  "Unload a plugin by NAME.
Calls the plugin's cleanup function, removes from registry.
Does not delete the package (CL packages can't be deleted portably)."
  (let ((info (gethash name *loaded-plugins*)))
    (unless info
      (hngh.core:log-warn "Plugin ~A is not loaded" name)
      (return-from unload-plugin nil))
    ;; Call cleanup function if present
    (when (plugin-info-cleanup-fn info)
      (hngh.core:log-debug "Calling cleanup for ~A" name)
      (handler-case
          (funcall (plugin-info-cleanup-fn info))
        (error (c)
          (hngh.core:log-warn "Plugin ~A cleanup error: ~A" name c))))
    ;; Remove from registry
    (remhash name *loaded-plugins*)
    (hngh.core:log-info "Plugin ~A unloaded" name)
    t))

;;; --- Plugin reload (hot-patch) ---

(defun reload-plugin (name)
  "Reload a CL plugin by NAME.
If the plugin has a reload-fn, calls it. Otherwise, does unload + load."
  (let ((info (gethash name *loaded-plugins*)))
    (unless info
      (error "Plugin ~A is not loaded" name))
    (cond
      ;; Hot-reload function available
      ((plugin-info-reload-fn info)
       (hngh.core:log-info "Hot-reloading plugin ~A" name)
       (handler-case
           (progn
             (funcall (plugin-info-reload-fn info))
             (hngh.core:log-info "Plugin ~A hot-reloaded" name)
             t)
         (error (c)
           (hngh.core:log-error "Plugin ~A hot-reload failed: ~A" name c)
           nil)))
      ;; Fall back to unload + load
      (t
       (hngh.core:log-info "Reloading plugin ~A (unload + load)" name)
       (let ((manifest-path (plugin-info-manifest-path info)))
         (unload-plugin name)
         (load-plugin manifest-path))))))

;;; --- Query ---

(defun list-plugins ()
  "Return a list of all loaded plugin-info structs."
  (loop for info being the hash-values of *loaded-plugins*
        collect info))

(defun get-plugin (name)
  "Return the plugin-info for NAME, or NIL if not loaded."
  (gethash name *loaded-plugins*))

(defun plugin-loaded-p (name)
  "Return T if a plugin named NAME is loaded."
  (nth-value 1 (gethash name *loaded-plugins*)))

;;; --- Bulk operations ---

(defun unload-all-plugins ()
  "Unload all loaded plugins. Used during shutdown."
  (loop for name being the hash-keys of *loaded-plugins*
        do (unload-plugin name)))

(defun clear-registry ()
  "Clear the plugin registry without calling cleanup functions.
Used during emergency shutdown only."
  (clrhash *loaded-plugins*))