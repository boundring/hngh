#!/usr/bin/env python3
"""Plan reference sections + routed template drift check, hermetic.

Inventory items 1, 2, 4, 5 (docs/research/2026-09-09-queue-dependency-
inventory.md): plans/README.md carries a verification contract, an
autonomy reference, and a ceremony runbook so steps cite them instead
of repeating paragraphs; routing drafts candidates from
routed-candidate-template.md-shaped files, so the template's
placeholders must match the fields scripts/router-tick.py fills
(candidate_text: routed-from front-matter, identity line, alert text,
one step + verification).
"""

import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PLANS = ROOT.parent / "docs" / "project" / "plans"
TEMPLATE = PLANS / "routed-candidate-template.md"
README = PLANS / "README.md"
STAGING = PLANS / "2026-09-03-staging.plan.md"


class PlanTemplates(unittest.TestCase):
    def test_readme_has_three_reference_sections(self):
        text = README.read_text(encoding="utf-8")
        for section in ("## Verification contract", "## Autonomy reference",
                        "## Ceremony runbook"):
            self.assertIn(section, text)
        self.assertIn("New plans cite the reference sections", text)

    def test_routed_template_matches_router_fields(self):
        text = TEMPLATE.read_text(encoding="utf-8")
        # Fields scripts/router-tick.py candidate_text() fills:
        self.assertIn("routed-from=<ALERT_IDENTITY>", text)
        self.assertIn("alert identity `<ALERT_IDENTITY>`", text)
        self.assertIn("Alert text: <ALERT_TEXT>", text)
        self.assertRegex(text, r"- \[ \] <ONE_CONCRETE_STEP")
        self.assertIn("Verification:", text)
        # Front-matter must stay parseable: status=proposed, accepted=-
        self.assertIn("status=proposed risk=normal accepted=-", text)

    def test_staging_annotated_front_matter_untouched(self):
        text = STAGING.read_text(encoding="utf-8")
        first = text.splitlines()[0]
        self.assertTrue(first.startswith("<!-- plan: status="), first)
        self.assertIn("status=", first)
        self.assertIn("plans/README.md \"Autonomy reference\"", text)


if __name__ == "__main__":
    unittest.main(verbosity=2)