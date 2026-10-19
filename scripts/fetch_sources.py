#!/usr/bin/env python3
"""Fetch declared public source pages into an untracked, reproducible cache."""
from __future__ import annotations

import csv
import hashlib
import json
import sys
import time
from datetime import datetime, timezone
from pathlib import Path
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen

ROOT = Path(__file__).resolve().parents[1]
RAW = ROOT / "data" / "raw"
LOG = RAW / "fetch_log.jsonl"


def main(manifest_path: str) -> None:
    with open(manifest_path, newline="", encoding="utf-8") as handle:
        rows = list(csv.DictReader(handle))
    required = {"request_id", "source_id", "url", "expected_kind"}
    if not rows:
        print("No requests declared; nothing fetched.")
        return
    missing = required - set(rows[0])
    if missing:
        raise SystemExit(f"Manifest is missing columns: {', '.join(sorted(missing))}")
    RAW.mkdir(parents=True, exist_ok=True)
    with LOG.open("a", encoding="utf-8") as log:
        for row in rows:
            request_id, url = row["request_id"].strip(), row["url"].strip()
            if not request_id or not url:
                print(f"SKIP blank request_id/url: {row}")
                continue
            destination = RAW / f"{request_id}.source"
            result = {**row, "retrieved_at": datetime.now(timezone.utc).isoformat()}
            for attempt in range(1, 4):
                try:
                    request = Request(url, headers={"User-Agent": "golf-research-data/1.0 (public academic collection)"})
                    with urlopen(request, timeout=45) as response:
                        body = response.read()
                        result.update(status="ok", http_status=response.status,
                                      content_type=response.headers.get_content_type(),
                                      sha256=hashlib.sha256(body).hexdigest(), bytes=len(body))
                        destination.write_bytes(body)
                    break
                except (HTTPError, URLError, TimeoutError) as exc:
                    result.update(status="error", error=str(exc), attempt=attempt)
                    if attempt == 3:
                        print(f"ERROR {request_id}: {exc}")
                    else:
                        time.sleep(attempt * 2)
            log.write(json.dumps(result, sort_keys=True) + "\n")
            log.flush()
            time.sleep(1.0)


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else str(ROOT / "data/reference/source_requests.csv"))
