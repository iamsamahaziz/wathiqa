import http.server
import urllib.request
import json
import os

PORT = 8080
N8N_URL = "http://127.0.0.1:5679"

class ProxyHandler(http.server.SimpleHTTPRequestHandler):

    def do_OPTIONS(self):
        self.send_response(200)
        self._cors()
        self.end_headers()

    def do_POST(self):
        if self.path.startswith("/webhook/") or self.path.startswith("/webhook-test/"):
            target = N8N_URL + self.path
            length = int(self.headers.get("Content-Length", 0))
            body = self.rfile.read(length)
            try:
                req = urllib.request.Request(target, data=body,
                    headers={"Content-Type": "application/json"}, method="POST")
                with urllib.request.urlopen(req, timeout=30) as resp:
                    resp_body = resp.read()
                self.send_response(200)
                self._cors()
                self.send_header("Content-Type", "application/json")
                self.end_headers()
                self.wfile.write(resp_body)
            except Exception as e:
                self.send_response(502)
                self._cors()
                self.send_header("Content-Type", "application/json")
                self.end_headers()
                self.wfile.write(json.dumps({"error": str(e)}).encode())
        else:
            super().do_POST()

    def _cors(self):
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")

    def log_message(self, format, *args):
        pass

os.chdir(os.path.dirname(os.path.abspath(__file__)))
print(f"[OK] Wathiqa Server: http://localhost:{PORT}/Page_chatbot.html")
with http.server.HTTPServer(("", PORT), ProxyHandler) as httpd:
    httpd.serve_forever()
