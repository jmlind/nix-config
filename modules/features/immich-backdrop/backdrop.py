"""Serve a random photo from one Immich album, for the status page background.

Each GET picks a new photo (Immich random search, filtered to the album) and
returns its preview-size image with Cache-Control: no-store, so every page
load, and every rotation, gets a different one.

Environment: IMMICH_URL, ALBUM_ID, PORT, ALLOW_ORIGIN (the status page,
whose rotation script fetches this cross-origin); the API key comes from the systemd
credential "immich-api-key". The key needs asset.read and asset.view.
"""

import json
import os
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.request import Request, urlopen

IMMICH_URL = os.environ["IMMICH_URL"].rstrip("/")
ALBUM_ID = os.environ["ALBUM_ID"]
PORT = int(os.environ["PORT"])
ALLOW_ORIGIN = os.environ["ALLOW_ORIGIN"]
with open(os.path.join(os.environ["CREDENTIALS_DIRECTORY"], "immich-api-key")) as f:
    API_KEY = f.read().strip()


def immich(method, path, body=None):
    data = None if body is None else json.dumps(body).encode()
    headers = {"x-api-key": API_KEY, "Accept": "*/*"}
    if data is not None:
        headers["Content-Type"] = "application/json"
    return urlopen(Request(IMMICH_URL + path, data, headers, method=method), timeout=15)


def random_photo():
    search = {
        "size": 1,
        "filter": {"albumIds": {"any": [ALBUM_ID]}, "type": {"eq": "IMAGE"}},
    }
    with immich("POST", "/api/search/random", search) as r:
        assets = json.load(r)
    if not assets:
        raise LookupError(f"album {ALBUM_ID} has no photos this key can see")
    with immich("GET", f"/api/assets/{assets[0]['id']}/thumbnail?size=preview") as r:
        return r.headers.get("Content-Type", "image/jpeg"), r.read()


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        try:
            content_type, image = random_photo()
        except Exception as e:  # report any Immich failure as a bad gateway
            self.log_error("immich: %s", e)
            self.send_error(502, "Immich request failed")
            return
        self.send_response(200)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(image)))
        self.send_header("Cache-Control", "no-store")
        self.send_header("Access-Control-Allow-Origin", ALLOW_ORIGIN)
        self.end_headers()
        self.wfile.write(image)


ThreadingHTTPServer(("127.0.0.1", PORT), Handler).serve_forever()
