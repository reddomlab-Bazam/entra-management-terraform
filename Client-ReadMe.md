# Entra Management Console - Automated Deployment

## 🎯 Overview

This Terraform configuration deploys a complete Entra ID management solution with:
- ✅ Web-based management console with Entra ID authentication
- ✅ PowerShell automation runbooks for user/device/group management
- ✅ Role-based access control and audit logging
- ✅ Azure infrastructure (App Service, Automation Account, Key Vault, Storage)

## 🚀 Quick Start

### Prerequisites
- Azure subscription with **Owner** permissions
- Azure CLI installed and configured
- Terraform Cloud account
- jq installed (`sudo apt install jq` or `brew install jq`)

### Step 1: Setup Azure Service Principal

Run the provided setup script:

```bash
chmod +x setup-terraform-cloud.sh
./setup-terraform-cloud.sh
```

This script will:
1. Create a service principal with Owner role
2. Grant required Azure AD Graph permissions
3. Display the credentials for Terraform Cloud

### Step 2: Configure Terraform Cloud

1. **Create a new workspace** in Terraform Cloud
2. **Connect to your Git repository** containing this configuration
3. **Add Environment Variables**:

   **Sensitive Variables:**
   ```
   ARM_CLIENT_ID = <from setup script>
   ARM_CLIENT_SECRET = <from setup script>
   ```

   **Regular Variables:**
   ```
   ARM_SUBSCRIPTION_ID = <your subscription ID>
   ARM_TENANT_ID = <your tenant ID>
   TF_VAR_allowed_ip_address = <your public IP>
   TF_VAR_from_email = automation@yourdomain.com
   TF_VAR_to_email = admin@yourdomain.com
   ```

### Step 3: Deploy

1. **Queue a plan** in Terraform Cloud
2. **Review the changes** (should show ~15 resources to create)
3. **Apply the plan** to deploy the infrastructure

### Step 4: Access Your Console

After deployment:
1. Navigate to: `https://lab-uks-entra-webapp.azurewebsites.net`
2. Sign in with your organizational account
3. Verify your role-based access to operations

## 🔧 Configuration Options

### Customize Deployment

Edit these variables in your Terraform Cloud workspace:

```hcl
# Network Security
TF_VAR_allowed_ip_address = "your.public.ip.address"
TF_VAR_enable_ip_restrictions = true

# Email Notifications  
TF_VAR_from_email = "automation@yourdomain.com"
TF_VAR_to_email = "admin@yourdomain.com"

# Resource Naming
TF_VAR_environment = "prod"           # or "dev", "test"
TF_VAR_location_code = "uks"          # or "eus", "weu", etc.
TF_VAR_service_name = "entra"
```

### Role Requirements

Users need these Azure AD roles for different operations:

| Operation | Required Roles |
|-----------|----------------|
| Extension Attributes | User Administrator, Global Administrator |
| Device Cleanup | Cloud Device Administrator, Global Administrator |
| Group Management | Groups Administrator, Global Administrator |
| All Operations | Global Administrator |

## 🛡️ Security Features

- **IP Restrictions**: Access limited to specified IP addresses
- **Entra ID Authentication**: No local accounts or passwords
- **Role-Based Access**: Operations limited by Azure AD roles
- **Managed Identities**: No stored credentials in application code
- **Audit Logging**: Complete user action tracking
- **Encrypted Secrets**: All sensitive data stored in Key Vault

## 📊 Monitoring

### Application Insights
- Performance metrics and error tracking
- User authentication events
- Custom telemetry for runbook executions

### Access Logs
- Real-time monitoring in Azure Portal
- Log Analytics queries for audit reports
- Alerting on failed operations

## 🔄 Operations

### Extension Attribute Management
- Bulk user attribute updates
- What-If preview mode
- Email confirmation reports

### Device Cleanup
- Automated inactive device detection
- Safety limits and Azure VM protection
- Compliance reporting

### Group Management
- Membership cleanup based on user age
- Bulk operations with safety controls
- Detailed audit trails

## 🆘 Troubleshooting

### Common Issues

**Authentication Errors:**
- Verify API permissions are granted with admin consent
- Check user has required Azure AD roles
- Confirm web app registration redirect URIs

**Deployment Failures:**
- Ensure service principal has Owner role
- Verify Azure AD Graph permissions
- Check Terraform Cloud environment variables

**Access Denied:**
- Confirm IP address is whitelisted
- Verify user account is in correct tenant
- Check application registration configuration

### Support

For technical support:
1. Check Application Insights logs
2. Review Automation Account runbook history
3. Verify Key Vault access policies
4. Contact your deployment team

## 📚 Additional Resources

- [Azure AD Role Definitions](https://docs.microsoft.com/en-us/azure/active-directory/roles/permissions-reference)
- [Microsoft Graph Permissions](https://docs.microsoft.com/en-us/graph/permissions-reference)
- [Terraform Cloud Documentation](https://www.terraform.io/cloud/docs)

## 🔄 Updates and Maintenance

### Regular Tasks
- Review and rotate client secrets (every 12-24 months)
- Update IP restrictions as needed
- Monitor Application Insights for performance
- Review audit logs for compliance

### Scaling
- Increase App Service Plan SKU for higher traffic
- Add additional IP addresses for multi-location access
- Configure custom domains and SSL certificates