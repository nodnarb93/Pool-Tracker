#!/usr/bin/env python3
"""
Simple HTTP server for local development
Usage: python serve.py [port]
Default port: 8000
"""

import http.server
import socketserver
import sys
import os

PORT = int(sys.argv[1]) if len(sys.argv) > 1 else 8000

class MyHTTPRequestHandler(http.server.SimpleHTTPRequestHandler):
    def end_headers(self):
        # Add CORS headers for local development
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', 'Content-Type')
        super().end_headers()

    def log_message(self, format, *args):
        # Custom log format
        print(f"[{self.address_string()}] {format % args}")

if __name__ == "__main__":
    os.chdir(os.path.dirname(os.path.abspath(__file__)))
    
    with socketserver.TCPServer(("", PORT), MyHTTPRequestHandler) as httpd:
        url = f"http://localhost:{PORT}/index.local.html"
        # This line is detected by VS Code's serverReadyAction
        print(f"Server running at http://localhost:{PORT}/")
        print("=" * 60)
        print("🚀 SERVER STARTED SUCCESSFULLY!")
        print("=" * 60)
        print(f"📄 Application URL: {url}")
        print("⏹️  Press Ctrl+C to stop the server")
        print("=" * 60)
        try:
            httpd.serve_forever()
        except KeyboardInterrupt:
            print("\n👋 Server stopped")

