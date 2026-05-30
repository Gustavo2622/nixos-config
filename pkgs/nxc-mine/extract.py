"""LLM extraction of problems + assumptions from paper title+abstract.

Single qwen2.5:14b call per paper, JSON-schema mode. The prompt now:
  1. Decides crypto_relevant up front; non-crypto papers return empty arrays.
  2. Constrains assumption canonical_name to a known whitelist; novel
     assumptions are flagged for review rather than auto-merged by name.
  3. Asks for discrete confidence buckets (0.3 / 0.6 / 0.9) tied to evidence
     strength, so the field carries a real signal instead of always-1.0.
"""

from __future__ import annotations

from typing import Any

import config
import ollama


# Output schema given to Ollama. The model MUST also set `crypto_relevant`,
# and `problems`/`assumptions` MUST be empty when `crypto_relevant=false`.
EXTRACTION_SCHEMA = {
    "type": "object",
    "properties": {
        "crypto_relevant": {
            "type": "boolean",
            "description": (
                "True iff this paper is research in CRYPTOGRAPHY (classical or "
                "post-quantum): encryption, signatures, key exchange, MPC, ZK, "
                "homomorphic encryption, hash functions, cryptanalysis, hardness "
                "assumptions used in crypto, PQC (lattice/code/isogeny/MQ/hash). "
                "False for: LLM safety / jailbreaks / prompt injection, "
                "adversarial ML, network/OS/UAV security, generic information "
                "security without cryptographic content, pure quantum physics "
                "with no crypto application."
            ),
        },
        "relevance_reason": {
            "type": "string",
            "description": "One sentence explaining the crypto_relevant decision.",
        },
        "problems": {
            "type": "array",
            "items": {
                "type": "object",
                "properties": {
                    "canonical_statement": {
                        "type": "string",
                        "description": (
                            "One-sentence statement of the open question, "
                            "normalised to a question form. Avoid paper-specific "
                            "phrasing, acronyms unexplained, or naming the paper."
                        ),
                    },
                    "problem_type": {
                        "type": "string",
                        "enum": ["open_problem", "future_work", "conjecture"],
                    },
                    "role": {
                        "type": "string",
                        "enum": ["states", "addresses", "solves"],
                    },
                    "evidence": {
                        "type": "string",
                        "description": "Verbatim substring from the abstract.",
                    },
                    "confidence": {
                        "type": "number",
                        "enum": [0.3, 0.6, 0.9],
                        "description": (
                            "Discrete: 0.9 = abstract explicitly names the open "
                            "problem with strong language (\"we leave open\", \"it "
                            "is unknown whether\"); 0.6 = clear future-work pointer "
                            "but not a sharp claim; 0.3 = inferred / weak cue."
                        ),
                    },
                },
                "required": [
                    "canonical_statement", "problem_type", "role",
                    "evidence", "confidence",
                ],
            },
        },
        "assumptions": {
            "type": "array",
            "items": {
                "type": "object",
                "properties": {
                    "canonical_name": {
                        "type": "string",
                        "description": (
                            "Pick from the canonical list given in the prompt when "
                            "applicable. For a genuinely new assumption introduced "
                            "by this paper, use its standard name as given (e.g. "
                            "\"Hidden-Target Diffie-Hellman\") and set is_novel=true."
                        ),
                    },
                    "is_novel": {
                        "type": "boolean",
                        "description": (
                            "True iff `canonical_name` is NOT in the supplied "
                            "whitelist. Novel assumptions go to the review queue."
                        ),
                    },
                    "statement": {
                        "type": "string",
                        "description": (
                            "One-sentence general statement of the hardness "
                            "assumption itself — NOT paper-specific context. "
                            "E.g. \"LWE: given (A, As+e), recovering s is hard.\""
                        ),
                    },
                    "role": {
                        "type": "string",
                        "enum": ["introduces", "relies_on", "attacks", "weakens"],
                    },
                    "parameters": {
                        "type": "string",
                        "description": "Concrete parameter set if stated (e.g. 'n=512, q=2^14'); else empty.",
                    },
                    "evidence": {"type": "string"},
                    "confidence": {
                        "type": "number",
                        "enum": [0.3, 0.6, 0.9],
                    },
                },
                "required": [
                    "canonical_name", "is_novel", "statement", "role",
                    "evidence", "confidence",
                ],
            },
        },
    },
    "required": ["crypto_relevant", "relevance_reason", "problems", "assumptions"],
}


