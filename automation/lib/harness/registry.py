import os

from lib.harness.adapters.gnome import GNOMEAdapter
from lib.harness.adapters.kde import KDEAdapter

_ADAPTERS = {"kde": KDEAdapter, "gnome": GNOMEAdapter}


def resolve_adapter():
    """Map HNGH_DE to a TargetAdapter instance; fail closed on unknown/unset."""
    de = os.environ.get("HNGH_DE", "").strip().lower()
    try:
        return _ADAPTERS[de]()
    except KeyError:
        raise ValueError(
            "unknown HNGH_DE %r; supported: %s" % (de, sorted(_ADAPTERS))
        ) from None
