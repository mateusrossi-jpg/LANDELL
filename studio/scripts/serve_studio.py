#!/usr/bin/env python3
"""
ENDAP Studio Dedicated Web Server
Serves Flutter Web release bundle with:
- SPA Fallback (/qualquer-rota -> /index.html)
- Explicit and complete MIME types (js, wasm, json, html, otf, woff2, etc.)
- Security headers (X-Frame-Options: SAMEORIGIN, X-Content-Type-Options: nosniff)
- Path traversal & hidden file prevention (Returns 403/404 for forbidden files)
"""

import sys
import os
import argparse
from http.server import HTTPServer, SimpleHTTPRequestHandler
import socketserver
from urllib.parse import unquote
import urllib.request
import urllib.error

import threading
import time

DEFAULT_PORT = 8080
DEFAULT_HOST = "0.0.0.0"
DEFAULT_ESP32_IP = os.environ.get("ESP32_IP", "192.168.0.229")
CANDIDATE_HOSTS = [h for h in [DEFAULT_ESP32_IP, "192.168.0.229", "192.168.4.1", "192.168.0.27", "endap.local"] if h]
BASE_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "build", "web"))

TARGET_ESP32_HOST = DEFAULT_ESP32_IP if DEFAULT_ESP32_IP else "192.168.0.229"

_PROXY_CACHE_LOCK = threading.Lock()
_PROXY_CACHE = {}  # path -> (timestamp, status_code, content_type, resp_body)
_PROXY_CACHE_TTL_SEC = 0.12

class StudioSPAHandler(SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=BASE_DIR, **kwargs)

    def end_headers(self):
        self.send_header("X-Frame-Options", "SAMEORIGIN")
        self.send_header("X-Content-Type-Options", "nosniff")
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Cache-Control", "no-cache, no-store, must-revalidate")
        self.send_header("Pragma", "no-cache")
        self.send_header("Expires", "0")
        super().end_headers()

    def guess_type(self, path):
        lower_path = path.lower()
        if lower_path.endswith(".wasm"):
            return "application/wasm"
        elif lower_path.endswith(".js") or lower_path.endswith(".mjs"):
            return "text/javascript; charset=utf-8"
        elif lower_path.endswith(".json"):
            return "application/json; charset=utf-8"
        elif lower_path.endswith(".html") or lower_path.endswith(".htm"):
            return "text/html; charset=utf-8"
        elif lower_path.endswith(".otf"):
            return "font/otf"
        elif lower_path.endswith(".woff2"):
            return "font/woff2"
        elif lower_path.endswith(".woff"):
            return "font/woff"
        elif lower_path.endswith(".ttf"):
            return "font/ttf"
        elif lower_path.endswith(".png"):
            return "image/png"
        elif lower_path.endswith(".svg"):
            return "image/svg+xml"
        elif lower_path.endswith(".ico"):
            return "image/x-icon"
        elif lower_path.endswith(".css"):
            return "text/css; charset=utf-8"
        return super().guess_type(path)

    def _proxy_request(self, method):
        global TARGET_ESP32_HOST
        content_length = int(self.headers.get('Content-Length', 0))
        body = self.rfile.read(content_length) if content_length > 0 else None

        clean_path = self.path.split('?', 1)[0]
        is_cacheable_get = (method == 'GET' and clean_path in ('/api/io/map', '/api/pve', '/api/public/status'))
        if is_cacheable_get:
            now = time.monotonic()
            with _PROXY_CACHE_LOCK:
                cached = _PROXY_CACHE.get(clean_path)
                if cached and (now - cached[0]) <= _PROXY_CACHE_TTL_SEC:
                    _, c_status, c_type, c_body = cached
                    self.send_response(c_status)
                    self.send_header('Content-Type', c_type)
                    self.send_header('Content-Length', str(len(c_body)))
                    self.send_header("Access-Control-Allow-Origin", "*")
                    self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS, PUT, DELETE")
                    self.send_header("Access-Control-Allow-Headers", "Content-Type, Authorization, X-ENDAP-Session")
                    self.end_headers()
                    self.wfile.write(c_body)
                    return

        headers = {
            'User-Agent': self.headers.get('User-Agent', 'ENDAP-Studio-Proxy'),
        }
        if 'Content-Type' in self.headers:
            headers['Content-Type'] = self.headers['Content-Type']
        if 'Authorization' in self.headers:
            headers['Authorization'] = self.headers['Authorization']
        if 'X-ENDAP-Session' in self.headers:
            headers['X-ENDAP-Session'] = self.headers['X-ENDAP-Session']

        hosts_to_try = [TARGET_ESP32_HOST] if TARGET_ESP32_HOST else []
        for c in CANDIDATE_HOSTS:
            if c and c not in hosts_to_try:
                hosts_to_try.append(c)

        last_error = None
        for host in hosts_to_try:
            target_url = f"http://{host}{self.path}"
            try:
                req = urllib.request.Request(target_url, data=body, headers=headers, method=method)
                with urllib.request.urlopen(req, timeout=1.5) as response:
                    status_code = response.getcode()
                    resp_body = response.read()
                    content_type = response.headers.get('Content-Type', 'application/json')

                    if host != TARGET_ESP32_HOST:
                        TARGET_ESP32_HOST = host
                        sys.stderr.write(f"[ENDAP-STUDIO-WEB] Switched active ESP32 target to: {host}\n")

                    if is_cacheable_get and status_code == 200:
                        with _PROXY_CACHE_LOCK:
                            _PROXY_CACHE[clean_path] = (time.monotonic(), status_code, content_type, resp_body)
                    elif method == 'POST':
                        with _PROXY_CACHE_LOCK:
                            _PROXY_CACHE.clear()

                    self.send_response(status_code)
                    self.send_header('Content-Type', content_type)
                    self.send_header('Content-Length', str(len(resp_body)))
                    self.send_header("Access-Control-Allow-Origin", "*")
                    self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS, PUT, DELETE")
                    self.send_header("Access-Control-Allow-Headers", "Content-Type, Authorization, X-ENDAP-Session")
                    self.end_headers()
                    self.wfile.write(resp_body)
                    return
            except urllib.error.HTTPError as e:
                resp_body = e.read()
                if host != TARGET_ESP32_HOST:
                    TARGET_ESP32_HOST = host
                self.send_response(e.code)
                self.send_header('Content-Type', e.headers.get('Content-Type', 'application/json'))
                self.send_header('Content-Length', str(len(resp_body)))
                self.send_header("Access-Control-Allow-Origin", "*")
                self.end_headers()
                self.wfile.write(resp_body)
                return
            except Exception as e:
                last_error = (e, target_url)
                continue

        err, url = last_error if last_error else (Exception("No targets available"), "unknown")
        err_json = f'{{"error": "proxy_failed", "detail": "{str(err)}", "target": "{url}"}}'.encode('utf-8')
        self.send_response(502)
        self.send_header('Content-Type', 'application/json')
        self.send_header('Content-Length', str(len(err_json)))
        self.send_header("Access-Control-Allow-Origin", "*")
        self.end_headers()
        self.wfile.write(err_json)

    def do_OPTIONS(self):
        self.send_response(200)
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS, PUT, DELETE")
        self.send_header("Access-Control-Allow-Headers", "Content-Type, Authorization, X-ENDAP-Session")
        self.end_headers()

    def do_GET(self):
        clean_path = unquote(self.path.split('?', 1)[0].split('#', 1)[0])
        if clean_path.startswith('/api/'):
            return self._proxy_request('GET')

        parts = [p for p in clean_path.split('/') if p]

        # Bloqueia qualquer tentativa de acessar arquivos/pastas ocultas (ex: .env, .git)
        for part in parts:
            if part.startswith('.'):
                self.send_error(403, "Access denied")
                return

        return super().do_GET()

    def do_POST(self):
        clean_path = unquote(self.path.split('?', 1)[0].split('#', 1)[0])
        if clean_path.startswith('/api/'):
            return self._proxy_request('POST')
        self.send_error(405, "Method not allowed")

    def do_HEAD(self):
        clean_path = unquote(self.path.split('?', 1)[0].split('#', 1)[0])
        parts = [p for p in clean_path.split('/') if p]

        for part in parts:
            if part.startswith('.'):
                self.send_error(403, "Access denied")
                return

        return super().do_HEAD()

    def translate_path(self, path):
        # Base translation provided by SimpleHTTPRequestHandler
        translated = super().translate_path(path)
        norm_translated = os.path.abspath(translated)

        # Path traversal guard: must be strictly inside BASE_DIR
        if not norm_translated.startswith(BASE_DIR):
            return os.path.join(BASE_DIR, "index.html")

        # Se o arquivo físico existe no build/web, retorna ele
        if os.path.exists(norm_translated):
            return norm_translated

        # Se não existe: se for rota sem extensão (SPA), entrega index.html
        _, ext = os.path.splitext(norm_translated)
        if not ext:
            return os.path.join(BASE_DIR, "index.html")

        # Se for um arquivo com extensão que não existe (ex: imagem faltando), deixa dar 404
        return norm_translated

    def log_message(self, format, *args):
        sys.stderr.write(f"[ENDAP-STUDIO-WEB] {self.address_string()} - {format % args}\n")

