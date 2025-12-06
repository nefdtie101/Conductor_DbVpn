# Conductor_Db_vpn - WireGuard Client + TCP Proxy

Securely expose a PostgreSQL database (or any TCP service) inside your Kubernetes cluster to other clients on your WireGuard VPN. This pod runs as a **WireGuard client** that connects to an external WireGuard server. Any client on the VPN can connect to the pod's VPN IP and reach the database via a TCP proxy (using socat).

## Features

- **WireGuard VPN Client**: Connects to external WireGuard server (not hosted in cluster)
- **TCP Proxy (socat)**: Exposes PostgreSQL (or any TCP service) to VPN clients
- **Kubernetes Native**: Works seamlessly with Kubernetes networking
- **Single Configuration File**: Everything configured in `deployment.yaml`
- **Easy Deployment**: Simple one-file deployment

## Architecture

This solution runs a WireGuard client inside a Kubernetes pod, connecting to an external WireGuard VPN server. Socat proxies PostgreSQL traffic from the cluster to any client on the VPN.

```
┌─────────────────────────────────────────────────────────────┐
│  External Network (Outside Kubernetes)                      │
│                                                             │
│  ┌──────────────────┐         ┌──────────────────┐          │
│  │  WireGuard       │         │  WireGuard       │          │
│  │  Server          │◄───────►│  Client          │          │
│  │  (VPN Gateway)   │         │  (e.g., laptop)  │          │
│  └────────┬─────────┘         └────────┬─────────┘          │
│           │ VPN Tunnel (WireGuard)              │           │
└───────────┼──────────────────────────────────────┘           │
            │                                                  │
┌───────────┼──────────────────────────────────────────────────┐
│  Kubernetes Cluster                                         │
│           │                                                │
│  ┌────────▼────────────────────────────────────────────┐    │
│  │  db-vpn Pod (Namespace: db-vpn)                     │    │
│  │  WireGuard Client (VPN IP)                          │    │
│  │  TCP Proxy (socat, :5432)                           │    │
│  └─────────┬───────────────────────────────────────────┘    │
│            │                                                │
│  ┌─────────▼───────────────────────────────────────────┐    │
│  │  PostgreSQL Database (internal cluster)             │    │
│  └─────────────────────────────────────────────────────┘    │
└────────────────────────────────────────────────────────────┘
```

**Flow:**
- External WireGuard client connects to VPN server.
- External client can reach db-vpn pod at VPN IP (e.g., 10.8.0.2:5432).
- Socat in pod forwards traffic to internal PostgreSQL DB.

## Prerequisites

- Kubernetes cluster with access
- `kubectl` configured and authenticated
- External WireGuard server already set up with:
  - Server public key
  - Server endpoint (IP:port)
  - Client VPN address assigned to this pod
- Container registry access (Docker Hub, etc.)

## Quick Start

### 1. Generate WireGuard Client Keys

```bash
wg genkey > client_private.key
wg pubkey < client_private.key > client_public.key
# Send client_public.key to your WireGuard server administrator
# They will assign you a VPN IP address and configure their server
```

### 2. Use the Published Container Image

```yaml
image: nefdie101/Conductor_DbVpn:latest
```

### 3. Configure deployment.yaml

Open `deployment.yaml` and replace the following placeholders:

- `YOUR_CLIENT_PRIVATE_KEY_HERE` → your WireGuard client private key
- `YOUR_CLIENT_VPN_ADDRESS` → VPN IP assigned by your server admin (e.g., 10.8.0.2/24)
- `YOUR_WIREGUARD_SERVER_PUBLIC_KEY_HERE` → server's public key
- `YOUR_WIREGUARD_SERVER_IP:51820` → server's external endpoint
- `YOUR_ALLOWED_IPS` → **only the networks you need to access via VPN (e.g., 192.168.10.0/24, 192.168.4.0/24)**
- `YOUR_POSTGRES_VPN_HOST:YOUR_POSTGRES_PORT` → internal DB DNS/hostname and port (e.g., postgres.default.svc.cluster.local:5432)

> **Important:**
> 
> In your WireGuard config (`wg0.conf`), set:
> 
> ```ini
> AllowedIPs = <your WireGuard network(s)>
> ```
> 
> For example, if you only need access to specific private subnets, use:
> 
> ```ini
> AllowedIPs = 192.168.10.0/24, 192.168.4.0/24
> ```
> 
> **Do NOT use `AllowedIPs = 0.0.0.0/0` or include the Kubernetes service subnet (e.g., 10.96.0.0/12).**
> Only include the subnets you need to reach via the VPN. This ensures Kubernetes DNS (service discovery) will work and prevents routing issues.

### 4. Deploy to Kubernetes

```bash
chmod +x deploy.sh
./deploy.sh
```

### 5. Verify Connection

```bash
kubectl get pods -n db-vpn
kubectl logs -n db-vpn -l app=db-vpn -f
kubectl exec -n db-vpn -l app=db-vpn -- wg show
```

## Connecting from VPN Clients

Once deployed, any client on the VPN can connect to the pod's VPN IP on port 5432:

```bash
psql -h <pod's VPN IP> -p 5432 -U your_user -d your_database
```

- The pod's VPN IP is the address assigned in the WireGuard config (e.g., 10.8.0.2).
- Socat will forward traffic to the internal database DNS/hostname and port.

## Configuration Files

- **deployment.yaml** - Complete Kubernetes deployment (CONFIGURE THIS)
- **Dockerfile** - Container image definition
- **start.sh** - Container startup script
- **wg0.conf** - WireGuard config template (for reference)
- **deploy.sh** - Deployment helper script

## Customization

- Change the internal DB DNS/hostname and port in the deployment config.
- Use NodePort or LoadBalancer service if you want to expose 5432 outside the cluster (for VPN clients).
- Add more `[Peer]` entries in your WireGuard server config for additional VPN clients.

## Troubleshooting

- Check pod status: `kubectl get pods -n db-vpn`
- View logs: `kubectl logs -n db-vpn -l app=db-vpn -f`
- Check WireGuard status: `kubectl exec -n db-vpn -l app=db-vpn -- wg show`
- Test health endpoint: `kubectl port-forward -n db-vpn svc/db-vpn-service 8080:8080 && curl http://localhost:8080/health`

## Security Considerations

- ✅ Keep private keys secure - never commit to version control
- ✅ Use strong, unique keys for each client
- ✅ Regularly rotate WireGuard keys
- ✅ Limit `AllowedIPs` to specific client addresses/subnets
- ✅ Use Kubernetes secrets for sensitive data
- ✅ Enable network policies to restrict pod communication
- ✅ Enable audit logging in Kubernetes
- ✅ Regularly update container images
