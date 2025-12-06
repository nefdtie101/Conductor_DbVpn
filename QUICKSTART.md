# Quick Start Summary - WireGuard CLIENT Mode

## This pod runs as a WireGuard CLIENT connecting to external VPN server!

### Prerequisites from VPN Admin:
- [ ] VPN IP address assigned to this pod (e.g., 10.8.0.2/24)
- [ ] WireGuard server public key
- [ ] WireGuard server endpoint (IP:port)
- [ ] Networks accessible via VPN (AllowedIPs)
- [ ] PostgreSQL IP/hostname accessible through VPN

### Setup Steps:

1. **Generate client keys:**
   ```bash
   wg genkey > client_private.key
   wg pubkey < client_private.key > client_public.key
   
   # Send client_public.key to your VPN server admin
   ```

2. **Edit deployment.yaml and replace:**
   - `YOUR_CLIENT_PRIVATE_KEY_HERE` → content of client_private.key
   - `YOUR_CLIENT_VPN_ADDRESS` → e.g., `10.8.0.2/24` (assigned by VPN admin)
   - `YOUR_WIREGUARD_SERVER_PUBLIC_KEY_HERE` → VPN server's public key
   - `YOUR_WIREGUARD_SERVER_IP:51820` → e.g., `vpn.example.com:51820`
   - `YOUR_ALLOWED_IPS` → e.g., `10.8.0.0/24` or `0.0.0.0/0`
   - `YOUR_POSTGRES_VPN_HOST:YOUR_POSTGRES_PORT` → e.g., `10.8.0.5:5432`
   - `YOUR_POSTGRES_CONNECTION_STRING_HERE` → full connection string
   - `YOUR_DOCKER_IMAGE_HERE` → e.g., `ghcr.io/yourusername/db-vpn:latest`

3. **Deploy:**
   ```bash
   ./deploy.sh
   ```

4. **Verify WireGuard connection:**
   ```bash
   kubectl logs -n db-vpn -l app=db-vpn -f
   kubectl exec -n db-vpn -l app=db-vpn -- wg show
   ```

5. **Connect from other pods:**
   ```bash
   psql -h db-vpn-service.db-vpn.svc.cluster.local -p 5432 -U user -d db
   ```

## Architecture:

```
External VPN Server (vpn.example.com:51820)
         ↓ VPN Tunnel
WireGuard Client in K8s Pod (10.8.0.2)
         ↓
Nginx Reverse Proxy (:5432)
         ↓
db-vpn-service.db-vpn.svc.cluster.local:5432
         ↓
Other K8s Pods
```

## Key Differences from Server Mode:

❌ NO LoadBalancer service (not exposing WireGuard to outside)
❌ NO incoming WireGuard connections
❌ NO client peer configuration needed
✅ Connects OUT to external VPN server
✅ Accessible only from within Kubernetes cluster
✅ Other pods connect to db-vpn-service to reach PostgreSQL via VPN

## Files Overview:

- **deployment.yaml** ← Configure everything here!
- **deploy.sh** ← Run this to deploy
- **README.md** ← Full documentation
- **CONFIG_REFERENCE.md** ← Configuration examples

## Example Configuration:

```yaml
# WireGuard Client Config in deployment.yaml
[Interface]
Address = 10.8.0.2/24
PrivateKey = <your_client_private_key>

[Peer]
PublicKey = <vpn_server_public_key>
Endpoint = vpn.company.com:51820
AllowedIPs = 10.8.0.0/24
PersistentKeepalive = 25
```

```yaml
# Nginx pointing to PostgreSQL via VPN
server 10.8.0.5:5432;  # PostgreSQL accessible via VPN
```

