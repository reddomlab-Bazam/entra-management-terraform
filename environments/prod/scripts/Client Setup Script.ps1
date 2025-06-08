#!/bin/bash
# =============================================================================
# Entra Management Console - Client Setup Script
# =============================================================================

set -e

# Configuration
SP_NAME="terraform-cloud-entra-deployment"
REQUIRED_ROLES=("Owner")

echo "🎯 Entra Management Console - Terraform Cloud Setup"
echo "=================================================="

# Check if user is logged in to Azure CLI
if ! az account show &>/dev/null; then
    echo "❌ Please login to Azure CLI first:"
    echo "   az login"
    exit 1
fi

# Get current subscription info
SUBSCRIPTION_ID=$(az account show --query "id" -o tsv)
SUBSCRIPTION_NAME=$(az account show --query "name" -o tsv)
TENANT_ID=$(az account show --query "tenantId" -o tsv)

echo "✅ Current Azure Context:"
echo "   Subscription: $SUBSCRIPTION_NAME"
echo "   Subscription ID: $SUBSCRIPTION_ID"
echo "   Tenant ID: $TENANT_ID"
echo

# Confirm subscription
read -p "🤔 Is this the correct subscription for deployment? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "❌ Please switch to the correct subscription:"
    echo "   az account set --subscription 'Your-Subscription-Name'"
    exit 1
fi

echo "🔑 Creating service principal for Terraform Cloud..."

# Create service principal with Owner role
SP_OUTPUT=$(az ad sp create-for-rbac \
  --name "$SP_NAME" \
  --role "Owner" \
  --scopes "/subscriptions/$SUBSCRIPTION_ID" \
  --only-show-errors)

if [ $? -ne 0 ]; then
    echo "❌ Failed to create service principal"
    exit 1
fi

# Extract credentials
CLIENT_ID=$(echo "$SP_OUTPUT" | jq -r '.appId')
CLIENT_SECRET=$(echo "$SP_OUTPUT" | jq -r '.password')
TENANT_ID=$(echo "$SP_OUTPUT" | jq -r '.tenant')

echo "✅ Service principal created successfully!"
echo

# Grant Azure AD Graph permissions
echo "🔐 Granting Azure AD Graph API permissions..."

# Get service principal object ID
SP_OBJECT_ID=$(az ad sp show --id "$CLIENT_ID" --query "id" -o tsv)

# Get Microsoft Graph service principal ID
GRAPH_SP_ID=$(az ad sp show --id "00000003-0000-0000-c000-000000000000" --query "id" -o tsv)

# Grant Application.ReadWrite.All
echo "   Granting Application.ReadWrite.All..."
az rest --method POST \
  --uri "https://graph.microsoft.com/v1.0/servicePrincipals/$SP_OBJECT_ID/appRoleAssignments" \
  --body "{
    \"principalId\": \"$SP_OBJECT_ID\",
    \"resourceId\": \"$GRAPH_SP_ID\",
    \"appRoleId\": \"1bfefb4e-e0b5-418b-a88f-73c46d2cc8e9\"
  }" --only-show-errors > /dev/null

# Grant AppRoleAssignment.ReadWrite.All
echo "   Granting AppRoleAssignment.ReadWrite.All..."
az rest --method POST \
  --uri "https://graph.microsoft.com/v1.0/servicePrincipals/$SP_OBJECT_ID/appRoleAssignments" \
  --body "{
    \"principalId\": \"$SP_OBJECT_ID\",
    \"resourceId\": \"$GRAPH_SP_ID\",
    \"appRoleId\": \"06b708a9-e830-4db3-a914-8e69da51d44f\"
  }" --only-show-errors > /dev/null

# Grant Directory.Read.All
echo "   Granting Directory.Read.All..."
az rest --method POST \
  --uri "https://graph.microsoft.com/v1.0/servicePrincipals/$SP_OBJECT_ID/appRoleAssignments" \
  --body "{
    \"principalId\": \"$SP_OBJECT_ID\",
    \"resourceId\": \"$GRAPH_SP_ID\",
    \"appRoleId\": \"7ab1d382-f21e-4acd-a863-ba3e13f7da61\"
  }" --only-show-errors > /dev/null

echo "✅ Azure AD permissions granted successfully!"
echo

# Get public IP for client
echo "🌐 Detecting your public IP address..."
PUBLIC_IP=$(curl -s https://api.ipify.org 2>/dev/null || echo "Unable to detect")

echo "✅ Setup completed successfully!"
echo
echo "📋 Terraform Cloud Configuration"
echo "================================"
echo "Add these Environment Variables to your Terraform Cloud workspace:"
echo
echo "🔒 SENSITIVE Variables (mark as sensitive):"
echo "   ARM_CLIENT_ID = $CLIENT_ID"
echo "   ARM_CLIENT_SECRET = $CLIENT_SECRET"
echo
echo "📝 Regular Variables:"
echo "   ARM_SUBSCRIPTION_ID = $SUBSCRIPTION_ID"
echo "   ARM_TENANT_ID = $TENANT_ID"
echo "   TF_VAR_allowed_ip_address = $PUBLIC_IP"
echo
echo "📧 Update these variables as needed:"
echo "   TF_VAR_from_email = automation@yourdomain.com"
echo "   TF_VAR_to_email = admin@yourdomain.com"
echo
echo "🎯 Next Steps:"
echo "1. Copy the credentials above to your Terraform Cloud workspace"
echo "2. Update the email addresses and IP address as needed"
echo "3. Run 'terraform plan' to verify the configuration"
echo "4. Run 'terraform apply' to deploy the Entra Management Console"
echo
echo "🔗 Documentation: https://github.com/your-org/entra-management-terraform"