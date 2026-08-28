# telemetry schema exemplars

Status: crystallized 2026-08-28 from research line `telemetry-schema-exemplars`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-telemetry-schema-exemplars.md.

# Telemetry Schema Exemplars — Contracted Line Record

**Line:** telemetry schema exemplars
**Lifecycle state:** contracting
**Target context:** `hngh/hngh-automation`
**Record type:** final structured summary / lasting record for the line

---

## 1. Findings

### F1. Business-level telemetry needs a stable semantic contract
Standard OpenTelemetry conventions are useful, but they do not by themselves define the business meaning of automation-specific signals such as workflow execution, provisioning, tenant isolation, or regional behavior.

For `hngh/hngh-automation`, custom metrics, logs, and traces need a shared business semantic layer. Without it, teams can independently introduce names like:

- `workflow_execution_duration`
- `workflow_exec_time`
- `automation_run_duration_seconds`

...with inconsistent units, missing attributes, and no reliable correlation to traces or logs.

**Implication:**
Without a schema contract, observability becomes fragmented across services, dashboards become brittle, and debugging automation failures requires manual reconstruction of context.

---

### F2. Exemplars are the practical bridge between metrics and traces
Exemplars are metric data points that carry associated trace identifiers and selected attributes. They allow an engineer to move from a metric spike directly to the relevant trace.

The key risk is that exemplars can be dropped during aggregation, downsampling, processor transformation, or export if the pipeline does not explicitly preserve them.

**Implication:**
If exemplars are not preserved end-to-end, metric anomalies in automation pipelines lose their actionable context. Engineers may see a spike in `workflow_execution_duration_seconds` but still need to search logs or traces manually to find the failing step.

---

### F3. Metric-to-trace linkage is fragile without explicit exemplar policy
Automation systems often produce high-value signals such as:

- workflow duration
- step failures
- resource provisioning latency
- retry counts
- tenant-specific execution errors

These metrics are only useful operationally if they can be connected to the actual execution path.

**Implication:**
Exemplars should be treated as first-class telemetry artifacts for critical automation metrics, not optional debug metadata.

---

### F4. Schema evolution requires versioning and compatibility rules
Adding new telemetry fields, such as `cost_center`, `workflow_version`, or `tenant_id`, can break existing pipelines if the schema is not versioned and if collectors/exporters do not handle unknown or evolving fields predictably.

**Implication:**
Without a versioning strategy, schema changes can cause silent data loss, dashboard breakage, alert misbehavior, or pipeline instability.

---

### F5. High-cardinality attributes must be governed
Business attributes such as `tenant_id`, `workflow_id`, and `region` are valuable for correlation, but they can create cardinality problems if used carelessly as metric labels.

**Implication:**
