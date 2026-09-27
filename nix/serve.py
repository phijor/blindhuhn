"""Serve a directory of static files with caching disabled."""

import socketserver
import sys
from http.server import SimpleHTTPRequestHandler
from pathlib import Path
from os import chdir

DEFAULT_PORT = 8001


class NoCacheHandler(SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header(
            "Cache-Control", "no-store, no-cache, must-revalidate, max-age=0"
        )
        self.send_header("Pragma", "no-cache")
        self.send_header("Expires", "0")
        super().end_headers()


def parse_args(argv) -> tuple[Path, int]:
    try:
        _, dir, *rest = argv
    except ValueError:
        raise SystemExit("no site directory given")

    if not rest:
        return (dir, DEFAULT_PORT)
    try:
        port, *_ = rest
    except ValueError:
        port = DEFAULT_PORT

    try:
        return (dir, int(port))
    except ValueError:
        raise SystemExit(f"invalid port: {port!r}")


if __name__ == "__main__":
    dir, port = parse_args(sys.argv)

    print(f"Serving files from '{dir}'")
    chdir(dir)

    with socketserver.TCPServer(("", port), NoCacheHandler) as httpd:
        print(f"Serving site at 'http://127.0.0.1:{port}'")
        try:
            httpd.serve_forever()
        except KeyboardInterrupt:
            pass
