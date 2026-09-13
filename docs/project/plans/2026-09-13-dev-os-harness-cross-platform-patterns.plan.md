<!-- plan: status=proposed risk=normal accepted=- -->
# 2026-09-13 - dev-os-harness-cross-platform-patterns (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

This plan implements the os-harness-cross-platform-patterns research line by establishing a late-binding capability registry and adapter interface for DE/WM, editor, and browser targets in hngh-automation.

## Steps

- [ ] Define a `TargetAdapter` abstract base class with `probe()` and `execute()` methods in `lib/harness/adapters.py`.
  Verification: python3 -c "from lib.harness.adapters import TargetAdapter; assert hasattr(TargetAdapter, 'probe')"
- [ ] Implement a `KDEAdapter` subclass in `lib/harness/adapters/kde.py` that returns a static capability dict for KDE Plasma.
  Verification: python3 -c "from lib.harness.adapters.kde import KDEAdapter; assert KDEAdapter().probe()['de'] == 'kde'"
- [ ] Implement a `GNOMEAdapter` subclass in `lib/harness/adapters/gnome.py` that returns a static capability dict for GNOME.
  Verification: python3 -c "from lib.harness.adapters.gnome import GNOMEAdapter; assert GNOMEAdapter().probe()['de'] == 'gnome'"
- [ ] Create a registry function `resolve_adapter()` in `lib/harness/registry.py` that maps environment variables to adapter instances.
  Verification: python3 -c "import os; os.environ['HNGH_DE']='kde'; from lib.harness.registry import resolve_adapter; assert type(resolve_adapter()).__name__ == 'KDEAdapter'"
- [ ] Add a unit test in `tests/test_adapters.py` verifying that `resolve_adapter()` returns the correct adapter for each supported DE.
  Verification: make test
