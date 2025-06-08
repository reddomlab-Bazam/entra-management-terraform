# Terraform Cloud Setup Guide

## Overview
This guide explains how to set up the Entra Management Console with Terraform Cloud when you have existing Azure resources.

## Prerequisites
1. Terraform Cloud account
2. GitHub repository connected to Terraform Cloud
3. Azure subscription with existing resources
4. Azure CLI installed locally (for importing existing resources)

## Step 1: Terraform Cloud Workspace Setup

### 1.1 Create Workspace
1. Log into Terraform Cloud
2. Create a new workspace
3. Choose "Version control workflow"
4. Connect to your GitHub repository
5. Set the working directory to `environments/prod`

### 1.2 Configure Workspace Settings
- **Terraform Version**: 1.0.0 or later
- **Auto Apply**: Disabled (for safety)
- **Working Directory**: `environments/prod`

### 1.3 Set Environment Variables
In your Terraform Cloud workspace, set these environment variables:

#### Azure Authentication (Environment Variables - not Terraform variables)
```
ARM_CLIENT_ID = "your-service-principal-client-id"
ARM_CLIENT_SECRET = "your-service-principal-secret"
ARM_SUBSCRIPTION_ID = "102e9107-d789-4139-9220-6eb6ed33b472"
ARM_TENANT_ID = "your-tenant-id"
```

#### Optional Terraform Variables (if needed)
```
TF_VAR_web_app_client_secret = "your-web-app-client-secret"
TF_VAR_allowed_ip_address = "your-ip-address"
```

## Step 2: Import Existing Resources

Since you have existing resources, you need to import them into Terraform state. You have two options:

### Option A: Using Terraform Cloud CLI (Recommended)

1. Install Terraform CLI locally
2. Login to Terraform Cloud:
   ```bash
   terraform login
   ```

3. Navigate to your project:
   ```bash
   cd environments/prod
   ```

4. Initialize (this will connect to your TFC workspace):
   ```bash
   terraform init
   ```

5. Import existing resources:
   ```bash
   # Import Resource Group
   terraform import azurerm_resource_group.main /subscriptions/102e9107-d789-4139-9220-6eb6ed33b472/resourceGroups/lab-uks-entra-rg

   # Import Log Analytics Workspace
   terraform import azurerm_log_analytics_workspace.main /subscriptions/102e9107-d789-4139-9220-6eb6ed33b472/resourceGroups/lab-uks-entra-rg/providers/Microsoft.OperationalInsights/workspaces/lab-uks-entra-logs

   # Import Key Vault
   terraform import azurerm_key_vault.main /subscriptions/102e9107-d789-4139-9220-6eb6ed33b472/resourceGroups/lab-uks-entra-rg/providers/Microsoft.KeyVault/vaults/lab-uks-entra-kv

   # Import Storage Account into module
   terraform import module.storage.azurerm_storage_account.main /subscriptions/102e9107-d789-4139-9220-6eb6ed33b472/resourceGroups/lab-uks-entra-rg/providers/Microsoft.Storage/storageAccounts/labentraautomation

   # Import Storage Share
   terraform import module.storage.azurerm_storage_share.attribute_management https://labentraautomation.file.core.windows.net/entra-management

   # Import Storage Container
   terraform import module.storage.azurerm_storage_container.webfiles https://labentraautomation.blob.core.windows.net/webfiles

   # Import Storage Directories
   terraform import module.storage.azurerm_storage_share_directory.config https://labentraautomation.file.core.windows.net/entra-management/config
   terraform import module.storage.azurerm_storage_share_directory.logs https://labentraautomation.file.core.windows.net/entra-management/logs
   terraform import module.storage.azurerm_storage_share_directory.reports https://labentraautomation.file.core.windows.net/entra-management/reports
   terraform import module.storage.azurerm_storage_share_directory.backups https://labentraautomation.file.core.windows.net/entra-management/backups
   terraform import module.storage.azurerm_storage_share_directory.scripts https://labentraautomation.file.core.windows.net/entra-management/scripts
   terraform import module.storage.azurerm_storage_share_directory.templates https://labentraautomation.file.core.windows.net/entra-management/templates

   # Import App Service Plan into module
   terraform import module.webapp.azurerm_service_plan.main /subscriptions/102e9107-d789-4139-9220-6eb6ed33b472/resourceGroups/lab-uks-entra-rg/providers/Microsoft.Web/serverFarms/lab-uks-entra-webapp-plan

   # Import Web App into module
   terraform import module.webapp.azurerm_linux_web_app.main /subscriptions/102e9107-d789-4139-9220-6eb6ed33b472/resourceGroups/lab-uks-entra-rg/providers/Microsoft.Web/sites/lab-uks-entra-webapp

   # Import Application Insights into module
   terraform import module.webapp.azurerm_application_insights.main /subscriptions/102e9107-d789-4139-9220-6eb6ed33b472/resourceGroups/lab-uks-entra-rg/providers/Microsoft.Insights/components/lab-uks-entra-ai
   ```

### Option B: Using Import Blocks (Terraform 1.5+)

Add import blocks to your configuration and let Terraform handle the import during plan/apply.

## Step 3: Handle Azure AD Application

The Azure AD application will be created new. You may need to:
1. Update any external references to use the new application ID
2. Grant admin consent in Azure AD
3. Update redirect URIs if needed

## Step 4: Configure GitHub Integration

### 4.1 Update providers.tf
Update the cloud block with your organization name:
```hcl
terraform {
  cloud {
    organization = "your-org-name"
    workspaces {
      name = "entra-management-prod"
    }
  }
}
```

### 4.2 Commit Changes
```bash
git add .
git commit -m "Configure for Terraform Cloud"
git push origin main
```

## Step 5: Initial Run

1. In Terraform Cloud, trigger a plan
2. Review the plan carefully
3. Apply if everything looks correct

## Step 6: Cleanup Old Resources (Optional)

If you have old automation account resources that are no longer needed, you can remove them manually from Azure or import them to destroy them via Terraform.

## Troubleshooting

### Common Issues

1. **Authentication Errors**
   - Ensure Azure service principal has correct permissions
   - Verify environment variables are set correctly

2. **Import Errors**
   - Check resource IDs are correct
   - Ensure you have sufficient permissions

3. **State Conflicts**
   - Use `terraform state rm` to remove resources if needed
   - Contact support if you need to reset workspace state

### Getting Resource IDs

To find resource IDs for import:
```bash
# List resources in resource group
az resource list --resource-group lab-uks-entra-rg --query "[].{name:name, type:type, id:id}" -o table

# Get specific resource ID
az resource show --resource-group lab-uks-entra-rg --name lab-uks-entra-webapp --resource-type "Microsoft.Web/sites" --query id -o tsv
```

## Best Practices

1. **Use VCS-driven workflow** - All changes should go through Git
2. **Protect main branch** - Require pull requests for changes
3. **Use environment variables** for sensitive data
4. **Enable notifications** for failed runs
5. **Set up team access** as needed

## Security Considerations

1. Never commit `.tfvars` files to Git
2. Use Terraform Cloud environment variables for secrets
3. Rotate Azure service principal credentials regularly
4. Enable audit logging in Terraform Cloud
5. Use branch protection rules in GitHub

---

**Next Steps**: After completing this setup, all infrastructure changes should be made through Git commits, which will trigger Terraform Cloud runs automatically. 