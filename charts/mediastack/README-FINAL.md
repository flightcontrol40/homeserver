# MediaStack Kubernetes Helm Chart

A complete Helm chart for deploying a media automation stack to Kubernetes with VPN support.

## Features

### Media Servers
- **Jellyfin** - Open-source media server
- **Plex** - Media server platform

### Media Management (*ARR Suite)
- **Radarr** - Movie library manager
- **Sonarr** - TV series library manager  
- **Lidarr** - Music library manager
- **Readarr** - eBook/Audiobook library manager
- **Whisparr** - Adult media library manager
- **Prowlarr** - Indexer manager
- **Bazarr** - Subtitle manager

### Download Clients
- **qBittorrent** - Feature-rich torrent client with VPN support
- **Transmission** - Lightweight torrent client with VPN support
- **SABnzbd** - Usenet client

### Supporting Services
- **PostgreSQL** - Database for Guacamole
- **Guacamole/Guacd** - Clientless remote desktop gateway
- **Flaresolverr** - Cloudflare bypass proxy
- **Tdarr** - Media transcoding automation
- **Unpackerr** - Archive extraction for downloads
- **Crowdsec** - Cyber security threat intelligence

### Request Management
- **Jellyseerr** - Media request manager for Jellyfin
- **Overseerr** - Media request manager for Plex

### Dashboards
- **Heimdall** - Application dashboard
- **Homarr** - Modern application dashboard

### Utilities
- **Huntarr** - Missing content finder for *ARR apps

## Prerequisites

- Kubernetes cluster (1.19+)
- `kubectl` and `helm` installed
- Traefik ingress controller (or modify ingress configuration)
- Storage provisioner (local-path-provisioner recommended)

## Quick Start

### 1. Install Local-Path-Provisioner

For dynamic storage provisioning:

```bash
kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/v0.0.24/deploy/local-path-storage.yaml
```

Verify installation:
```bash
kubectl get storageclass
# Should show: local-path (default)
```

### 2. Configure values.yaml

Edit `values.yaml` to configure:

```yaml
# Domain for ingress
global:
  domain: example.com

# Storage configuration
storage:
  config:
    storageClass: "local-path"
    size: "5Gi"              # Per-service config size
  media:
    storageClass: "local-path"
    size: "1.5Ti"            # Total media library size
  downloads:
    storageClass: "local-path"
    size: "200Gi"            # Total downloads size

# Enable/disable services
jellyfin:
  enabled: true
plex:
  enabled: false
transmission:
  enabled: true
qbittorrent:
  enabled: false
```

### 3. Deploy

```bash
cd charts/mediastack-k8s
helm upgrade --install mediastack . -n mediastack --create-namespace
```

Or use the helper script:
```bash
./deploy.sh install
```

### 4. Check Status

```bash
kubectl get pods -n mediastack
kubectl get pvc -n mediastack
kubectl get ingress -n mediastack
```

## Storage Architecture

The chart uses three types of storage with local-path-provisioner:

### 1. Per-Service Config Storage
Each service gets its own PVC for configuration data:
- `radarr-config-pvc` → `/config` in radarr pod
- `sonarr-config-pvc` → `/config` in sonarr pod
- `transmission-config-pvc` → `/config` in transmission pod
- etc.

**Benefits:**
- Isolated configuration per service
- Config survives pod deletion
- Easy per-service backup/restore

### 2. Shared Media Storage (`media-pvc`)
Single PVC mounted by all services that need media access:
- Plex, Jellyfin (read-only)
- Radarr, Sonarr, Lidarr (read-write)
- Tdarr, Unpackerr

### 3. Shared Downloads Storage (`downloads-pvc`)
Single PVC for downloads, mounted by:
- Transmission, qBittorrent, SABnzbd
- Radarr, Sonarr, Lidarr
- Unpackerr

### Storage on Host

With local-path-provisioner, volumes are created in `/opt/local-path-provisioner/` by default:

```bash
# List all PVCs and their volumes
kubectl get pvc -n mediastack

# Find data on host
ls -la /opt/local-path-provisioner/

# Find specific PVC path
PV=$(kubectl get pvc media-pvc -n mediastack -o jsonpath='{.spec.volumeName}')
echo "/opt/local-path-provisioner/$PV"
```

## Configuration

### Enable/Disable Services

Control which services are deployed:

```yaml
jellyfin:
  enabled: true
  
plex:
  enabled: false  # Disable if using Jellyfin
  
transmission:
  enabled: true
  
qbittorrent:
  enabled: false  # Only enable one torrent client
```

### Configure Ingress

Each service can have external access via Traefik:

```yaml
radarr:
  ingress:
    enabled: true
    host: radarr.example.com
    middlewares:
      - security-headers@file
```

Access services at:
- `https://radarr.example.com`
- `https://sonarr.example.com`
- `https://jellyfin.example.com`
- etc.

### Set Resource Limits

Configure CPU and memory for each service:

```yaml
radarr:
  resources:
    requests:
      memory: "256Mi"
      cpu: "100m"
    limits:
      memory: "1Gi"
      cpu: "1000m"
```

## VPN Configuration

### Quick VPN Setup (Mullvad)

Both Transmission and qBittorrent support VPN via Gluetun sidecar:

```yaml
transmission:
  enabled: true
  vpn:
    enabled: true
    provider: "mullvad"
    wireguard:
      privateKey: "YOUR_PRIVATE_KEY"
      addresses: "10.x.x.x/32"
      endpoint:
        ip: "185.65.134.66"
        port: "51820"
```

