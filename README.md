# DB VPN - WireGuard Client + Nginx Reverse Proxy

Secure access to PostgreSQL databases through an external WireGuard VPN server using Nginx as a reverse proxy. This container runs as a **WireGuard client** that connects to an external VPN server (outside the cluster) to access PostgreSQL databases.

## Features

- **WireGuard VPN Client**: Connects to external WireGuard server (not hosted in cluster)
- **Nginx Reverse Proxy**: Exposes PostgreSQL through the VPN to other pods in cluster
- **Kubernetes Native**: Works seamlessly with Kubernetes networking
- **Single Configuration File**: Everything configured in `deployment.yaml`
- **Easy Deployment**: Simple one-file deployment

## Architecture

```
External WireGuard Server (outside cluster)
    ↓ VPN Tunnel
WireGuard Client (in Kubernetes pod)
    ↓
Nginx Reverse Proxy (port 5432)
    ↓
Other Kubernetes Pods → db-vpn-service:5432
```

PostgreSQL database is accessible through the VPN tunnel, and this pod proxies the connection so other pods in the cluster can connect to it.

## Prerequisites

- Kubernetes cluster with access
- `kubectl` configured and authenticated
- External WireGuard server already set up with:
  - Server public key
  - Server endpoint (IP:port)
  - Client VPN address assigned to this pod
- Container registry access (GitHub Container Registry, Docker Hub, etc.)

## Quick Start

### 1. Generate WireGuard Client Keys

```bash
# Generate client keys for this pod
wg genkey > client_private.key
wg pubkey < client_private.key > client_public.key

# Send client_public.key to your WireGuard server administrator
# They will assign you a VPN IP address and configure their server
```

### 2. Build and Push Container Image

You'll set up GitHub Actions or your CI/CD pipeline later. For now, you can build manually:

```bash
# Build the image
docker build -t your-registry/db-vpn:latest .

# Push to registry
docker push your-registry/db-vpn:latest
```

### 3. Configure deployment.yaml

Open `deployment.yaml` and replace the following placeholders:

#### a. Client Private Key
Find `YOUR_CLIENT_PRIVATE_KEY_HERE` and replace with:
```bash
cat client_private.key
```

#### b. Client VPN Address
Find `YOUR_CLIENT_VPN_ADDRESS` and replace with the IP assigned by your VPN server admin:
```yaml
Address = 10.8.0.2/24
```

#### c. WireGuard Server Configuration
Find the `[Peer]` section and configure:
- `YOUR_WIREGUARD_SERVER_PUBLIC_KEY_HERE` → server's public key
- `YOUR_WIREGUARD_SERVER_IP:51820` → server's external endpoint
- `YOUR_ALLOWED_IPS` → networks accessible via VPN (e.g., `10.8.0.0/24` or `0.0.0.0/0`)

#### d. PostgreSQL Connection (via VPN)
Find `YOUR_POSTGRES_VPN_HOST:YOUR_POSTGRES_PORT` and replace with the PostgreSQL address accessible through the VPN:
```yaml
server 10.8.0.5:5432;  # PostgreSQL IP on VPN network
```

#### e. PostgreSQL Connection String
Find `YOUR_POSTGRES_CONNECTION_STRING_HERE` and replace with:
```yaml
postgres-connection-string: "postgresql://user:password@10.8.0.5:5432/dbname"
```

#### f. Docker Image
Find `YOUR_DOCKER_IMAGE_HERE` and replace with:
```yaml
image: your-registry/db-vpn:latest
```

### 4. Deploy to Kubernetes

```bash
# Make deploy script executable
chmod +x deploy.sh

# Deploy
./deploy.sh
```

### 5. Verify Connection

```bash
# Check pod status
kubectl get pods -n db-vpn

# View logs to see WireGuard connection
kubectl logs -n db-vpn -l app=db-vpn -f

# Check WireGuard status
kubectl exec -n db-vpn -l app=db-vpn -- wg show
```

## Connecting from Other Pods

Once deployed, other pods in your cluster can connect to PostgreSQL through the VPN:

```bash
# From any pod in the cluster
psql -h db-vpn-service.db-vpn.svc.cluster.local -p 5432 -U your_user -d your_database
```

## Architecture Details

