# Troubleshooting Guide

## Current Issue: Key Vault Permission Errors

### Problem
You're seeing this error:
```
Error: purging of Secret "AutomationClientSecret" (Key Vault "https://lab-uks-entra-kv.vault.azure.net/") : 
keyvault.BaseClient#PurgeDeletedSecret: Failure responding to request: StatusCode=403 -- 
Original Error: autorest/azure: Service returned an error. Status=403 Code="Forbidden" 
Message="The user, group or application 'appid=a308069b-8fd5-481e-84d3-ecdf9280dc5f;oid=45ddfbcb-7639-46eb-96e3-52e300aac298;iss=https://sts.windows.net/7d6f2030-fa33-4502-934d-ba575274de87/' 
does not have secrets purge permission on key vault 'lab-uks-entra-kv;location=uksouth'.
```

### What Happened
1. Terraform tried to delete and recreate Key Vault secrets during the migration
2. When secrets are deleted from Azure Key Vault, they go into a "soft deleted" state
3. Terraform tried to purge these secrets immediately (due to `purge_soft_delete_on_destroy = true`)
4. The service principal/user doesn't have "purge" permissions on the Key Vault
5. The deployment failed, leaving secrets in a soft-deleted state

### Solutions

#### Option 1: Quick Fix (Recommended)
I've already implemented this fix:

1. **Updated provider configuration** to disable automatic purging:
   ```hcl
   provider "azurerm" {
     features {
       key_vault {
         purge_soft_delete_on_destroy = false  # Changed from true
         recover_soft_deleted_key_vaults = true
       }
     }
   }
   ```

2. **Run the cleanup script**:
   ```bash
   cd environments/prod
   ./cleanup-keyvault.sh
   ```

3. **Try the deployment again**:
   ```bash
   terraform plan
   terraform apply
   ```

#### Option 2: Add Purge Permissions
If you prefer to keep automatic purging enabled:

1. **In Azure Portal**:
   - Go to Key Vault → Access policies
   - Find your service principal/user
   - Add "Purge" permission to Secret permissions
   - Save

2. **Or via Azure CLI**:
   ```bash
   # Get your current object ID
   OBJECT_ID=$(az ad signed-in-user show --query objectId -o tsv)
   
   # Add purge permission
   az keyvault set-policy \
     --name lab-uks-entra-kv \
     --object-id $OBJECT_ID \
     --secret-permissions get list set delete purge recover
   ```

3. **Re-enable purging** in `providers.tf`:
   ```hcl
   purge_soft_delete_on_destroy = true
   ```

#### Option 3: Manual Cleanup (If scripts fail)
If the cleanup script doesn't work:

1. **List soft-deleted secrets**:
   ```bash
   az keyvault secret list-deleted --vault-name lab-uks-entra-kv
   ```

2. **Purge specific secrets**:
   ```bash
   az keyvault secret purge --vault-name lab-uks-entra-kv --name AutomationClientSecret
   az keyvault secret purge --vault-name lab-uks-entra-kv --name StorageAccountKey
   ```

3. **Or recover and delete properly**:
   ```bash
   az keyvault secret recover --vault-name lab-uks-entra-kv --name AutomationClientSecret
   az keyvault secret delete --vault-name lab-uks-entra-kv --name AutomationClientSecret
   ```

### Prevention
To prevent this in the future:

1. **Use Option 1** (disable auto-purging) - most reliable
2. **Or ensure proper permissions** are set up from the start
3. **Test with non-production** Key Vaults first

## Other Common Issues

### Issue: Resource Already Exists
**Problem**: `A resource with the ID "/subscriptions/.../resourceGroups/..." already exists`

**Solution**: Import the resource:
```bash
terraform import <resource_type>.<resource_name> <azure_resource_id>
```

### Issue: Module Not Found
**Problem**: `Module not found` errors

**Solution**: Run terraform init:
```bash
cd environments/prod
terraform init
```

### Issue: Authentication Errors
**Problem**: Azure authentication failures in Terraform Cloud

**Solution**: Check environment variables in TFC workspace:
- `ARM_CLIENT_ID`
- `ARM_CLIENT_SECRET`
- `ARM_SUBSCRIPTION_ID`
- `ARM_TENANT_ID`

### Issue: State Lock
**Problem**: `Error acquiring the state lock`

**Solution**: 
1. Wait for other operations to complete
2. Or force unlock (dangerous):
   ```bash
   terraform force-unlock <lock_id>
   ```

## Getting Help

### Check Logs
1. **Terraform Cloud**: Check run logs in the workspace
2. **Local**: Run with debug: `TF_LOG=DEBUG terraform apply`

### Useful Commands
```bash
# Check what Terraform thinks exists
terraform state list

# Show details of a resource
terraform state show <resource_address>

# Remove a resource from state (without destroying)
terraform state rm <resource_address>

# Import existing resource
terraform import <resource_type>.<name> <azure_resource_id>

# Refresh state to match reality
terraform refresh
```

### Azure CLI Debugging
```bash
# Check current account
az account show

# List resources in resource group
az resource list --resource-group lab-uks-entra-rg

# Check Key Vault access
az keyvault secret list --vault-name lab-uks-entra-kv
```

---

**Status**: ✅ Issue identified and fixes provided 