#!/bin/bash

set -e

echo "================================================"
echo "Starting DB VPN Container (WireGuard + socat)"
echo "================================================"

# Verify WireGuard config exists
if [ ! -f /etc/wireguard/wg0.conf ]; then
    echo "Error: /etc/wireguard/wg0.conf not found!"
    exit 1
fi

# Copy config to writable location and set permissions
cp /etc/wireguard/wg0.conf /tmp/wg0.conf
chmod 600 /tmp/wg0.conf

# Start WireGuard client
echo "Connecting to WireGuard server..."
wg-quick up /tmp/wg0.conf

# Show WireGuard status
echo ""
echo "WireGuard connection status:"
wg show
echo ""

# Show network interfaces and VPN IP
echo "Network interfaces:"
ip addr show | grep -E "inet|wg0" || ip addr show
echo ""

# Wait for VPN to stabilize
echo "Waiting for VPN to stabilize..."
sleep 3

# PostgreSQL endpoint configuration
# YOU CAN CHANGE THIS TO YOUR POSTGRESQL SERVICE
POSTGRES_HOST="${POSTGRES_HOST:-oneag-postgress.oneag-postgress.svc.cluster.local}"
POSTGRES_PORT="${POSTGRES_PORT:-5432}"
LISTEN_PORT="${LISTEN_PORT:-5432}"

echo "PostgreSQL Proxy Configuration:"
echo "  Listen on:    0.0.0.0:${LISTEN_PORT}"
echo "  Forward to:   ${POSTGRES_HOST}:${POSTGRES_PORT}"
echo ""

# Test DNS resolution
echo "Testing DNS resolution..."
if getent hosts "${POSTGRES_HOST}" > /dev/null 2>&1; then
    RESOLVED_IP=$(getent hosts "${POSTGRES_HOST}" | awk '{ print $1 }')
    echo "✅ DNS resolved: ${POSTGRES_HOST} -> ${RESOLVED_IP}"
else
    echo "⚠️  Warning: Could not resolve ${POSTGRES_HOST}"
    echo "   Continuing anyway (socat will retry)..."
fi
echo ""

# Function to handle shutdown
shutdown() {
    echo ""
    echo "Shutting down gracefully..."
    pkill socat 2>/dev/null || true
    wg-quick down /tmp/wg0.conf 2>/dev/null || true
    exit 0
}

trap shutdown SIGTERM SIGINT

echo "================================================"
echo "✅ Starting PostgreSQL TCP Proxy (socat)..."
echo "================================================"
echo ""

# Start socat TCP proxy in foreground
# fork = handle multiple connections
# reuseaddr = allow quick restart
exec socat -d -d \
    TCP-LISTEN:${LISTEN_PORT},fork,reuseaddr \
    TCP:${POSTGRES_HOST}:${POSTGRES_PORT}