```
┌─────────────────────────────────────────────────────────┐
│  External Network (Outside Kubernetes)                  │
│                                                          │
│  ┌──────────────────┐         ┌──────────────────┐     │
│  │  WireGuard       │         │  PostgreSQL      │     │
│  │  Server          │◄────────┤  Database        │     │
│  │  (VPN Gateway)   │         │  10.8.0.5:5432   │     │
│  └────────┬─────────┘         └──────────────────┘     │
│           │                                              │
└───────────┼──────────────────────────────────────────────┘
            │ VPN Tunnel (WireGuard)
            │
┌───────────┼──────────────────────────────────────────────┐
│  Kubernetes Cluster                                       │
│           │                                               │
│  ┌────────▼──────────────────────────────────────────┐  │
│  │  db-vpn Pod (Namespace: db-vpn)                   │  │
│  │                                                    │  │
│  │  ┌──────────────┐      ┌───────────────────┐     │  │
│  │  │  WireGuard   │      │  Nginx            │     │  │
│  │  │  Client      │─────►│  Reverse Proxy    │     │  │
│  │  │  10.8.0.2    │      │  :5432            │     │  │
│  │  └──────────────┘      └─────────┬─────────┘     │  │
│  └────────────────────────────────────┼──────────────┘  │
│                                       │                  │
│  ┌────────────────────────────────────▼──────────────┐  │
│  │  Service: db-vpn-service:5432                     │  │
│  └────────────────────┬──────────────────────────────┘  │
│                       │                                  │
│  ┌────────────────────▼──────────────────────────────┐  │
│  │  Other Kubernetes Pods                            │  │
│  │  (connect to db-vpn-service:5432)                 │  │
│  └───────────────────────────────────────────────────┘  │
│                                                          │
└──────────────────────────────────────────────────────────┘
```

**Flow:**
1. WireGuard client in pod connects to external VPN server
2. PostgreSQL database is accessible through VPN tunnel
3. Nginx proxies PostgreSQL connections through the VPN
4. Other Kubernetes pods connect to `db-vpn-service:5432`
5. Traffic is routed through VPN to external PostgreSQL

## Configuration Files

- **deployment.yaml** - Complete Kubernetes deployment (CONFIGURE THIS)
- **Dockerfile** - Container image definition
- **start.sh** - Container startup script
- **nginx.conf** - Nginx config template (for reference)
- **wg0.conf** - WireGuard config template (for reference)
- **deploy.sh** - Deployment helper script

## Customization

### Adding More Client Peers

Edit `deployment.yaml` and add more `[Peer]` sections:

```yaml
[Peer]
PublicKey = another_client_public_key
AllowedIPs = 10.200.0.3/32
PersistentKeepalive = 25
```

Then redeploy:
```bash
./deploy.sh
```

### Changing Network Configuration

All network settings are in `deployment.yaml`:
- WireGuard network: `Address = 10.200.0.1/24`
- Client IPs: `AllowedIPs = 10.200.0.X/32`
- PostgreSQL service: Update the upstream server address

### Service Type

By default, the service uses `LoadBalancer`. To change:

```yaml
# In deployment.yaml, find Service section and change type:
type: NodePort  # or ClusterIP
```

## Troubleshooting

### Check Pod Status

```bash
kubectl get pods -n db-vpn
kubectl describe pod -n db-vpn -l app=db-vpn
```

### View Logs

```bash
# Follow logs
kubectl logs -n db-vpn -l app=db-vpn -f

# Last 100 lines
kubectl logs -n db-vpn -l app=db-vpn --tail=100
```

### Check WireGuard Status

```bash
kubectl exec -n db-vpn -l app=db-vpn -- wg show
```

### Check Nginx Configuration

```bash
kubectl exec -n db-vpn -l app=db-vpn -- nginx -t
kubectl exec -n db-vpn -l app=db-vpn -- cat /etc/nginx/nginx.conf
```

### Test Health Endpoint

```bash
kubectl port-forward -n db-vpn svc/db-vpn-service 8080:8080
curl http://localhost:8080/health
```

### Pod Won't Start

Check for:
1. Invalid WireGuard private key format
2. Incorrect PostgreSQL host/port
3. Image pull errors (check image name in deployment.yaml)

```bash
kubectl describe pod -n db-vpn -l app=db-vpn
```

### Can't Connect via WireGuard

1. Check external IP is assigned:
   ```bash
   kubectl get svc db-vpn-service -n db-vpn
   ```

2. Verify firewall allows UDP 51820

3. Check client public key is added to server config in deployment.yaml

4. Verify client config has correct server public key and endpoint

## Security Considerations

- ✅ Keep private keys secure - never commit to version control
- ✅ Use strong, unique keys for each client
- ✅ Regularly rotate WireGuard keys
- ✅ Limit `AllowedIPs` to specific client addresses
- ✅ Use Kubernetes secrets for sensitive data
- ✅ Enable network policies to restrict pod communication
- ✅ Enable audit logging in Kubernetes
- ✅ Regularly update container images

## GitHub Actions / CI/CD

You mentioned setting up build files later on GitHub. Here's what you'll need:

### .github/workflows/build.yml (example)

```yaml
name: Build and Push

on:
  push:
    branches: [ main ]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Build and push
        uses: docker/build-push-action@v4
        with:
          context: .
          push: true
          tags: ghcr.io/${{ github.repository }}:latest
```

Then update the image in `deployment.yaml` to match your GitHub Container Registry path.

## License

MIT

