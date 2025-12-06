#!/bin/bash

set -e

echo "================================================"
echo "Starting DB VPN Container (WireGuard Client)"
echo "================================================"

# Verify WireGuard config exists
if [ ! -f /etc/wireguard/wg0.conf ]; then
    echo "Error: /etc/wireguard/wg0.conf not found!"
    exit 1
fi

# Copy config to writable location and set permissions
cp /etc/wireguard/wg0.conf /tmp/wg0.conf
chmod 600 /tmp/wg0.conf

# Start WireGuard client FIRST (before nginx test)
echo "Connecting to WireGuard server..."
wg-quick up /tmp/wg0.conf

# Show WireGuard status
echo ""
echo "WireGuard connection status:"
wg show
echo ""

# Wait a moment for VPN to stabilize
sleep 2

# Test nginx configuration (after VPN is up)
echo "Testing Nginx configuration..."
RETRY_COUNT=0
MAX_RETRIES=5
until nginx -t || [ $RETRY_COUNT -eq $MAX_RETRIES ]; do
    echo "Nginx config test failed, retrying in 2 seconds... (Attempt $((RETRY_COUNT + 1))/$MAX_RETRIES)"
    sleep 2
    RETRY_COUNT=$((RETRY_COUNT + 1))
done

if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
    echo "ERROR: Nginx configuration test failed after $MAX_RETRIES attempts"
    echo "Checking DNS resolution..."
    getent hosts oneag-postgress.oneag-postgress.svc.cluster.local || echo "DNS resolution failed"
    exit 1
fi

echo "Nginx configuration test successful!"

# Show network interfaces and IPs
echo ""
echo "Network interfaces:"
ip addr show
echo ""

# Start nginx in background
echo "Starting Nginx reverse proxy..."
nginx -g 'daemon off;' &
NGINX_PID=$!

# Wait a moment for nginx to start
sleep 2

# Check if nginx is actually listening
echo "Checking listening ports..."
netstat -tlnp 2>/dev/null | grep :5432 || ss -tlnp 2>/dev/null | grep :5432 || echo "Warning: Port 5432 not showing in netstat/ss"
netstat -tlnp 2>/dev/null | grep :8080 || ss -tlnp 2>/dev/null | grep :8080 || echo "Warning: Port 8080 not showing in netstat/ss"
echo ""

# Function to handle shutdown
shutdown() {
    echo ""
    echo "Shutting down gracefully..."
    nginx -s quit 2>/dev/null || true
    wg-quick down /tmp/wg0.conf 2>/dev/null || true
    exit 0
}

trap shutdown SIGTERM SIGINT

echo "================================================"
echo "✅ DB VPN Client is ready!"
echo "================================================"
echo "  WireGuard:      connected as VPN client"
echo "  PostgreSQL:     proxying on port 5432/TCP"
echo "  Health check:   available on port 8080/TCP"
echo "================================================"
echo ""

# Keep container running and wait for nginx
wait $NGINX_PID
