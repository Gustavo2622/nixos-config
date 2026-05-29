"""LLM extraction of problems + assumptions from paper title+abstract.

Single qwen3.6:27b call per paper, JSON-mode with an explicit schema.
Validates output shape; on shape error the paper is left unprocessed (the
ingest_runs / extract_runs mechanism will retry).
"""

from __future__ import annotations

from typing import Any

import config
import ollama

# Output schema given to Ollama. Keeping it tight constrains the model to the
# fields we actually persist; descriptions are critical — they're the part the
# model is most influenced by.
EXTRACTION_SCHEMA = {
    "type": "object",
    "properties": {
        "problems": {
            "type": "array",
            "items": {
                "type": "object",
                "properties": {
                    "canonical_statement": {
                        "type": "string",
                        "description": "One-sentence statement of the open question, normalized "
                                       "to a question form. Avoid paper-specific phrasing.",
                    },
                    "problem_type": {
                        "type": "string",
                        "enum": ["open_problem", "future_work", "conjecture"],
                    },
                    "role": {
                        "type": "string",
                        "enum": ["states", "addresses", "solves"],
                        "description": "The role THIS paper plays w.r.t. the problem.",
                    },
                    "evidence": {
                        "type": "string",
                        "description": "Verbatim substring from the abstract supporting the extraction.",
                    },
                    "confidence": {
                        "type": "number",
                        "minimum": 0,
                        "maximum": 1,
                    },
                },
                "required": ["canonical_statement", "problem_type", "role", "evidence", "confidence"],
            },
        },
        "assumptions": {
            "type": "array",
            "items": {
                "type": "object",
                "properties": {
                    "canonical_name": {
                        "type": "string",
                        "description": "Short canonical name (e.g. 'LWE', 'MLWE', 'SIDH', "
                                       "'isogeny path-finding'). Use the standard name; do "
                                       "not invent novel ones.",
                    },
                    "statement": {
                        "type": "string",
                        "description": "One-sentence statement of the hardness assumption.",
                    },
                    "role": {
                        "type": "string",
                        "enum": ["introduces", "relies_on", "attacks", "weakens"],
                    },
                    "parameters": {
                        "type": "string",
                        "description": "Concrete parameter set if stated (e.g. 'n=512, q=2^14'), else empty.",
                    },
                    "evidence": {"type": "string"},
                    "confidence": {
                        "type": "number",
                        "minimum": 0,
                        "maximum": 1,
                    },
                },
                "required": ["canonical_name", "statement", "role", "evidence", "confidence"],
            },
        },
    },
    "required": ["problems", "assumptions"],
}


_SYSTEM_PROMPT = """\
You are a careful reader of cryptography research papers. From the given
title + abstract, extract:

  1. OPEN PROBLEMS / FUTURE WORK / CONJECTURES that the paper STATES,
     ADDRESSES, or SOLVES. Look for cues like "we leave open whether…",
     "an interesting open problem is…", "future work includes…",
     "it remains unknown whether…", or a stated theorem the paper
     resolves. Phrase each as a single-sentence open question normalised
     across papers (avoid paper-specific phrasing).

  2. HARDNESS ASSUMPTIONS the paper INTRODUCES, RELIES_ON, ATTACKS, or
     WEAKENS. Use the standard canonical name (LWE, MLWE, RLWE, SIS, SVP,
     DLP, DDH, CDH, isogeny path-finding, SIDH, CSIDH, MQ, LPN, code-based
     decoding, etc.). Only extract assumptions that are EXPLICITLY named or
     unambiguously referenced — do not invent.

Be conservative. Prefer FEW high-confidence extractions over many noisy
ones. If the abstract doesn't make a claim, return an empty array.
`evidence` must be a verbatim quote from the abstract.
"""


def extract_from_abstract(title: str, abstract: str) -> dict[str, Any]:
    """Return the parsed JSON. Always has 'problems' and 'assumptions' arrays."""
    user = f"Title: {title}\n\nAbstract:\n{abstract}"
    out = ollama.chat_json(
        system=_SYSTEM_PROMPT,
        user=user,
        schema=EXTRACTION_SCHEMA,
    )
    # Defensive normalisation — even with the schema, models sometimes drop
    # arrays when empty or return confidences outside [0, 1].
    out.setdefault("problems", [])
    out.setdefault("assumptions", [])
    for item in out["problems"] + out["assumptions"]:
        try:
            item["confidence"] = max(0.0, min(1.0, float(item.get("confidence", 0.5))))
        except (TypeError, ValueError):
            item["confidence"] = 0.5
    # Truncate to safety caps.
    cfg = config.extract_cfg()
    out["problems"]    = out["problems"][: cfg["max_problems_per_paper"]]
    out["assumptions"] = out["assumptions"][: cfg["max_assumptions_per_paper"]]
    return out
