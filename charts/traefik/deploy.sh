#! /bin/bash

helm upgrade --install traefik traefik/traefik \
  --namespace traefik --create-namespace \
  --values ./values.yaml \
  --wait --timeout 5m0s