**How it works:**
- Gluetun VPN container runs alongside torrent client in same pod
- All torrent traffic routes through VPN tunnel
- Built-in kill switch: if VPN disconnects, torrent traffic stops
- Other services connect directly without VPN

**📖 See [VPN-SETUP.md](VPN-SETUP.md) for complete configuration guide.**

## Torrent Client Setup

### Transmission

Lightweight and simple torrent client:

```yaml
transmission:
  enabled: true
  rpcPassword:
    enabled: true
    value: "your-password"
  
  # VPN support
  vpn:
    enabled: true
    provider: "mullvad"
    # ... (see VPN-SETUP.md)
  
  # Configure settings
  settings:
    downloadDir: "/data/downloads/torrents/complete"
    incompleteDir: "/data/downloads/torrents/incomplete"
    watchDir: "/data/downloads/torrents/watch"
    speedLimitDownEnabled: false
    speedLimitUpEnabled: false
    ratioLimit: 2
```

### qBittorrent

Feature-rich alternative:

```yaml
qbittorrent:
  enabled: true
  
  # Web UI password (default user: admin)
  webui:
    password: "your-password"
  
  # VPN support  
  vpn:
    enabled: true
    provider: "mullvad"
    # ... (see VPN-SETUP.md)
```

### Configure *ARR Apps

Point your download client to the service:
- **Host:** `transmission` or `qbittorrent` (service name)
- **Port:** `9091` (Transmission) or `8080` (qBittorrent)
- **Category:** Set download categories for proper folder organization

## Storage Management

### View Storage

```bash
# List all PVCs
kubectl get pvc -n mediastack

# List all PVs
kubectl get pv

# Show PVC details
kubectl describe pvc radarr-config-pvc -n mediastack

# Check disk usage on host
df -h /opt/local-path-provisioner
```

### Resize PVC

```bash
# Edit PVC
kubectl edit pvc radarr-config-pvc -n mediastack

# Change spec.resources.requests.storage to new size
# Example: 5Gi → 10Gi
```

### Backup PVC Data

```bash
# Find PV path
PV=$(kubectl get pvc media-pvc -n mediastack -o jsonpath='{.spec.volumeName}')

# Backup
sudo tar czf media-backup.tar.gz /opt/local-path-provisioner/$PV/
```

### Restore PVC Data

```bash
# Find PV path
PV=$(kubectl get pvc media-pvc -n mediastack -o jsonpath='{.spec.volumeName}')

# Restore
sudo tar xzf media-backup.tar.gz -C /opt/local-path-provisioner/$PV/
```

## Troubleshooting

### Check Pod Status
```bash
kubectl get pods -n mediastack

# View logs
kubectl logs -n mediastack deployment/radarr -f

# Restart a service
kubectl rollout restart deployment/sonarr -n mediastack
```

### PVC Stuck in Pending
```bash
kubectl describe pvc <pvc-name> -n mediastack

# Check provisioner
kubectl get pods -n local-path-storage
kubectl logs -n local-path-storage <provisioner-pod>
```

### Permission Issues
```bash
# Check/fix permissions on host
sudo chown -R 1000:1000 /opt/local-path-provisioner/pvc-xxxxx/
```

### Service Can't Access Storage
```bash
# Check mounts inside pod
kubectl exec -n mediastack deployment/radarr -- df -h
kubectl exec -n mediastack deployment/radarr -- ls -la /config

# Check pod events
kubectl describe pod -n mediastack <pod-name>
```

### VPN Issues

```bash
# Check VPN container is running
kubectl get pods -n mediastack | grep transmission

# View VPN logs
kubectl logs -n mediastack deployment/transmission -c gluetun -f

# Check VPN connection
kubectl exec -n mediastack deployment/transmission -c gluetun -- wget -qO- https://am.i.mullvad.net/connected
```

## Updating

### Update Images

```bash
# Edit values.yaml to change image tags
helm upgrade mediastack . -n mediastack
```

Or use the helper script:
```bash
./deploy.sh upgrade
```

### Update Single Service

```bash
kubectl rollout restart deployment/radarr -n mediastack
```

## Uninstall

```bash
helm uninstall mediastack -n mediastack

# Delete PVCs (WARNING: This deletes all data!)
kubectl delete pvc -n mediastack --all
```

## Helper Scripts

### deploy.sh

Convenient deployment commands:

```bash
./deploy.sh install    # Install chart
./deploy.sh upgrade    # Upgrade existing installation
./deploy.sh uninstall  # Remove chart
./deploy.sh logs <service>    # View logs
./deploy.sh restart <service> # Restart service
```

### validate.sh

Pre-flight validation:

```bash
./validate.sh  # Check prerequisites and configuration
```

## Tips & Best Practices

1. **Start Small** - Enable only services you need, add more later
2. **Backup Regularly** - Especially config PVCs before upgrades
3. **Monitor Resources** - Adjust resource limits based on usage
4. **Use VPN** - Essential for torrent downloads
5. **Set Download Categories** - Organize downloads by media type
6. **Configure Hardlinks** - Use same filesystem for moves vs copies
7. **Security** - Use strong passwords and keep services updated

## Support & Resources

- **Quick Reference**: See [QUICKSTART.md](QUICKSTART.md) for common commands
- **VPN Setup**: See [VPN-SETUP.md](VPN-SETUP.md) for detailed VPN configuration
- **Issues**: Report bugs via GitHub issues
- **Community**: r/MediaStack on Reddit

## License

This chart is provided as-is for personal use.
