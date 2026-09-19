# Billion-Context + OMP + Jcode Configuration Fix

> **Status**: Partially complete — OMP provider API fixed, bili MITM whitelist added, CA trust still needed.
> **Date**: 2026-09-17
> **Author**: System agent (troubleshooting turn)

## Problem Summary

OMP sessions failed with `Error: 400 Provider returned error` when routing through billion-context. The root cause was a **provider API format mismatch** between OMP's default Anthropic-style request format and Z.AI's OpenAI-compatible API.

## Changes Made

### 1. OMP models.yml — Added `api: openai-completions` to zai provider

**File**: `~/.omp/agent/models.yml`

**Before**:
```yaml
zai:
  apiKey: Z_AI_API_KEY
```

**After**:
```yaml
zai:
  api: openai-completions
  apiKey: Z_AI_API_KEY
```

**Why**: Without the `api` field, OMP defaults to Anthropic's `anthropic-messages` format (using `input` array). Z.AI uses OpenAI's `chat/completions` format (using `messages` array). The mismatch caused 400 errors.

**Verified**: Direct curl test confirmed Z.AI returns 404 on `/responses` endpoint and works with `/chat/completions`.

### 2. Billion-context config — Added MITM domain whitelist

**File**: `~/.config/billion-context/billion-context.json`

**Before**:
```json
{
  "compress": { ... },
  "providers": {}
}
```

**After**:
```json
{
  "compress": { ... },
  "mitm": {
    "domains": [
      "api.openrouter.ai",
      "api.z.ai",
      "api.kimi.com",
      "api.zhipuai.cn"
    ]
  },
  "providers": {}
}
```

**Why**: Without the whitelist, bili can't decrypt TLS traffic to these hosts, so requests pass through opaquely and no compression occurs. The MITM whitelist tells bili which domains to terminate TLS for.

**Verified**: bili logs now show `MITM proxy on (whitelist) +api.openrouter.ai,api.z.ai,api.kimi.com,api.zhipuai.cn`.

### 3. CA Trust — NOT YET CONFIGURED

**Status**: ❌ Missing

Both OMP and jcode need to trust bili's CA certificate. The CA exists at:
```
~/.local/share/billion-context/ca/combined-ca.pem
```

But neither `NODE_EXTRA_CA_CERTS` nor `SSL_CERT_FILE` is set in the environment.

**Options**:
1. **Shell profile** (recommended): Add to `~/.bashrc` or `~/.zshrc`:
   ```bash
   export NODE_EXTRA_CA_CERTS="$HOME/.local/share/billion-context/ca/combined-ca.pem"
   export SSL_CERT_FILE="$HOME/.local/share/billion-context/ca/combined-ca.pem"
   export HTTPS_PROXY="http://127.0.0.1:8787"
   ```

2. **System trust store** (per-OS — the `update-ca-certificates` step below is Linux/Debian-only):
   - Linux (Debian/Ubuntu): file must end in `.crt` under `/usr/local/share/ca-certificates/`:
   ```bash
   sudo cp "$HOME/.local/share/billion-context/ca/combined-ca.pem" /usr/local/share/ca-certificates/billion-context.crt
   sudo update-ca-certificates
   ```
   - macOS (keychain): `update-ca-certificates` does not exist; trust via keychain:
   ```bash
   sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain "$HOME/.local/share/billion-context/ca/combined-ca.pem"
   ```
   - Windows (cert store, admin PowerShell): there is no `update-ca-certificates`; import to the root store:
   ```powershell
   Import-Certificate -FilePath "$env:USERPROFILE\.local\share\billion-context\ca\combined-ca.pem" -CertStoreLocation Cert:\LocalMachine\Root
   # or: certutil -addstore root combined-ca.pem
   ```

   Portability notes: `NODE_EXTRA_CA_CERTS` is Node.js-only (ignored by curl, Python, Go, Java). `SSL_CERT_FILE` covers OpenSSL-based clients (Python, codex/trae) but not Node. curl honours `CURL_CA_BUNDLE`/`--cacert`; Python `requests` honours `REQUESTS_CA_BUNDLE`. System-store install covers curl/Python/Go but Node may still need `NODE_EXTRA_CA_CERTS`, so set both on Linux/macOS/Windows. Never hardcode `~/...`; use `$HOME`/`~` (`%USERPROFILE%` on Windows). Filename: the bili bundle is `combined-ca.pem` (system roots + bili root); `root-ca.pem` is the bili root alone — `launch-session.sh` exports the latter, `model.sh`/curl paths use the former; prefer `combined-ca.pem` so non-MITM blind-tunnel hosts still validate.

