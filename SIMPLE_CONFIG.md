# Simple Configuration Guide

## ✅ No Persistent Volumes - Just ConfigMaps!

Everything is configured directly in `deployment.yaml` - no external volumes needed.

## What You Configure:

### 1. WireGuard Config (in ConfigMap):
```yaml
Address = 10.8.0.2/24                    # Your VPN IP
PrivateKey = <your_private_key>          # Your client key
PublicKey = <server_public_key>          # Server's public key  
Endpoint = vpn.server.com:51820          # Server endpoint
AllowedIPs = 10.8.0.0/24                 # Networks via VPN
```

### 2. PostgreSQL Config (in ConfigMap):
```yaml
server 10.8.0.5:5432;  # PostgreSQL IP accessible via VPN
```

### 3. DB Connection String (in Secret):
```yaml
postgres-connection-string: "postgresql://user:pass@10.8.0.5:5432/db"
```

### 4. Docker Image (in Deployment):
```yaml
image: ghcr.io/yourname/db-vpn:latest
```

## That's It!

✅ No persistent volumes
✅ No hostNetwork (won't break cluster networking)
✅ Uses pod network (ClusterFirst DNS)
✅ WireGuard runs as client only
✅ All config in one file

## Deploy:
```bash
# Edit deployment.yaml with your values
vim deployment.yaml

# Deploy
./deploy.sh

# Verify
kubectl get pods -n db-vpn
kubectl logs -n db-vpn -l app=db-vpn -f
```

## Use from Other Pods:
```bash
psql -h db-vpn-service.db-vpn.svc.cluster.local -p 5432
```

## Networking:
- ✅ Uses standard Kubernetes pod networking
- ✅ WireGuard client creates VPN interface inside pod only
- ✅ Doesn't touch cluster CNI or pod-to-pod networking
- ✅ Only routes traffic specified in AllowedIPs through VPN
- ✅ All other traffic uses normal cluster networking

