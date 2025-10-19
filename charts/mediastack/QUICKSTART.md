# MediaStack K8s - Quick Reference

Essential commands and operations for daily use.

## Installation

```bash
cd /home/nathan/homesever/charts/mediastack-k8s
./deploy.sh install
```

## Status & Monitoring

### View All Resources
```bash
kubectl get pods,pvc,svc,ingress -n mediastack
```

### Check Pod Status
```bash
kubectl get pods -n mediastack
kubectl get pods -n mediastack -w  # Watch mode
```

### View Logs
```bash
# Follow logs
kubectl logs -n mediastack deployment/radarr -f

# Last 100 lines
kubectl logs -n mediastack deployment/sonarr --tail=100

# Using helper script
./deploy.sh logs radarr
```

### Check Storage
```bash
# List PVCs
kubectl get pvc -n mediastack

# Show PVC details
kubectl describe pvc media-pvc -n mediastack

# Check disk usage on host
df -h /opt/local-path-provisioner
```

## Service Management

### Restart Services
```bash
kubectl rollout restart deployment/sonarr -n mediastack
./deploy.sh restart sonarr
```

### Update Configuration
```bash
# Edit values.yaml
nano values.yaml

# Apply changes
./deploy.sh upgrade
# or
helm upgrade mediastack . -n mediastack
```

### Scale Service
```bash
kubectl scale deployment/radarr -n mediastack --replicas=0  # Stop
kubectl scale deployment/radarr -n mediastack --replicas=1  # Start
```

## VPN Commands

### Check VPN Status (Transmission)
```bash
# Check pod has 2/2 containers running
kubectl get pods -n mediastack | grep transmission

# View VPN logs
kubectl logs -n mediastack deployment/transmission -c gluetun -f

# Check if connected to Mullvad
kubectl exec -n mediastack deployment/transmission -c gluetun -- wget -qO- https://am.i.mullvad.net/connected

# Check IP address
kubectl exec -n mediastack deployment/transmission -c gluetun -- wget -qO- https://ipinfo.io/ip
```

### Check VPN Status (qBittorrent)
```bash
# Check pod has 2/2 containers running
kubectl get pods -n mediastack | grep qbittorrent

# View VPN logs
kubectl logs -n mediastack deployment/qbittorrent -c gluetun -f

# Check if connected
kubectl exec -n mediastack deployment/qbittorrent -c gluetun -- wget -qO- https://am.i.mullvad.net/connected
```

### Restart VPN
```bash
# Restart entire pod (includes VPN)
kubectl rollout restart deployment/transmission -n mediastack
```

## Storage Operations

### Find PVC on Host
```bash
# Get PV name for a PVC
kubectl get pvc media-pvc -n mediastack -o jsonpath='{.spec.volumeName}'

# Full path
PV=$(kubectl get pvc media-pvc -n mediastack -o jsonpath='{.spec.volumeName}')
echo "/opt/local-path-provisioner/$PV"

# List all PVC mappings
kubectl get pvc -n mediastack -o json | \
  jq -r '.items[] | "\(.metadata.name) → \(.spec.volumeName)"'
```

### Backup Data
```bash
# Backup single PVC
PV=$(kubectl get pvc radarr-config-pvc -n mediastack -o jsonpath='{.spec.volumeName}')
sudo tar czf radarr-config-backup.tar.gz /opt/local-path-provisioner/$PV/

# Backup media
PV=$(kubectl get pvc media-pvc -n mediastack -o jsonpath='{.spec.volumeName}')
sudo tar czf media-backup.tar.gz /opt/local-path-provisioner/$PV/
```

### Restore Data
```bash
# Find PV path
PV=$(kubectl get pvc radarr-config-pvc -n mediastack -o jsonpath='{.spec.volumeName}')

# Restore
sudo tar xzf radarr-config-backup.tar.gz -C /opt/local-path-provisioner/$PV/
```

## Troubleshooting

### Pod Won't Start
```bash
# Describe pod for events
kubectl describe pod -n mediastack <pod-name>

# Check logs
kubectl logs -n mediastack <pod-name>

# Check previous logs (if crashed)
kubectl logs -n mediastack <pod-name> --previous
```

### Storage Issues
```bash
# Check PVC status
kubectl get pvc -n mediastack

# Check provisioner logs
kubectl logs -n local-path-storage -l app=local-path-provisioner

# Fix permissions on host
sudo chown -R 1000:1000 /opt/local-path-provisioner/pvc-xxxxx/
```