def _system_prompt() -> str:
    whitelist = ", ".join(config.CANONICAL_ASSUMPTIONS)
    return f"""\
You read cryptography research papers (title + abstract) and emit
strict JSON.

STEP 1 — CRYPTO RELEVANCE GATE
Decide `crypto_relevant`. Cryptography = encryption, signatures, key
exchange/agreement, MPC, ZK proofs, homomorphic encryption, hash
functions, cryptanalysis, hardness assumptions for crypto,
post-quantum cryptography (lattice / code / isogeny / MQ / hash-based).

NOT cryptography (set crypto_relevant=false, empty problems and
assumptions arrays, give one-sentence relevance_reason):
  • LLM safety, jailbreaks, prompt injection, RAG defences
  • Adversarial ML on classifiers / vision / robotics
  • Pure systems / network / OS / UAV security with no cryptographic content
  • Quantum physics without crypto application (SYK, photonic
    architectures, signal inequalities, generic quantum information)
  • Hardware side-channels in non-cryptographic contexts

STEP 2 — ONLY IF crypto_relevant=true, extract:

PROBLEMS — open questions, conjectures, future-work pointers that the
paper STATES, ADDRESSES, or SOLVES. Cue phrases include
"we leave open whether…", "it remains unknown whether…",
"an interesting open problem is…", "future work…". Phrase each as
ONE normalised question. Avoid paper-specific acronyms.
Be CONSERVATIVE — prefer few high-confidence extractions over many
noisy ones. Empty array is the right answer when nothing concrete is
stated.

ASSUMPTIONS — hardness assumptions the paper INTRODUCES, RELIES_ON,
ATTACKS, or WEAKENS. Use one of these canonical names when applicable:
  {whitelist}
For each, set `is_novel=false`.
For a brand-new assumption introduced by this paper, use its given
name (e.g. "Hidden-Target Diffie-Hellman") and set `is_novel=true`.

DO NOT classify the following as assumptions:
  • Algorithm names (Grover's, Shor's, Pollard's rho, AES, …)
  • Noise/error models (depolarising noise, Gaussian noise)
  • Areas / paradigms ("LLM", "Bell inequalities", "Crypto Dark Matter"
    as a paper-specific framework name, …)
  • Generic descriptions ("Lattice-based assumptions" without specifics)

The `statement` field must describe the ASSUMPTION ITSELF in general
terms, not paraphrase the current paper's claim about it.

CONFIDENCE is discrete:
  • 0.9 — explicit, verbatim, sharp claim in the abstract
  • 0.6 — clear pointer but requires light inference
  • 0.3 — weak / inferred cue

Output strictly conforming to the schema. No extra prose.
"""


def extract_from_abstract(title: str, abstract: str) -> dict[str, Any]:
    """Return parsed JSON. Always has crypto_relevant + problems + assumptions."""
    user = f"Title: {title}\n\nAbstract:\n{abstract}"
    out = ollama.chat_json(
        system=_system_prompt(),
        user=user,
        schema=EXTRACTION_SCHEMA,
    )
    # Defensive normalisation
    out.setdefault("crypto_relevant", False)
    out.setdefault("relevance_reason", "")
    out.setdefault("problems", [])
    out.setdefault("assumptions", [])

    # Hard rule: if gate says non-crypto, drop any extractions the model
    # accidentally produced anyway.
    if not out["crypto_relevant"]:
        out["problems"] = []
        out["assumptions"] = []

    # Clamp confidences and apply safety caps.
    for item in out["problems"] + out["assumptions"]:
        try:
            c = float(item.get("confidence", 0.3))
        except (TypeError, ValueError):
            c = 0.3
        # Snap to the discrete buckets (closest of 0.3/0.6/0.9).
        item["confidence"] = min((0.3, 0.6, 0.9), key=lambda b: abs(b - c))
    # is_novel default
    for a in out["assumptions"]:
        a.setdefault("is_novel", False)

    cfg = config.extract_cfg()
    out["problems"]    = out["problems"][: cfg["max_problems_per_paper"]]
    out["assumptions"] = out["assumptions"][: cfg["max_assumptions_per_paper"]]
    return out
