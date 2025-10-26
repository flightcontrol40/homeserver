# Traefik IngressClass Fix

## Problem
After making changes to the Traefik values in the baseline chart, pods were no longer accessible from a web browser. All requests returned 404 errors.

## Root Cause
The Traefik Helm chart creates an IngressClass with a name based on the release name (e.g., `baseline-traefik`), but all ingress resources in the mediastack namespace were configured to use an IngressClass named `traefik`. This mismatch caused Traefik to ignore all ingress rules.

## Solution
Created a custom IngressClass template in the baseline chart that creates an IngressClass named `traefik` pointing to the same Traefik controller. This allows ingress resources to use either `traefik` or `baseline-traefik` as their IngressClass.

## Changes Made

### 1. Created Template Files
- **`charts/baseline/templates/traefik-ingressclass.yaml`**: Creates the `traefik` IngressClass
- **`charts/baseline/templates/_helpers.tpl`**: Provides Helm template helper functions for labels

### 2. Updated values.yaml
- Set `traefik.ingressClass.enabled: false` to disable the default IngressClass creation
- Set `traefik.ingressClass.name: "traefik"` (though this is now unused since enabled=false)

## Verification
After applying these changes:
- The `traefik` IngressClass exists and is managed by Helm
- All ingress resources show the correct ADDRESS (192.168.70.125)
- Services are accessible from web browsers
- HTTP requests return proper responses (307 redirects instead of 404s)

## Testing
```bash
# Check IngressClass
kubectl get ingressclass

# Check Ingress resources
kubectl get ingress -A

# Test connectivity
curl -I http://192.168.70.125 -H "Host: homarr.supersussywebsite.com"
```

## Notes
- The custom IngressClass template is only created when `global.traefik.enabled: true`
- The IngressClass is set to NOT be the default class (`is-default-class: "false"`)
- The `baseline-traefik` IngressClass is no longer created since we disabled it in values.yaml


apiVersion: traefik.containo.us/v1alpha1
kind: IngressRoute
metadata:
  annotations:
    helm.sh/hook: post-install,post-upgrade
  creationTimestamp: "2025-10-19T15:58:50Z"
  generation: 1
  labels:
    app.kubernetes.io/instance: baseline
    app.kubernetes.io/managed-by: Helm
    app.kubernetes.io/name: traefik
    helm.sh/chart: traefik-10.3.6
  name: baseline-traefik-dashboard
  namespace: traefik
  resourceVersion: "220856"
  uid: 1d9adee1-3750-4a09-9f0e-67799ab1f9ee
spec:
  entryPoints:
  - traefik
  routes:
  - kind: Rule
    match: PathPrefix(`/dashboard`) || PathPrefix(`/api`)
    services:
    - kind: TraefikService
      name: api@internal
