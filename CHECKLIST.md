# Deployment Checklist - CLIENT MODE

Before deploying, ensure you have replaced ALL placeholders in `deployment.yaml`:

## Information Needed from VPN Administrator:

- [ ] VPN server public key
- [ ] VPN server endpoint (IP/hostname:port)
- [ ] VPN IP address assigned to this pod
- [ ] Networks accessible through VPN (AllowedIPs)
- [ ] PostgreSQL server IP/hostname accessible via VPN

## Required Replacements in deployment.yaml:

### WireGuard Client Configuration:

- [ ] `YOUR_CLIENT_PRIVATE_KEY_HERE` 
  - Generate with: `wg genkey`
  - Location: WireGuard ConfigMap → PrivateKey line
  - Share the public key (generated with `wg pubkey < private.key`) with VPN admin

- [ ] `YOUR_CLIENT_VPN_ADDRESS`
  - Example: `10.8.0.2/24`
  - Must be assigned by VPN server administrator
  - Location: WireGuard ConfigMap → Address line

- [ ] `YOUR_WIREGUARD_SERVER_PUBLIC_KEY_HERE`
  - Provided by VPN server administrator
  - Location: WireGuard ConfigMap → [Peer] → PublicKey

- [ ] `YOUR_WIREGUARD_SERVER_IP:51820`
  - Example: `vpn.company.com:51820` or `203.0.113.50:51820`
  - Location: WireGuard ConfigMap → [Peer] → Endpoint

- [ ] `YOUR_ALLOWED_IPS`
  - Example: `10.8.0.0/24` or `0.0.0.0/0`
  - Networks that will be routed through VPN
  - Location: WireGuard ConfigMap → [Peer] → AllowedIPs

### PostgreSQL Configuration:

- [ ] `YOUR_POSTGRES_VPN_HOST:YOUR_POSTGRES_PORT`
  - Example: `10.8.0.5:5432` (PostgreSQL accessible via VPN)
  - Location: Nginx ConfigMap → upstream postgres → server line

- [ ] `YOUR_POSTGRES_CONNECTION_STRING_HERE`
  - Example: `postgresql://user:password@10.8.0.5:5432/dbname`
  - Location: Secret → postgres-connection-string

### Docker Image:

- [ ] `YOUR_DOCKER_IMAGE_HERE`
  - Example: `ghcr.io/yourusername/conductor_dbvpn:latest`
  - Location: Deployment → containers → image

## Verification Commands:

```bash
# Check for remaining placeholders
grep -n "YOUR_" deployment.yaml

# Should return nothing if all replaced
```

## Pre-Deployment Checklist:

- [ ] Generated client private and public keys
- [ ] Sent client public key to VPN administrator
- [ ] Received VPN configuration from administrator:
  - [ ] Server public key
  - [ ] Server endpoint
  - [ ] Assigned VPN IP address
  - [ ] AllowedIPs/networks
- [ ] Know PostgreSQL IP/hostname accessible via VPN
- [ ] Built and pushed Docker image to registry
- [ ] Updated all placeholders in deployment.yaml

## Deploy:

```bash
chmod +x deploy.sh
./deploy.sh
```

## Post-Deployment Verification:

```bash
# Check pod is running
kubectl get pods -n db-vpn

# Check WireGuard connection
kubectl exec -n db-vpn -l app=db-vpn -- wg show

# Should show:
# - interface: wg0
# - peer: <server-public-key>
# - endpoint: <server-ip:port>
# - latest handshake: <recent timestamp>

# Check logs
kubectl logs -n db-vpn -l app=db-vpn

# Test PostgreSQL connectivity through VPN
kubectl exec -n db-vpn -l app=db-vpn -- nc -zv <postgres-ip> 5432

# Test from another pod
kubectl run -it --rm psql-test --image=postgres:15 --restart=Never -- \
  psql -h db-vpn-service.db-vpn.svc.cluster.local -p 5432 -U your_user -d your_db
```

## Troubleshooting:

### WireGuard not connecting:
- [ ] Verify server endpoint is reachable from pod
- [ ] Check server public key is correct
- [ ] Confirm client public key was added to server
- [ ] Check firewall allows UDP to VPN server port

### Can't reach PostgreSQL:
- [ ] Verify PostgreSQL IP is correct
- [ ] Check AllowedIPs includes PostgreSQL network
- [ ] Test connectivity: `kubectl exec ... -- ping <postgres-ip>`
- [ ] Check PostgreSQL is listening on VPN interface

### Other pods can't connect:
- [ ] Verify service exists: `kubectl get svc -n db-vpn`
- [ ] Check pod is ready: `kubectl get pods -n db-vpn`
- [ ] Test from within pod first
- [ ] Check network policies allow traffic

