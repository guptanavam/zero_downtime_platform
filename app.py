import os
import json
import logging
import sys
import time
import psycopg2
from flask import Flask, jsonify, request, Response
from prometheus_client import Counter, Histogram, generate_latest, CONTENT_TYPE_LATEST

app = Flask(__name__)

# --- STRUCTURED JSON LOGGING ---
class JsonFormatter(logging.Formatter):
    def format(self, record):
        log_record = {
            "timestamp": self.formatTime(record),
            "level": record.levelname,
            "message": record.getMessage(),
            "environment": os.environ.get("ENVIRONMENT", "development")
        }
        return json.dumps(log_record)

handler = logging.StreamHandler(sys.stdout)
handler.setFormatter(JsonFormatter())
logger = logging.getLogger("zero_downtime_app")
logger.setLevel(logging.INFO)
logger.addHandler(handler)

# --- PROMETHEUS RED METRICS ---
REQUEST_COUNT = Counter(
    "http_requests_total",
    "Total HTTP requests received",
    ["method", "endpoint", "status"]
)

REQUEST_LATENCY = Histogram(
    "http_request_duration_seconds",
    "HTTP request duration in seconds",
    ["endpoint"]
)

@app.before_request
def start_timer():
    request.start_time = time.time()

@app.after_request
def record_metrics(response):
    if hasattr(request, "start_time"):
        duration = time.time() - request.start_time
        endpoint = request.endpoint or "unknown"
        # Record Duration (Histogram)
        REQUEST_LATENCY.labels(endpoint=endpoint).observe(duration)
        # Record Rate & Errors (Counter)
        REQUEST_COUNT.labels(
            method=request.method,
            endpoint=endpoint,
            status=response.status_code
        ).inc()
    return response

# --- CONFIGURATION ---
PORT = int(os.environ.get("PORT", 5000))
ENVIRONMENT = os.environ.get("ENVIRONMENT", "development")
APP_VERSION = os.environ.get("APP_VERSION", "1.0.0")
DATABASE_URL = os.environ.get("DATABASE_URL", None)

def check_db_connection():
    if not DATABASE_URL:
        return False, "No DATABASE_URL configured"
    try:
        conn = psycopg2.connect(DATABASE_URL, connect_timeout=3)
        conn.close()
        return True, "Database connection successful"
    except Exception as e:
        return False, str(e)

# --- ROUTES ---
@app.route("/")
def home():
    logger.info("Home endpoint requested")
    return jsonify({
        "message": "Welcome to the Zero-Downtime Platform API",
        "environment": ENVIRONMENT,
        "version": APP_VERSION
    })

@app.route("/health")
def health():
    logger.info("Health check endpoint requested")
    db_ok, db_msg = check_db_connection()
    status_code = 200 if db_ok else 500
    return jsonify({
        "status": "healthy" if db_ok else "unhealthy",
        "database": db_msg,
        "environment": ENVIRONMENT,
        "version": APP_VERSION
    }), status_code

@app.route("/version")
def version():
    return jsonify({
        "version": APP_VERSION,
        "environment": ENVIRONMENT
    }), 200

# --- PROMETHEUS SCRAPE ENDPOINT ---
@app.route("/metrics")
def metrics():
    """Endpoint scraped by Prometheus"""
    return Response(generate_latest(), mimetype=CONTENT_TYPE_LATEST)

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=PORT)