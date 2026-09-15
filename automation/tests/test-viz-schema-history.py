#!/usr/bin/env python3
"""Acceptance gate for the history payload schema: {'schema': 'history/1',
'entries': [{'key', 'ts', 'summary'}...]}.

The history payload PRODUCER DOES NOT EXIST YET: it lands via deep-task
node viz-history-payload (survey of loop-history / sessions / telemetry
history producers and dashboard consumers). These tests are the
ACCEPTANCE GATE that producer must pass: nothing may emit a history
payload that fails this file.

Contract (pending, pinned by node schema-tests-history / the
schema-validation-contract): fail closed on malformed JSON; missing or
non-string 'schema'; unknown schema version; unknown keys in the
envelope; unknown keys inside an entry when their value is a nested
object/array (a nested payload could hide deeper schema violations);
missing required entry fields; wrong types; duplicate entry keys. WARN
and accept (additive tolerance) only for an unknown extra ENTRY key
carrying a scalar value.

Validator seam: targets automation/jobs/viz_schema.py
validate_history(payload_text) -> (ok, detail, warn) from node
schema-validate-seam. Until that module lands, an in-file contract seam
with exactly these semantics runs the gate; when viz_schema.py appears,
it is loaded instead and a missing validate_history fails loudly here.

Hermetic: stdlib only, tmp file fixtures, no network, no producer, no
dashboard dependency.
"""

import importlib.util
import json
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SEAM = ROOT / "jobs" / "viz_schema.py"
HISTORY_SCHEMA = "history/1"


# ---------------------------------------------------------------------------
# Contract seam (stands in for automation/jobs/viz_schema.py until it lands)
# ---------------------------------------------------------------------------

def _contract_validate_history(payload_text):
    """validate(payload_text) -> (ok, detail, warn) for the history/1
    envelope. Mirrors the schema-validate-seam contract so the acceptance
    semantics are executable before the shared validator exists."""
    try:
        payload = json.loads(payload_text)
    except (json.JSONDecodeError, ValueError):
        return (False, "fail: malformed JSON: history payload is not parseable", [])

    if not isinstance(payload, dict):
        return (False, "fail: history envelope must be a JSON object", [])

    warns = []

    if "schema" not in payload:
        return (False, "fail: missing required envelope key 'schema'", [])
    schema = payload["schema"]
    if not isinstance(schema, str):
        return (False, "fail: 'schema' must be a string, got %r" % (schema,), [])
    if schema != HISTORY_SCHEMA:
        return (False, "fail: schema version mismatch: expected '%s', got '%s'"
                % (HISTORY_SCHEMA, schema), [])

    for key, value in payload.items():
        if key not in ("schema", "entries"):
            return (False, "fail: unknown envelope key %r (fail closed)"
                    % (key,), [])

    if "entries" not in payload:
        return (False, "fail: missing required envelope key 'entries'", [])
    entries = payload["entries"]
    if not isinstance(entries, list):
        return (False, "fail: 'entries' must be a list, got %r"
                % (type(entries).__name__,), [])

    seen = set()
    for i, entry in enumerate(entries):
        if not isinstance(entry, dict):
            return (False, "fail: entries[%d] must be a JSON object" % i, [])
        for field in ("key", "ts", "summary"):
            if field not in entry:
                return (False,
                        "fail: entries[%d] missing required field %r" % (i, field), [])
        for field in ("key", "ts", "summary"):
            if not isinstance(entry[field], str):
                return (False,
                        "fail: entries[%d].%s must be a string, got %r"
                        % (i, field, entry[field]), [])
        for key, value in entry.items():
            if key in ("key", "ts", "summary"):
                continue
            if isinstance(value, (dict, list)):
                return (False,
                        "fail: entries[%d] unknown key %r carries a nested %s; "
                        "nested payloads fail closed"
                        % (i, key, type(value).__name__), [])
            warns.append("warn: entries[%d] unknown extra key %r accepted (additive)"
                         % (i, key))
        if entry["key"] in seen:
            return (False, "fail: duplicate entry key %r" % (entry["key"],), [])
        seen.add(entry["key"])

    return (True, "ok: %s payload valid" % HISTORY_SCHEMA, warns)


# ---------------------------------------------------------------------------
# Seam selection: real validator when it lands, contract seam until then
# ---------------------------------------------------------------------------

if SEAM.exists():
    _spec = importlib.util.spec_from_file_location("viz_schema", SEAM)
    _viz_schema = importlib.util.module_from_spec(_spec)
    _spec.loader.exec_module(_viz_schema)
    try:
        validate_history = _viz_schema.validate_history
    except AttributeError as exc:
        raise SystemExit(
            "test-viz-schema-history: automation/jobs/viz_schema.py exists but "
            "exposes no validate_history(payload_text) -> (ok, detail, warn); "
            "update this acceptance gate to the landed seam interface "
            "(node schema-validate-seam).") from exc
