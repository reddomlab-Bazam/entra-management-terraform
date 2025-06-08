# URGENT: Fix Environment Variables in Azure Portal

## 🚨 **Immediate Fix Required**

Your application is failing because of missing environment variables. Here's how to fix it **immediately** through the Azure Portal:

## 📋 **Step-by-Step Instructions**

### 1. **Open Azure Portal**
1. Go to [portal.azure.com](https://portal.azure.com)
2. Navigate to **App Services**
3. Click on **lab-uks-entra-webapp**

### 2. **Access Configuration Settings**
1. In the left sidebar, click **"Configuration"**
2. Click on the **"Application settings"** tab

### 3. **Add Missing Environment Variables**

Click **"+ New application setting"** for each of these:

#### **AZURE_SUBSCRIPTION_ID**
- **Name:** `AZURE_SUBSCRIPTION_ID`
- **Value:** `102e9107-d789-4139-9220-6eb6ed33b472`
- Click **OK**

#### **RESOURCE_GROUP_NAME**
- **Name:** `RESOURCE_GROUP_NAME`  
- **Value:** `lab-uks-entra-rg`
- Click **OK**

#### **KEY_VAULT_URI**
- **Name:** `KEY_VAULT_URI`
- **Value:** `https://lab-uks-entra-kv.vault.azure.net/`
- Click **OK**

#### **AUTOMATION_ACCOUNT_NAME**
- **Name:** `AUTOMATION_ACCOUNT_NAME`
- **Value:** *(leave empty or set to "null")*
- Click **OK**

#### **SESSION_TIMEOUT_MINUTES**
- **Name:** `SESSION_TIMEOUT_MINUTES`
- **Value:** `60`
- Click **OK**

#### **NODE_ENV**
- **Name:** `NODE_ENV`
- **Value:** `production`
- Click **OK**

### 4. **Save Configuration**
1. Click **"Save"** at the top of the page
2. Click **"Continue"** when prompted
3. Wait for the configuration to save

### 5. **Restart the App Service**
1. In the left sidebar, click **"Overview"**
2. Click **"Restart"** at the top
3. Click **"Yes"** to confirm
4. Wait for the restart to complete (about 30-60 seconds)

## 🎯 **Expected Results**

After saving and restarting, your application should:
- ✅ Start successfully without container errors
- ✅ Be accessible at: `https://lab-uks-entra-webapp.azurewebsites.net`
- ✅ Show the login page instead of an error page
- ✅ Health endpoint should work: `https://lab-uks-entra-webapp.azurewebsites.net/health`

## 🔍 **Verify the Fix**

### Test 1: Health Check
```bash
curl https://lab-uks-entra-webapp.azurewebsites.net/health
```

**Expected Response:**
```json
{
  "status": "healthy",
  "timestamp": "2025-01-08T...",
  "nodeVersion": "v18.20.8",
  "port": 8080,
  "authentication": "enabled",
  "azureClientId": "configured"
}
```

### Test 2: Main Application
Visit: `https://lab-uks-entra-webapp.azurewebsites.net`

**Expected:** Entra Management Console login page (not error page)

## 📊 **Current Environment Variables**

After adding these, your app will have:

```
✅ AZURE_CLIENT_ID (already configured)
✅ AZURE_CLIENT_SECRET (already configured) 
✅ AZURE_TENANT_ID (already configured)
✅ AZURE_SUBSCRIPTION_ID (newly added)
✅ RESOURCE_GROUP_NAME (newly added)
✅ KEY_VAULT_URI (newly added)
✅ AUTOMATION_ACCOUNT_NAME (newly added)
✅ SESSION_TIMEOUT_MINUTES (newly added)
✅ NODE_ENV (newly added)
✅ APPINSIGHTS_INSTRUMENTATIONKEY (already configured)
✅ APPLICATIONINSIGHTS_CONNECTION_STRING (already configured)
```

## 🚨 **If You Need Help Finding Values**

### Finding Your Key Vault URI:
1. Go to **Key Vaults** in Azure Portal
2. Click **lab-uks-entra-kv**
3. Copy the **Vault URI** from the overview page

### Verifying Subscription ID:
1. Go to **Subscriptions** in Azure Portal
2. Your subscription ID should be: `102e9107-d789-4139-9220-6eb6ed33b472`

## ⏱️ **Timeline**

This fix should take **2-3 minutes** total:
- 1-2 minutes to add the environment variables
- 30-60 seconds for app restart
- Application should be working immediately after restart

## 🎉 **Next Steps After Fix**

Once the application is working:
1. Test all functionality to ensure it's working properly
2. We can then sync the Terraform state to match the current Azure configuration
3. Future deployments can be handled through the CI/CD pipeline

---

**This is the fastest way to get your application working again!** 🚀 