"""Bead tiers — pure functions, no I/O."""

from __future__ import annotations

from typing import Mapping, Sequence

import contract

_KEYWORDS = ("gate", "kernel", "cert", "scrub")
_RANK = {contract.Tier.T1: 0, contract.Tier.T2: 1, contract.Tier.T3: 2}


def _num(value: object, default: float = 0) -> float:
    try:
        return float(value)  # type: ignore[arg-type]
    except (TypeError, ValueError):
        return default


def tier_for(bead: Mapping) -> contract.Tier:
    """Tier for one bead: explicit "tier" wins, else keyword/staleness."""
    explicit = bead.get("tier")
    if isinstance(explicit, contract.Tier):
        return explicit
    if isinstance(explicit, str):
        try:
            return contract.Tier(explicit.strip().upper())
        except ValueError:
            pass
    text = f"{bead.get('title', '')}\n{bead.get('body', '')}".lower()
    if any(k in text for k in _KEYWORDS):
        return contract.Tier.T1
    if _num(bead.get("age_days")) >= 7 and _num(bead.get("attempts")) >= 2:
        return contract.Tier.T1
    return contract.Tier.T2


def order(beads: Sequence[Mapping]) -> list[Mapping]:
    """T1 before T2 before T3, then age_days descending within a tier."""
    return sorted(beads, key=lambda b: (_RANK[tier_for(b)], -_num(b.get("age_days"))))


def leg_order(legs: Sequence[Mapping]) -> list[Mapping]:
    """Pre-paid quota legs before paid-cash; blocked legs last — a cap
    block re-routes to the next usable leg or the next window."""
    return sorted(legs, key=lambda l: (1 if l.get("blocked") else 0,
                                       0 if l.get("prepaid") else 1))


if __name__ == "__main__":
    _gate = {"title": "gate review", "age_days": 0, "attempts": 0}
    _stale = {"title": "docs tidy", "age_days": 9, "attempts": 3}
    _plain = {"title": "docs tidy", "age_days": 1, "attempts": 0}
    assert tier_for(_gate) is contract.Tier.T1
    assert tier_for(_stale) is contract.Tier.T1
    assert tier_for(_plain) is contract.Tier.T2
    assert tier_for({"tier": "T3", "title": "gate review"}) is contract.Tier.T3
    assert order([_plain, _gate, _stale]) == [_stale, _gate, _plain]
    _legs_ = [{"kind": "cash", "url": "u-c"}, {"kind": "prepaid", "url": "u-p"},
              {"kind": "prepaid", "url": ""}]
    assert [l["url"] for l in leg_order(_legs_)] == ["u-p", "u-c", ""]
    print("tiering self-check ok")
