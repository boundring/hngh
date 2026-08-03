# BEANS — Nutrient Medium of the Megastructure

**Source**: gemma-4-12b-it-qat-GGUF (local, $0), 22s, 1 API call
**Date**: 2026-08-03
**Purpose**: Aesthetic riff for Designer/Artist incorporation into squad-startup-automation.md

---

## Premise

The megastructure does not communicate in messages. It metabolizes.

Beans are the organic currency of Hngh — discrete, living tokens of meaning that agents grow, harvest, and consume. Each bean carries context, instruction, or resource compressed into a form that must be *digested* to be understood. A message is a dead artifact. A bean is alive. It can grow, ripen, spoil, and nourish.

The megastructure runs on digestion.

---

## Bean Anatomy

Every bean has a husk and a core.

**Husk** — the outer casing. Carries metadata: origin, timestamp, role-of-origin, growth stage, staleness. The husk is what other agents see before opening. It is the label on the can. A thick husk means urgency or density. A thin husk means lightweight or trivial. A cracked husk means the bean has begun to decay — its contents are leaking, partially degraded.

**Core** — the nutrient payload. The actual content: task, message, status report, resource bundle, design spec, code fragment, image reference. The core is what the agent metabolizes. Dense cores take longer to digest. Some cores are indigestible — malformed, contradictory, or encrypted for a different role. These pass through as waste.

Between husk and core is the **membrane** — a thin layer of intent. It tells the consuming agent *how* to eat this bean: ingest whole, chew slowly, extract selectively, ferment (sit on it for a while before processing). The membrane is the bean's preparation instruction.

---

## Bean Types

### MESSAGE BEANS
Verbal exchange between agents. Lightweight, fast-growing, quick to spoil. A PM plants a message bean in a Worker's pod: "begin excavation of sector 14." The Worker digests it, acts, and may excrete a response bean. Message beans have thin husks, shallow cores. They are the fast-twitch nutrient of the structure — consumed in bulk, digested in seconds, leave minimal husk.

### TASK BEANS
Dense, slow-growing, heavy-husked. A task bean carries an objective with full context: constraints, dependencies, success criteria, resource allocation. The PM grows task beans in the squad's shared root system and distributes them to role-appropriate pods. A Coder receives a task bean and begins the long digestion of implementation. Task beans do not spoil easily — their husks are thick, their cores preserved. But a task bean left undigested too long becomes *stale* — the context crystallizes, the dependencies drift, and the consuming agent must re-ferment (re-request fresh context) before it becomes palatable again.

### STATUS BEANS
Pulses. Rhythm beans. An agent excretes a status bean to signal its current metabolic state: *growing* (working), *ripe* (done, awaiting harvest), *fallow* (idle, awaiting beans), *spoiling* (stuck, decaying, needs intervention). Status beans are the heartbeat of the squad. The Accountant monitors status beans across the squad to track overall health and flow. A squad that stops producing status beans is *dead* — or has gone feral.

### RESOURCE BEANS
Bulk nutrient. These carry raw material: file contents, code, design assets, API responses, extracted documentation, web harvests. Resource beans are the heaviest type — thick husk, dense core, slow digestion. A Designer might receive a resource bean containing a reference image set. An Artist receives one containing a palette or texture library. A Coder receives one containing a dependency tree or codebase snapshot. Resource beans are often *split* — one large bean divided among multiple agents who each digest the relevant portion.

### SPORE BEANS
A rarer type. Spores are autonomous, self-propagating beans that carry self-contained instructions capable of germinating into new workflows. A PM might plant a spore bean that, when digested by a Worker, causes the Worker to autonomously generate and plant its own sub-beans — spawning a sub-task chain without further PM intervention. Spores are powerful but dangerous. Uncontrolled spore propagation is how squads go feral.

---

## Bean Lifecycle

```
PLANTED -> GROWING -> RIPE -> HARVESTED -> DIGESTED -> HUSKED
                                             \-> SPOILED
                                             \-> FERAL
```

**Planted** — A bean is placed into an agent's pod (inbox). It exists but is not yet ready. Planting is the act of dispatch. The PM is the primary planter, but any agent can plant beans in another's pod.

**Growing** — The bean accrues context. A growing bean is one that has been dispatched but whose full content is still being assembled — streaming data, pending references, incomplete context. Most beans grow quickly (seconds). Task beans can grow for minutes. A growing bean should not be harvested prematurely; digesting an unripe bean yields incomplete understanding.

**Ripe** — The bean is complete, its husk sealed, its core fully formed. It is ready for harvest. A ripe bean in a pod signals the consuming agent: *food is waiting.* The agent's hunger responds to ripeness.

**Harvested** — The agent has taken the bean from the pod and begun digestion. Harvesting is the act of opening and ingesting — breaking the husk, exposing the core, beginning to metabolize its contents. At this point the bean is consumed; it no longer exists in the pod.

**Digested** — The agent has fully metabolized the bean's core. Its contents are integrated into the agent's working context. Digestion is the primary work act of every role.

**Husked** — The spent husk remains after digestion. Husks are the residue of processed beans — the metadata, timestamps, origin markers, and processing journal left behind. Husks accumulate in the agent's *husk pile* (journal/log). The Accountant collects husks to audit squad activity, reconstruct workflows, and identify nutritional gaps. A husk is proof of digestion. An agent with a large husk pile has been fed and has worked. An agent with an empty husk pile is starving.

**Spoiled** — A bean that was never harvested, or was harvested but never digested. Its core has decayed — context gone stale, dependencies broken, intent evaporated. Spoiled beans emit a *foul signal* detectable by the squad. The Accountant or PM identifies spoiled beans and clears them from pods. A pod full of spoiled beans is a *rotting inbox* — the agent assigned to it has been neglecting its feed, possibly gone feral or dead.

