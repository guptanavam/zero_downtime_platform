#!/usr/bin/env bash

set -e

NGINX_CONF="./nginx/nginx.conf"

echo "=================================================="
echo "🚨 MANUAL EMERGENCY ROLLBACK INITIATED"
echo "=================================================="

if grep -q "web-blue:5000" "$NGINX_CONF"; then
    CURRENT="blue"
    ROLLBACK_TO="green"
elif grep -q "web-green:5000" "$NGINX_CONF"; then
    CURRENT="green"
    ROLLBACK_TO="blue"
else
    echo "❌ Error: Could not determine active environment."
    exit 1
fi

echo "⏪ Rolling back from web-$CURRENT to web-$ROLLBACK_TO..."

if [ "$ROLLBACK_TO" = "blue" ]; then
    sed -i 's/server web-green:5000;/server web-blue:5000;/' "$NGINX_CONF"
else
    sed -i 's/server web-blue:5000;/server web-green:5000;/' "$NGINX_CONF"
fi

docker compose exec -T nginx nginx -t
docker compose exec -T nginx nginx -s reload

echo "=================================================="
echo "✅ EMERGENCY ROLLBACK SUCCESSFUL!"
echo "🌟 Restored Active Environment : web-$ROLLBACK_TO"
echo "🌐 Public Version Check        : $(curl -s http://localhost/version)"
echo "=================================================="