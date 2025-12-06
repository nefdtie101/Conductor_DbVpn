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

# Force Kubernetes DNS (fix for VPN overwriting resolv.conf)
echo "Restoring Kubernetes DNS configuration..."
echo "nameserver 10.96.0.10" > /etc/resolv.conf
# Add search domains for Kubernetes service discovery
echo "search svc.cluster.local cluster.local" >> /etc/resolv.conf

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

# DNS Debugging
echo "================================================"
echo "DNS Configuration Debugging"
echo "================================================"
echo "Environment Variables:"
echo "  POSTGRES_HOST: ${POSTGRES_HOST}"
echo "  POSTGRES_PORT: ${POSTGRES_PORT}"
echo ""

echo "DNS resolvers (/etc/resolv.conf):"
cat /etc/resolv.conf | grep -v "^#" | grep -v "^$"
echo ""

# Check DNS search domains
if grep -q "^search" /etc/resolv.conf; then
    echo "DNS Search domains:"
    grep "^search" /etc/resolv.conf
    echo ""
else
    echo "⚠️  No DNS search domains configured in /etc/resolv.conf"
    echo ""
fi

echo "Testing DNS resolution methods:"
echo ""

# Method 1: nslookup
echo "1. nslookup test:"
if command -v nslookup > /dev/null 2>&1; then
    nslookup "${POSTGRES_HOST}" || echo "   ⚠️  nslookup failed"
else
    echo "   nslookup not available"
fi
echo ""

# Method 2: dig
echo "2. dig test:"
if command -v dig > /dev/null 2>&1; then
    dig "${POSTGRES_HOST}" +short || echo "   ⚠️  dig failed"
else
    echo "   dig not available"
fi
echo ""

# Method 3: host command
echo "3. host test:"
if command -v host > /dev/null 2>&1; then
    host "${POSTGRES_HOST}" || echo "   ⚠️  host command failed"
else
    echo "   host not available"
fi
echo ""

# Method 4: getent
echo "4. getent hosts test (Full FQDN):"
HOSTNAME_TO_USE="${POSTGRES_HOST}"
RESOLUTION_SUCCESS=false

if getent hosts "${POSTGRES_HOST}" > /dev/null 2>&1; then
    RESOLVED_IP=$(getent hosts "${POSTGRES_HOST}" | awk '{ print $1 }')
    echo "   ✅ DNS resolved: ${POSTGRES_HOST} -> ${RESOLVED_IP}"
    RESOLUTION_SUCCESS=true
else
    echo "   ⚠️  Could not resolve ${POSTGRES_HOST}"
fi
echo ""

# Method 5: Try alternative hostname formats if full FQDN failed
if [ "$RESOLUTION_SUCCESS" = false ]; then
    echo "5. Trying alternative hostname formats:"
    echo ""

    # Try without .svc.cluster.local suffix
    ALT_HOST_1=$(echo "${POSTGRES_HOST}" | sed 's/.svc.cluster.local$//')
    echo "   a) Testing: ${ALT_HOST_1}"
    if getent hosts "${ALT_HOST_1}" > /dev/null 2>&1; then
        RESOLVED_IP=$(getent hosts "${ALT_HOST_1}" | awk '{ print $1 }')
        echo "      ✅ Resolved: ${ALT_HOST_1} -> ${RESOLVED_IP}"
        HOSTNAME_TO_USE="${ALT_HOST_1}"
        RESOLUTION_SUCCESS=true
    else
        echo "      ❌ Failed"
    fi
    echo ""

    # Try just service.namespace (without .svc.cluster.local)
    if [ "$RESOLUTION_SUCCESS" = false ]; then
        # Extract service.namespace from full FQDN
        ALT_HOST_2=$(echo "${POSTGRES_HOST}" | sed 's/.svc.cluster.local$//' | cut -d'.' -f1-2)
        if [ "${ALT_HOST_2}" != "${ALT_HOST_1}" ]; then
            echo "   b) Testing: ${ALT_HOST_2}"
            if getent hosts "${ALT_HOST_2}" > /dev/null 2>&1; then
                RESOLVED_IP=$(getent hosts "${ALT_HOST_2}" | awk '{ print $1 }')
                echo "      ✅ Resolved: ${ALT_HOST_2} -> ${RESOLVED_IP}"
                HOSTNAME_TO_USE="${ALT_HOST_2}"
                RESOLUTION_SUCCESS=true
            else
                echo "      ❌ Failed"
            fi
            echo ""
        fi
    fi

    # Try just the service name (first part before first dot)
    if [ "$RESOLUTION_SUCCESS" = false ]; then
        ALT_HOST_3=$(echo "${POSTGRES_HOST}" | cut -d'.' -f1)
        echo "   c) Testing: ${ALT_HOST_3}"
        if getent hosts "${ALT_HOST_3}" > /dev/null 2>&1; then
            RESOLVED_IP=$(getent hosts "${ALT_HOST_3}" | awk '{ print $1 }')
            echo "      ✅ Resolved: ${ALT_HOST_3} -> ${RESOLVED_IP}"
            HOSTNAME_TO_USE="${ALT_HOST_3}"
            RESOLUTION_SUCCESS=true
        else
            echo "      ❌ Failed"
        fi
        echo ""
    fi

    if [ "$RESOLUTION_SUCCESS" = true ]; then
        echo "   💡 Using working hostname: ${HOSTNAME_TO_USE}"
        POSTGRES_HOST="${HOSTNAME_TO_USE}"
    else
        echo "   ⚠️  All DNS resolution attempts failed!"
        echo "   ⚠️  Continuing with original hostname: ${POSTGRES_HOST}"
        echo "   ⚠️  Connection will likely fail unless DNS resolves dynamically"
    fi
    echo ""
fi

echo "================================================"
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
echo "Final connection parameters:"
echo "  Target: ${POSTGRES_HOST}:${POSTGRES_PORT}"
echo "  Listen: 0.0.0.0:${LISTEN_PORT}"
echo ""

# Start socat TCP proxy in foreground
# fork = handle multiple connections
# reuseaddr = allow quick restart
exec socat -d -d \
    TCP-LISTEN:${LISTEN_PORT},fork,reuseaddr \
    TCP:${POSTGRES_HOST}:${POSTGRES_PORT}
