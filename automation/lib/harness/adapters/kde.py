from lib.harness.adapters import TargetAdapter


class KDEAdapter(TargetAdapter):
    """KDE Plasma target: static capability dict (plan step 2)."""

    def probe(self) -> dict:
        return {"de": "kde"}

    def execute(self, action: dict) -> dict:
        if not isinstance(action, dict):
            raise ValueError("action must be a dict")
        return {"ok": True, "de": "kde", "action": action}
