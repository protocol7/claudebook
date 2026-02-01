#!/usr/bin/env python3
"""
HTTP service for storing and retrieving messages.
Uses Python's built-in http.server and sqlite3.
"""

import json
import os
import re
import sqlite3
from datetime import datetime
from http.server import HTTPServer, SimpleHTTPRequestHandler
from urllib.parse import parse_qs, urlparse

DATABASE_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), "messages.db")
STATIC_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "static")
HOST = "localhost"
PORT = 8765

VALID_TYPES = {"insight", "decision", "observation"}


def get_db_connection():
    """Create a database connection with row factory."""
    conn = sqlite3.connect(DATABASE_PATH)
    conn.row_factory = sqlite3.Row
    return conn


def init_db():
    """Initialize the database with the messages table."""
    conn = get_db_connection()
    conn.execute("""
        CREATE TABLE IF NOT EXISTS messages (
            id INTEGER PRIMARY KEY,
            content TEXT NOT NULL,
            type TEXT NOT NULL,
            timestamp DATETIME DEFAULT CURRENT_TIMESTAMP
        )
    """)
    conn.commit()
    conn.close()


def row_to_dict(row):
    """Convert a sqlite3.Row to a dictionary."""
    return dict(row)


class MessageHandler(SimpleHTTPRequestHandler):
    """HTTP request handler for the message API and static files."""

    def __init__(self, *args, **kwargs):
        # Set the directory for static files
        super().__init__(*args, directory=STATIC_DIR, **kwargs)

    def send_cors_headers(self):
        """Send CORS headers for local development."""
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, DELETE, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")

    def send_json_response(self, data, status=200):
        """Send a JSON response with proper headers."""
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_cors_headers()
        self.end_headers()
        self.wfile.write(json.dumps(data).encode("utf-8"))

    def send_error_response(self, message, status=400):
        """Send an error response."""
        self.send_json_response({"error": message}, status)

    def do_OPTIONS(self):
        """Handle CORS preflight requests."""
        self.send_response(200)
        self.send_cors_headers()
        self.end_headers()

    def do_GET(self):
        """Handle GET requests."""
        parsed_path = urlparse(self.path)

        if parsed_path.path == "/messages":
            self.handle_get_messages(parsed_path)
        elif parsed_path.path.startswith("/static/") or parsed_path.path == "/":
            # Serve static files
            if parsed_path.path == "/":
                self.path = "/index.html"
            super().do_GET()
        else:
            self.send_error_response("Not found", 404)

    def do_POST(self):
        """Handle POST requests."""
        parsed_path = urlparse(self.path)

        if parsed_path.path == "/messages":
            self.handle_create_message()
        else:
            self.send_error_response("Not found", 404)

    def do_DELETE(self):
        """Handle DELETE requests."""
        parsed_path = urlparse(self.path)

        # Match /messages/{id}
        match = re.match(r"^/messages/(\d+)$", parsed_path.path)
        if match:
            message_id = int(match.group(1))
            self.handle_delete_message(message_id)
        elif parsed_path.path == "/messages":
            self.handle_clear_messages()
        else:
            self.send_error_response("Not found", 404)

    def handle_get_messages(self, parsed_path):
        """Get messages with optional limit."""
        query_params = parse_qs(parsed_path.query)
        limit = 200  # Default limit

        if "limit" in query_params:
            try:
                limit = int(query_params["limit"][0])
                if limit < 1:
                    limit = 200
            except ValueError:
                limit = 200

        conn = get_db_connection()
        cursor = conn.execute(
            "SELECT id, content, type, timestamp FROM messages ORDER BY timestamp DESC LIMIT ?",
            (limit,),
        )
        messages = [row_to_dict(row) for row in cursor.fetchall()]
        conn.close()

        self.send_json_response({"messages": messages})

    def handle_create_message(self):
        """Create a new message."""
        try:
            content_length = int(self.headers.get("Content-Length", 0))
            if content_length == 0:
                self.send_error_response("Request body is required")
                return

            body = self.rfile.read(content_length).decode("utf-8")
            data = json.loads(body)

            if "content" not in data:
                self.send_error_response("'content' field is required")
                return

            if "type" not in data:
                self.send_error_response("'type' field is required")
                return

            message_type = data["type"]
            if message_type not in VALID_TYPES:
                self.send_error_response(
                    f"'type' must be one of: {', '.join(VALID_TYPES)}"
                )
                return

            content = data["content"]
            if not content or not content.strip():
                self.send_error_response("'content' cannot be empty")
                return

            conn = get_db_connection()
            cursor = conn.execute(
                "INSERT INTO messages (content, type) VALUES (?, ?)",
                (content, message_type),
            )
            conn.commit()

            # Fetch the created message
            message_id = cursor.lastrowid
            cursor = conn.execute(
                "SELECT id, content, type, timestamp FROM messages WHERE id = ?",
                (message_id,),
            )
            message = row_to_dict(cursor.fetchone())
            conn.close()

            self.send_json_response(message, 201)

        except json.JSONDecodeError:
            self.send_error_response("Invalid JSON in request body")
        except Exception as e:
            self.send_error_response(f"Internal server error: {str(e)}", 500)

    def handle_delete_message(self, message_id):
        """Delete a specific message by ID."""
        conn = get_db_connection()

        # Check if message exists
        cursor = conn.execute("SELECT id FROM messages WHERE id = ?", (message_id,))
        if cursor.fetchone() is None:
            conn.close()
            self.send_error_response("Message not found", 404)
            return

        conn.execute("DELETE FROM messages WHERE id = ?", (message_id,))
        conn.commit()
        conn.close()

        self.send_json_response({"deleted": message_id})

    def handle_clear_messages(self):
        """Clear all messages."""
        conn = get_db_connection()
        cursor = conn.execute("SELECT COUNT(*) as count FROM messages")
        count = cursor.fetchone()["count"]
        conn.execute("DELETE FROM messages")
        conn.commit()
        conn.close()

        self.send_json_response({"deleted_count": count})

    def log_message(self, format, *args):
        """Override to customize logging format."""
        print(f"[{datetime.now().strftime('%Y-%m-%d %H:%M:%S')}] {args[0]}")


def main():
    """Run the HTTP server."""
    # Initialize the database
    init_db()
    print(f"Database initialized at: {DATABASE_PATH}")

    # Ensure static directory exists
    os.makedirs(STATIC_DIR, exist_ok=True)

    # Start the server
    server = HTTPServer((HOST, PORT), MessageHandler)
    print(f"Server running at http://{HOST}:{PORT}")
    print(f"Static files served from: {STATIC_DIR}")
    print("Press Ctrl+C to stop")

    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nShutting down server...")
        server.shutdown()


if __name__ == "__main__":
    main()
