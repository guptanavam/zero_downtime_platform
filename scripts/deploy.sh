#!/usr/bin/env bash

# Exit immediately if a command exits with a non-zero status
set -e

NGINX_CONF="./nginx/nginx.conf"

echo "=================================================="
echo "  Starting Zero-Downtime Blue-Green Deployment"
echo "=================================================="

# 1. Determine currently active environment
if grep -q "web-blue:5000" "$NGINX_CONF"; then
    ACTIVE="blue"
    TARGET="green"
elif grep -q "web-green:5000" "$NGINX_CONF"; then
    ACTIVE="green"
    TARGET="blue"
else
    echo "Error: Could not determine active environment from $NGINX_CONF"
    exit 1
fi

echo "Currently Active Environment : web-$ACTIVE"
echo "Target Environment for Deploy : web-$TARGET"

# 2. Build and start the target container
echo "Building and starting web-$TARGET..."
docker compose up -d --no-deps --build "web-$TARGET"

# 3. Smoke Test / Readiness Probe
echo "Running Smoke Test on web-$TARGET health endpoint..."

MAX_RETRIES=5
COUNT=0
HEALTHY=false

while [ $COUNT -lt $MAX_RETRIES ]; do
    sleep 2
    COUNT=$((COUNT + 1))
    
    # Query target container health through the Nginx container network
    STATUS=$(docker compose exec -T nginx wget -qO- "http://web-$TARGET:5000/health" || true)
    
    if echo "$STATUS" | grep -q '"status":"healthy"'; then
        echo "✅ Smoke Test PASSED! Target web-$TARGET is healthy."
        HEALTHY=true
        break
    else
        echo "⏳ Attempt $COUNT/$MAX_RETRIES: web-$TARGET not ready yet..."
    fi
done

if [ "$HEALTHY" = false ]; then
    echo "CRITICAL ERROR: Smoke test failed for web-$TARGET!"
    echo "Aborting deployment. Live traffic remains safely on web-$ACTIVE."
    exit 1
fi

# 4. Atomic Cutover in Nginx
echo "Switching Nginx upstream traffic from web-$ACTIVE to web-$TARGET..."

# Replace the active upstream with target upstream in nginx.conf
if [ "$TARGET" = "green" ]; then
    sed -i 's/server web-blue:5000;/server web-green:5000;/' "$NGINX_CONF"
else
    sed -i 's/server web-green:5000;/server web-blue:5000;/' "$NGINX_CONF"
fi

# 5. Validate Syntax and Reload Nginx
echo "Validating Nginx configuration syntax..."
docker compose exec -T nginx nginx -t

echo "Reloading Nginx with Zero Downtime..."
docker compose exec -T nginx nginx -s reload

echo "=================================================="
echo "DEPLOYMENT SUCCESSFUL!"
echo "New Active Environment : web-$TARGET"
echo "Public Version Check    : $(curl -s http://localhost/version)"
echo "=================================================="