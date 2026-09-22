"""secrets.py — sole seam between software and 1Password (vault Hngh Secrets).
Plaintext env stores are being retired; consumers import secret().

Under the hood every read routes through automation/lib/opv -> cred_get
(the single `op` CLI seam; token mapping, 45s timeout, daily breadcrumbs).
No plaintext-env fallback: an op failure raises.
"""

import os
import subprocess
import sys
import time
from pathlib import Path

_VAULT = "Hngh Secrets"
_TTL = 900  # seconds; bursts must not re-spawn op
_OPV = Path(__file__).resolve().parent / "opv"

SECRET_ITEMS = {
    'UNSLOTH_API_KEY': 'UNSLOTH - unsloth studio local server',
    'ANTHROPIC_API_KEY': 'Anthropic',
    'OPENAI_API_KEY': 'OpenAI',
    'OPENROUTER_API_KEY': 'OpenRouter',
    'GITHUB_PAT_TOKEN': 'GitHub PAT',
    '1PASSWORD_SERVICE_TOKEN': '1Password Service Account Token',
    'GEMINI_API_KEY': 'Gemini',
    'GOOGLE_GENERATIVE_AI_API_KEY': 'Google Generative AI',
    'DEEPSEEK_API_KEY': 'DeepSeek',
    'GROQ_API_KEY': 'Groq',
    'XAI_API_KEY': 'xAI',
    'KIMI_FOR_CODING_KEY': 'Kimi for Coding',
    'KIMI_AI_KEY': 'Kimi AI',
    'MOONSHOTAI_API_KEY': 'Moonshot AI',
    'MINIMAX_API_KEY': 'MiniMax',
    'Z_AI_API_KEY': 'Z.AI',
    'ZAI_API_KEY': 'ZAI Zhipu Route',
    'ZHIPU_API_KEY': 'ZHIPU',
    'ELEVENLABS_API_KEY': 'ElevenLabs',
    'PYPI_API_KEY': 'PyPI',
    'AGENT_MAIL_API_KEY': 'Agent Mail',
    'OPENCODE_API_KEY': 'OpenCode',
    'ARTIFICIAL_ANALYSIS_API_KEY': 'Artificial Analysis',
    'CODEIUM_KEY': 'Codeium',
    'LOBEHUB_API_KEY': 'LobeHub',
    'TOKENROUTER_API_KEY': 'TokenRouter',
    'TYPESAFE_API_KEY': 'Typesafe',
}

_cache: dict = {}


def secret(key: str, field: str = 'password') -> str:
    """Read one secret field from the Hngh Secrets vault. Fails closed."""
    if not key:
        raise ValueError("empty key")
    if not field:
        raise ValueError("empty field")
    title = SECRET_ITEMS[key]  # unknown key -> KeyError
    ck = (key, field)
    now = time.monotonic()
    hit = _cache.get(ck)
    if hit is not None and now - hit[0] < _TTL:
        return hit[1]
    proc = subprocess.run(
        ['bash', str(_OPV), title, field],
        capture_output=True, text=True, env=dict(os.environ),
    )
    if proc.returncode != 0:
        raise RuntimeError(f"opv failed for {key}: exit {proc.returncode}")
    value = proc.stdout.removesuffix('\n')
    _cache[ck] = (now, value)
    return value


def _exports() -> None:
    """Print `export VAR=<value>` lines for login-shell rearm.

    env_vars.sh evals this at plasma login so agents (omp, jcode) inherit
    vault-backed keys without any plaintext store on disk. Parallel reads
    (0.9s each sequential would mean ~22s of login delay). Fail-soft per
    item: a failed read warns and skips; consumers still fail closed at
    first use via secret().
    """
    import shlex
    from concurrent.futures import ThreadPoolExecutor

    def fetch(item):
        key, _title = item
        try:
            return key, secret(key)
        except Exception as exc:  # noqa: BLE001 — one bad item must not kill login
            print(f"secrets: vault read failed for {key}: {exc}", file=sys.stderr)
            return key, None

    with ThreadPoolExecutor(max_workers=8) as pool:
        for key, value in pool.map(fetch, SECRET_ITEMS.items()):
            if value:
                print(f"export {key}={shlex.quote(value)}")


if __name__ == '__main__':
    if '--exports' in sys.argv:
        _exports()