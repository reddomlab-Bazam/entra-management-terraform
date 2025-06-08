#!/bin/bash

# =============================================================================
# KEY VAULT FIREWALL FIX SCRIPT
# =============================================================================
# This script fixes Key Vault firewall issues preventing Terraform Cloud access

set -e

echo "🔥 Key Vault Firewall Fix Script"
echo "================================"
echo ""

# Key Vault name
KEY_VAULT_NAME="lab-uks-entra-kv"
TFC_IP="18.207.100.119"  # Terraform Cloud IP from error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Issue: Terraform Cloud IP $TFC_IP is blocked by Key Vault firewall${NC}"
echo ""

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

echo -e "${BLUE}Choose a solution:${NC}"
echo "1. Add Terraform Cloud IP to Key Vault firewall (Recommended)"
echo "2. Temporarily disable Key Vault firewall (Less secure)"
echo "3. Add common Terraform Cloud IP ranges"
echo "4. Show current Key Vault network settings"
echo ""

read -p "Enter your choice (1-4): " choice

case $choice in
    1)
        echo -e "${YELLOW}Adding Terraform Cloud IP $TFC_IP to Key Vault firewall...${NC}"
        if az keyvault network-rule add \
            --name "$KEY_VAULT_NAME" \
            --ip-address "$TFC_IP" \
            --output table; then
            echo -e "${GREEN}✅ Successfully added Terraform Cloud IP to firewall${NC}"
        else
            echo -e "${RED}❌ Failed to add IP. You may need Key Vault admin permissions.${NC}"
        fi
        ;;
    
    2)
        echo -e "${YELLOW}Temporarily disabling Key Vault firewall restrictions...${NC}"
        echo -e "${RED}⚠️  WARNING: This makes your Key Vault accessible from all networks!${NC}"
        read -p "Are you sure? (yes/no): " confirm
        if [[ $confirm == "yes" ]]; then
            if az keyvault update \
                --name "$KEY_VAULT_NAME" \
                --default-action Allow \
                --output table; then
                echo -e "${GREEN}✅ Key Vault firewall disabled${NC}"
                echo -e "${YELLOW}Remember to re-enable it after deployment!${NC}"
            else
                echo -e "${RED}❌ Failed to disable firewall${NC}"
            fi
        else
            echo "Operation cancelled."
        fi
        ;;
    
    3)
        echo -e "${YELLOW}Adding common Terraform Cloud IP ranges...${NC}"
        # Add multiple known TFC IP ranges
        TFC_IPS=(
            "18.207.100.119"    # Current error IP
            "52.86.200.106"     # Common TFC IP
            "3.91.118.151"      # Common TFC IP
            "52.86.201.227"     # Common TFC IP
        )
        
        for ip in "${TFC_IPS[@]}"; do
            echo -e "${YELLOW}Adding IP: $ip${NC}"
            az keyvault network-rule add \
                --name "$KEY_VAULT_NAME" \
                --ip-address "$ip" \
                --output none 2>/dev/null || echo "  (Already exists or failed)"
        done
        echo -e "${GREEN}✅ Terraform Cloud IP ranges added${NC}"
        ;;
    
    4)
        echo -e "${YELLOW}Current Key Vault network settings:${NC}"
        az keyvault show \
            --name "$KEY_VAULT_NAME" \
            --query "properties.networkAcls" \
            --output table
        ;;
    
    *)
        echo -e "${RED}Invalid choice. Exiting.${NC}"
        exit 1
        ;;
esac

echo ""
echo -e "${GREEN}🎉 Fix applied!${NC}"
echo ""
echo "Next steps:"
echo "1. Wait 2-3 minutes for changes to propagate"
echo "2. Trigger a new Terraform Cloud run"
echo "3. The deployment should complete successfully"
echo ""
echo "Alternative: Update Terraform configuration to skip firewall restrictions:"
echo "  - Set default_action = \"Allow\" in azurerm_key_vault resource"
echo "  - Or remove ip_rules completely"

# Show how to re-enable firewall later
if [[ $choice == "2" ]]; then
    echo ""
    echo -e "${YELLOW}To re-enable Key Vault firewall later:${NC}"
    echo "az keyvault update --name $KEY_VAULT_NAME --default-action Deny"
    echo "az keyvault network-rule add --name $KEY_VAULT_NAME --ip-address YOUR_IP"
fi 