# Fix Automation Architecture - PowerShell Script Execution

## 🔍 **Problem Summary**

The PowerShell scripts exist but can't execute because:
- ✅ **PowerShell Business Logic**: Complete script with 530+ lines of functionality
- ❌ **Azure Automation Account**: Removed from deployment (set to null)
- ❌ **Execution Engine**: No way to run PowerShell scripts
- ❌ **Job Management**: No tracking or monitoring system

## 🏗️ **Solution Options**

### **Option 1: Restore Azure Automation Account** ⭐ **Recommended**

**Pros:**
- ✅ Leverages existing PowerShell scripts without changes
- ✅ Built-in job management and monitoring
- ✅ Secure execution environment with managed identity
- ✅ Native Azure integration
- ✅ Scheduled execution capabilities

**Implementation:**
```hcl
# Add to environments/prod/main.tf
resource "azurerm_automation_account" "main" {
  name                = "${var.environment}-${var.location_code}-entra-automation"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku_name           = "Basic"

  identity {
    type = "SystemAssigned"
  }

  tags = local.tags_all
}

resource "azurerm_automation_runbook" "extension_attribute_management" {
  name                    = "Manage-ExtensionAttributes"
  location                = azurerm_resource_group.main.location
  resource_group_name     = azurerm_resource_group.main.name
  automation_account_name = azurerm_automation_account.main.name
  log_verbose             = true
  log_progress            = true
  description             = "Enhanced Entra ID Extension Attribute Management with Role-Based Access Control"
  runbook_type           = "PowerShell"

  content = file("../../scripts/extension-attribute-management.ps1")

  tags = local.tags_all
}
```

**Update webapp module:**
```hcl
# In modules/webapp/main.tf - change automation_account_name
automation_account_name = azurerm_automation_account.main.name
```

### **Option 2: Azure Container Instances (Alternative)**

**Pros:**
- ✅ Serverless execution
- ✅ Can run PowerShell scripts
- ✅ Cost-effective (pay per execution)
- ✅ Faster startup than VMs

**Implementation:**
```hcl
resource "azurerm_container_group" "powershell_runner" {
  name                = "entra-powershell-runner"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  ip_address_type     = "None"
  os_type            = "Linux"

  container {
    name   = "powershell"
    image  = "mcr.microsoft.com/powershell:latest"
    cpu    = "0.5"
    memory = "1.0"

    environment_variables = {
      AZURE_CLIENT_ID     = azuread_application.web_app.client_id
      AZURE_TENANT_ID     = data.azurerm_client_config.current.tenant_id
      RESOURCE_GROUP_NAME = azurerm_resource_group.main.name
    }
  }

  identity {
    type = "SystemAssigned"
  }
}
```

**Node.js Changes:**
```javascript
// Replace automation client with container execution
const { ContainerInstanceManagementClient } = require('@azure/arm-containerinstance');
const containerClient = new ContainerInstanceManagementClient(credential, config.subscriptionId);

// Execute PowerShell via container restart
await containerClient.containerGroups.restart(resourceGroupName, containerGroupName);
```

### **Option 3: Azure Functions with PowerShell** 

**Pros:**
- ✅ Serverless and cost-effective
- ✅ Native PowerShell support
- ✅ HTTP triggers from Node.js app
- ✅ Built-in monitoring and logging

**Implementation:**
```hcl
resource "azurerm_service_plan" "functions" {
  name                = "entra-functions-plan"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  os_type            = "Windows"
  sku_name           = "Y1"  # Consumption plan
}

resource "azurerm_windows_function_app" "powershell_runner" {
  name                = "entra-powershell-functions"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  service_plan_id     = azurerm_service_plan.functions.id
  storage_account_name       = module.storage.storage_account_name
  storage_account_access_key = module.storage.storage_account_primary_access_key

  site_config {
    application_stack {
      powershell_core_version = "7.2"
    }
  }

  app_settings = {
    "AZURE_CLIENT_ID"     = azuread_application.web_app.client_id
    "AZURE_TENANT_ID"     = data.azurerm_client_config.current.tenant_id
    "RESOURCE_GROUP_NAME" = azurerm_resource_group.main.name
    "KEY_VAULT_URI"       = azurerm_key_vault.main.vault_uri
  }

  identity {
    type = "SystemAssigned"
  }
}
```

**Function Code Structure:**
```
functions/
├── ExtensionAttributeManagement/
│   ├── function.json
│   └── run.ps1  # Existing PowerShell script logic
├── DeviceCleanup/
│   ├── function.json
│   └── run.ps1
└── GroupCleanup/
    ├── function.json
    └── run.ps1
```

## 🎯 **Recommended Approach: Option 1 (Azure Automation)**

### **Why Azure Automation is Best:**
1. **Minimal Changes**: Existing PowerShell script works as-is
2. **Job Management**: Built-in tracking, logging, and monitoring
3. **Security**: Managed identity integration
4. **Scalability**: Can handle multiple concurrent jobs
5. **Monitoring**: Native integration with Application Insights

### **Implementation Plan:**

#### **Phase 1: Add Automation Account to Terraform**
```bash
# 1. Update environments/prod/main.tf
# 2. Add automation account resource
# 3. Add runbook resource with existing PowerShell script
# 4. Update webapp module parameters
```

#### **Phase 2: Deploy Infrastructure**
```bash
terraform plan   # Review automation account addition
terraform apply  # Deploy automation infrastructure
```

#### **Phase 3: Test Integration**
```bash
# 1. Verify automation account exists
# 2. Test runbook execution from Azure Portal
# 3. Test Node.js app triggering runbooks
# 4. Verify job monitoring works
```

### **Immediate Next Steps:**

1. **Update Terraform Configuration**:
   - Add automation account resource
   - Upload PowerShell script as runbook
   - Grant necessary permissions

2. **Update Node.js App**:
   - Change `automation_account_name` from null to actual name
   - Remove 503 "not configured" responses
   - Restore full automation functionality

3. **Test End-to-End**:
   - Deploy updated infrastructure
   - Test PowerShell execution via web interface
   - Verify job monitoring and logging

## 📊 **Cost Comparison**

| Option | Monthly Cost (Est.) | Complexity | Maintenance |
|--------|-------------------|------------|-------------|
| **Automation Account** | $10-30 | Low | Low |
| Container Instances | $5-20 | Medium | Medium |
| Azure Functions | $0-10 | High | Medium |

## 🚀 **Ready to Implement?**

**Recommendation**: Implement Option 1 (Azure Automation Account) because:
- ✅ Your PowerShell scripts are already designed for it
- ✅ Minimal code changes required
- ✅ Most reliable and feature-complete solution
- ✅ Best integration with existing Node.js frontend

Would you like me to implement the Azure Automation Account solution? 