3. **Per-client config**: Configure OMP and jcode to use the proxy URL directly (more complex, not recommended).

## Verification Steps

After CA trust is configured:

```bash
# Kill any running bili processes
pkill -f "bili" || true

# Start bili fresh
bili start

# Test OMP through bili
bili omp --model zai/glm-5.3-flash "Hello"

# Test jcode through bili
bili jcode --provider zai --model glm-5.3-flash "Hello"
```

Expected log output from bili:
```
[info] mitm whitelisted: api.openrouter.ai
[info] mitm whitelisted: api.z.ai
```

Instead of:
```
[info] mitm <private-host> BLIND TUNNEL WARNING
```

## Adversarial Review

### Potential Issues

1. **OMP's `api: openai-responses` for unsloth**: The unsloth provider uses `api: openai-responses`. This is correct only if unsloth serves the `/responses` endpoint. Verify unsloth actually supports this endpoint; otherwise it will also fail.

2. **Billion-context config file format**: The `mitm.domains` format was inferred from GitHub issues. If the format is wrong, bili may ignore it silently. Check bili docs or source for the exact schema.

3. **CA trust scope**: Setting `NODE_EXTRA_CA_CERTS` globally affects all Node.js processes. This may have unintended side effects for other tools.

4. **Proxy cycling**: If OMP or jcode are configured to use the proxy URL directly (e.g., `http://127.0.0.1:8787/bili/https://api.z.ai/...`), they may bypass the MITM entirely and connect directly to the upstream, defeating the purpose.

5. **Stale session state**: OMP's session database (`~/.omp/agent/agent.db`) may cache provider state. If the API format was changed mid-session, a restart may be needed.

6. **Billion-context version**: The installed version is `0.1.118`. Check if the `mitm.domains` feature was added in a later version.

### Open Questions

1. Why does the unsloth provider use `openai-responses` while Z.AI needs `openai-completions`? Are they using different API endpoints?

2. Is the `api.zhipuai.cn` domain needed, or is `api.z.ai` sufficient for Z.AI?

3. Does jcode need separate CA trust configuration, or does it inherit from the environment?

4. Should the bili process be managed by systemd instead of running as a background process?

## Breadcrumb for Future Agents

When troubleshooting OMP + billion-context failures:

1. **Check provider API format**: Verify the `api` field in `~/.omp/agent/models.yml` matches the upstream's actual API format.
2. **Check MITM whitelist**: Verify `mitm.domains` in `~/.config/billion-context/billion-context.json` includes all upstream hosts.
3. **Check CA trust**: Verify `NODE_EXTRA_CA_CERTS` or system trust includes bili's CA.
4. **Check proxy routing**: Verify clients are not bypassing bili by connecting directly to upstream.
5. **Check bili logs**: Look for `BLIND TUNNEL WARNING` (missing whitelist) or `TLS terminated locally` (working MITM).

## Related Files

- `~/.omp/agent/models.yml` — OMP provider API format definitions
- `~/.omp/agent/config.yml` — OMP retry/fallback configuration
- `~/.config/billion-context/billion-context.json` — Billion-context proxy configuration
- `~/.local/share/billion-context/ca/combined-ca.pem` — Billion-context CA certificate
- `~/.bashrc` or `~/.zshrc` — Shell environment variables (needs updating)

## Next Steps

1. Configure CA trust (see options above)
2. Restart shell or run `source ~/.bashrc`
3. Restart bili: `pkill -f "bili" && bili start`
4. Test OMP and jcode
5. Monitor bili logs for successful MITM termination

---
*Generated: 2026-09-17T23:30:00Z*
*Status: Partially complete — CA trust pending*