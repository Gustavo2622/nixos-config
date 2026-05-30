"""Configuration: hard-coded defaults overlaid by ~/.config/nxc/mine/mine.toml.

Anything tweakable at runtime (dedup thresholds, model choice, prompts) lives
in the TOML so iteration doesn't need a rebuild. Sources stay in code for now
— they'll move to TOML when we add categories beyond crypto.
"""

from __future__ import annotations

import os
import pathlib
import tomllib
from typing import Any

# ─── source/category config (still code-only; move to TOML once we expand) ─

CATEGORIES = {
    "crypto": {
        "arxiv": {
            # Dropped quant-ph: too much physics noise (SYK, photonics, signal
            # inequalities, …) that's only loosely crypto-adjacent. Quantum
            # attacks on crypto + post-quantum proposals show up on cs.CR
            # anyway. Re-add quant-ph with a PQC keyword filter if recall
            # becomes an issue.
            "categories": ["cs.CR"],
            "keywords": [],
        },
        "eprint": {
            "enabled": True,
            "areas": [],
        },
    },
}

# Canonical hardness assumptions used in cryptography. The extract prompt
# instructs the model to pick from this list when applicable, and to flag
# anything new with is_novel=true (which routes to the review queue rather
# than auto-merging by name).
CANONICAL_ASSUMPTIONS = [
    # Lattice
    "LWE", "RLWE", "MLWE", "Hint-MLWE", "decisional-LWE",
    "SIS", "Module-SIS", "Ring-SIS", "Inhomogeneous-SIS",
    "SVP", "GapSVP", "CVP", "approx-SVP", "approx-CVP", "BDD", "LWR",
    "NTRU", "NTRU-Assumption",
    # Discrete log family
    "DLP", "DLOG", "ECDLP", "CDH", "DDH", "Gap-CDH", "Strong-DH", "DBDH",
    # Pairing-based / bilinear
    "BDH", "DLIN", "SXDH", "q-SDH",
    # Isogeny
    "SIDH", "CSIDH", "isogeny-path-finding", "isogeny-CDH",
    # Code-based
    "syndrome-decoding", "QC-SD", "QA-SD", "Ring-LPN", "LPN", "code-based-decoding",
    "Goppa-code", "MDPC-decoding", "rank-syndrome-decoding",
    # Multivariate
    "MQ", "MinRank", "PRE",
    # Hash / generic
    "collision-resistance", "preimage-resistance", "random-oracle",
    # Obfuscation / advanced
    "iO", "indistinguishability-obfuscation", "puncturable-PRF",
    "sub-exponential-iO", "LWE-with-leakage",
    # Factoring / RSA
    "RSA", "factoring", "strong-RSA", "QR",
]


# Names the LLM keeps misclassifying as assumptions even with the negative
# examples in the prompt. Anything matching (lowercased exact match, or any
# substring in the regex set) is routed to the review queue instead of
# UPSERTing into the assumptions table — the human can still accept it via
# the TUI if it turns out to be legitimate.
ASSUMPTION_DENYLIST_EXACT = {
    # Ciphers (concrete algorithms, not assumptions)
    "aes", "des", "3des", "chacha", "chacha20", "salsa", "salsa20",
    "blowfish", "twofish", "serpent", "camellia", "sm4", "rc4",
    # Hash functions
    "sha-1", "sha1", "sha-256", "sha256", "sha-512", "sha512", "sha-3",
    "md5", "blake2", "blake3", "keccak", "hmac",
    # Primitives / categories (not assumptions themselves)
    "fhe", "he", "homomorphic encryption", "prf", "prg", "prp", "mac",
    "kdf", "aead", "psi", "psm", "private simultaneous messages",
    "oprf", "ot", "oblivious transfer", "snark", "stark", "zk",
    "zero-knowledge", "zero knowledge",
    # Areas / fields (not assumptions)
    "post-quantum cryptography", "pqc", "quantum cryptography",
    "lattice-based assumptions", "lattice-based cryptography",
    "code-based cryptography",
    # Attack / channel / noise models
    "bsc", "binary symmetric channel", "collective-attacks",
    "collective attacks", "depolarizing noise", "gaussian noise",
    "side-channel", "side channel",
    # Algorithm names
    "grover's algorithm", "grover", "shor's algorithm", "shor",
    "pollard's rho",
    # Generic / wrong
    "none", "n/a", "llm", "regev", "crypto dark matter",
    "k-colorability problem", "bell inequalities",
}
ASSUMPTION_DENYLIST_SUBSTRING = [
    "protocol",  # "Private Simultaneous Messages (PSM) protocols", "OPRF protocols"
    "algorithm",  # algorithm names slipping in
]


