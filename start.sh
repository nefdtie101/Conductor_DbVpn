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

# Test nginx configuration
echo "Testing Nginx configuration..."
nginx -t

# Start WireGuard client using the copied config
echo "Connecting to WireGuard server..."
wg-quick up /tmp/wg0.conf

# Show WireGuard status
echo ""
echo "WireGuard connection status:"
wg show
echo ""

# Start nginx in background
echo "Starting Nginx reverse proxy..."
nginx -g 'daemon off;' &
NGINX_PID=$!

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
