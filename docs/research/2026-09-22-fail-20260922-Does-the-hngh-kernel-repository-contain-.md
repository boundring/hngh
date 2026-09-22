# Does the `hngh` kernel repository contain any code or configuration that explicitly parses or validates the `research-lines.tsv` format, and if so, what error messages are generated for schema violations?

Status: crystallized 2026-09-22 from research line `fail-20260922-Does-the-hngh-kernel-repository-contain-`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-fail-20260922-Does-the-hngh-kernel-repository-contain-.md.

# Contracted research line

**Line:** Does the `hngh` kernel repository contain any code or configuration that explicitly parses or validates the `research-lines.tsv` format, and if so, what error messages are generated for schema violations?  
**Lifecycle state:** contracting → contracted  
**Evidence boundary:** This summary is grounded only in the supplied research record and the provided prior-material pointers. I cannot verify live repository contents beyond the named repository root, `[redacted path] from this transition. Therefore, no specific parser file, validator module, configuration file, test file, or error-message string inside that repository is asserted as existing unless it is explicitly supported by the supplied material.

## Findings

1. **No verified kernel-level parser or validator can be cited.**  
   The available material does not identify a concrete file path inside `[redacted path] that explicitly parses `research-lines.tsv`, validates its schema, or enforces its lifecycle-state format.

2. **Candidate parser names remain hypotheses, not confirmed artifacts.**  
   Prior material proposed searching for names such as `tsv_parser.py`, `line_state.py`, `research_lines.py`, `validation.py`, and functions such as `validate_line_state`, `check_schema`, or `parse_research_lines`. These are plausible search targets, but the supplied record does not confirm that any of them exist in the `hngh` kernel repository.

3. **No schema-violation error messages can be enumerated.**  
   Because no verified parser, validator, configuration file, or test suite has been identified, no specific error strings for missing fields, invalid lifecycle states, malformed TSV structure, or other schema violations can be responsibly attributed to the `hngh` kernel repository.

4. **The line-state record itself is operationally referenced, but that does not prove kernel-level validation.**  
   The current research process treats `research-lines.tsv` as the line-state carrier. That supports the conclusion that the file has an operational role in the research process, but it does not by itself demonstrate that the `hngh` kernel

[truncated at model call: completion hit the max_tokens cap (finish_reason=length) - re-run the beat]
