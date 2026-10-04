FROM python:3.11-slim

# 1. Create a dedicated non-root group and user with fixed UID/GID
RUN groupadd -g 10001 appgroup && \
    useradd -u 10001 -g appgroup -s /sbin/nologin -d /app appuser

WORKDIR /app

# 2. Install dependencies (runs as root during build time)
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# 3. Copy application code and grant ownership to appuser
COPY . .
RUN chown -R appuser:appgroup /app

# 4. DROP ROOT PRIVILEGES: Everything below this runs as appuser!
USER appuser:appgroup

ENV PORT=5000 \
    ENVIRONMENT=production \
    APP_VERSION=1.0.0

EXPOSE 5000

CMD ["gunicorn", "--bind", "0.0.0.0:5000", "app:app"]