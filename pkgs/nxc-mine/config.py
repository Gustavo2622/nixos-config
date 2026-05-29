"""Built-in defaults for the first slice. Will move to ~/.config/nxc/mine/sources.toml later."""

# Crypto-only subset for the first slice — keeps volume manageable while we
# iterate on extraction/dedup. Expand to complexity + math once the pipeline is
# proven, and externalize this into a TOML config.
CATEGORIES = {
    "crypto": {
        "arxiv": {
            # cs.CR is the active crypto/security category; quant-ph picks up
            # PQC + cryptanalysis-on-quantum-hardness papers.
            "categories": ["cs.CR", "quant-ph"],
            # Optional keyword filter applied client-side after retrieval.
            "keywords": [],
        },
        "eprint": {
            "enabled": True,
            # ePrint area tags to keep. Empty list = accept all.
            "areas": [],
        },
    },
}

# Peer auth via unix socket; the user=nxcmine query param tells libpq to
# request the `nxcmine` PG role explicitly. Without it libpq defaults to the
# OS user and identMap can't kick in (it maps gustavo→nxcmine, not vice versa).
DB_DSN = "postgresql:///nxcmine?user=nxcmine"
DEFAULT_WINDOW_DAYS = 7
HTTP_TIMEOUT = 30.0
HTTP_USER_AGENT = "nxc-mine/0.1 (https://github.com/Gustavo2622/nixos-config)"
