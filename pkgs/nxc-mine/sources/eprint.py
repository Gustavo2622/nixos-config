"""IACR ePrint source client — OAI-PMH at eprint.iacr.org/oai.

Uses `verb=ListRecords&metadataPrefix=oai_dc&from=<date>`. Multiple
`<dc:date>` entries inside a record give us version history: the earliest
is treated as `first_published`, the latest (== OAI `<datestamp>`) as
`last_revised`. A single dc:date means no revisions yet.
"""

from __future__ import annotations

import datetime as dt
import xml.etree.ElementTree as ET

import httpx

from config import HTTP_TIMEOUT, HTTP_USER_AGENT
from store import Paper

OAI_URL = "https://eprint.iacr.org/oai"
NS = {
    "oai": "http://www.openarchives.org/OAI/2.0/",
    "oai_dc": "http://www.openarchives.org/OAI/2.0/oai_dc/",
    "dc": "http://purl.org/dc/elements/1.1/",
}


def _parse_oai_ts(s: str) -> dt.date:
    return dt.datetime.fromisoformat(s.replace("Z", "+00:00")).date()


def _ext_id_from_identifier(identifier: str) -> str | None:
    """`oai:eprint.iacr.org:2026/123` → `2026/123`."""
    if ":" not in identifier:
        return None
    return identifier.rsplit(":", 1)[-1]


def fetch(
    *,
    since: dt.date,
    areas: list[str] | None = None,
    our_category: str = "crypto",
) -> tuple[list[Paper], int]:
    """Pull ePrint records with datestamp >= since. Handles resumptionToken
    pagination if the server splits the result set.

    `areas` filters by dc:subject — leave empty/None to accept all areas.
    """
    headers = {"User-Agent": HTTP_USER_AGENT}
    papers: list[Paper] = []
    errors = 0
    params: dict[str, str] = {
        "verb": "ListRecords",
        "metadataPrefix": "oai_dc",
        "from": since.strftime("%Y-%m-%d"),
    }
    area_filter = {a.lower() for a in (areas or [])}

    with httpx.Client(timeout=HTTP_TIMEOUT, headers=headers, follow_redirects=True) as client:
        while True:
            r = client.get(OAI_URL, params=params)
            r.raise_for_status()
            try:
                root = ET.fromstring(r.text)
            except ET.ParseError:
                errors += 1
                break

            for rec in root.findall(".//oai:record", NS):
                try:
                    hdr = rec.find("oai:header", NS)
                    if hdr is None:
                        continue
                    if hdr.attrib.get("status") == "deleted":
                        continue
                    identifier = (hdr.findtext("oai:identifier", default="", namespaces=NS) or "").strip()
                    ext_id = _ext_id_from_identifier(identifier)
                    if not ext_id:
                        continue
                    datestamp = _parse_oai_ts(
                        (hdr.findtext("oai:datestamp", default="", namespaces=NS) or "").strip()
                    )

                    md = rec.find("oai:metadata/oai_dc:dc", NS)
                    if md is None:
                        continue
                    title = (md.findtext("dc:title", default="", namespaces=NS) or "").strip()
                    abstract = (md.findtext("dc:description", default="", namespaces=NS) or "").strip() or None
                    authors = [
                        (e.text or "").strip()
                        for e in md.findall("dc:creator", NS)
                        if (e.text or "").strip()
                    ]
                    subjects = [
                        (e.text or "").strip()
                        for e in md.findall("dc:subject", NS)
                        if (e.text or "").strip()
                    ]
                    if area_filter and not any(s.lower() in area_filter for s in subjects):
                        continue

                    # dc:date may appear multiple times; min = first published,
                    # max = last revised. Falls back to datestamp.
                    raw_dates = [
                        (e.text or "").strip()
                        for e in md.findall("dc:date", NS)
                        if (e.text or "").strip()
                    ]
                    parsed_dates: list[dt.date] = []
                    for d in raw_dates:
                        try:
                            parsed_dates.append(_parse_oai_ts(d))
                        except ValueError:
                            continue
                    if parsed_dates:
                        first_published = min(parsed_dates)
                        last_revised = max(parsed_dates)
                    else:
                        first_published = datestamp
                        last_revised = datestamp

                    papers.append(
                        Paper(
                            source="eprint",
                            ext_id=ext_id,
                            title=title,
                            authors=authors,
                            first_published=first_published,
                            last_revised=last_revised,
                            latest_version=datestamp.isoformat(),
                            category=our_category,
                            source_categories=subjects,
                            abstract=abstract,
                            pdf_url=f"https://eprint.iacr.org/{ext_id}.pdf",
                        )
                    )
                except Exception:
                    errors += 1
                    continue

            # OAI pagination via <resumptionToken>.
            token_el = root.find(".//oai:resumptionToken", NS)
            token = (token_el.text or "").strip() if token_el is not None else ""
            if not token:
                break
            params = {"verb": "ListRecords", "resumptionToken": token}

    return (papers, errors)
