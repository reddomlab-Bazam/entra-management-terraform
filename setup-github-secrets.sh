#!/bin/bash
# setup-github-secrets.sh - Configure GitHub repository secrets

set -e

echo "🔐 Setting up GitHub repository secrets for Azure deployment"
echo "============================================================="

# Check if GitHub CLI is installed
if ! command -v gh &> /dev/null; then
    echo "❌ GitHub CLI (gh) is not installed. Please install it first:"
    echo "   brew install gh"
    exit 1
fi

# Check if user is logged into GitHub CLI
if ! gh auth status &> /dev/null; then
    echo "❌ Please login to GitHub CLI first:"
    echo "   gh auth login"
    exit 1
fi

# Get current repository
REPO=$(gh repo view --json nameWithOwner --jq .nameWithOwner)
echo "📁 Setting secrets for repository: $REPO"

# Get Azure subscription info
echo "🔍 Getting Azure subscription information..."
SUBSCRIPTION_ID=$(az account show --query id -o tsv)
TENANT_ID=$(az account show --query tenantId -o tsv)

if [[ -z "$SUBSCRIPTION_ID" || -z "$TENANT_ID" ]]; then
    echo "❌ Could not get Azure subscription info. Please run 'az login' first."
    exit 1
fi

echo "✅ Found Azure subscription: $SUBSCRIPTION_ID"

# Create or get service principal
echo "�� Creating Azure service principal..."
SP_NAME="gh-actions-entra-management"

# Create new service principal
echo "🆕 Creating new service principal..."
SP_OUTPUT=$(az ad sp create-for-rbac \
    --name "$SP_NAME" \
    --role "Contributor" \
    --scopes "/subscriptions/$SUBSCRIPTION_ID" \
    --only-show-errors)

CLIENT_ID=$(echo "$SP_OUTPUT" | jq -r '.appId')
CLIENT_SECRET=$(echo "$SP_OUTPUT" | jq -r '.password')

echo "✅ Service principal configured: $CLIENT_ID"

# Create Azure credentials JSON for GitHub Actions
AZURE_CREDENTIALS=$(cat <<CREDENTIALS_EOF
{
  "clientId": "$CLIENT_ID",
  "clientSecret": "$CLIENT_SECRET",
  "subscriptionId": "$SUBSCRIPTION_ID",
  "tenantId": "$TENANT_ID"
}
CREDENTIALS_EOF
)

# Set GitHub repository secrets
echo "🔒 Setting GitHub repository secrets..."

gh secret set AZURE_CREDENTIALS --body "$AZURE_CREDENTIALS"
echo "✅ AZURE_CREDENTIALS secret set"

echo ""
echo "🎉 GitHub secrets setup completed!"
echo "🚀 You can now deploy via GitHub Actions"
