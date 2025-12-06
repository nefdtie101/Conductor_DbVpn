# Deployment Configuration Quick Reference - CLIENT MODE

## What to Replace in deployment.yaml

### 1. WireGuard Client Private Key
```yaml
# Find this line:
PrivateKey = YOUR_CLIENT_PRIVATE_KEY_HERE

# Replace with (generate with: wg genkey):
PrivateKey = aBcDeFgHiJkLmNoPqRsTuVwXyZ1234567890ABCD=
```

### 2. Client VPN Address
```yaml
# Find this line:
Address = YOUR_CLIENT_VPN_ADDRESS

# Replace with IP assigned by VPN server admin:
Address = 10.8.0.2/24
```

### 3. WireGuard Server Public Key
```yaml
# Find this line:
PublicKey = YOUR_WIREGUARD_SERVER_PUBLIC_KEY_HERE

# Replace with your VPN server's public key:
PublicKey = XyZ123AbC456DeF789GhI012JkL345MnO678PqR901StU=
```

### 4. WireGuard Server Endpoint
```yaml
# Find this line:
Endpoint = YOUR_WIREGUARD_SERVER_IP:51820

# Replace with your VPN server's external address:
Endpoint = vpn.example.com:51820
# OR with IP:
Endpoint = 203.0.113.50:51820
```

### 5. Allowed IPs (Networks via VPN)
```yaml
# Find this line:
AllowedIPs = YOUR_ALLOWED_IPS

# Replace with networks accessible through VPN:
AllowedIPs = 10.8.0.0/24
# OR for all traffic through VPN:
AllowedIPs = 0.0.0.0/0
# OR specific subnets:
AllowedIPs = 10.8.0.0/24, 192.168.100.0/24
```

### 6. PostgreSQL Host via VPN
```yaml
# Find this line:
server YOUR_POSTGRES_VPN_HOST:YOUR_POSTGRES_PORT;

# Replace with PostgreSQL accessible through VPN:
server 10.8.0.5:5432;
# OR with hostname:
server db.internal.vpn:5432;
```

### 7. PostgreSQL Connection String
```yaml
# Find this line:
postgres-connection-string: "YOUR_POSTGRES_CONNECTION_STRING_HERE"

# Replace with actual connection string:
postgres-connection-string: "postgresql://myuser:mypassword@10.8.0.5:5432/mydb"
```

### 8. Docker Image
```yaml
# Find this line:
image: YOUR_DOCKER_IMAGE_HERE

# Replace with your actual image:
image: ghcr.io/yourusername/db-vpn:latest
# OR
image: your-registry.io/db-vpn:latest
```

## Complete Example

Here's what a complete WireGuard client config section should look like:

```yaml
wg0.conf: |
  [Interface]
  Address = 10.8.0.2/24
  PrivateKey = KHabC8iFV9FRaFkEPj+Hc7UQL3gL9l8Qp5sVGTqQrGk=
  
  [Peer]
  PublicKey = xTIBA5rboUvnH4htodjb6e697QjLERt1NAB4mZqp8Dg=
  Endpoint = vpn.company.com:51820
  AllowedIPs = 10.8.0.0/24
  PersistentKeepalive = 25
```

And the Nginx config pointing to PostgreSQL via VPN:

```yaml
upstream postgres {
  server 10.8.0.5:5432;
}
```

## Important Notes

### Client Mode vs Server Mode
- **This is CLIENT mode**: Pod connects TO external VPN server
- **Not server mode**: Pod does NOT accept incoming VPN connections
- **Service type**: ClusterIP (no LoadBalancer needed)
- **No exposed ports**: Only accessible from within cluster

### VPN Network Planning
1. **Client Address**: Your pod's VPN IP (e.g., 10.8.0.2/24)
2. **Server Address**: VPN server's internal IP (e.g., 10.8.0.1)
3. **PostgreSQL Address**: Database IP on VPN network (e.g., 10.8.0.5)
4. **AllowedIPs**: What networks are routed through VPN

### Testing Connection
```bash
# Check WireGuard is connected
kubectl exec -n db-vpn -l app=db-vpn -- wg show

# Test connectivity to PostgreSQL via VPN
kubectl exec -n db-vpn -l app=db-vpn -- nc -zv 10.8.0.5 5432

# Check logs
kubectl logs -n db-vpn -l app=db-vpn -f
```

### Troubleshooting

**Can't connect to VPN server:**
- Check Endpoint is correct (IP/hostname and port)
- Verify server public key is correct
- Ensure pod has internet access to reach VPN endpoint
- Check firewall allows UDP traffic to VPN server

**Can't reach PostgreSQL:**
- Verify PostgreSQL IP is correct and accessible via VPN
- Check AllowedIPs includes PostgreSQL network
- Test from within pod: `kubectl exec ... -- ping 10.8.0.5`

**From other pods:**
```bash
# Connect to PostgreSQL through the VPN proxy
psql -h db-vpn-service.db-vpn.svc.cluster.local -p 5432 -U user -d database
```

