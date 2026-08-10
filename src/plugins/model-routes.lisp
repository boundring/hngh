;;;; plugins/model-routes.lisp — model route table + task-class→model routing
;;;;                                 (M8 seed, docs/design/model-routing.md).
;;;;
;;;; Design verification step task #2: land the routing table as DATA with a
;;;; read-only parse test — seed M8 without committing to full routing logic.
;;;;
;;;; Route split (2026-08, operator policy): DeepSeek Flash is the interactive
;;;; agentic and coding default. Other routes require an explicit policy gate.

(in-package :hngh.plugins.model-routes)

;;; --- Route table (mirror of docs/design/model-routing.md §routes) ----------

(defparameter *routes*
  '((:id :local-12b    :backend :ollama   :model "gemma-4-12B-it-qat"      :price 0.0  :class :local)
    (:id :local-long   :backend :unsloth  :model "Qwythos-9B"              :price 0.0  :class :local)
    (:id :local-heavy  :backend :unsloth  :model "Qwen3.6-27B"             :price 0.0  :class :local)
    (:id :or-free      :backend :openrouter :model "nemotron-3-ultra-550b" :price 0.0 :class :free)
    (:id :gemini-free  :backend :gemini   :model "gemini-3.5-flash"        :price 0.0 :class :free)
    (:id :kimi-k3     :backend :kimi     :model "k3"                    :price 0.0  :class :quota)
    (:id :cheap        :backend :openai   :model "gpt-5.6-luna"            :price 0.35 :class :payg)
    (:id :or-dsv4      :backend :openrouter :model "deepseek-v4-flash"     :price 0.09 :class :payg)
    (:id :zen-drain    :backend :zen      :model "gpt-5.6-luna"            :price 0.0  :class :quota)
    (:id :frontier     :backend :openai   :model "gpt-5.6-terra"           :price 3.0  :class :payg))
  "The model route table. Each route: (:id :backend :model :price :class).
Mirror of docs/design/model-routing.md §routes; the authoritative copy for
the read-only parse test.")

;;; --- Role → primary model split (operator cost policy) ----------------------

(defparameter *primary-agents*
  '(; Operator policy: interactive agentic and coding work starts on Flash.
    (:role :agentic :route :or-dsv4 :model "deepseek-v4-flash" :backend :openrouter)
    (:role :coding  :route :or-dsv4 :model "deepseek-v4-flash" :backend :openrouter))
  "The cost-floor primary split. Specialist routes require an explicit policy
packet; this data table does not make them defaults.")

;;; --- Functional accessors -------------------------------------------------

(defun route-elt (route-id key)
  "Return KEY of route ROUTE-ID (e.g. :model), or NIL when absent."
  (let ((route (find route-id *routes* :key (lambda (r) (getf r :id)))))
    (and route (getf route key))))

(defun route-model (route-id)
  "Return the model string for ROUTE-ID, or NIL."
  (route-elt route-id :model))

(defun role-model (role)
  "Return the primary model for ROLE (:agentic or :coding), or NIL.
Backstop: if no explicit role entry, fall back to the agentic primary."
  (or (getf (find role *primary-agents* :key (lambda (r) (getf r :role)))
            :model)
      (getf (find :agentic *primary-agents* :key (lambda (r) (getf r :role)))
            :model)))
