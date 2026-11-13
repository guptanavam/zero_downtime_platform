#!/usr/bin/env bash

# Exit immediately if an unhandled command fails
set -e

NGINX_CONF="./nginx/nginx.conf"

echo "=================================================="
echo "🚀 Starting Zero-Downtime Blue-Green Deployment"
echo "=================================================="

# 1. Determine currently active environment
if grep -q "web-blue:5000" "$NGINX_CONF"; then
    ACTIVE="blue"
    TARGET="green"
elif grep -q "web-green:5000" "$NGINX_CONF"; then
    ACTIVE="green"
    TARGET="blue"
else
    echo "❌ Error: Could not determine active environment from $NGINX_CONF"
    exit 1
fi

echo "🟢 Currently Active Environment : web-$ACTIVE"
echo "🎯 Target Environment for Deploy : web-$TARGET"

# --- ROLLBACK FUNCTION ---
# Automatically triggered if post-cutover verification fails
rollback() {
    echo ""
    echo "🚨 =============================================="
    echo "🚨 CRITICAL: POST-CUTOVER VERIFICATION FAILED!"
    echo "🚨 INITIATING AUTOMATED ROLLBACK TO web-$ACTIVE..."
    echo "🚨 =============================================="
    
    # Switch Nginx upstream back to the original active container
    if [ "$ACTIVE" = "blue" ]; then
        sed -i 's/server web-green:5000;/server web-blue:5000;/' "$NGINX_CONF"
    else
        sed -i 's/server web-blue:5000;/server web-green:5000;/' "$NGINX_CONF"
    fi
    
    docker compose exec -T nginx nginx -t
    docker compose exec -T nginx nginx -s reload
    
    echo "✅ ROLLBACK COMPLETE! Live traffic safely restored to web-$ACTIVE."
    echo "🌐 Active Version: $(curl -s http://localhost/version)"
    exit 1
}

# 2. Build and start target container
echo "📦 Building and starting web-$TARGET..."
docker compose up -d --no-deps --build "web-$TARGET"

# 3. Pre-Cutover Smoke Test
echo "🩺 Running Pre-Cutover Smoke Test on internal web-$TARGET..."

MAX_RETRIES=5
COUNT=0
HEALTHY=false

while [ $COUNT -lt $MAX_RETRIES ]; do
    sleep 2
    COUNT=$((COUNT + 1))
    
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
    echo "❌ CRITICAL ERROR: Pre-cutover smoke test failed for web-$TARGET!"
    echo "🛑 Aborting deployment. Live traffic remains untouched on web-$ACTIVE."
    exit 1
fi

# 4. Atomic Cutover in Nginx
echo "🔄 Switching Nginx upstream traffic from web-$ACTIVE to web-$TARGET..."

if [ "$TARGET" = "green" ]; then
    sed -i 's/server web-blue:5000;/server web-green:5000;/' "$NGINX_CONF"
else
    sed -i 's/server web-green:5000;/server web-blue:5000;/' "$NGINX_CONF"
fi

docker compose exec -T nginx nginx -t
docker compose exec -T nginx nginx -s reload

echo "⚡ Cutover executed! Traffic is now routing to web-$TARGET."

# 5. Post-Cutover Live Verification Window
echo "🔍 Conducting Post-Cutover Verification Probe on public Port 80..."

POST_RETRIES=3
POST_COUNT=0
POST_HEALTHY=false

while [ $POST_COUNT -lt $POST_RETRIES ]; do
    sleep 2
    POST_COUNT=$((POST_COUNT + 1))
    
    LIVE_STATUS=$(curl -s http://localhost/health || true)
    
    if echo "$LIVE_STATUS" | grep -q '"status":"healthy"'; then
        echo "✅ Post-Cutover Probe $POST_COUNT/$POST_RETRIES: System healthy!"
        POST_HEALTHY=true
    else
        echo "⚠️ Warning: Live health check failed on probe $POST_COUNT/$POST_RETRIES!"
        POST_HEALTHY=false
        break
    fi
done

# If live verification failed, trigger automated rollback!
if [ "$POST_HEALTHY" = false ]; then
    rollback
fi

echo "=================================================="
echo "🎉 DEPLOYMENT FULLY VERIFIED & COMPLETE!"
echo "🌟 New Active Environment : web-$TARGET"
echo "🌐 Public Version Check    : $(curl -s http://localhost/version)"
echo "=================================================="