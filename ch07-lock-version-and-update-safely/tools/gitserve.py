#!/usr/bin/env python3
"""Tiny smart-HTTP git server for the Chapter 7 demo (localhost only).
Serves bare repositories under ROOT through `git http-backend` so APM can
clone them over http://127.0.0.1:PORT/<owner>/<repo>.git. Test fixture only."""
import os, subprocess, sys
from wsgiref.simple_server import make_server, WSGIRequestHandler

ROOT, PORT = sys.argv[1], int(sys.argv[2])

class Quiet(WSGIRequestHandler):
    def log_message(self, fmt, *args):
        sys.stderr.write("%s\n" % (fmt % args))

def app(environ, start_response):
    env = {
        "GIT_PROJECT_ROOT": ROOT, "GIT_HTTP_EXPORT_ALL": "1",
        "PATH_INFO": environ.get("PATH_INFO", ""),
        "QUERY_STRING": environ.get("QUERY_STRING", ""),
        "REQUEST_METHOD": environ["REQUEST_METHOD"],
        "CONTENT_TYPE": environ.get("CONTENT_TYPE", ""),
        "REMOTE_ADDR": "127.0.0.1", "PATH": os.environ.get("PATH", ""),
    }
    if environ.get("HTTP_GIT_PROTOCOL"):
        env["GIT_PROTOCOL"] = environ["HTTP_GIT_PROTOCOL"]
    length = int(environ.get("CONTENT_LENGTH") or 0)
    body = environ["wsgi.input"].read(length) if length else b""
    if environ.get("HTTP_CONTENT_ENCODING") == "gzip":
        import gzip; body = gzip.decompress(body)
    out = subprocess.run(["git", "http-backend"], input=body, env=env,
                         capture_output=True, timeout=60).stdout
    head, _, payload = out.partition(b"\r\n\r\n")
    status, headers = "200 OK", []
    for line in head.decode().split("\r\n"):
        if not line:
            continue
        k, _, v = line.partition(":")
        if k.lower() == "status":
            status = v.strip()
        else:
            headers.append((k, v.strip()))
    start_response(status, headers)
    return [payload]

make_server("127.0.0.1", PORT, app, handler_class=Quiet).serve_forever()
