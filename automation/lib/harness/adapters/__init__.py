"""Target adapters: late-binding DE capability probes (plan 2026-09-13-dev-os-harness-cross-platform-patterns)."""
from abc import ABC, abstractmethod


class TargetAdapter(ABC):
    """A desktop-environment harness target.

    probe() returns a capability dict carrying at least {"de": <name>}.
    execute(action) runs one action dict and returns a result dict.
    """

    @abstractmethod
    def probe(self) -> dict:
        """Return the static capability dict for this target."""

    @abstractmethod
    def execute(self, action: dict) -> dict:
        """Execute one action dict; fail closed on non-dict action."""
