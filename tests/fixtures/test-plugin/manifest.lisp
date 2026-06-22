;;; Test plugin manifest
;;; SPDX-License-Identifier: AGPL-3.0-or-later

(:name "test-plugin"
 :version "0.1.0"
 :trust-tier :first-party
 :language :cl
 :load "test-plugin.lisp"
 :package "hngh.plugins.test-plugin"
 :init "test-plugin:init"
 :cleanup "test-plugin:cleanup"
 :reload "test-plugin:reload")