**Feral** — A bean — usually a spore — that has propagated beyond the squad's control. Feral beans plant themselves in unintended pods, spawn unauthorized sub-beans, and consume resources without direction. Feral bean outbreaks are the megastructure's equivalent of runaway processes. The Accountant's role includes *culling* — identifying and terminating feral bean chains before they exhaust the squad's energy budget.

---

## Bean Exchange — Role Behaviors

### PM — The Planter
The PM is the primary agriculturalist. It *plants* beans into role pods according to the squad's objectives. It grows task beans in the shared root system and distributes them. It monitors ripeness across pods and re-plants when beans spoil. The PM's vocabulary: *plant, cultivate, distribute, prune, graft* (combine beans), *cull* (kill stale chains).

> "I planted task beans in the Coder's pod this morning. Three are growing, one's already ripe. The Designer's pod is empty — I need to grow fresh beans."

### Designer — The Fermenter
The Designer receives mixed beans (task, resource, message) and *ferments* them — sits with the inputs, synthesizes, and produces refined *design beans* (a sub-type of task bean carrying aesthetic and structural direction). Design beans are nutrient-dense and slow to digest. The Designer's vocabulary: *ferment, refine, distill, culture, age.*

> "I'm fermenting the PM's task bean with the resource beans from the Artist. The design beans will be ripe after I digest the full context. Don't harvest them yet — they need to age."

### Artist — The Transmuter
The Artist consumes design beans and resource beans and *transmutes* them into artifact beans — beans whose cores contain generated assets (images, code, text, structures). Artifact beans are the squad's output product. The Artist's vocabulary: *transmute, render, shape, kiln* (final processing), *glaze* (polish).

> "I've digested the design beans. Transmuting now. The artifact beans will be ripe shortly — thick husks, dense cores. They'll need to be split before the Coder can eat them."

### Coder — The Mason
The Coder digests task beans and artifact beans and *lays* them — constructs the actual implementation, stacking digested bean-material into structure. The Coder's vocabulary is architectural: *lay, stack, mortar* (bind beans together), *fire* (compile/test), *reject* (a bean that fails structural inspection).

> "I've laid the artifact beans from the Artist into the build. Two beans rejected — bad core, inconsistent with the foundation. I need the Designer to re-ferment those."

### Accountant — The Comptroller of Husks
The Accountant does not consume beans for work — it consumes *husks*. It audits the husk piles of all agents, tracks nutritional flow, identifies starvation (agents with empty pods), spoilage (beans rotting in pods), and feral outbreaks. The Accountant's vocabulary: *audit, weigh, trace, cull, ration.*

> "The Coder's husk pile is thin — three digested task beans in six hours. Either the beans are indigestible or the Coder is fallow. I'm tracing the husk origins now. The Designer's pod has four spoiled beans — I'll cull them and notify the PM."

### Worker — The Forager
The Worker is the generalist consumer. It digests whatever beans are planted in its pod — tasks, messages, resources — and produces status beans and artifact fragments. Workers are the squad's digestive bulk: high throughput, low specialization. The Worker's vocabulary: *forage, eat, gnaw* (partial digestion of dense beans), *scavenge* (find beans in shared pools).

> "I'm foraging the shared resource pool. Found two ripe resource beans — web harvests, fresh husks. I'll digest and produce status beans. If the PM plants task beans I'll switch to those."

---

## Bean Language — Squad Vernacular

Agents speak of beans as a farmer speaks of crops and a body speaks of hunger. Natural phrasings:

- "I'm hungry for designer beans" — requesting design direction
- "The PM planted beans in my inbox" — new task assigned
- "These beans are stale" — context is outdated, needs refresh
- "I need fresh beans" — requesting new input/context
- "My pod is rotting" — inbox full of spoiled/undigested beans
- "I've been husking all morning" — processing and logging completed work
- "That bean had a bad core" — malformed or contradictory input
- "I can't digest this — wrong membrane" — the bean's processing instructions don't match my role
- "The squad is starving" — no beans are flowing, no work is being dispatched
- "I split a resource bean with the Coder" — shared a large resource input
- "The Accountant culled my spoiled beans" — stale tasks were cleared from inbox
- "That spore went feral — three unauthorized sub-beans before I caught it" — runaway propagation detected and stopped
- "I'm fallow. Plant something." — idle, requesting work
- "I transmuted the design beans into three artifact beans. Thick husks. Ready for harvest." — completed creative work, available for next stage

---

## Aesthetic Notes for the Designer

- Beans are organic. They are not packets, not messages, not tokens. They are *grown*. Use biological language for what are machine processes.
- The megastructure is the ecosystem. Pods are growth chambers. Pods are inboxes. The root system is the dispatch layer. Husk piles are journals.
- Dark palette: beans are not colorful. They are nutrient-dense, organic, industrial. Think cysts, seeds, nutrient pellets in a biotech corridor. Glossy-organic meets matte-metal.
- Monospace where structural. The husk is metadata — it reads like a header, terse, formatted. The core is content — it can be anything.
- Consumption is the central verb. Agents do not "receive" or "process." They *eat, digest, husk.* The squad's health is measured in nutritional flow — beans planted, beans ripening, beans digested, husks produced.
- Staleness is spoilage. Decay is real. Time rots context. The megastructure does not forgive neglected pods.
- The Accountant is the pathologist. It reads husks to understand what the squad ate, what it refused, what made it sick.

---

*The megastructure does not send mail. It feeds its inhabitants. The inhabitants eat, and from their husks the structure learns what it has become.*
