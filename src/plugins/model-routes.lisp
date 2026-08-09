;;;; plugins/model-routes.lisp — model route table + task-class→model routing
;;;;                                 (M8 seed, docs/design/model-routing.md).
;;;;
;;;; Design verification step task #2: land the routing table as DATA with a
;;;; read-only parse test — seed M8 without committing to full routing logic.
;;;;
;;;; Route split (2026-08, human steer): the primary AGENTIC model is
;;;; deepseek-v4-flash; the primary CODING model is gpt-5.6-luna. Other routes
;;;; stay as fallback positions, not primary, per the cost ladder + the
;;;; 2026-08-05 mandate (cheapest capable beats free faucets on $-per-D).

(in-package :hngh.plugins.model-routes)

;;; --- Route table (mirror of docs/design/model-routing.md §routes) ----------

(defparameter *routes*
  '((:id :local-12b    :backend :ollama   :model "gemma-4-12B-it-qat"      :price 0.0  :class :local)
    (:id :local-long   :backend :unsloth  :model "Qwythos-9B"              :price 0.0  :class :local)
    (:id :local-heavy  :backend :unsloth  :model "Qwen3.6-27B"             :price 0.0  :class :local)
    (:id :or-free      :backend :openrouter :model "nemotron-3-ultra-550b" :price 0.0 :class :free)
    (:id :gemini-free  :backend :gemini   :model "gemini-3.5-flash"        :price 0.0 :class :free)
    (:id :kimi-sub     :backend :kimi     :model "kimi-for-coding"         :price 0.0  :class :quota)
    (:id :copilot      :backend :copilot  :model "claude-sonnet-5"         :price 0.0  :class :quota)
    (:id :cheap        :backend :openai   :model "gpt-5.6-luna"            :price 0.35 :class :payg)
    (:id :or-dsv4      :backend :openrouter :model "deepseek-v4-flash"     :price 0.09 :class :payg)
    (:id :zen-drain    :backend :zen      :model "gpt-5.6-luna"            :price 0.0  :class :quota)
    (:id :frontier     :backend :openai   :model "gpt-5.6-terra"           :price 3.0  :class :payg))
  "The model route table. Each route: (:id :backend :model :price :class).
Mirror of docs/design/model-routing.md §routes; the authoritative copy for
the read-only parse test.")

;;; --- Role → primary/coding model split (2026-08 human steer) ---------------

(defparameter *primary-agents*
  '(; human steer: primary AGENTIC model = deepseek-v4-flash
    (:role :agentic :route :or-dsv4 :model "deepseek-v4-flash" :backend :openrouter)
    (:role :coding  :route :cheap  :model "gpt-5.6-luna"      :backend :openai))
  "The two-role primary split: agentic work on deepseek-v4-flash, coding work
on gpt-5.6-luna (2026-08 human steer). The collector is the functional
wire-up; everything else here is data that a future M8 routing load reads.")

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
