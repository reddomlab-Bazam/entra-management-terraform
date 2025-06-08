#!/bin/bash

# =============================================================================
# KEY VAULT CLEANUP SCRIPT
# =============================================================================
# This script helps clean up soft-deleted Key Vault secrets that may be 
# blocking the Terraform deployment

set -e

echo "🔑 Key Vault Cleanup Script"
echo "=========================="
echo ""

# Key Vault name
KEY_VAULT_NAME="lab-uks-entra-kv"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Checking for soft-deleted secrets in Key Vault: $KEY_VAULT_NAME${NC}"
echo ""

# Function to purge a secret
purge_secret() {
    local secret_name=$1
    echo -e "${YELLOW}Attempting to purge secret: $secret_name${NC}"
    
    if az keyvault secret purge --vault-name "$KEY_VAULT_NAME" --name "$secret_name" 2>/dev/null; then
        echo -e "${GREEN}✅ Successfully purged secret: $secret_name${NC}"
    else
        echo -e "${RED}❌ Failed to purge secret: $secret_name${NC}"
        echo "   This might be normal if the secret doesn't exist or is already purged."
    fi
    echo ""
}

# Function to recover a secret
recover_secret() {
    local secret_name=$1
    echo -e "${YELLOW}Attempting to recover secret: $secret_name${NC}"
    
    if az keyvault secret recover --vault-name "$KEY_VAULT_NAME" --name "$secret_name" 2>/dev/null; then
        echo -e "${GREEN}✅ Successfully recovered secret: $secret_name${NC}"
    else
        echo -e "${RED}❌ Failed to recover secret: $secret_name${NC}"
        echo "   This might be normal if the secret doesn't exist or is not deleted."
    fi
    echo ""
}

# Check if Azure CLI is installed and user is logged in
if ! command -v az &> /dev/null; then
    echo -e "${RED}❌ Azure CLI is not installed. Please install it first.${NC}"
    exit 1
fi

if ! az account show &> /dev/null; then
    echo -e "${RED}❌ Not logged into Azure CLI. Please run 'az login' first.${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Azure CLI is available and you are logged in.${NC}"
echo ""

# List soft-deleted secrets
echo -e "${YELLOW}Listing soft-deleted secrets...${NC}"
if az keyvault secret list-deleted --vault-name "$KEY_VAULT_NAME" --query "[].name" -o tsv 2>/dev/null; then
    echo ""
else
    echo -e "${GREEN}No soft-deleted secrets found or access denied.${NC}"
    echo ""
fi

# Purge specific secrets that were causing issues
echo -e "${YELLOW}Purging specific secrets that were causing deployment issues...${NC}"
echo ""

purge_secret "AutomationClientSecret"
purge_secret "StorageAccountKey"
purge_secret "storage-account-key"
purge_secret "webapp-client-secret"

echo -e "${GREEN}🎉 Cleanup completed!${NC}"
echo ""
echo "Next steps:"
echo "1. Run 'terraform plan' again to see if the issues are resolved"
echo "2. Run 'terraform apply' to complete the deployment"
echo ""
echo "Note: If you still get permission errors, you may need to:"
echo "- Ask your Azure admin to grant 'Key Vault Crypto Service Encryption User' role"
echo "- Or disable purge protection in the Key Vault configuration" 