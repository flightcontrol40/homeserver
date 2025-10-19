#!/bin/bash
#
# MediaStack Kubernetes Deployment Script
# This script helps deploy and manage the MediaStack helm chart
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NAMESPACE="mediastack"
RELEASE_NAME="mediastack"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Functions
log_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

log_success() {
    echo -e "${GREEN}✓${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

log_error() {
    echo -e "${RED}✗${NC} $1"
}

show_help() {
    cat << EOF
MediaStack Kubernetes Deployment Script

Usage: $0 [COMMAND] [OPTIONS]

Commands:
    install         Install the MediaStack helm chart
    upgrade         Upgrade the existing MediaStack deployment
    uninstall       Remove the MediaStack deployment
    status          Show deployment status
    logs [service]  Show logs for a service
    restart [svc]   Restart a specific service
    validate        Run pre-installation validation
    create-dirs     Create storage directories on the node
    
Options:
    -n, --namespace  Specify namespace (default: mediastack)
    -r, --release    Specify release name (default: mediastack)
    -h, --help       Show this help message

Examples:
    $0 install                  # Install MediaStack
    $0 upgrade                  # Upgrade to latest config
    $0 status                   # Show pod status
    $0 logs radarr             # Show Radarr logs
    $0 restart sonarr          # Restart Sonarr

EOF
}

validate_environment() {
    log_info "Validating environment..."
    
    if [ -f "$SCRIPT_DIR/validate.sh" ]; then
        bash "$SCRIPT_DIR/validate.sh"
    else
        log_warning "Validation script not found, skipping..."
    fi
}

create_storage_dirs() {
    log_info "Creating storage directories..."
    
    if [ ! -f "$SCRIPT_DIR/values.yaml" ]; then
        log_error "values.yaml not found!"
        exit 1
    fi
    
    # Extract paths from values.yaml or use defaults
    APPDATA_PATH=$(grep -A 5 "config:" "$SCRIPT_DIR/values.yaml" | grep "basePath:" | awk '{print $2}' | tr -d '"' | head -1)
    APPDATA_PATH=${APPDATA_PATH:-"/mediastack/appdata"}
    
    MEDIA_PATH=$(grep -A 5 "media:" "$SCRIPT_DIR/values.yaml" | grep "basePath:" | awk '{print $2}' | tr -d '"' | head -1)
    MEDIA_PATH=${MEDIA_PATH:-"/mediastack/media"}
    
    DOWNLOADS_PATH=$(grep -A 5 "downloads:" "$SCRIPT_DIR/values.yaml" | grep "basePath:" | awk '{print $2}' | tr -d '"' | head -1)
    DOWNLOADS_PATH=${DOWNLOADS_PATH:-"/mediastack/downloads"}
    
    echo ""
    echo "The following directories will be created:"
    echo "  Appdata: $APPDATA_PATH"
    echo "  Media: $MEDIA_PATH"
    echo "  Downloads: $DOWNLOADS_PATH"
    echo ""
    echo "This script will create subdirectories for media types."
    echo ""
    read -p "Continue? (y/N) " -n 1 -r
    echo
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Cancelled."
        exit 0
    fi
    
    log_info "Creating directories..."
    
    # Create base directories
    sudo mkdir -p "$APPDATA_PATH"
    sudo mkdir -p "$MEDIA_PATH"/{movies,tv,music,books,xxx}
    sudo mkdir -p "$DOWNLOADS_PATH"/{torrents,usenet}/{movies,tv,music,books,complete}
    sudo mkdir -p "$DOWNLOADS_PATH"/{sonarr,radarr}
    
    # Set permissions
    PUID=$(grep "puid:" "$SCRIPT_DIR/values.yaml" | head -1 | awk '{print $2}' | tr -d '"')
    PGID=$(grep "pgid:" "$SCRIPT_DIR/values.yaml" | head -1 | awk '{print $2}' | tr -d '"')
    
    log_info "Setting ownership to $PUID:$PGID..."
    sudo chown -R "$PUID:$PGID" "$APPDATA_PATH" "$MEDIA_PATH" "$DOWNLOADS_PATH"
    sudo chmod -R 755 "$APPDATA_PATH" "$MEDIA_PATH" "$DOWNLOADS_PATH"
    
    log_success "Storage directories created successfully!"
}

install_chart() {
    log_info "Installing MediaStack helm chart..."
    
    cd "$SCRIPT_DIR"
    
    # Validate first
    if [ -f "./validate.sh" ]; then
        log_info "Running validation..."
        bash ./validate.sh || {
            log_error "Validation failed. Please fix errors before installing."
            exit 1
        }
    fi
    
    # Check if namespace exists
    if ! kubectl get namespace "$NAMESPACE" &> /dev/null; then
        log_info "Creating namespace $NAMESPACE..."
        kubectl create namespace "$NAMESPACE"
    fi
    
    # Lint the chart
    log_info "Linting chart..."
    helm lint . || {
        log_error "Chart linting failed!"
        exit 1
    }
    
    # Install
    log_info "Installing chart..."
    helm install "$RELEASE_NAME" . \
        --namespace "$NAMESPACE" \
        --create-namespace \
        --timeout 10m
    
    log_success "MediaStack installed successfully!"
    echo ""
    log_info "Checking pod status..."
    kubectl get pods -n "$NAMESPACE"
    echo ""
    log_info "Access your services at: https://<service>.$(grep "domain:" values.yaml | head -1 | awk '{print $2}' | tr -d '"')"
}

upgrade_chart() {
    log_info "Upgrading MediaStack deployment..."
    
    cd "$SCRIPT_DIR"
    
    # Lint first
    log_info "Linting chart..."
    helm lint . || {
        log_error "Chart linting failed!"
        exit 1
    }
    
    # Upgrade
    log_info "Upgrading..."
    helm upgrade "$RELEASE_NAME" . \
        --namespace "$NAMESPACE" \
        --timeout 10m
    
    log_success "MediaStack upgraded successfully!"
    echo ""
    log_info "Checking pod status..."
    kubectl get pods -n "$NAMESPACE"
}

uninstall_chart() {
    log_warning "This will remove the MediaStack deployment."
    log_warning "PersistentVolumes and data will be retained."
    echo ""
    read -p "Are you sure? (y/N) " -n 1 -r
    echo
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Cancelled."
        exit 0
    fi
    
    log_info "Uninstalling MediaStack..."
    helm uninstall "$RELEASE_NAME" -n "$NAMESPACE"
    
    log_success "MediaStack uninstalled!"
    echo ""
    log_info "To also remove PersistentVolumes, run:"
    echo "  kubectl delete pv -l app.kubernetes.io/instance=$RELEASE_NAME"
}

show_status() {
    log_info "MediaStack Status"
    echo ""
    
    echo "Helm Release:"
    helm status "$RELEASE_NAME" -n "$NAMESPACE" 2>/dev/null || log_warning "Release not found"
    echo ""
    
    echo "Pods:"
    kubectl get pods -n "$NAMESPACE"
    echo ""
    
    echo "Services:"
    kubectl get svc -n "$NAMESPACE"
    echo ""
    
    echo "Ingresses:"
    kubectl get ingress -n "$NAMESPACE"
    echo ""
    
    echo "PersistentVolumes:"
    kubectl get pv -l app.kubernetes.io/instance="$RELEASE_NAME"
    echo ""
    
    echo "PersistentVolumeClaims:"
    kubectl get pvc -n "$NAMESPACE"
}

show_logs() {
    local service=$1
    
    if [ -z "$service" ]; then
        log_error "Please specify a service name"
        log_info "Available services:"
        kubectl get pods -n "$NAMESPACE" -o custom-columns=NAME:.metadata.name --no-headers
        exit 1
    fi
    
    log_info "Showing logs for $service..."
    kubectl logs -n "$NAMESPACE" "deployment/$service" -f
}

restart_service() {
    local service=$1
    
    if [ -z "$service" ]; then
        log_error "Please specify a service name"
        exit 1
    fi
    
    log_info "Restarting $service..."
    kubectl rollout restart "deployment/$service" -n "$NAMESPACE"
    
    log_success "$service restarted!"
    log_info "Waiting for rollout to complete..."
    kubectl rollout status "deployment/$service" -n "$NAMESPACE"
}

# Main script
case "${1:-}" in
    install)
        install_chart
        ;;
    upgrade)
        upgrade_chart
        ;;
    uninstall)
        uninstall_chart
        ;;
    status)
        show_status
        ;;
    logs)
        show_logs "$2"
        ;;
    restart)
        restart_service "$2"
        ;;
    validate)
        validate_environment
        ;;
    create-dirs)
        create_storage_dirs
        ;;
    -h|--help|help)
        show_help
        ;;
    *)
        show_help
        exit 1
        ;;
esac
