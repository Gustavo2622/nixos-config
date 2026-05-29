"""arXiv source client — Atom API at export.arxiv.org/api/query.

Distinguishes new submissions (`<published>` == `<updated>`) from revisions
(`<updated>` > `<published>`). Strips the trailing version suffix from the
arXiv ID so the ext_id is stable across versions; the version itself goes
into `latest_version` (e.g. "v3").
"""

from __future__ import annotations

import datetime as dt
import re
import xml.etree.ElementTree as ET

import httpx

from config import HTTP_TIMEOUT, HTTP_USER_AGENT
from store import Paper

API_URL = "https://export.arxiv.org/api/query"
NS = {"atom": "http://www.w3.org/2005/Atom"}

_ID_VERSION_RE = re.compile(r"^(.+?)v(\d+)$")


def _strip_version(arxiv_id: str) -> tuple[str, str | None]:
    """`2509.12345v3` → (`2509.12345`, `v3`); fall back to (id, None) if no suffix."""
    m = _ID_VERSION_RE.match(arxiv_id)
    if not m:
        return (arxiv_id, None)
    return (m.group(1), f"v{m.group(2)}")


def _parse_date(s: str) -> dt.date:
    # Atom timestamps look like "2026-05-25T17:30:00Z".
    return dt.datetime.fromisoformat(s.replace("Z", "+00:00")).date()


def fetch(
    *,
    categories: list[str],
    since: dt.date,
    max_results: int = 500,
    our_category: str = "crypto",
) -> tuple[list[Paper], int]:
    """Pull recent arXiv entries from `categories`, keep only those whose
    `updated` is on/after `since`. Returns (papers, errors).

    arXiv has no native date filter, so we sort by submittedDate desc and
    short-circuit once we cross the cutoff.
    """
    query = " OR ".join(f"cat:{c}" for c in categories)
    params = {
        "search_query": query,
        "sortBy": "submittedDate",
        "sortOrder": "descending",
        "start": 0,
        "max_results": max_results,
    }
    headers = {"User-Agent": HTTP_USER_AGENT}
    papers: list[Paper] = []
    errors = 0
    with httpx.Client(timeout=HTTP_TIMEOUT, headers=headers, follow_redirects=True) as client:
        r = client.get(API_URL, params=params)
        r.raise_for_status()
        try:
            root = ET.fromstring(r.text)
        except ET.ParseError:
            return ([], 1)
        for entry in root.findall("atom:entry", NS):
            try:
                arxiv_url = entry.findtext("atom:id", default="", namespaces=NS)
                arxiv_id_with_ver = arxiv_url.rsplit("/", 1)[-1]
                ext_id, version = _strip_version(arxiv_id_with_ver)

                title = (entry.findtext("atom:title", default="", namespaces=NS) or "").strip()
                abstract = (entry.findtext("atom:summary", default="", namespaces=NS) or "").strip() or None
                published = _parse_date(entry.findtext("atom:published", default="", namespaces=NS))
                updated = _parse_date(entry.findtext("atom:updated", default="", namespaces=NS))

                if updated < since:
                    # results are sorted descending; once we cross cutoff, stop
                    break

                authors = [
                    (a.findtext("atom:name", default="", namespaces=NS) or "").strip()
                    for a in entry.findall("atom:author", NS)
                ]
                cats = [c.attrib.get("term", "") for c in entry.findall("atom:category", NS)]

                pdf_url = None
                for link in entry.findall("atom:link", NS):
                    if link.attrib.get("title") == "pdf" or link.attrib.get("type") == "application/pdf":
                        pdf_url = link.attrib.get("href")
                        break
                if not pdf_url:
                    pdf_url = f"http://arxiv.org/pdf/{ext_id}"

                papers.append(
                    Paper(
                        source="arxiv",
                        ext_id=ext_id,
                        title=title,
                        authors=authors,
                        first_published=published,
                        last_revised=updated,
                        latest_version=version,
                        category=our_category,
                        source_categories=cats,
                        abstract=abstract,
                        pdf_url=pdf_url,
                    )
                )
            except Exception:
                errors += 1
                continue
    return (papers, errors)
