"""List ARM's active rips as a JSON array, for a homepage customapi widget.

ARM's own /json?mode=joblist returns jobs as an object keyed "0", "1", ...,
which homepage's dynamic-list cannot read, and it is unreachable whenever
the ARM host is off. This helper always answers, with
{"jobs": [{"title": ..., "status": ...}, ...]}: one row per active job, or a
single row saying there is nothing ripping or that ARM is offline.

Environment: ARM_URL (ARM's web UI), PORT.
"""

import json
import os
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.request import urlopen

ARM_URL = os.environ["ARM_URL"].rstrip("/")
PORT = int(os.environ["PORT"])

STATUS = {
    "active": "starting",
    "info": "reading disc",
    "ripping": "ripping",
    "waiting": "waiting",
    "transcoding": "transcoding",
    "waiting_transcode": "queued for transcode",
}


def field(job, key):
    value = job.get(key)
    return None if value in (None, "", "None") else str(value)


def row(job):
    title = field(job, "title") or field(job, "label") or "Unknown disc"
    year = field(job, "year")
    if year and year != "0000":
        title = f"{title} ({year})"
    status = job.get("status", "")
    parts = [STATUS.get(status, status)]
    if status in ("ripping", "transcoding"):
        progress = field(job, "progress_round") or field(job, "progress")
        if progress:
            parts.append(f"{progress}%")
        eta = field(job, "eta")
        if eta:
            parts.append(f"ETA {eta}")
    return {"title": title, "status": " · ".join(p for p in parts if p)}


def jobs():
    try:
        with urlopen(f"{ARM_URL}/json?mode=joblist", timeout=3) as r:
            results = json.load(r).get("results") or {}
    except OSError:
        return [{"title": "ARM is offline", "status": ""}]
    rows = [row(j) for _, j in sorted(results.items(), key=lambda kv: int(kv[0]))]
    return rows or [{"title": "No active rips", "status": ""}]


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        body = json.dumps({"jobs": jobs()}).encode()
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)


ThreadingHTTPServer(("127.0.0.1", PORT), Handler).serve_forever()
