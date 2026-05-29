"""Two-stage dedup: embed → retrieve top-K → optionally LLM-judge → decide.

Decision policy (thresholds in mine.toml [dedup]):
    max_sim ≥ similarity_high  → LLM judges; if 'same'/'specializes'/'related' → merge/edge
    similarity_low ≤ max_sim < similarity_high → enqueue for human review
    max_sim < similarity_low   → accept as new
    no existing candidates      → accept as new
"""

from __future__ import annotations

from dataclasses import dataclass
from typing import Literal

import config
import ollama

Decision = Literal[
    "accept_new",
    "merge_into",
    "specialize_of",
    "related_to",
    "queue",
]


@dataclass
class DedupResult:
    decision: Decision
    target_id: int | None         # set when merge_into / specialize_of / related_to
    target_score: float | None    # max similarity observed
    candidates: list[tuple[int, float]]  # all (id, similarity) considered, for the review queue payload


_JUDGE_SCHEMA = {
    "type": "object",
    "properties": {
        "relation": {
            "type": "string",
            "enum": ["same", "specializes", "related", "distinct"],
            "description": "Is the new statement the SAME problem as the existing one, "
                           "a SPECIALIZATION (e.g. an instance with concrete parameters), "
                           "RELATED (close but distinct problem), or DISTINCT?",
        },
        "rationale": {
            "type": "string",
            "description": "One short sentence justifying the choice.",
        },
        "confidence": {"type": "number", "minimum": 0, "maximum": 1},
    },
    "required": ["relation", "rationale", "confidence"],
}

_JUDGE_SYSTEM = """\
You judge whether two short statements about cryptography refer to the SAME
research problem (or hardness assumption). Reply strictly via the schema.

Use:
  • same        — they ask the same question / name the same assumption, just
                  phrased differently.
  • specializes — A is a more specific instance of B (or vice versa, treat
                  the NEW one as potentially specializing the EXISTING).
  • related     — same topic / family but distinct claims.
  • distinct    — different problems entirely.
"""


def judge_pair(new_statement: str, existing_statement: str) -> dict:
    user = f"NEW:\n{new_statement}\n\nEXISTING:\n{existing_statement}"
    return ollama.chat_json(
        system=_JUDGE_SYSTEM,
        user=user,
        schema=_JUDGE_SCHEMA,
        temperature=config.llm_cfg()["temperature_judge"],
        model=config.llm_cfg()["judge_model"],
    )


def decide(
    new_statement: str,
    candidates: list[tuple[int, str, float]],  # (existing_id, existing_statement, similarity)
) -> DedupResult:
    """Apply the threshold + LLM-judge policy."""
    cfg = config.dedup_cfg()
    high = cfg["similarity_high"]
    low = cfg["similarity_low"]
    score_only = [(cid, sim) for (cid, _, sim) in candidates]

    if not candidates:
        return DedupResult(decision="accept_new", target_id=None, target_score=None, candidates=[])

    best_id, best_text, best_sim = max(candidates, key=lambda c: c[2])

    if best_sim < low:
        return DedupResult(decision="accept_new", target_id=None, target_score=best_sim,
                           candidates=score_only)

    if best_sim < high:
        # Uncertain — defer to a human.
        return DedupResult(decision="queue", target_id=best_id, target_score=best_sim,
                           candidates=score_only)

    # High similarity — ask the model.
    verdict = judge_pair(new_statement, best_text)
    rel = verdict["relation"]
    if rel == "same":
        return DedupResult(decision="merge_into", target_id=best_id, target_score=best_sim,
                           candidates=score_only)
    if rel == "specializes":
        return DedupResult(decision="specialize_of", target_id=best_id, target_score=best_sim,
                           candidates=score_only)
    if rel == "related":
        return DedupResult(decision="related_to", target_id=best_id, target_score=best_sim,
                           candidates=score_only)
    # 'distinct' — high cosine but the model disagrees → defer to a human (likely
    # an embedding model false-positive worth inspecting).
    return DedupResult(decision="queue", target_id=best_id, target_score=best_sim,
                       candidates=score_only)
