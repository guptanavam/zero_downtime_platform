# Zero-Downtime Deployment Platform (Blue-Green SRE Engine)

[![Continuous Integration & Delivery](https://github.com/guptanavam/zero_downtime_platform/actions/workflows/ci.yml/badge.svg)](https://github.com/guptanavam/zero_downtime_platform/actions)
![Docker](https://img.shields.io/badge/Docker-2496ED?style=flat&logo=docker&logoColor=white)
![Nginx](https://img.shields.io/badge/Nginx-009639?style=flat&logo=nginx&logoColor=white)
![Prometheus](https://img.shields.io/badge/Prometheus-E6522C?style=flat&logo=prometheus&logoColor=white)
![Python](https://img.shields.io/badge/Python-3.11-3776AB?style=flat&logo=python&logoColor=white)
![License](https://img.shields.io/badge/License-MIT-green.svg)

An enterprise-grade, high-availability Blue-Green deployment and Site Reliability Engineering (SRE) platform. Features atomic zero-downtime traffic switching via an Nginx Layer 7 reverse proxy, automated pre-cutover smoke testing, post-cutover live canary verification, sub-second automated rollbacks, non-root container hardening, and Prometheus RED metrics telemetry.

---

## 🏛️ System Architecture

```text
                               Public Traffic (Port 80)
                                          │
                                          ▼
                             ┌────────────────────────┐
                             │   Nginx Reverse Proxy  │ ◄─── Prometheus Server
                             │        (Port 80)       │      (Scrapes :80/metrics)
                             └────────────┬───────────┘
                                          │
                        Atomic Dynamic Upstream Routing (SIGHUP)
                                          │
                     ┌────────────────────┴────────────────────┐
                     ▼ (ACTIVE)                                ▼ (IDLE / WARM STANDBY)
           ┌───────────────────┐                     ┌───────────────────┐
           │   web-blue (v1)   │                     │  web-green (v2)   │
           │    Port 5000      │                     │    Port 5000      │
           └─────────┬─────────┘                     └─────────┬─────────┘
                     │                                         │
                     └────────────────────┬────────────────────┘
                                          │
                                          ▼
                             ┌────────────────────────┐
                             │    PostgreSQL (db)     │
                             │       (Port 5432)      │
                             └────────────────────────┘
```

---

# Key Highlights

 1. Zero-Downtime Blue-Green Cutover
* Runs dual identical application environments (`web-blue` and `web-green`) in parallel behind Nginx.
* Updates the upstream configuration pointer atomically and triggers an in-memory configuration reload (`nginx -s reload` / `SIGHUP`) without dropping active TCP connections.

### 2. Self-Healing & Automated Rollback Engine
* **Pre-Cutover Smoke Tests:** Verifies internal container health before routing customer traffic.
* **Post-Cutover Live Canary Verification:** Executes 3 consecutive live health probes directly against public Port 80.
* **Instant Automated Rollback:** Automatically triggers `rollback.sh` within **<1 second** if public probes fail, safely restoring traffic to the previous warm standby.

### 3. DevSecOps & Security Hardening
* **Non-Root Execution:** Container execution context drops root privileges to a dedicated unprivileged user (`appuser:appgroup`, UID/GID `10001`), mitigating container breakout and privilege escalation risks.
* **Automated CVE Scanning:** 3-stage GitHub Actions CI/CD pipeline runs **Trivy** vulnerability audits on every build to detect base OS and library CVEs prior to publishing to Docker Hub.
* **Static Code Analysis:** Enforces code quality with Flake8 and runs unit tests via Pytest before deployment gates.

### 4. SRE Observability & RED Metrics
* **Rate & Errors:** Exposes Prometheus `Counter` metrics (`http_requests_total`) tracking request volume by endpoint, method, and HTTP status code.
* **Duration:** Tracks request latency percentiles using Prometheus `Histogram` buckets (`http_request_duration_seconds`).
* **Pull-Based Scraping:** Integrated Prometheus server scrapes `/metrics` through Nginx every 5 seconds.

### 5. High-Throughput Performance Benchmarks
* Stress-tested with a multi-threaded concurrent load generator (`load_test.py` with 20 parallel worker threads).
* **Throughput:** **678.80 Requests / Second (RPS)**
* **Latency:** **28.19 ms** average response time
* **Error Rate:** **0% (500/500 successful 200 OK responses)**

---

## 📂 Repository Structure

```text
├── .github/
│   └── workflows/
│       └── ci.yml              # 3-stage CI/CD pipeline (Test, Trivy Scan, Docker Hub Delivery)
├── nginx/
│   └── nginx.conf              # Nginx Layer 7 reverse proxy & upstream configuration
├── prometheus/
│   └── prometheus.yml          # Prometheus scrape configuration
├── scripts/
│   ├── deploy.sh               # Automated Blue-Green deployment engine with auto-rollback
│   ├── rollback.sh             # Instant emergency manual rollback script (<1s)
│   └── load_test.py            # High-throughput concurrent load testing suite
├── tests/
│   └── test_app.py             # Pytest unit tests for API and metrics endpoints
├── app.py                      # Flask microservice with structured JSON logs & RED metrics
├── Dockerfile                  # Hardened non-root (UID 10001) container build
├── docker-compose.yml          # 5-tier local orchestration (db, blue, green, nginx, prometheus)
└── requirements.txt            # Application dependencies
```

---

## 🚀 Quickstart & Local Setup

### Prerequisites
* Docker & Docker Desktop
* Git Bash or POSIX terminal
* Python 3.11+

### 1. Clone the Repository
```bash
git clone https://github.com/guptanavam/zero_downtime_platform.git
cd zero_downtime_platform
```

### 2. Boot the Entire Cluster
```bash
docker compose up -d --build
```

Verify that all 5 services are healthy and running:
```bash
docker compose ps
```

### 3. Verify Endpoints
```bash
# Public Welcome Endpoint
curl http://localhost/

# Health Check (validates DB connectivity)
curl http://localhost/health

# Current Active Version
curl http://localhost/version

# Prometheus Metrics
curl http://localhost/metrics
```

---

## 🔄 Deployment & Rollback Workflows

### Automated Zero-Downtime Deployment
Deploy a new release to the idle target environment:
```bash
./scripts/deploy.sh
```
*The script automatically detects the active color, builds the target, runs readiness checks, flips Nginx upstream, runs live verification probes, and auto-rolls back if an issue is detected.*

### Instant Emergency Rollback
Manually roll back to the previous stable release in under 1 second:
```bash
./scripts/rollback.sh
```

---

## 📊 Load Testing & Prometheus Metrics

1. Open Prometheus in your browser: [http://localhost:9090](http://localhost:9090)
2. Execute concurrent load test (500 requests across 20 threads):
   ```bash
   python scripts/load_test.py
   ```
3. In Prometheus, query live request rate surges:
   ```promql
   rate(http_requests_total[1m])
   ```

---

## 🛡️ CI/CD Pipeline Architecture

Every commit pushed to `main` undergoes automated verification in GitHub Actions:

```text
[ Push to main ]
       │
       ▼
┌──────────────────────────────┐
│ Stage 1: test-and-lint       │ ➔ Flake8 static analysis & Pytest unit tests
└──────────────┬───────────────┘
               │
               ▼
┌──────────────────────────────┐
│ Stage 2: security-scan       │ ➔ Trivy container image vulnerability audit
└──────────────┬───────────────┘
               │
               ▼
┌──────────────────────────────┐
│ Stage 3: build-and-push      │ ➔ Buildx compilation & dual-tagging (:sha, :latest) to Docker Hub
└──────────────────────────────┘
```

---

## 👤 Author
* **Navam Gupta** — [GitHub](https://github.com/guptanavam) • [LinkedIn](https://linkedin.com/in/guptanavam)
