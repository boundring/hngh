# remote access patterns: WoL, tailnet VPN, SSH, headless dashboard exposure

Status: crystallized 2026-08-29 from research line `remote-access-patterns`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-remote-access-patterns.md.

# Final structured summary — remote access patterns: WoL, tailnet VPN, SSH, headless dashboard exposure

**Line:** remote access patterns: WoL, tailnet VPN, SSH, headless dashboard exposure

**State:** contracting → crystallized

**Applicability:** `hngh/hngh-automation`

**Record type:** Lasting research record for this line

---

## Core stance

Remote access for `hngh/hngh-automation` should be treated as a **privileged control plane**, not a convenience network feature.

The durable posture is:

1. **No standing public inbound ports.**
2. **Tailnet/VPN is the normal remote-admin path.**
3. **WoL is only a recovery primitive.**
4. **SSH is a privileged channel and must be tightly scoped.**
5. **Headless dashboards are administrative endpoints, not ordinary web services.**
6. **Every remote access path must be attributable, revocable, and logged.**

This line should remain closed unless a new requirement forces a change in identity model, network topology, recovery strategy, or dashboard exposure model.

---

# Findings

## 1. Remote access is the primary trust boundary

For headless automation systems, remote access paths are not merely “networking details.” They define who can:

- wake machines,
- reach internal services,
- execute privileged commands,
- view operational state,
- modify automation behavior,
- exfiltrate or tamper with local data.

Therefore, remote access should be designed as a **control plane**, not an always-on convenience surface.

The key insight is that each access primitive has a different trust meaning:

| Primitive | Correct role | Incorrect role |
|---|---|---|
| WoL | Recovery / power-state primitive | Normal remote access path |
| Tailnet/VPN | Default authenticated remote network | Flat trusted LAN replacement |
| SSH | Privileged admin channel | Broadly exposed convenience shell |
| Headless dashboard | Administrative endpoint | Public web app or unauthenticated status page |

---

## 2. Wake-on-LAN is a recovery primitive, not an access path

WoL should be understood as a **power-state control**, not a remote administration method.

WoL can be useful when:

- a node is asleep or powered off,
- the operator needs to bring it back into a reachable state,
- no other remote path is available because the node is not running.

But WoL itself should never grant meaningful access. It only changes the node’s power state. After wake, access must still occur through an authenticated channel such as tailnet/VPN, SSH, or an authenticated dashboard proxy.

The main risk is treating WoL as a public convenience endpoint. If WoL can be triggered from untrusted sources, it becomes:

- a denial-of-service vector,
- a reconnaissance signal,
- a path to wake and probe otherwise dormant systems,
- a way to bypass the intended remote-access trust model.

Therefore, WoL should be **disabled by default**, restricted when enabled, and treated as an audited recovery action.

---

## 3. Tailnet/VPN reduces exposure but does not replace identity

Tailnet/VPN is the preferred default remote-admin network because it removes public inbound ports and provides a private addressing model.

However, a tailnet is not automatically safe. The main risk is treating it as a trusted flat network where every node can reach every other node.

A compromised device inside the tailnet should not automatically become able to reach:

- SSH endpoints,
- dashboard control interfaces,
- automation APIs,
- local service ports,
- privileged management interfaces,
- sensitive internal hosts.

The tailnet should be used as a **transport and identity boundary**, not as blanket trust.

The correct model is:

- every node has an explicit identity,
- access is scoped by purpose,
- stale identities are disabled,
- human access requires MFA where supported,
- automation uses scoped or short-lived credentials,
- reachability is periodically audited.

In other words: **tailnet membership is necessary but not sufficient.**

---

## 4. SSH is a high-value privileged channel

SSH remains one of the most useful administration paths for headless systems, but it should be treated as privileged access.

The default risk model is that SSH gives direct shell access to a machine that may control automation, networking, services, or sensitive local state. Therefore, SSH must be hardened and scoped.

Key findings:

- SSH should be key-only.
- Password authentication should be disabled.
- Direct root login should be disabled.
- Access should be limited to named admin users.
- Source access should be restricted to tailnet/VPN or bastion where possible.
- Agent forwarding and unnecessary forwarding features should be disabled by default.
- SSH should be logged and attributable.
- Automation SSH access should use scoped credentials, not broad human keys.

SSH is valuable, but it should not become a loosely governed back door.

---

## 5. Headless dashboards are administrative endpoints

Headless dashboards should not be treated like ordinary web services.

A dashboard on a headless automation node may expose:

- live system state,
- automation controls,
- service status,
- logs,
- configuration,
- device control surfaces,
- API endpoints,
- webhook or integration interfaces.

Even if the dashboard is read-only, it can still be sensitive because it reveals operational state and may include authenticated APIs behind the UI.

Therefore, dashboards should be treated as **administrative endpoints**, with access controlled at the same level as SSH or other privileged remote paths.

The default posture is:

- no direct public exposure,
- access only through tailnet/VPN or authenticated proxy,
- MFA/SSO for human access where supported,
- scoped tokens for automation,
- read-only and control endpoints separated where possible,
- audit logging of administrative actions.

A dashboard should not become a convenient public surface just because it has a browser UI.

---

## 6. Attribution, revocation, and logging are mandatory

Every remote access path must be able to answer:

- Who accessed this?
- From which identity or device?
- What did they touch?
- When did it happen?
- Can that access be revoked quickly?
- Is the action attributable to a human, job, token, or automation runner?

This applies equally to:

- WoL triggers,
- tailnet node identities,
- SSH sessions,
- dashboard logins,
- API tokens,
- machine credentials.

The system should assume that access will need to be audited after an incident, not only during normal operation.

---

# Recommendations

## Canonical remote-access posture

For `hngh/hngh-automation`, the default remote-access model should be:

```yaml
remote_access:
  public_inbound_ports: none
  preferred_remote_admin_path: tailnet_or_vpn
  wol: recovery_only
  ssh: privileged_channel
  dashboards: administrative_endpoints
  identity: required
  authorization: least_privilege
  logging: required
  revocation: required
```

This should be treated as the baseline unless a specific node has an approved exception.

---

## Recommendation 1: Disable WoL by default

WoL should not be enabled unless there is a concrete recovery requirement.

Default:

```yaml
wol:
  enabled: false
  allow_public_relay: false
  require_auth: true
  log_all_requests: true
  post_wake_access: tailnet_or_ssh_only
```

When WoL is enabled, it should only be reachable through a trusted path such as:

- trusted LAN/VLAN,
- authenticated relay,
- controlled tailnet/VPN path.

WoL requests must be logged with:

- source identity,
- target host/MAC,
- timestamp,
- operator or automation job ID,
- reason if available.

Operational rule:

> WoL may turn a node on, but it must not grant access.

After wake, the node should only become reachable through an authenticated remote path such as tailnet/VPN, SSH, or an authenticated dashboard proxy.

If WoL is unavailable, fail closed: do not fall back to public inbound exposure.

---

## Recommendation 2: Use tailnet/VPN as the default remote-admin network

Tailnet/VPN should be the normal remote administration path for `hngh/hngh-automation` nodes.

Default:

```yaml
tailnet:
  required_for_remote_admin: true
  default_policy: deny
  per_node_identities: true
  stale_identity_disable_days: 30
  human_access_mfa: true
  machine_credentials: scoped_or_short_lived
  audit_reachability: true
```

Every node should have an explicit identity:

- hostname,
- owner/operator,
- purpose,
- expiry or review date,
- allowed services.

The tailnet should enforce least privilege. It should not be treated as a trusted flat network.

Required practices:

- deny by default,
- scope access per node and service,
- disable stale identities automatically,
- require MFA for human interactive access where supported,
- use scoped machine tokens or short-lived credentials for automation jobs,
- periodically audit what can reach what.

Key risk to prevent:

> A compromised laptop, phone, edge node, or automation runner should not be able to reach all sensitive local services simply because it is in the tailnet.

The tailnet should reduce inbound exposure, not replace authentication and authorization.

---

## Recommendation 3: Harden SSH as a privileged channel

SSH should remain available for administration, but only under a strict baseline.

Required SSH posture:

- key-only authentication,
- no password authentication,
- no direct root login,
- named admin users only,
- source access restricted to tailnet/VPN or bastion where possible,
- agent forwarding disabled unless explicitly required,
- X11 forwarding disabled by default,
- unnecessary forwarding disabled,
- session logging enabled,
- automation SSH credentials scoped and revocable.

Example baseline:

```yaml
ssh:
  password_authentication: false
  permit_root_login: false
  allowed_users: named_admins_only
  source_restriction: tailnet_or_bastion
  agent_forwarding: disabled_by_default
  x11_forwarding: false
  session_logging: true
  automation_credentials: scoped_or_short_lived
```

For sensitive nodes, prefer a bastion or jump-host model where practical. Direct SSH from many devices should be avoided when it complicates attribution and revocation.

SSH should be treated as privileged access, not as a casual remote shell.

---

## Recommendation 4: Treat headless dashboards as administrative endpoints

Headless dashboards should not be exposed directly to the public internet.

Default:

```yaml
dashboards:
  public_exposure: false
  required_access_path: tailnet_or_authenticated_proxy
  human_auth: mfa_or_sso_where_supported
  machine_auth: scoped_tokens
  read_only_mode: preferred_for_monitoring
  control_actions: logged
  audit_logging: true
```

Recommended practices:

- serve dashboards only through tailnet/VPN or an authenticated proxy,
- require MFA/SSO for human access where supported,
- use short-lived or scoped tokens for automation,
- separate read-only monitoring views from control interfaces,
- disable unauthenticated APIs and webhooks by default,
- log administrative actions,
- avoid exposing dashboards as ordinary public web services.

A dashboard should be considered sensitive even if it is primarily for viewing state. The UI may be convenient, but the underlying endpoints are administrative.

---

## Recommendation 5: Require attribution and revocation for all remote paths

Every remote access path must support:

- identity,
- authorization,
- logging,
- revocation.

This includes:

- WoL triggers,
- tailnet node identities,
- SSH keys,
- dashboard sessions,
- API tokens,
- automation credentials.

Minimum audit fields:

```yaml
audit:
  required_fields:
    - actor_identity
    - source_address_or_device
    - target_host
    - target_service
    - timestamp
    - action
    - result
    - job_id_if_automation
```

The system should be able to answer, after the fact:

- who accessed what,
- from where,
- with which credential,
- and whether that credential can still act.

---

## Recommendation 6: Fail closed when remote access is ambiguous

If a remote access path cannot be clearly attributed, authenticated, or scoped, it should not be enabled.

Fail-closed rules:

- no public inbound ports by default,
- no WoL fallback to public exposure,
- no dashboard exposed without authentication,
- no SSH password login,
- no broad tailnet allow-all access,
- no unscoped automation tokens for privileged actions.

When in doubt, prefer a more restrictive path and document the exception
