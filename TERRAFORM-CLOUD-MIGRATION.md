# 🔄 **Terraform Cloud Setup & State Migration Guide**

## 🎯 **Current Situation**

- ✅ **Local State**: All automation resources deployed successfully (automation account, runbooks, variables)
- ❌ **Terraform Cloud**: Not yet configured - organization doesn't exist
- 🎯 **Goal**: Migrate local state to Terraform Cloud for team collaboration

## 📋 **Step-by-Step Migration Process**

### **Phase 1: Set Up Terraform Cloud Organization**

#### **1.1 Create Organization (Web Interface)**
1. Go to **https://app.terraform.io**
2. Sign in with your account (`bazame03dd495`)
3. Click **"New Organization"**
4. **Organization Name**: `redddome-lab`
5. **Email**: Your work email
6. Click **"Create Organization"**

#### **1.2 Create Workspace**
1. In your new organization, click **"New Workspace"**
2. Choose **"CLI-driven workflow"**
3. **Workspace Name**: `entra-management-prod`
4. **Description**: `Production Entra ID Management Console`
5. Click **"Create Workspace"**

#### **1.3 Configure Environment Variables**
In the workspace settings, add these **Environment Variables**:

| Variable | Value | Sensitive |
|----------|-------|-----------|
| `ARM_CLIENT_ID` | Your Azure Service Principal ID | ❌ |
| `ARM_CLIENT_SECRET` | Your Azure Service Principal Secret | ✅ |
| `ARM_SUBSCRIPTION_ID` | `102e9107-d789-4139-9220-6eb6ed33b472` | ❌ |
| `ARM_TENANT_ID` | `7d6f2030-fa33-4502-934d-ba575274de87` | ❌ |

### **Phase 2: Migrate Local State to Terraform Cloud**

#### **2.1 Update Backend Configuration**
```bash
cd environments/prod
```

Edit `providers.tf` and replace the local backend with:
```hcl
cloud {
  organization = "redddome-lab"
  workspaces {
    name = "entra-management-prod"
  }
}
```

#### **2.2 Initialize and Migrate**
```bash
# This will prompt to migrate state from local to cloud
terraform init

# Answer "yes" when prompted to copy existing state
```

#### **2.3 Verify Migration**
```bash
# Check that all resources are tracked
terraform plan

# Should show no changes if migration was successful
```

### **Phase 3: Verify Terraform Cloud Integration**

#### **3.1 Test Cloud Execution**
1. Go to your Terraform Cloud workspace
2. Click **"Start new plan"**
3. Should see all your automation resources in state
4. Confirm everything matches what we deployed locally

#### **3.2 Set Up Automatic Runs (Optional)**
1. Connect your GitHub repository
2. Configure auto-runs on commits to main branch
3. Set up plan-only mode for pull requests

## 🎮 **Quick Commands After Setup**

### **Local Development Workflow:**
```bash
# Make changes locally
terraform plan

# Apply through Terraform Cloud
terraform apply
```

### **View Resources in Terraform Cloud:**
- Automation Account: `lab-uks-entra-automation`
- Runbook: `Manage-ExtensionAttributes`
- Variables: 7 automation variables
- Permissions: Key Vault access, storage roles

## ⚠️ **Important Notes**

### **State File Security**
- ✅ Local state contains sensitive data (automation secrets)
- ✅ Terraform Cloud encrypts state at rest
- ✅ Migration will preserve all sensitive values securely

### **Current Working Resources**
These resources are already deployed and working:
- ✅ Azure Automation Account
- ✅ PowerShell Runbook (530+ lines)
- ✅ 7 Configuration Variables
- ✅ Security permissions and role assignments
- ✅ Web app environment variables updated

### **No Downtime**
- Migration doesn't affect running resources
- Your automation functionality continues working
- Only changes the state storage location

## 🚨 **Alternative: Continue with Local State**

If you prefer to continue with local state for now:

### **Pros:**
- ✅ Already working
- ✅ No additional setup required
- ✅ Full control over state

### **Cons:**
- ❌ No team collaboration
- ❌ No remote execution
- ❌ State not backed up in cloud
- ❌ Manual state management

### **Keep Local State Command:**
```bash
# Current configuration already set for local
terraform plan
terraform apply
```

## 🎯 **Recommendation**

**Option 1 (Recommended)**: Set up Terraform Cloud for better collaboration and state management

**Option 2 (Quick)**: Continue with local state and migrate later when needed

**Current Status**: All automation functionality is working regardless of state storage choice!

---

## 🔍 **Troubleshooting**

### **If Terraform Cloud Migration Fails:**
1. Check organization name spelling
2. Verify workspace exists
3. Ensure you're logged in: `terraform login`
4. Check environment variables in workspace

### **If Resources Show as "to be created" in Cloud:**
- This is normal - means state migration is needed
- Don't apply! This would create duplicates
- Follow migration steps above instead 