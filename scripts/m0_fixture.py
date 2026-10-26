#!/usr/bin/env python3
"""Local test fixtures only. No third-party packages, authentication, or user data."""
from contextlib import contextmanager
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from http.cookies import SimpleCookie
from pathlib import Path
from urllib.parse import urlsplit, parse_qs, quote
import json, threading

HTML = Path(__file__).resolve().parents[1] / 'Fixtures/M0/index.html'

class Handler(BaseHTTPRequestHandler):
    protocol_version = 'HTTP/1.1'
    def log_message(self, *args):
        pass  # Do not log cookies, request bodies or query strings.
    def respond(self, body, status=200, content_type='application/json', headers=()):
        if isinstance(body, str): body = body.encode()
        self.send_response(status)
        self.send_header('Content-Type', content_type)
        self.send_header('Content-Length', str(len(body)))
        self.send_header('Cache-Control', 'no-store')
        for name, value in headers: self.send_header(name, value)
        self.end_headers()
        self.wfile.write(body)
    def do_GET(self):
        url = urlsplit(self.path)
        port = self.server.server_port
        if url.path in ('/', '/page'):
            self.respond(HTML.read_bytes(), content_type='text/html; charset=utf-8')
        elif url.path == '/cookie':
            value = parse_qs(url.query).get('value', [''])[0]
            if len(value) > 120 or not all(c.isascii() and (c.isalnum() or c == '-') for c in value):
                self.respond('{"error":"invalid marker"}', 400); return
            self.respond('{"ok":true}', headers=[
                ('Set-Cookie', f'm0_{port}={quote(value)}; Max-Age=86400; Path=/; SameSite=Lax'),
                ('Set-Cookie', f'http_{port}={quote(value)}; Max-Age=86400; Path=/; SameSite=Lax; HttpOnly')])
        elif url.path == '/echo-cookie':
            cookies = SimpleCookie(self.headers.get('Cookie', ''))
            item = cookies.get(f'http_{port}')
            self.respond(json.dumps({'httpOnly': item.value if item else None}))
        elif url.path == '/redirect':
            self.respond('', status=302, headers=[('Location', '/page?redirected=1')])
        elif url.path == '/download':
            self.respond('ArcLake M0 fixture download\n', content_type='text/plain',
                         headers=[('Content-Disposition', 'attachment; filename="fixture.txt"')])
        else:
            self.respond('{"error":"not found"}', 404)
    def do_POST(self):
        length = int(self.headers.get('Content-Length', '0'))
        if length > 4096:
            self.respond('{"error":"too large"}', 413); self.close_connection = True; return
        body = self.rfile.read(length).decode('utf-8', errors='replace')
        if urlsplit(self.path).path != '/post':
            self.respond('{"error":"not found"}', 404); return
        self.respond(json.dumps({'method': 'POST', 'received': parse_qs(body)}))

@contextmanager
def servers():
    owned = [ThreadingHTTPServer(('127.0.0.1', 0), Handler) for _ in range(2)]
    for s in owned:
        s.daemon_threads = True
        threading.Thread(target=s.serve_forever, daemon=True).start()
    try: yield [f'http://127.0.0.1:{s.server_port}' for s in owned]
    finally:
        for s in owned: s.shutdown(); s.server_close()

if __name__ == '__main__':
    import argparse, signal
    parser = argparse.ArgumentParser()
    parser.add_argument('--config-output', type=Path)
    args = parser.parse_args()
    stop = threading.Event()
    signal.signal(signal.SIGTERM, lambda *_: stop.set())
    signal.signal(signal.SIGINT, lambda *_: stop.set())
    with servers() as origins:
        if args.config_output:
            args.config_output.parent.mkdir(parents=True, exist_ok=True)
            args.config_output.write_text(json.dumps({'origins': origins}, indent=2))
        print(json.dumps({'origins': origins}), flush=True)
        stop.wait()