class ThreadedHTTPServer(socketserver.ThreadingMixIn, HTTPServer):
    allow_reuse_address = True
    daemon_threads = True
    request_queue_size = 128

def run():
    global BASE_DIR, TARGET_ESP32_HOST
    parser = argparse.ArgumentParser(description="ENDAP Studio Dedicated Server")
    parser.add_argument("--port", type=int, default=DEFAULT_PORT, help="Port to listen on (default 8080)")
    parser.add_argument("--host", type=str, default=DEFAULT_HOST, help="Host to bind (default 0.0.0.0)")
    parser.add_argument("--dir", type=str, default=BASE_DIR, help="Web root directory")
    parser.add_argument("--esp32-ip", type=str, default=DEFAULT_ESP32_IP, help="Target ESP32 IP for /api proxy (default 192.168.0.27)")
    args = parser.parse_args()

    BASE_DIR = os.path.abspath(args.dir)
    TARGET_ESP32_HOST = args.esp32_ip if args.esp32_ip else "192.168.0.229"

    if not os.path.isdir(BASE_DIR):
        sys.stderr.write(f"Error: Directory {BASE_DIR} does not exist!\n")
        sys.exit(1)

    server_address = (args.host, args.port)
    ThreadedHTTPServer.allow_reuse_address = True
    httpd = ThreadedHTTPServer(server_address, StudioSPAHandler)

    print(f"============================================================")
    print(f"🚀 ENDAP Studio Web Server Online")
    print(f"   Root Directory: {BASE_DIR}")
    print(f"   Listening on:   http://{args.host}:{args.port}")
    print(f"============================================================")
    sys.stdout.flush()

    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        print("\nStopping server...")
        httpd.server_close()

if __name__ == "__main__":
    run()
