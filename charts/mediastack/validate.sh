#!/bin/bash
#
# MediaStack Kubernetes Pre-Installation Validator
# This script checks your environment before deploying the helm chart
#

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

ERRORS=0
WARNINGS=0

echo "========================================="
echo "MediaStack K8s Pre-Installation Checker"
echo "========================================="
echo ""

# Check if kubectl is installed
echo -n "Checking for kubectl... "
if command -v kubectl &> /dev/null; then
    echo -e "${GREEN}✓${NC}"
else
    echo -e "${RED}✗${NC}"
    echo "  kubectl is not installed. Please install it first."
    ((ERRORS++))
fi

# Check if helm is installed
echo -n "Checking for helm... "
if command -v helm &> /dev/null; then
    HELM_VERSION=$(helm version --short)
    echo -e "${GREEN}✓${NC} ($HELM_VERSION)"
else
    echo -e "${RED}✗${NC}"
    echo "  Helm is not installed. Please install Helm 3.x"
    ((ERRORS++))
fi

# Check kubectl connectivity
echo -n "Checking kubectl connectivity... "
if kubectl cluster-info &> /dev/null; then
    echo -e "${GREEN}✓${NC}"
else
    echo -e "${RED}✗${NC}"
    echo "  Cannot connect to Kubernetes cluster"
    ((ERRORS++))
fi

# Check for Traefik
echo -n "Checking for Traefik ingress controller... "
if kubectl get ingressclass traefik &> /dev/null 2>&1; then
    echo -e "${GREEN}✓${NC}"
elif kubectl get deployment -A | grep -q traefik; then
    echo -e "${YELLOW}⚠${NC}"
    echo "  Traefik found but IngressClass may not be configured"
    ((WARNINGS++))
else
    echo -e "${RED}✗${NC}"
    echo "  Traefik ingress controller not found"
    echo "  MediaStack requires Traefik for ingress"
    ((ERRORS++))
fi

# Check namespace
echo -n "Checking if mediastack namespace exists... "
if kubectl get namespace mediastack &> /dev/null 2>&1; then
    echo -e "${GREEN}✓${NC}"
    echo "  Note: Existing namespace found. Helm will use it."
else
    echo -e "${YELLOW}⚠${NC}"
    echo "  Namespace will be created during installation"
fi

# Check nodes
echo ""
echo "Kubernetes Nodes:"
kubectl get nodes -o wide
echo ""

# Get node hostname for affinity
echo "Node hostname for values.yaml nodeAffinity:"
NODE_HOSTNAME=$(kubectl get nodes -o jsonpath='{.items[0].metadata.name}')
echo -e "  ${GREEN}$NODE_HOSTNAME${NC}"
echo ""

# Check values-example exists
echo -n "Checking values.yaml... "
if [ -f "values.yaml" ]; then
    echo -e "${GREEN}✓${NC}"
    
    # Check for default/example values that need changing
    echo ""
    echo "Checking values.yaml configuration:"
    
    if grep -q "domain: \"example.com\"" values.yaml; then
        echo -e "  ${RED}✗${NC} Domain is still set to 'example.com'"
        echo "    Please update global.domain in values.yaml"
        ((ERRORS++))
    else
        DOMAIN=$(grep "domain:" values.yaml | head -1 | awk '{print $2}' | tr -d '"')
        echo -e "  ${GREEN}✓${NC} Domain configured: $DOMAIN"
    fi
    
    if grep -q "hostname: \"example\"" values.yaml; then
        echo -e "  ${YELLOW}⚠${NC} Node affinity hostname is set to default 'example'"
        echo "    Please verify this matches your node: $NODE_HOSTNAME"
        ((WARNINGS++))
    fi
    
    if grep -q "changeme" values.yaml; then
        echo -e "  ${RED}✗${NC} Found 'changeme' passwords in values.yaml"
        echo "    Please update PostgreSQL passwords"
        ((ERRORS++))
    else
        echo -e "  ${GREEN}✓${NC} Passwords appear to be configured"
    fi
    
else
    echo -e "${RED}✗${NC}"
    echo "  values.yaml not found in current directory"
    ((ERRORS++))
fi

# Check storage paths (if local storage)
echo ""
echo "Storage Configuration Check:"
if [ -f "values.yaml" ]; then
    APPDATA_PATH=$(grep -A 5 "appdata:" values.yaml | grep "hostPath:" | awk '{print $2}' | tr -d '"')
    MEDIA_PATH=$(grep -A 5 "media:" values.yaml | grep "hostPath:" | awk '{print $2}' | tr -d '"' | head -1)
    
    if [ -n "$APPDATA_PATH" ]; then
        echo "  Application data path: $APPDATA_PATH"
        echo -e "    ${YELLOW}⚠${NC} Ensure this directory exists on the node with correct permissions"
        echo "    Run on node: sudo mkdir -p $APPDATA_PATH && sudo chown -R 1000:1000 $APPDATA_PATH"
    fi
    
    if [ -n "$MEDIA_PATH" ]; then
        echo "  Media path: $MEDIA_PATH"
        echo -e "    ${YELLOW}⚠${NC} Ensure this directory exists on the node with correct permissions"
    fi
fi

# Summary
echo ""
echo "========================================="
echo "Validation Summary"
echo "========================================="
if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
    echo -e "${GREEN}✓ All checks passed!${NC}"
    echo ""
    echo "You can proceed with installation:"
    echo "  helm install mediastack . -n mediastack --create-namespace"
    exit 0
elif [ $ERRORS -eq 0 ]; then
    echo -e "${YELLOW}Warnings: $WARNINGS${NC}"
    echo ""
    echo "You can proceed, but please review the warnings above."
    echo "  helm install mediastack . -n mediastack --create-namespace"
    exit 0
else
    echo -e "${RED}Errors: $ERRORS${NC}"
    echo -e "${YELLOW}Warnings: $WARNINGS${NC}"
    echo ""
    echo "Please fix the errors above before installing."
    exit 1
fi
