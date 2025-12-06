#!/bin/bash

# Deploy script for DB VPN with WireGuard Client and Nginx
# All configuration is done in deployment.yaml

set -e

echo "================================================"
echo "DB VPN Client Deployment Script"
echo "================================================"
echo ""

# Check if deployment.yaml exists
if [ ! -f "deployment.yaml" ]; then
    echo "Error: deployment.yaml not found!"
    exit 1
fi

# Check for placeholder values
echo "Checking deployment.yaml for placeholder values..."
if grep -q "YOUR_CLIENT_PRIVATE_KEY_HERE" deployment.yaml || \
   grep -q "YOUR_WIREGUARD_SERVER_PUBLIC_KEY_HERE" deployment.yaml || \
   grep -q "YOUR_WIREGUARD_SERVER_IP" deployment.yaml || \
   grep -q "YOUR_POSTGRES_VPN_HOST" deployment.yaml || \
   grep -q "YOUR_DOCKER_IMAGE_HERE" deployment.yaml || \
   grep -q "YOUR_CLIENT_VPN_ADDRESS" deployment.yaml || \
   grep -q "YOUR_ALLOWED_IPS" deployment.yaml; then
    echo ""
    echo "⚠️  WARNING: Found placeholder values in deployment.yaml"
    echo ""
    echo "Please update the following in deployment.yaml:"
    echo "  1. YOUR_CLIENT_PRIVATE_KEY_HERE - Your WireGuard client private key"
    echo "  2. YOUR_CLIENT_VPN_ADDRESS - Your VPN IP address (e.g., 10.8.0.2/24)"
    echo "  3. YOUR_WIREGUARD_SERVER_PUBLIC_KEY_HERE - External WireGuard server public key"
    echo "  4. YOUR_WIREGUARD_SERVER_IP:51820 - External WireGuard server endpoint"
    echo "  5. YOUR_ALLOWED_IPS - Networks accessible via VPN (e.g., 10.8.0.0/24)"
    echo "  6. YOUR_POSTGRES_VPN_HOST:YOUR_POSTGRES_PORT - PostgreSQL accessible via VPN"
    echo "  7. YOUR_DOCKER_IMAGE_HERE - Your container image"
    echo "  8. YOUR_POSTGRES_CONNECTION_STRING_HERE - PostgreSQL connection string"
    echo ""
    read -p "Continue anyway? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

echo "Deploying to Kubernetes..."
kubectl apply -f deployment.yaml

echo ""
echo "✅ Deployment complete!"
echo ""
echo "================================================"
echo "Next Steps:"
echo "================================================"
echo ""
echo "1. Check pod status:"
echo "   kubectl get pods -n db-vpn"
echo ""
echo "2. View logs to verify WireGuard connection:"
echo "   kubectl logs -n db-vpn -l app=db-vpn -f"
echo ""
echo "3. Check WireGuard connection status:"
echo "   kubectl exec -n db-vpn -l app=db-vpn -- wg show"
echo ""
echo "4. Test PostgreSQL connection from within cluster:"
echo "   kubectl run -it --rm psql-test --image=postgres:15 --restart=Never -- \\"
echo "     psql -h db-vpn-service.db-vpn.svc.cluster.local -p 5432"
echo ""