else:
    validate_history = _contract_validate_history


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------

def _entry(key="h-2026-09-14", ts="2026-09-14T23:20:13Z",
           summary="witness-grade run, all feeds green"):
    return {"key": key, "ts": ts, "summary": summary}


def _payload(entries=None, **extra):
    envelope = {"schema": HISTORY_SCHEMA,
                "entries": [_entry()] if entries is None else entries}
    envelope.update(extra)
    return envelope


def _validate_obj(payload):
    return validate_history(json.dumps(payload))


# ---------------------------------------------------------------------------
# Acceptance tests
# ---------------------------------------------------------------------------

class HistorySchemaAcceptance(unittest.TestCase):

    def test_valid_fixture_accepts(self):
        ok, detail, warn = _validate_obj(_payload())
        self.assertTrue(ok, detail)
        self.assertEqual([], warn, "clean accept must not warn")

    def test_valid_fixture_survives_json_roundtrip(self):
        text = json.dumps(json.loads(json.dumps(_payload())))
        ok, detail, warn = validate_history(text)
        self.assertTrue(ok, detail)
        self.assertEqual([], warn)

    def test_multiple_valid_entries_accept(self):
        entries = [_entry(key="h-%d" % i) for i in range(3)]
        ok, detail, warn = _validate_obj(_payload(entries=entries))
        self.assertTrue(ok, detail)

    def test_malformed_json_fails_closed(self):
        ok, detail, _ = validate_history("{not json")
        self.assertFalse(ok)
        self.assertIn("malformed", detail)

    def test_missing_schema_key_fails_closed(self):
        payload = _payload()
        del payload["schema"]
        ok, detail, _ = _validate_obj(payload)
        self.assertFalse(ok)
        self.assertIn("schema", detail)

    def test_unknown_schema_version_fails_closed(self):
        ok, detail, _ = _validate_obj(_payload(schema="history/2"))
        self.assertFalse(ok)
        self.assertIn("history/1", detail)
        self.assertIn("history/2", detail)

    def test_non_string_schema_fails_closed(self):
        ok, detail, _ = _validate_obj(_payload(schema=1))
        self.assertFalse(ok)

    def test_missing_entries_key_fails_closed(self):
        payload = _payload()
        del payload["entries"]
        ok, detail, _ = _validate_obj(payload)
        self.assertFalse(ok)
        self.assertIn("entries", detail)

    def test_non_list_entries_fails_closed(self):
        ok, detail, _ = _validate_obj(_payload(entries=_entry()))
        self.assertFalse(ok)

    def test_entry_not_object_fails_closed(self):
        ok, detail, _ = _validate_obj(_payload(entries=["h-1"]))
        self.assertFalse(ok)

    def test_unknown_envelope_key_fails_closed(self):
        for extra in ({"window_days": 30}, {"meta": {"source": "loop-history"}}):
            with self.subTest(extra=extra):
                ok, detail, _ = _validate_obj(_payload(**extra))
                self.assertFalse(ok)
                self.assertIn("envelope", detail)

    def test_unknown_entry_nested_key_fails_closed(self):
        for value in ({"of": "h-1"}, ["h-0"]):
            with self.subTest(value=value):
                entry = _entry()
                entry["repeats"] = value
                ok, detail, _ = _validate_obj(_payload(entries=[entry]))
                self.assertFalse(ok)

    def test_missing_entry_field_fails_closed(self):
        for field in ("key", "ts", "summary"):
            with self.subTest(field=field):
                entry = _entry()
                del entry[field]
                ok, detail, _ = _validate_obj(_payload(entries=[entry]))
                self.assertFalse(ok)
                self.assertIn(field, detail)

    def test_wrong_entry_type_fails_closed(self):
        for field, bad in (("key", 7), ("ts", None), ("summary", ["a"])):
            with self.subTest(field=field, bad=bad):
                entry = _entry(**{field: bad})
                ok, detail, _ = _validate_obj(_payload(entries=[entry]))
                self.assertFalse(ok)

    def test_duplicate_entry_keys_fail_closed(self):
        entries = [_entry(key="h-dup"), _entry(key="h-other"),
                   _entry(key="h-dup")]
        ok, detail, _ = _validate_obj(_payload(entries=entries))
        self.assertFalse(ok)
        self.assertIn("h-dup", detail)

    def test_unknown_extra_entry_scalar_key_warns_and_accepts(self):
        entry = _entry()
        entry["note"] = "carry-over from previous window"
        ok, detail, warn = _validate_obj(_payload(entries=[entry]))
        self.assertTrue(ok, "scalar extra entry keys are additive: %s" % detail)
        self.assertTrue(warn, "accept-with-warning must flag the extra key")


if __name__ == "__main__":
    unittest.main()
