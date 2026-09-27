# How should broadsheet fetches attach the dashboard token and fail closed (error state, no fake data) on 401/403?

Status: crystallized 2026-09-27 from research line `arc-20260927-dashboard-fail-closed-auth`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-arc-20260927-dashboard-fail-closed-auth.md.

# research beat 2026-09-27

_line: How should broadsheet fetches attach the dashboard token and fail closed (error state, no fake data) on 401/403? | state: contracting -> contracting | model: unsloth:unsloth/Ornith-1.0-9B-GGUF | wall_s: 42.0_

---

# Research Line Transition: Dashboard Token Attachment and Fail-Closed Fetches — Final Record

## Capability statement

This transition is the **contracting phase** of the line. The prior beat (2026-09-27) produced three recommendations. This beat contracts those into a final structured record: findings, recommendations, and open threads.

**Honest constraint**: I have no tool access to read either repository — not the working repo containing `research-lines.tsv`, and not `[redacted path] I will not fabricate file paths. Where a claim references prior material, I cite it as a pointer that requires repo access to verify. Where a claim needs external sources I cannot verify, I say so explicitly.

---

## Findings

### Finding 1: Token attachment must be explicit, not ambient

The dashboard token is a credential that must travel with every dashboard-scoped fetch. Ambient state (environment variables, process globals) is unreliable across multi-process flows — a known hazard in storeless CLI patterns. Explicit configuration is auditable, testable, and survives process boundaries.

### Finding 2: Fail-closed states must be a closed enum

hngh's ceremony pattern is built on closed vocabularies. Raw exceptions propagate unstructured error states that can leak fake data into the dashboard. A closed enum makes "fail closed" testable and auditable. Any outcome outside the enum is itself a bug.

### Finding 3: 401 and 403 require differentiated handling

RFC 9110 defines 401 (unauthenticated) and 403 (forbidden) as fundamentally different failure modes. Conflating them produces incorrect user-facing messages and incorrect retry policies. 401 requires re-authentication; 403 requires investigation and hard back-off.

### Finding 4: Startup validation must occur before any outbound request

If the token is missing at startup, no fetch should be attempted. This prevents the dashboard from displaying stale or fake data while the operator is still configuring credentials.

---

## Recommendations

### Recommendation 1: Token attachment via dedicated config field

**Spec**:
- Define a `dashboard_token` field in `hngh-automation`'s config schema (YAML/TOML)
- The fetch layer reads this field at startup and validates it is non-empty before any outbound request
- If empty at startup → fail closed immediately with `no_token_configured` state, no fetch attempted
- If populated → attach to all dashboard-scoped fetches via a fixed header name (e.g., `Authorization: Bearer <token>`)

**Rationale**: Explicit config is auditable and testable. Ambient state (env vars, process globals) is exactly what gets lost between processes in storeless CLI flows.

### Recommendation 2: Fail-closed states as a closed enum

**Spec**:
```
FetchOutcome enum:
  - ok
  - unauthenticated    # 401: token missing/expired
  - forbidden          # 403: token valid but insufficient scope
  - transport_error    # network/DNS/TLS failure
  - no_token_configured # startup validation failure
```

**Rules**:
- Any outcome outside this enum is itself a bug (closed vocabulary principle)
- `unauthenticated` → fail closed, surface "token missing/expired", do not retry with same token
- `forbidden` → fail closed, surface "token valid but forbidden", back off hard, no retry loop
- `transport_error` → fail closed, surface "connection failed", no fake data
- `no_token_configured` → fail closed at startup, no fetch attempted

**Rationale**: Raw exceptions propagate unstructured error states that can leak fake data into the dashboard. A closed enum makes "fail closed" testable and auditable.

### Recommendation 3: 401 and 403 must be distinguished, not conflated

**Spec**:
- **401 response**: Set `FetchOutcome.unauthenticated`. Message: "Dashboard token is missing or expired. Re-authenticate." Action: Do not retry with same token. Require user re-authentication.
- **403 response**: Set `FetchOutcome.forbidden`. Message: "Dashboard token is valid but insufficient for this operation." Action: Back off hard. No retry loop. Log for investigation.

**Rationale**: Standard HTTP semantics (RFC 9110) define them as fundamentally different failure modes. Conflation produces incorrect user-facing messages and incorrect retry policies.

### Recommendation 4: Startup validation gate

**Spec**:
- Add a startup validation gate that checks `dashboard_token` is non-empty before the fetch layer initializes
- If validation fails → exit with `no_token_configured` state, no fetch attempted, no dashboard data displayed
- Log the validation failure with timestamp and operator identity for audit trail

**Rationale**: Prevents the dashboard from displaying stale or fake data while the operator is still configuring credentials.

---

## Open Threads

### Open Thread 1: Config schema location and format

**Question**: Where exactly in the `hngh-automation` config schema should `dashboard_token` live? Is YAML or TOML preferred?

**Status**: Unresolved. Requires repo access to confirm schema conventions.

### Open Thread 2: Header name standardization

**Question**: What is the fixed header name for token attachment? `Authorization: Bearer <token>` is conventional but should be confirmed against the dashboard API spec.

**Status**: Unresolved. Requires repo access to confirm API conventions.

### Open Thread 3: Retry policy for transport errors

**Question**: Should `transport_error` ever be retried? The recommendation says "fail closed, no fake data" but transient network failures may warrant a single retry with exponential back-off.

**Status**: Unresolved. Requires trade-off analysis between availability and data integrity.

### Open Thread 4: Token refresh mechanism

**Question**: If the token expires between fetches, should the fetch layer attempt a refresh token rotation, or should it fail closed immediately?

**Status**: Unresolved. Requires understanding of the dashboard's authentication flow.

### Open Thread 5: Audit trail format

**Question**: What format should the audit trail for `no_token_configured` and `unauthenticated` failures use? JSON? Structured log? Dashboard-visible?

**Status**: Unresolved. Requires understanding of hngh's logging conventions.

---

## References

### Repository references (require access to verify)

- `[redacted path] — hngh kernel repository (ground truth for ceremony patterns, config schema, logging conventions)
- Working repository containing `research-lines.tsv` — source of truth for line state and prior material

### Prior material pointers (require access to verify)

- `[[sources/hngh-storeless-cli-state-loss]]` — Hngh storeless CLI state loss in multi-process flows
- `[[sources/hngh-ceremony-loop-mechanics]]` — hngh dogfood ceremony: closed vocabularies, path positioning
- `[[sources/LES-fail-20260915-If-drift-is-confirmed-in-the-scroll-beha]]` — Research Lesson: If drift is confirmed in the scroll behavior
- `[[sources/LES-fail-20260915-Does-the-research-lines-tsv-schema-inclu]]` — Research Lesson: Does the research lines tsv schema include

### External references (cannot verify without access)

- RFC 9110 — HTTP Semantics (defines 401/403 distinction) — *unverified without access to confirm hngh's adoption*

---

## Line state

**State**: contracting → **final record produced**

**Next action**: This line is complete as a structured record. If implementation work is needed, the open threads above should be addressed in a follow-up transition. The recommendations are ready for review and integration into `hngh-automation`'s config schema and fetch layer.

**Wall clock**: 42.0s since line start.

---

*This transition is the final record for this research line. No further transitions are expected unless open threads are revisited.*