### Service Not Accessible
```bash
# Check ingress
kubectl get ingress -n mediastack

# Check service
kubectl get svc -n mediastack

# Port forward for testing
kubectl port-forward -n mediastack deployment/radarr 7878:7878
# Then access: http://localhost:7878
```

### VPN Not Working
```bash
# Check if gluetun container is running
kubectl get pods -n mediastack | grep transmission

# View full pod logs
kubectl logs -n mediastack deployment/transmission --all-containers

# Check VPN container logs
kubectl logs -n mediastack deployment/transmission -c gluetun --tail=50

# Restart pod
kubectl rollout restart deployment/transmission -n mediastack
```

## Access Services

### Web UIs
After deployment, access via:
- Radarr: `https://radarr.example.com`
- Sonarr: `https://sonarr.example.com`
- Transmission: `https://transmission.example.com`
- Jellyfin: `https://jellyfin.example.com`
- Prowlarr: `https://prowlarr.example.com`

### Internal Access (from other pods)
- Radarr: `http://radarr:7878`
- Sonarr: `http://sonarr:8989`
- Transmission: `http://transmission:9091`
- qBittorrent: `http://qbittorrent:8080`

## Useful Aliases

Add to your `~/.bashrc`:

```bash
# Kubectl shortcuts
alias k='kubectl'
alias kgp='kubectl get pods -n mediastack'
alias kl='kubectl logs -n mediastack'
alias kd='kubectl describe -n mediastack'
alias ke='kubectl exec -n mediastack'

# MediaStack shortcuts
alias ms-logs='kubectl logs -n mediastack'
alias ms-restart='kubectl rollout restart -n mediastack deployment/'
alias ms-pods='kubectl get pods -n mediastack'
alias ms-pvc='kubectl get pvc -n mediastack'
```

## Common Tasks

### Add New Service
1. Edit `values.yaml` - Set `servicename.enabled: true`
2. Configure service-specific settings
3. Apply: `./deploy.sh upgrade`
4. Check: `kubectl get pods -n mediastack`

### Change Service Image/Version
1. Edit `values.yaml` - Update `servicename.image.tag`
2. Apply: `./deploy.sh upgrade`
3. Monitor: `kubectl get pods -n mediastack -w`

### Increase Storage Size
1. Edit PVC: `kubectl edit pvc media-pvc -n mediastack`
2. Change `spec.resources.requests.storage` to new size
3. The filesystem will expand automatically

### Update Download Client Settings
1. For Transmission: Edit `values.yaml` under `transmission.settings`
2. Apply: `./deploy.sh upgrade`
3. Pod will restart with new configuration

## Performance Monitoring

### Resource Usage
```bash
# CPU and memory usage by pod
kubectl top pods -n mediastack

# Node resource usage
kubectl top nodes
```

### Storage Usage
```bash
# Check PV disk usage on host
df -h /opt/local-path-provisioner

# Check usage inside pod
kubectl exec -n mediastack deployment/radarr -- df -h
```

## Maintenance

### Update All Services
```bash
# Pull latest images and restart
./deploy.sh upgrade
```

### Clean Up Completed Pods
```bash
kubectl delete pod -n mediastack --field-selector=status.phase==Succeeded
kubectl delete pod -n mediastack --field-selector=status.phase==Failed
```

### View Events
```bash
# Recent events in namespace
kubectl get events -n mediastack --sort-by='.lastTimestamp'
```

## Emergency Procedures

### Stop All Services
```bash
kubectl scale deployment --all -n mediastack --replicas=0
```

### Start All Services
```bash
kubectl scale deployment --all -n mediastack --replicas=1
```

### Complete Reinstall
```bash
# Uninstall
helm uninstall mediastack -n mediastack

# Delete PVCs (WARNING: Deletes all data!)
kubectl delete pvc -n mediastack --all

# Reinstall
./deploy.sh install
```

## Tips

- Use `kubectl get pods -n mediastack -w` to watch pod status in real-time
- Always backup config PVCs before major upgrades
- Check VPN connection regularly with the verification commands
- Use port-forwarding for direct access without ingress during troubleshooting
- Monitor disk space - `/opt/local-path-provisioner` can fill up quickly

## More Information

- Full documentation: [README.md](README.md)
- VPN setup guide: [VPN-SETUP.md](VPN-SETUP.md)
