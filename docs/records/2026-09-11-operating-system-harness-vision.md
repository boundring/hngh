# 2026-09-11 -- operating-system harness vision: operator long-horizon directive

Operator-directed 2026-09-11: this record captures the operator's long-run
vision for Hngh, in the operator's own framing, plus the staging decision
and near-term ladder that serve it. Records only; no capability is built
tonight.

## The vision (operator's words, distilled)

Hngh's long-run ambition is to become an operating system in its own right
-- a Linux distribution taking advantage of CachyOS or other distros -- OR
an operating-system HARNESS installable alongside practically any OS:
paired with the Linux kernel, systemd, and supporting packages, adjusting
to, optimizing for, and aiding configuration and use of the operator's
choice of additional software (DE/WM: KDE vs GNOME vs X11-variants;
editors; browsers) -- a fully-harnessed agentic OS suited to user
preference.

Hngh is a wrapper and QoL improvement for an OS, or its own OS. The
operator's framing, kept as intent language: computers and devices are
little houses for data and technology-extended capabilities; Hngh's arms
and legs are the operator's arms and legs; agentic capability becomes
operator capability; memory and recall ride alongside operator experience;
Hngh is the offload for meaningless complication.

Method: clean architecture's late binding -- rely on open-source material.
The only eventual hard limits are vendor-locked device drivers, which could
require extensive reverse-engineering (game-genie-class device tooling is
the named long-run flavor). Browser-relay plus the operator's Kagi
subscription covers internet-source research until then.

Run-up: Hngh advances fulfilment for the CURRENT operator first -- operator
steering recorded as coherent intent, progressively automated so the
operator observes and comments via daily/day-quarterly news briefs in
dashboard + email, submitting feedback and feature requests.

## Staging decision

The distribution ambition is explicitly BACK-BURNERED: the near-term work
is the OS-harness shape (install alongside, adjust to, aid), which is the
strict subset of the distro ambition and no wasted motion toward it.
Named triggers to revisit the distro path:

- The kernel + automation tier runs reliably on a second machine.
- An installer-verified install exists on N distinct distros.
- A stranger-capable install path exists (someone else can install it).

Until those hold, no distro packaging effort is admitted.

## The near-term ladder

1. Interactive installer skeleton (host orientation pass, backlog
   `host orientation pass`, is the existing anchor).
2. Environment contract: what Hngh expects of a host (kernel, systemd,
   packages, secrets seam) written down and checkable.
3. Package registry: the operator's chosen software per host, declared
   and reconciled rather than edited in place (rides the config-manager
   backlog row).
4. Cross-platform abstraction: late-binding edges so the same harness core
   adjusts to different DE/WM/editor/browser choices.

Each rung rides the normal gates: backlog row, proposal, certificate -- no
shortcut.

## Research tracks implied

Queued via automation/research-subjects.txt (2026-09-11): distro packaging
prior art; systemd integration depth; cross-platform harness patterns.
These are stage 5 research beats, admitted per the house alternation.

Linked records: [social-surfaces policy](2026-09-11-social-surfaces-policy.md),
[OSS contribution policy](2026-09-11-oss-contribution-policy.md).