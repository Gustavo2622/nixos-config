# aria2

Multi-protocol, multi-source download accelerator. Supports HTTP(S), FTP, BitTorrent, and Metalink.

## Basic Downloads

```bash
# Simple download
aria2c https://example.com/file.tar.gz

# Download with custom filename
aria2c -o myfile.tar.gz https://example.com/file.tar.gz

# Download to specific directory
aria2c -d ~/Downloads https://example.com/file.tar.gz
```

## Speed & Parallelism

```bash
# Multi-connection download (split file into 16 parts)
aria2c -x 16 https://example.com/large-file.iso

# Limit download speed (1M = 1MB/s)
aria2c --max-download-limit=1M https://example.com/file.tar.gz

# Multiple files at once (max 5 concurrent)
aria2c -j 5 -i urls.txt
```

## Resume & Retry

```bash
# Resume interrupted download
aria2c -c https://example.com/large-file.iso

# Auto-retry on failure (5 times)
aria2c --max-tries=5 --retry-wait=10 https://example.com/file.tar.gz
```

## Batch Downloads

```bash
# Download from a list of URLs (one per line)
aria2c -i urls.txt

# Download all URLs with 16 connections each, 3 concurrent
aria2c -x 16 -j 3 -i urls.txt
```

## BitTorrent

```bash
# Download a torrent
aria2c file.torrent

# Download magnet link
aria2c 'magnet:?xt=urn:btih:...'

# Seed after download (ratio 1.0)
aria2c --seed-ratio=1.0 file.torrent

# Select specific files from torrent
aria2c --select-file=1,3,5 file.torrent
```

## Useful Patterns

```bash
# Download large ISO with resume + 16 connections
aria2c -c -x 16 https://example.com/nixos.iso

# Mirror a set of URLs quietly
aria2c -q -j 10 -i urls.txt -d ~/mirror/

# Download with authentication
aria2c --http-user=user --http-passwd=pass https://example.com/protected.zip
```
