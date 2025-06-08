#!/bin/bash
# validate-deployment.sh - Validate Entra Management Console deployment

set -e

# Configuration
RESOURCE_GROUP="lab-uks-entra-rg"
WEB_APP_NAME="lab-uks-entra-webapp"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

success() {
    echo -e "${GREEN}✅ $1${NC}"
}

error() {
    echo -e "${RED}❌ $1${NC}"
}

warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

echo "🎯 Entra Management Console - Deployment Validation"
echo "===================================================="

# Check Azure CLI login
if ! az account show &> /dev/null; then
    error "Not logged into Azure CLI. Please run 'az login' first."
    exit 1
fi
success "Azure CLI authenticated"

# Check Web App
if az webapp show --resource-group "$RESOURCE_GROUP" --name "$WEB_APP_NAME" &> /dev/null; then
    success "Web App: $WEB_APP_NAME exists"
    
    # Get web app details
    WEB_APP_STATE=$(az webapp show --resource-group "$RESOURCE_GROUP" --name "$WEB_APP_NAME" --query "state" -o tsv)
    WEB_APP_URL=$(az webapp show --resource-group "$RESOURCE_GROUP" --name "$WEB_APP_NAME" --query "defaultHostName" -o tsv)
    
    if [[ "$WEB_APP_STATE" == "Running" ]]; then
        success "Web App Status: Running"
        info "Web App URL: https://$WEB_APP_URL"
        
        # Test health endpoint
        echo "Testing health endpoint..."
        if curl -f -s "https://$WEB_APP_URL/health" > /dev/null; then
            success "Health endpoint: Responding"
        else
            error "Health endpoint: Not responding"
        fi
        
        # Test main page
        echo "Testing main application..."
        RESPONSE_CODE=$(curl -s -o /dev/null -w "%{http_code}" "https://$WEB_APP_URL")
        if [[ "$RESPONSE_CODE" == "200" ]]; then
            success "Main application: Responding (HTTP $RESPONSE_CODE)"
        else
            warning "Main application: HTTP $RESPONSE_CODE"
        fi
        
    else
        warning "Web App Status: $WEB_APP_STATE"
    fi
else
    error "Web App: $WEB_APP_NAME not found"
fi

echo ""
success "🎉 Validation completed!"
info "🌐 Application URL: https://$WEB_APP_URL"
