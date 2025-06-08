# Entra Management Console - Deployment Guide

## Overview
This guide explains how to deploy the updated Entra Management Console infrastructure using the new modular Terraform configuration.

## Recent Changes
- **Modular Architecture**: Split configuration into storage and webapp modules
- **Azure AD Application**: Now managed directly in Terraform instead of using data sources
- **Simplified Configuration**: Removed automation account dependencies
- **Fixed Deprecation Warnings**: Updated to use latest Azure provider features

## Prerequisites
1. Azure CLI installed and authenticated
2. Terraform >= 1.0.0 installed
3. Appropriate Azure permissions to create resources
4. Access to the Azure subscription: `102e9107-d789-4139-9220-6eb6ed33b472`

## Deployment Steps

### 1. Navigate to Production Environment
```bash
cd environments/prod
```

### 2. Initialize Terraform
```bash
terraform init
```

### 3. Review Configuration
Review the `terraform.tfvars` file and adjust values if needed:
```bash
cat terraform.tfvars
```

### 4. Migrate Existing State (If Upgrading)
If you have existing infrastructure, run the migration script:
```bash
./migrate-state.sh
```

This script will:
- Move existing resources into the new module structure
- Remove deprecated automation resources
- Clean up old Azure AD application references

### 5. Plan the Deployment
```bash
terraform plan
```

Review the plan output to ensure it matches your expectations.

### 6. Apply the Configuration
```bash
terraform apply
```

### 7. Verify Deployment
After successful deployment, verify the following outputs:
- `web_app_default_hostname`: The URL of your web application
- `storage_account_name`: Name of the storage account
- `key_vault_name`: Name of the Key Vault

## Configuration Details

### Variables
Key variables in `terraform.tfvars`:
- `environment`: Environment name (default: "lab")
- `location`: Azure region (default: "uksouth")
- `resource_group_name`: Resource group name
- `web_app_name`: Web application name
- `storage_account_name`: Storage account name
- `enable_ip_restrictions`: Enable IP restrictions for web app

### Modules
- **Storage Module**: Manages Azure Storage Account and File Share
- **WebApp Module**: Manages App Service Plan, Web App, and Application Insights

### Security Features
- Key Vault for storing sensitive information
- Managed Identity for Web App
- IP restrictions (optional)
- HTTPS-only traffic enforcement

## Troubleshooting

### Common Issues

1. **Azure AD Application Not Found**
   - Solution: The new configuration creates the application automatically

2. **Key Vault IP Restrictions Error**
   - Solution: Set `enable_ip_restrictions = false` or provide a valid `allowed_ip_address`

3. **Storage Account Name Conflicts**
   - Solution: Update `storage_account_name` in `terraform.tfvars` to a unique value

4. **State Migration Issues**
   - Solution: Review the migration script output and manually import any missing resources

### Manual State Operations
If automatic migration fails, you can manually move resources:
```bash
# Example: Move storage account to module
terraform state mv azurerm_storage_account.main module.storage.azurerm_storage_account.main

# Example: Remove deprecated resource
terraform state rm azurerm_automation_account.main
```

## Post-Deployment

### Azure AD Application Setup
After deployment, you may need to:
1. Grant admin consent for the Azure AD application
2. Update any external systems with the new application client ID
3. Configure additional API permissions if required

### Monitoring
- Application Insights is automatically configured
- Logs are sent to the Log Analytics workspace
- Key Vault access is logged and monitored

## Support
For issues or questions, refer to:
- Azure provider documentation
- Terraform module documentation
- Azure AD application setup guides

---

**Important**: Keep your `terraform.tfvars` file secure as it may contain sensitive configuration values. 