def is_denylisted_assumption(name: str) -> bool:
    """True iff `name` shouldn't auto-merge into the assumptions table."""
    n = (name or "").strip().lower()
    if not n:
        return True
    if n in ASSUMPTION_DENYLIST_EXACT:
        return True
    for s in ASSUMPTION_DENYLIST_SUBSTRING:
        if s in n:
            return True
    return False

# ─── infra constants ──────────────────────────────────────────────────────

DB_DSN = "postgresql:///nxcmine?user=nxcmine"
DEFAULT_WINDOW_DAYS = 7
HTTP_TIMEOUT = 30.0
HTTP_USER_AGENT = "nxc-mine/0.2 (https://github.com/Gustavo2622/nixos-config)"

# ─── runtime-tunable defaults (overlaid by mine.toml) ─────────────────────

DEFAULTS: dict[str, Any] = {
    "llm": {
        "host": "http://localhost:11434",
        "embed_model": "bge-m3",       # 1024d, 8192-token context
        # qwen3.6:27b + glm-4.7-flash crash to load on this ROCm build
        # (rocBLAS Tensile init error). qwen2.5:14b is fine for structured JSON
        # extraction at much lower latency.
        "extract_model": "qwen2.5:14b",
        "judge_model": "qwen2.5:14b",
        "temperature_extract": 0.1,
        "temperature_judge": 0.0,
        "request_timeout": 240.0,  # extraction can be slow on a 27B
    },
    "dedup": {
        # cosine similarity is in [0, 1]; nomic/mxbai produce values usually in
        # [0.3, 0.95] range for related-but-distinct claims, so these defaults
        # tend to be conservative. Tune after observing first runs.
        "similarity_high": 0.85,  # ≥ → LLM judge then auto-merge if confirmed
        "similarity_low":  0.65,  # < → accept as new without judge
        # else → enqueue for human review
        "top_k": 5,                # candidates retrieved per claim
    },
    "extract": {
        "max_problems_per_paper":    8,  # safety cap; usually 1-3 in practice
        "max_assumptions_per_paper": 8,
        # Concurrent extract calls to Ollama. Each loaded qwen2.5:14b instance
        # takes ~9 GB VRAM; with bge-m3 (~1.3 GB) we have headroom for 2-3.
        # Dedup decisions stay serial (no merge races between papers).
        "concurrency": 2,
    },
}

_CONFIG_PATH = pathlib.Path(
    os.environ.get(
        "NXC_MINE_CONFIG",
        os.path.expanduser("~/.config/nxc/mine/mine.toml"),
    )
)


def _deep_merge(base: dict, overlay: dict) -> dict:
    """Recursively merge `overlay` into `base`. Leaves `base` untouched."""
    out = dict(base)
    for k, v in overlay.items():
        if k in out and isinstance(out[k], dict) and isinstance(v, dict):
            out[k] = _deep_merge(out[k], v)
        else:
            out[k] = v
    return out


def load() -> dict[str, Any]:
    """Load defaults with TOML overlay if the file exists."""
    cfg = DEFAULTS
    if _CONFIG_PATH.exists():
        with open(_CONFIG_PATH, "rb") as f:
            user = tomllib.load(f)
        cfg = _deep_merge(cfg, user)
    return cfg


# Convenience accessors for common values; everything else lives in load()["section"]["key"].
def llm_cfg() -> dict[str, Any]:
    return load()["llm"]


def dedup_cfg() -> dict[str, Any]:
    return load()["dedup"]


def extract_cfg() -> dict[str, Any]:
    return load()["extract"]
