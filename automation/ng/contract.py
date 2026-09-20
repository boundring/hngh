"""automation/ng — ledger contract for the beat loop.

Kernel contract — three verbs, one for every kernel:

  observe() — read state from the ledger
  judge()   — a Jev seam call or a deterministic check
  act()     — write an event, or request a certificate

Load-bearing rule: kernels NEVER talk to each other directly. Every
edge is (a) an Event written to the ledger, or (b) a mutation certified
through the certificate lane. Jev verdicts are advisory; the certificate
lane stays the only mutation path (fail closed).

All modules here import `contract` as a sibling module (run with cwd
automation/ng/ or that dir on sys.path). Stdlib only.
"""
from __future__ import annotations

import time
from dataclasses import dataclass, field
from enum import Enum
from typing import Any, Mapping, Sequence


class Verdict(str, Enum):
    """Closed label set for judgment outputs."""
    DONE = "done"
    UNCERTAIN = "uncertain"
    ESCALATE = "escalate"


class Tier(str, Enum):
    """Bead tiers."""
    T1 = "T1"  # gates, synthesis, must-land slices
    T2 = "T2"  # ordinary work
    T3 = "T3"  # whenever capacity allows


@dataclass(frozen=True)
class Event:
    """A typed state delta — the only inter-kernel edge.

    state_version binds the event to the ledger snapshot it was cut
    against; consumers must refuse stale versions (fail closed).
    """
    kind: str                    # e.g. bead.ready, gate.red, audit.finding
    state_version: int
    payload: Mapping[str, Any]
    created_at: float = field(default_factory=time.time)
    refs: tuple[str, ...] = ()   # evidence hashes / bead ids cited


@dataclass(frozen=True)
class Question:
    """A bounded Jev question: fixed slots + closed labels, no prose."""
    head: str                    # judgment head, e.g. "triage"
    slots: Mapping[str, Any]     # fixed-schema input row
    labels: tuple[str, ...]      # closed answer set
    state_version: int


@dataclass(frozen=True)
class Answer:
    """Jev verdict, bound to the snapshot it judged."""
    verdict: Verdict
    label: str | None            # which closed label, if any
    evidence: tuple[str, ...]    # hashes cited; verified downstream
    state_version: int


class Kernel:
    """Base class for every kernel."""

    name: str = "kernel"

    def observe(self, ledger: Any) -> Sequence[Event]:
        raise NotImplementedError

    def judge(self, question: Question) -> Answer:
        raise NotImplementedError

    def act(self, event: Event) -> None:
        raise NotImplementedError