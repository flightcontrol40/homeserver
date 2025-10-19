# VPN Configuration Guide for qBittorrent

This guide will help you set up Mullvad VPN with qBittorrent in your MediaStack Kubernetes deployment.

## Why VPN for Torrents?

Routing torrent traffic through a VPN:
- ✅ Protects your privacy
- ✅ Hides your real IP address from peers
- ✅ Prevents ISP throttling
- ✅ Provides additional security

## Architecture

The VPN is implemented using a **sidecar pattern**:
- `gluetun` container runs alongside qBittorrent in the same pod
- All qBittorrent network traffic is routed through the VPN
- If VPN disconnects, torrent traffic stops (kill switch)
- Other services (Radarr, Sonarr, etc.) connect directly without VPN

## Step-by-Step Setup

### 1. Get Mullvad Account

1. Go to [https://mullvad.net](https://mullvad.net)
2. Sign up for an account (€5/month)
3. Note your account number

### 2. Generate WireGuard Configuration

1. Log into your Mullvad account: https://mullvad.net/en/account/
2. Navigate to "WireGuard configuration"
3. Click "Generate key" to create a new WireGuard key pair
4. **Important**: Keep this page open, you'll need these details

### 3. Choose a Server

1. Go to [Mullvad Servers](https://mullvad.net/en/servers/)
2. Select a server (recommended: closest to your location for speed)
3. Note the server details:
   - Server hostname (e.g., `se-sto-wg-001`)
   - Server IP address (e.g., `185.65.134.66`)
   - Public key

### 4. Configure values.yaml

Edit `/home/nathan/charts/mediastack-k8s/values.yaml`:

```yaml
qbittorrent:
  enabled: true
  
  vpn:
    enabled: true  # ENABLE VPN
    provider: "mullvad"
    
    # Optional: Specify preferred servers
    serverCountries: "Sweden"  # Or your choice
    serverCities: ""
    
    wireguard:
      # From Mullvad account WireGuard page:
      privateKey: "YOUR_PRIVATE_KEY_FROM_MULLVAD"
      
      # From selected Mullvad server:
      publicKey: "SERVER_PUBLIC_KEY"
      
      # From Mullvad account (your assigned IPs):
      addresses: "10.66.x.x/32,fc00:bbbb:bbbb:bb01::x:xxxx/128"
      
      # Usually empty for Mullvad:
      presharedKey: ""
      
      # Selected server endpoint:
      endpoint:
        ip: "185.65.134.66"  # Server IP
        port: "51820"        # Usually 51820
```

### 5. Deploy/Update

```bash
cd /home/nathan/charts/mediastack-k8s

# If first install:
./deploy.sh install

# If already installed:
./deploy.sh upgrade
```

### 6. Verify VPN Connection

```bash
# Check pod status
kubectl get pods -n mediastack | grep qbittorrent

# Should see 2/2 containers running:
# qbittorrent-xxxxxxxxx-xxxxx   2/2     Running   0          2m
#                                ^^^
#                          Both containers

# Check VPN connection
kubectl logs -n mediastack deployment/qbittorrent -c gluetun

# Should see:
# [INFO] VPN is running
# [INFO] Public IP address: <Mullvad IP>
```

### 7. Verify IP Address

Access qBittorrent and check the external IP:

```bash
# Option 1: Check from logs
kubectl logs -n mediastack deployment/qbittorrent -c gluetun | grep "Public IP"

# Option 2: Exec into pod and check
kubectl exec -n mediastack deployment/qbittorrent -c gluetun -- wget -qO- https://am.i.mullvad.net/connected

# Should show: "You are connected to Mullvad"
```

## Configuration Options

### Server Selection

**By Country:**
```yaml
serverCountries: "Sweden,Netherlands"
```

**By City:**
```yaml
serverCities: "Stockholm,Amsterdam"
```

**Leave empty for automatic selection:**
```yaml
serverCountries: ""
serverCities: ""
```

### Port Forwarding

Mullvad discontinued port forwarding. For better seeding ratios with port forwarding, consider:
- AirVPN
- ProtonVPN
- PIA (Private Internet Access)

To use a different provider, change:
```yaml
vpn:
  provider: "airvpn"  # or "protonvpn", "private internet access", etc.
```

## Troubleshooting

### Pod Stuck in Init

```bash
# Check init container logs
kubectl logs -n mediastack deployment/qbittorrent -c wait-for-vpn

# Check VPN logs
kubectl logs -n mediastack deployment/qbittorrent -c gluetun
```

**Common issues:**
- Incorrect WireGuard keys
- Invalid server IP/endpoint
- Firewall blocking VPN traffic

### VPN Not Connecting

```bash
# View detailed VPN logs
kubectl logs -n mediastack deployment/qbittorrent -c gluetun -f

# Check for errors:
# - "authentication failed" → Wrong keys
# - "timeout" → Network/firewall issue
# - "permission denied" → Check securityContext
```

**Fix:**
1. Verify all credentials in values.yaml
2. Check Mullvad account is active
3. Try a different server

### qBittorrent Can't Connect

```bash
# Check both containers are running
kubectl describe pod -n mediastack -l app.kubernetes.io/name=qbittorrent

# Ensure VPN container has NET_ADMIN capability
```

### No Internet in qBittorrent

```bash
# Exec into qBittorrent container
kubectl exec -it -n mediastack deployment/qbittorrent -c qbittorrent -- /bin/bash

# Test connectivity through VPN
curl https://am.i.mullvad.net/connected
```

### IP Leak Test

To verify ALL traffic goes through VPN:

```bash
# Get your real IP (from outside the cluster)
curl https://api.ipify.org

# Get qBittorrent's IP (should be different - Mullvad IP)
kubectl exec -n mediastack deployment/qbittorrent -c gluetun -- wget -qO- https://api.ipify.org
```

## Security Features

### Kill Switch

If VPN disconnects, qBittorrent loses internet access automatically. This is enforced by:
- Gluetun firewall rules
- Kubernetes network policies
- Pod restart on VPN failure

### DNS Leak Protection

Gluetun handles DNS through the VPN tunnel, preventing DNS leaks.

### Local Network Access

The `allowedSubnets` configuration allows:
- Radarr/Sonarr to connect to qBittorrent
- You to access the WebUI
- No external access without VPN

## Performance Considerations

### Resource Usage

VPN sidecar adds minimal overhead:
- Memory: ~128MB
- CPU: ~100m (0.1 core)

### Speed

VPN will reduce speeds slightly:
- Choose servers close to you
- Mullvad has excellent speeds
- 100+ Mbps typical on good connection

### Multiple Servers

Gluetun will automatically reconnect if a server fails. You can specify multiple countries for failover:

```yaml
serverCountries: "Sweden,Netherlands,Germany"
```

## Alternative Providers

### To use AirVPN:

```yaml
vpn:
  provider: "airvpn"
  # Use OpenVPN config from AirVPN
```

### To use ProtonVPN:

```yaml
vpn:
  provider: "protonvpn"
  wireguard:
    # Get credentials from ProtonVPN account
```

### To use PIA:

```yaml
vpn:
  provider: "private internet access"
  # Use PIA credentials
```

See [Gluetun Wiki](https://github.com/qdm12/gluetun-wiki) for all supported providers.

## Disable VPN

To disable VPN and use direct connection:

```yaml
qbittorrent:
  vpn:
    enabled: false
```

Then upgrade:
```bash
./deploy.sh upgrade
```

## Health Monitoring

Check VPN health:

```bash
# HTTP control server endpoint
kubectl port-forward -n mediastack deployment/qbittorrent 8000:8000

# In browser or curl:
curl http://localhost:8000/v1/openvpn/status
```

Returns JSON with VPN status, public IP, etc.

## Best Practices

1. **Rotate Keys Periodically**: Generate new WireGuard keys every few months
2. **Monitor Connection**: Set up alerts for VPN disconnection
3. **Test After Updates**: Verify VPN after upgrading
4. **Backup Config**: Keep VPN credentials in secure password manager
5. **Use Strong Passwords**: Change qBittorrent default password immediately

## Example: Complete Configuration

```yaml
qbittorrent:
  enabled: true
  image:
    repository: lscr.io/linuxserver/qbittorrent
    tag: "latest"
  
  service:
    port: 8080
    torrentPort: 6881
  
  vpn:
    enabled: true
    provider: "mullvad"
    serverCountries: "Sweden"
    
    wireguard:
      privateKey: "cPeQGfKNXwJHQmJHz8VsRJKHj9Q0NPTL+WZLGdIjQ3c="
      publicKey: "gPIPR/Qa0LDq0IxJ+P7p3h6RyVE/7YJDOlJ+lL7hU0c="
      addresses: "10.66.123.45/32,fc00:bbbb:bbbb:bb01::4:abcd/128"
      endpoint:
        ip: "185.65.134.66"
        port: "51820"
  
  resources:
    requests:
      memory: "512Mi"
      cpu: "200m"
    limits:
      memory: "2Gi"
      cpu: "1000m"
```

## Support

- Gluetun Issues: https://github.com/qdm12/gluetun/issues
- Mullvad Support: https://mullvad.net/en/help/
- MediaStack Reddit: https://www.reddit.com/r/MediaStack/

## Quick Reference Commands

```bash
# View VPN logs
kubectl logs -n mediastack deployment/qbittorrent -c gluetun -f

# Check VPN status
kubectl exec -n mediastack deployment/qbittorrent -c gluetun -- wget -qO- https://am.i.mullvad.net/connected

# Restart qBittorrent (restarts VPN too)
kubectl rollout restart deployment/qbittorrent -n mediastack

# Get public IP
kubectl exec -n mediastack deployment/qbittorrent -c gluetun -- wget -qO- https://api.ipify.org

# Shell into VPN container
kubectl exec -it -n mediastack deployment/qbittorrent -c gluetun -- /bin/sh
```
