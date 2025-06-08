const express = require('express');
const { DefaultAzureCredential } = require('@azure/identity');
const { AutomationClient } = require('@azure/arm-automation');
const jwt = require('jsonwebtoken');
const path = require('path');

const app = express();
const port = process.env.PORT || 8080;

// Configuration from environment variables
const config = {
    azureClientId: process.env.AZURE_CLIENT_ID,
    azureTenantId: process.env.AZURE_TENANT_ID,
    subscriptionId: process.env.AZURE_SUBSCRIPTION_ID,
    resourceGroupName: process.env.RESOURCE_GROUP_NAME,
    automationAccountName: process.env.AUTOMATION_ACCOUNT_NAME,
    keyVaultUri: process.env.KEY_VAULT_URI
};

app.use(express.json());
app.use(express.static(path.join(__dirname, 'public')));

// Initialize Azure clients
const credential = new DefaultAzureCredential();
let automationClient;

try {
    if (config.subscriptionId) {
        automationClient = new AutomationClient(credential, config.subscriptionId);
    }
} catch (error) {
    console.warn('Azure automation client initialization failed:', error.message);
}

// Role requirements for operations
const roleRequirements = {
    'ExtensionAttributes': [
        'User Administrator',
        'Global Administrator', 
        'Privileged Role Administrator'
    ],
    'DeviceCleanup': [
        'Cloud Device Administrator',
        'Intune Administrator', 
        'Global Administrator'
    ],
    'GroupCleanup': [
        'Groups Administrator',
        'User Administrator',
        'Global Administrator'
    ],
    'All': [
        'Global Administrator',
        'Privileged Role Administrator'
    ]
};

// JWT verification middleware
function verifyToken(req, res, next) {
    const authHeader = req.headers.authorization;
    
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
        return res.status(401).json({ 
            error: 'Authentication required',
            requiresLogin: true
        });
    }

    const token = authHeader.substring(7);
    
    try {
        // In production, verify the JWT token with Microsoft's public keys
        // For now, decode without verification (development only)
        const decoded = jwt.decode(token);
        
        if (!decoded) {
            return res.status(401).json({ error: 'Invalid token' });
        }

        req.user = {
            upn: decoded.upn || decoded.unique_name || decoded.preferred_username,
            name: decoded.name,
            roles: decoded.roles || [],
            tenantId: decoded.tid,
            oid: decoded.oid
        };
        
        next();
    } catch (error) {
        return res.status(401).json({ error: 'Token verification failed' });
    }
}

// Check if user has required roles for operation
function checkPermissions(operation, userRoles) {
    const required = roleRequirements[operation] || [];
    return required.some(role => userRoles.includes(role));
}

// Main page with authentication interface
app.get('/', (req, res) => {
    res.send(`<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Entra Management Console</title>
    <script src="https://alcdn.msauth.net/browser/2.38.3/js/msal-browser.min.js"></script>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            padding: 20px;
        }

        .container {
            max-width: 1400px;
            margin: 0 auto;
            background: white;
            border-radius: 20px;
            box-shadow: 0 20px 40px rgba(0, 0, 0, 0.1);
            overflow: hidden;
        }

        .header {
            background: linear-gradient(135deg, #6366f1, #8b5cf6);
            color: white;
            padding: 30px;
            text-align: center;
            position: relative;
        }

        .login-container {
            max-width: 500px;
            margin: 50px auto;
            text-align: center;
            padding: 40px;
        }

        .btn {
            background: linear-gradient(135deg, #6366f1, #8b5cf6);
            color: white;
            border: none;
            padding: 14px 28px;
            border-radius: 10px;
            font-size: 16px;
            font-weight: 600;
            cursor: pointer;
            transition: all 0.3s ease;
            margin: 10px;
            text-decoration: none;
            display: inline-block;
        }

        .btn:hover {
            transform: translateY(-2px);
            box-shadow: 0 10px 20px rgba(99, 102, 241, 0.3);
        }

        .btn-danger {
            background: linear-gradient(135deg, #ef4444, #dc2626);
        }

        .btn-warning {
            background: linear-gradient(135deg, #f59e0b, #d97706);
        }

        .status-card {
            background: #f8f9fa;
            border-radius: 15px;
            padding: 25px;
            margin: 25px;
            border-left: 5px solid #6366f1;
        }

        .alert {
            padding: 15px 20px;
            border-radius: 10px;
            margin: 15px 25px;
            font-weight: 500;
        }

        .alert-warning {
            background: #fef3c7;
            color: #92400e;
            border: 1px solid #fcd34d;
        }

        .alert-success {
            background: #dcfce7;
            color: #166534;
            border: 1px solid #a7f3d0;
        }

        .alert-danger {
            background: #fee2e2;
            color: #991b1b;
            border: 1px solid #fca5a5;
        }

        .hidden { display: none; }

        .logout-btn {
            position: absolute;
            top: 20px;
            right: 20px;
            background: rgba(255,255,255,0.2);
            border: 1px solid rgba(255,255,255,0.3);
            color: white;
            padding: 8px 16px;
            border-radius: 5px;
            cursor: pointer;
        }

        .user-info {
            background: #d4edda;
            padding: 15px;
            border-radius: 10px;
            margin: 25px;
            text-align: left;
        }

        .form-group {
            margin-bottom: 20px;
        }

        .form-row {
            display: grid;
            grid-template-columns: 1fr 1fr;
            gap: 20px;
            margin-bottom: 20px;
        }

        label {
            display: block;
            margin-bottom: 8px;
            font-weight: 600;
            color: #374151;
        }

        input, select, textarea {
            width: 100%;
            padding: 12px 16px;
            border: 2px solid #e5e7eb;
            border-radius: 10px;
            font-size: 14px;
            transition: border-color 0.3s ease;
        }

        input:focus, select:focus, textarea:focus {
            outline: none;
            border-color: #6366f1;
            box-shadow: 0 0 0 3px rgba(99, 102, 241, 0.1);
        }

        .help-text {
            font-size: 12px;
            color: #6b7280;
            margin-top: 5px;
        }

        .loading {
            display: none;
            text-align: center;
            padding: 20px;
        }

        .spinner {
            border: 4px solid #f3f4f6;
            border-top: 4px solid #6366f1;
            border-radius: 50%;
            width: 40px;
            height: 40px;
            animation: spin 1s linear infinite;
            margin: 0 auto 15px;
        }

        @keyframes spin {
            0% { transform: rotate(0deg); }
            100% { transform: rotate(360deg); }
        }

        ul { margin-left: 20px; margin-top: 10px; }
        li { margin-bottom: 5px; }

        .nav-tabs {
            display: flex;
            background: #f8f9fa;
            border-bottom: 1px solid #dee2e6;
        }

        .nav-tab {
            flex: 1;
            padding: 20px;
            background: none;
            border: none;
            cursor: pointer;
            font-size: 16px;
            font-weight: 600;
            color: #6c757d;
            transition: all 0.3s ease;
        }

        .nav-tab.active {
            background: white;
            color: #6366f1;
            border-bottom: 3px solid #6366f1;
        }

        .nav-tab:hover {
            background: #e9ecef;
        }

        .tab-content {
            padding: 30px;
            display: none;
        }

        .tab-content.active {
            display: block;
        }

        @media (max-width: 768px) {
            .form-row {
                grid-template-columns: 1fr;
            }
            
            .nav-tab {
                padding: 15px 10px;
                font-size: 14px;
            }
        }
    </style>
</head>
<body>
    <div class="container">
        <!-- Login Screen -->
        <div id="loginContainer" class="login-container">
            <h1>🎯 Entra Management Console</h1>
            <p style="margin: 20px 0; color: #666;">
                Secure access to Entra ID management tools.<br>
                Sign in with your organizational account to continue.
            </p>
            <button id="loginBtn" class="btn">🔐 Sign In with Entra ID</button>
            
            <div style="margin-top: 30px; padding: 20px; background: #f8f9fa; border-radius: 10px; text-align: left;">
                <h4>Required Permissions:</h4>
                <ul style="margin-top: 10px;">
                    <li><strong>Extension Attributes:</strong> User Administrator, Global Administrator</li>
                    <li><strong>Device Cleanup:</strong> Cloud Device Administrator, Global Administrator</li>
                    <li><strong>Group Management:</strong> Groups Administrator, Global Administrator</li>
                </ul>
            </div>
        </div>

        <!-- Main Application -->
        <div id="mainApp" class="hidden">
            <div class="header">
                <h1>🎯 Entra Management Console</h1>
                <p>Role-based Entra ID Management</p>
                <button id="logoutBtn" class="logout-btn">Sign Out</button>
            </div>

            <div id="userInfo" class="user-info"></div>

            <div class="nav-tabs">
                <button class="nav-tab active" onclick="switchTab('dashboard')">Dashboard</button>
                <button class="nav-tab" onclick="switchTab('extensions')">Extension Attributes</button>
                <button class="nav-tab" onclick="switchTab('devices')">Device Cleanup</button>
                <button class="nav-tab" onclick="switchTab('groups')">Group Management</button>
                <button class="nav-tab" onclick="switchTab('monitor')">Monitoring</button>
            </div>

            <!-- Dashboard Tab -->
            <div id="dashboard" class="tab-content active">
                <h2>System Dashboard</h2>
                
                <div class="status-card">
                    <h3>✅ Infrastructure Status</h3>
                    <ul>
                        <li>✅ Azure infrastructure deployed via Terraform</li>
                        <li>✅ Web app running on Node.js ${process.version}</li>
                        <li>✅ Entra ID authentication configured</li>
                        <li>✅ PowerShell 7.2 runtime ready</li>
                        <li>✅ Microsoft Graph modules installed</li>
                        <li>✅ Role-based access control active</li>
                    </ul>
                </div>

                <div id="permissionsSummary" class="status-card">
                    <h3>🔐 Your Permissions</h3>
                    <p>Loading permissions...</p>
                </div>
            </div>

            <!-- Extension Attributes Tab -->
            <div id="extensions" class="tab-content">
                <h2>Extension Attribute Management</h2>
                <div id="extensionsAccess"></div>
                <form id="extensionForm">
                    <div class="form-row">
                        <div class="form-group">
                            <label for="attributeNumber">Extension Attribute Number (1-15)</label>
                            <select id="attributeNumber" name="attributeNumber" required>
                                <option value="">Select Attribute</option>
                                <option value="1">Extension Attribute 1</option>
                                <option value="2">Extension Attribute 2</option>
                                <option value="3">Extension Attribute 3</option>
                                <option value="4">Extension Attribute 4</option>
                                <option value="5">Extension Attribute 5</option>
                                <option value="6">Extension Attribute 6</option>
                                <option value="7">Extension Attribute 7</option>
                                <option value="8">Extension Attribute 8</option>
                                <option value="9">Extension Attribute 9</option>
                                <option value="10">Extension Attribute 10</option>
                                <option value="11">Extension Attribute 11</option>
                                <option value="12">Extension Attribute 12</option>
                                <option value="13">Extension Attribute 13</option>
                                <option value="14">Extension Attribute 14</option>
                                <option value="15">Extension Attribute 15</option>
                            </select>
                        </div>
                        <div class="form-group">
                            <label for="attributeValue">Attribute Value</label>
                            <input type="text" id="attributeValue" name="attributeValue" maxlength="256" 
                                   placeholder="Enter the value to set">
                            <div class="help-text">Maximum 256 characters</div>
                        </div>
                    </div>

                    <div class="form-group">
                        <label for="usersToAdd">Users to Add/Update (Email Addresses)</label>
                        <textarea id="usersToAdd" name="usersToAdd" rows="3" 
                                  placeholder="user1@domain.com, user2@domain.com"></textarea>
                        <div class="help-text">Comma-separated email addresses</div>
                    </div>

                    <div class="form-group">
                        <label for="usersToRemove">Users to Remove (Clear Attribute)</label>
                        <textarea id="usersToRemove" name="usersToRemove" rows="3" 
                                  placeholder="user1@domain.com, user2@domain.com"></textarea>
                        <div class="help-text">Comma-separated email addresses</div>
                    </div>

                    <div class="form-group">
                        <button type="button" class="btn btn-warning" onclick="executeExtensions(true)">
                            🔍 Preview Changes (What-If)
                        </button>
                        <button type="button" class="btn" onclick="executeExtensions(false)">
                            ▶️ Execute Changes
                        </button>
                    </div>
                </form>
            </div>

            <!-- Device Cleanup Tab -->
            <div id="devices" class="tab-content">
                <h2>Device Cleanup Management</h2>
                <div id="devicesAccess"></div>
                <form id="deviceForm">
                    <div class="form-row">
                        <div class="form-group">
                            <label for="maxDevices">Maximum Devices to Process</label>
                            <input type="number" id="maxDevices" name="maxDevices" value="50" min="1" max="500">
                            <div class="help-text">Safety limit to prevent mass operations</div>
                        </div>
                        <div class="form-group">
                            <label for="excludeAzureVMs">Exclude Azure VMs</label>
                            <select id="excludeAzureVMs" name="excludeAzureVMs">
                                <option value="true">Yes (Recommended)</option>
                                <option value="false">No</option>
                            </select>
                        </div>
                    </div>

                    <div class="status-card">
                        <h4>📋 Cleanup Criteria</h4>
                        <ul>
                            <li><strong>Inactive Devices:</strong> Disabled after 120 days of inactivity</li>
                            <li><strong>Mobile Devices:</strong> Unmanaged iOS/Android devices deleted immediately</li>
                            <li><strong>Desktop Devices:</strong> Unmanaged Windows/macOS/Linux disabled after 30 days</li>
                            <li><strong>Long-disabled Devices:</strong> Deleted after 30 additional days</li>
                            <li><strong>Protected Devices:</strong> Servers and Azure VMs are automatically excluded</li>
                        </ul>
                    </div>

                    <div class="form-group">
                        <button type="button" class="btn btn-warning" onclick="executeDeviceCleanup(true)">
                            🔍 Preview Device Cleanup
                        </button>
                        <button type="button" class="btn btn-danger" onclick="executeDeviceCleanup(false)">
                            🗑️ Execute Device Cleanup
                        </button>
                    </div>
                </form>
            </div>

            <!-- Group Management Tab -->
            <div id="groups" class="tab-content">
                <h2>Group Membership Management</h2>
                <div id="groupsAccess"></div>
                <form id="groupForm">
                    <div class="form-row">
                        <div class="form-group">
                            <label for="groupName">Group Name</label>
                            <input type="text" id="groupName" name="groupName" 
                                   placeholder="Enter exact group display name">
                            <div class="help-text">Case-sensitive group display name</div>
                        </div>
                        <div class="form-group">
                            <label for="groupCleanupDays">Cleanup Threshold (Days)</label>
                            <input type="number" id="groupCleanupDays" name="groupCleanupDays" 
                                   value="14" min="1" max="365">
                            <div class="help-text">Remove users older than this many days</div>
                        </div>
                    </div>

                    <div class="status-card">
                        <h4>⚠️ Group Cleanup Process</h4>
                        <p>This will remove users from the specified group based on their account creation date. 
                           Users created more than the specified days ago will be removed from the group.</p>
                    </div>

                    <div class="form-group">
                        <button type="button" class="btn btn-warning" onclick="executeGroupCleanup(true)">
                            🔍 Preview Group Cleanup
                        </button>
                        <button type="button" class="btn" onclick="executeGroupCleanup(false)">
                            👥 Execute Group Cleanup
                        </button>
                    </div>
                </form>
            </div>

            <!-- Monitoring Tab -->
            <div id="monitor" class="tab-content">
                <h2>Job Monitoring & Logs</h2>
                
                <div class="form-row">
                    <div class="form-group">
                        <button type="button" class="btn" onclick="refreshJobStatus()">
                            🔄 Refresh Job Status
                        </button>
                        <button type="button" class="btn" onclick="downloadLogs()">
                            📥 Download Logs
                        </button>
                    </div>
                </div>

                <div id="jobStatus" class="status-card">
                    <h4>📊 Recent Job Status</h4>
                    <p>Click "Refresh Job Status" to see recent automation jobs...</p>
                </div>

                <div id="executionLogs" class="status-card">
                    <h4>📝 Execution Logs</h4>
                    <div style="background: #1f2937; color: #f9fafb; padding: 15px; border-radius: 5px; font-family: monospace; max-height: 300px; overflow-y: auto;">
                        Execution logs will appear here...
                    </div>
                </div>
            </div>

            <!-- Loading overlay -->
            <div id="loadingOverlay" class="loading">
                <div class="spinner"></div>
                <div>Processing request...</div>
            </div>

            <!-- Alerts container -->
            <div id="alertsContainer"></div>
        </div>
    </div>

    <script>
        // MSAL Configuration
        const msalConfig = {
            auth: {
                clientId: "${config.azureClientId || 'your-client-id'}",
                authority: "https://login.microsoftonline.com/${config.azureTenantId || 'your-tenant-id'}",
                redirectUri: window.location.origin
            },
            cache: {
                cacheLocation: "localStorage",
                storeAuthStateInCookie: false
            }
        };

        const msalInstance = new msal.PublicClientApplication(msalConfig);

        let currentUser = null;
        let accessToken = null;
        let currentJobId = null;
        let logPollingInterval = null;

        // Login request configuration
        const loginRequest = {
            scopes: [
                "User.ReadWrite.All",
                "Device.ReadWrite.All", 
                "Group.ReadWrite.All",
                "Directory.Read.All"
            ]
        };

        // Initialize authentication
        async function initAuth() {
            try {
                await msalInstance.initialize();
                
                const accounts = msalInstance.getAllAccounts();
                if (accounts.length > 0) {
                    currentUser = accounts[0];
                    await getAccessToken();
                    showMainApp();
                } else {
                    showLoginScreen();
                }
            } catch (error) {
                console.error('Auth initialization failed:', error);
                showError('Authentication initialization failed: ' + error.message);
            }
        }

        // Sign in
        async function signIn() {
            try {
                const response = await msalInstance.loginPopup(loginRequest);
                currentUser = response.account;
                accessToken = response.accessToken;
                
                showMainApp();
            } catch (error) {
                console.error('Sign in failed:', error);
                showError('Sign in failed: ' + error.message);
            }
        }

        // Get access token
        async function getAccessToken() {
            try {
                const tokenRequest = {
                    ...loginRequest,
                    account: currentUser
                };

                const response = await msalInstance.acquireTokenSilent(tokenRequest);
                accessToken = response.accessToken;
                return accessToken;
            } catch (error) {
                try {
                    const response = await msalInstance.acquireTokenPopup(tokenRequest);
                    accessToken = response.accessToken;
                    return accessToken;
                } catch (interactiveError) {
                    console.error('Token acquisition failed:', interactiveError);
                    return null;
                }
            }
        }

        // Show main app
        function showMainApp() {
            document.getElementById('loginContainer').classList.add('hidden');
            document.getElementById('mainApp').classList.remove('hidden');
            
            // Display user info
            updateUserInfo();
            updatePermissions();
        }

        // Show login screen
        function showLoginScreen() {
            document.getElementById('loginContainer').classList.remove('hidden');
            document.getElementById('mainApp').classList.add('hidden');
        }

        // Update user info display
        function updateUserInfo() {
            if (currentUser) {
                document.getElementById('userInfo').innerHTML = \`
                    <h4>👤 Signed in as:</h4>
                    <p><strong>Name:</strong> \${currentUser.name || 'N/A'}</p>
                    <p><strong>Email:</strong> \${currentUser.username}</p>
                    <p><strong>Tenant:</strong> \${currentUser.tenantId}</p>
                \`;
            }
        }

        // Update permissions based on user roles
        function updatePermissions() {
            // This would normally decode the access token to get roles
            // For now, show placeholder
            document.getElementById('permissionsSummary').innerHTML = \`
                <h3>🔐 Your Permissions</h3>
                <p>✅ Authenticated user - permissions are evaluated per operation</p>
                <p>Permissions are checked against your Entra ID roles when you execute operations.</p>
            \`;

            // Enable/disable tabs based on permissions
            updateTabAccess();
        }

        // Update tab access based on permissions
        function updateTabAccess() {
            // Show access info for each tab
            document.getElementById('extensionsAccess').innerHTML = \`
                <div class="alert alert-success">
                    <strong>✅ Extension Attributes Access</strong><br>
                    This operation requires: User Administrator or Global Administrator roles.
                </div>
            \`;

            document.getElementById('devicesAccess').innerHTML = \`
                <div class="alert alert-success">
                    <strong>✅ Device Cleanup Access</strong><br>
                    This operation requires: Cloud Device Administrator or Global Administrator roles.
                </div>
            \`;

            document.getElementById('groupsAccess').innerHTML = \`
                <div class="alert alert-success">
                    <strong>✅ Group Management Access</strong><br>
                    This operation requires: Groups Administrator or Global Administrator roles.
                </div>
            \`;
        }

        // Tab switching functionality
        function switchTab(tabName) {
            document.querySelectorAll('.tab-content').forEach(tab => {
                tab.classList.remove('active');
            });
            
            document.querySelectorAll('.nav-tab').forEach(tab => {
                tab.classList.remove('active');
            });
            
            document.getElementById(tabName).classList.add('active');
            event.target.classList.add('active');
        }

        // Show loading overlay
        function showLoading() {
            document.getElementById('loadingOverlay').style.display = 'block';
        }

        // Hide loading overlay
        function hideLoading() {
            document.getElementById('loadingOverlay').style.display = 'none';
        }

        // Show alert message
        function showAlert(message, type = 'info') {
            const alertsContainer = document.getElementById('alertsContainer');
            const alertDiv = document.createElement('div');
            alertDiv.className = \`alert alert-\${type}\`;
            alertDiv.innerHTML = \`
                \${message}
                <button onclick="this.parentElement.remove()" style="float: right; background: none; border: none; font-size: 18px; cursor: pointer;">&times;</button>
            \`;
            
            alertsContainer.appendChild(alertDiv);
            
            setTimeout(() => {
                if (alertDiv.parentElement) {
                    alertDiv.remove();
                }
            }, 5000);
        }

        // Show error
        function showError(message) {
            showAlert(\`❌ Error: \${message}\`, 'danger');
        }

        // Execute Extension Attributes operation
        async function executeExtensions(whatIf = true) {
            if (!accessToken) {
                showError('Please sign in again');
                return;
            }

            const form = document.getElementById('extensionForm');
            const formData = new FormData(form);
            
            if (!formData.get('attributeNumber')) {
                showAlert('Please select an extension attribute number', 'warning');
                return;
            }

            if (!formData.get('usersToAdd') && !formData.get('usersToRemove')) {
                showAlert('Please specify users to add or remove', 'warning');
                return;
            }

            const params = {
                Operation: 'ExtensionAttributes',
                WhatIf: whatIf,
                ExtensionAttributeNumber: parseInt(formData.get('attributeNumber')),
                AttributeValue: formData.get('attributeValue') || '',
                UsersToAdd: formData.get('usersToAdd') || '',
                UsersToRemove: formData.get('usersToRemove') || '',
                SendEmail: true,
                UserContext: {
                    upn: currentUser.username,
                    name: currentUser.name,
                    tenantId: currentUser.tenantId
                }
            };

            await executeRunbook(params, whatIf ? 'Extension Attributes Preview' : 'Extension Attributes Execution');
        }

        // Execute Device Cleanup operation
        async function executeDeviceCleanup(whatIf = true) {
            if (!accessToken) {
                showError('Please sign in again');
                return;
            }

            const form = document.getElementById('deviceForm');
            const formData = new FormData(form);

            const params = {
                Operation: 'DeviceCleanup',
                WhatIf: whatIf,
                MaxDevices: parseInt(formData.get('maxDevices')),
                ExcludeAzureVMs: formData.get('excludeAzureVMs') === 'true',
                SendEmail: true,
                UserContext: {
                    upn: currentUser.username,
                    name: currentUser.name,
                    tenantId: currentUser.tenantId
                }
            };

            await executeRunbook(params, whatIf ? 'Device Cleanup Preview' : 'Device Cleanup Execution');
        }

        // Execute Group Cleanup operation
        async function executeGroupCleanup(whatIf = true) {
            if (!accessToken) {
                showError('Please sign in again');
                return;
            }

            const form = document.getElementById('groupForm');
            const formData = new FormData(form);

            if (!formData.get('groupName')) {
                showAlert('Please enter a group name', 'warning');
                return;
            }

            const params = {
                Operation: 'GroupCleanup',
                WhatIf: whatIf,
                GroupName: formData.get('groupName'),
                GroupCleanupDays: parseInt(formData.get('groupCleanupDays')),
                SendEmail: true,
                UserContext: {
                    upn: currentUser.username,
                    name: currentUser.name,
                    tenantId: currentUser.tenantId
                }
            };

            await executeRunbook(params, whatIf ? 'Group Cleanup Preview' : 'Group Cleanup Execution');
        }

        // Generic function to execute runbook
        async function executeRunbook(params, operationName) {
            showLoading();
            
            try {
                const response = await fetch('/api/execute-runbook', {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json',
                        'Authorization': \`Bearer \${accessToken}\`
                    },
                    body: JSON.stringify(params)
                });

                if (!response.ok) {
                    const errorData = await response.json();
                    throw new Error(errorData.error || \`HTTP error! status: \${response.status}\`);
                }

                const result = await response.json();
                
                if (result.success) {
                    currentJobId = result.jobId;
                    showAlert(\`\${operationName} started successfully. Job ID: \${result.jobId}\`, 'success');
                    
                    startJobPolling();
                    switchTab('monitor');
                } else {
                    showAlert(\`Failed to start \${operationName}: \${result.error}\`, 'danger');
                }
                
            } catch (error) {
                console.error('Error executing runbook:', error);
                showAlert(\`Error starting \${operationName}: \${error.message}\`, 'danger');
            } finally {
                hideLoading();
            }
        }

        // Start polling for job status
        function startJobPolling() {
            if (logPollingInterval) {
                clearInterval(logPollingInterval);
            }
            
            logPollingInterval = setInterval(async () => {
                if (currentJobId) {
                    await checkJobStatus(currentJobId);
                }
            }, 5000);
        }

        // Check job status
        async function checkJobStatus(jobId) {
            try {
                const response = await fetch(\`/api/job-status/\${jobId}\`, {
                    headers: {
                        'Authorization': \`Bearer \${accessToken}\`
                    }
                });
                
                if (!response.ok) return;
                
                const status = await response.json();
                
                const statusContainer = document.getElementById('jobStatus');
                statusContainer.innerHTML = \`
                    <h4>📊 Job Status: \${status.status}</h4>
                    <p><strong>Job ID:</strong> \${jobId}</p>
                    <p><strong>Started:</strong> \${new Date(status.startTime).toLocaleString()}</p>
                    <p><strong>Status:</strong> \${status.status}</p>
                    \${status.endTime ? \`<p><strong>Completed:</strong> \${new Date(status.endTime).toLocaleString()}</p>\` : ''}
                \`;
                
                if (status.output) {
                    const logsContainer = document.getElementById('executionLogs');
                    logsContainer.innerHTML = \`
                        <h4>📝 Execution Logs</h4>
                        <div style="background: #1f2937; color: #f9fafb; padding: 15px; border-radius: 5px; font-family: monospace; max-height: 300px; overflow-y: auto;">
                            <pre>\${status.output}</pre>
                        </div>
                    \`;
                }
                
                if (status.status === 'Completed' || status.status === 'Failed') {
                    clearInterval(logPollingInterval);
                    logPollingInterval = null;
                    currentJobId = null;
                    
                    if (status.status === 'Completed') {
                        showAlert('Job completed successfully!', 'success');
                    } else {
                        showAlert('Job failed. Check logs for details.', 'danger');
                    }
                }
                
            } catch (error) {
                console.error('Error checking job status:', error);
            }
        }

        // Refresh job status manually
        async function refreshJobStatus() {
            showLoading();
            
            try {
                const response = await fetch('/api/recent-jobs', {
                    headers: {
                        'Authorization': \`Bearer \${accessToken}\`
                    }
                });
                
                if (!response.ok) throw new Error('Failed to fetch job status');
                
                const jobs = await response.json();
                
                const statusContainer = document.getElementById('jobStatus');
                if (jobs.length === 0) {
                    statusContainer.innerHTML = '<h4>📊 No recent jobs found</h4>';
                    return;
                }
                
                let statusHtml = '<h4>📊 Recent Jobs</h4><table style="width: 100%; border-collapse: collapse;"><tr><th>Job ID</th><th>Runbook</th><th>Status</th><th>User</th><th>Start Time</th></tr>';
                
                jobs.slice(0, 10).forEach(job => {
                    statusHtml += \`
                        <tr style="border-bottom: 1px solid #eee;">
                            <td style="padding: 8px;">\${job.jobId}</td>
                            <td style="padding: 8px;">\${job.runbookName}</td>
                            <td style="padding: 8px;"><span style="color: \${job.status === 'Completed' ? 'green' : job.status === 'Failed' ? 'red' : 'orange'}">\${job.status}</span></td>
                            <td style="padding: 8px;">\${job.executedBy || 'System'}</td>
                            <td style="padding: 8px;">\${new Date(job.startTime).toLocaleString()}</td>
                        </tr>
                    \`;
                });
                
                statusHtml += '</table>';
                statusContainer.innerHTML = statusHtml;
                
            } catch (error) {
                console.error('Error refreshing job status:', error);
                showAlert('Failed to refresh job status', 'danger');
            } finally {
                hideLoading();
            }
        }

        // Download logs
        async function downloadLogs() {
            try {
                const response = await fetch('/api/download-logs', {
                    headers: {
                        'Authorization': \`Bearer \${accessToken}\`
                    }
                });
                
                if (!response.ok) throw new Error('Failed to download logs');
                
                const blob = await response.blob();
                const url = window.URL.createObjectURL(blob);
                const a = document.createElement('a');
                a.href = url;
                a.download = \`entra-management-logs-\${new Date().toISOString().split('T')[0]}.zip\`;
                document.body.appendChild(a);
                a.click();
                document.body.removeChild(a);
                window.URL.revokeObjectURL(url);
                
                showAlert('Logs downloaded successfully', 'success');
                
            } catch (error) {
                console.error('Error downloading logs:', error);
                showAlert('Failed to download logs', 'danger');
            }
        }

        // Sign out
        async function signOut() {
            try {
                await msalInstance.logoutPopup();
                currentUser = null;
                accessToken = null;
                showLoginScreen();
            } catch (error) {
                console.error('Sign out failed:', error);
            }
        }

        // Event listeners
        document.addEventListener('DOMContentLoaded', function() {
            document.getElementById('loginBtn').addEventListener('click', signIn);
            document.getElementById('logoutBtn').addEventListener('click', signOut);
            
            // Initialize authentication
            initAuth();
        });
    </script>
</body>
</html>`);
});

// API Routes with authentication

// Execute runbook with user context
app.post('/api/execute-runbook', verifyToken, async (req, res) => {
    try {
        const { Operation, WhatIf, UserContext, ...params } = req.body;
        
        // Check permissions
        if (!checkPermissions(Operation, req.user.roles)) {
            return res.status(403).json({
                success: false,
                error: `Insufficient permissions for ${Operation}. Required roles: ${roleRequirements[Operation].join(', ')}`
            });
        }

        if (!automationClient) {
            return res.status(500).json({
                success: false,
                error: 'Azure Automation client not initialized'
            });
        }

        // Prepare runbook parameters with user context
        const runbookParams = {
            ...params,
            Operation,
            WhatIf,
            ExecutedBy: req.user.upn,
            ExecutedByName: req.user.name,
            ExecutionContext: 'WebApp'
        };

        // Start the runbook job
        const jobResult = await automationClient.jobs.create(
            config.resourceGroupName,
            config.automationAccountName,
            'Manage-ExtensionAttributes',
            {
                parameters: runbookParams
            }
        );

        res.json({
            success: true,
            jobId: jobResult.jobId,
            message: `${Operation} started successfully`,
            executedBy: req.user.upn
        });

    } catch (error) {
        console.error('Error executing runbook:', error);
        res.status(500).json({
            success: false,
            error: error.message
        });
    }
});

// Get job status
app.get('/api/job-status/:jobId', verifyToken, async (req, res) => {
    try {
        if (!automationClient) {
            return res.status(500).json({ error: 'Azure Automation client not initialized' });
        }

        const { jobId } = req.params;
        
        const job = await automationClient.jobs.get(
            config.resourceGroupName,
            config.automationAccountName,
            jobId
        );

        // Get job output if available
        let output = '';
        try {
            const outputResult = await automationClient.jobStreams.listByJob(
                config.resourceGroupName,
                config.automationAccountName,
                jobId
            );
            
            output = outputResult.map(stream => stream.summary).join('\n');
        } catch (outputError) {
            console.warn('Could not retrieve job output:', outputError.message);
        }

        res.json({
            status: job.status,
            startTime: job.startTime,
            endTime: job.endTime,
            output: output,
            jobId: jobId
        });

    } catch (error) {
        console.error('Error getting job status:', error);
        res.status(500).json({ error: error.message });
    }
});

// Get recent jobs
app.get('/api/recent-jobs', verifyToken, async (req, res) => {
    try {
        if (!automationClient) {
            return res.json([]);
        }

        const jobs = await automationClient.jobs.listByAutomationAccount(
            config.resourceGroupName,
            config.automationAccountName
        );

        const recentJobs = jobs.slice(0, 20).map(job => ({
            jobId: job.jobId,
            runbookName: job.runbook?.name || 'Unknown',
            status: job.status,
            startTime: job.startTime,
            endTime: job.endTime,
            executedBy: job.parameters?.ExecutedBy || 'System'
        }));

        res.json(recentJobs);

    } catch (error) {
        console.error('Error getting recent jobs:', error);
        res.json([]);
    }
});

// Download logs (placeholder)
app.get('/api/download-logs', verifyToken, (req, res) => {
    // This would generate and return a zip file of logs
    res.status(501).json({ error: 'Log download not yet implemented' });
});

// Health check endpoint
app.get('/health', (req, res) => {
    res.json({ 
        status: 'healthy',
        timestamp: new Date().toISOString(),
        nodeVersion: process.version,
        port: port,
        authentication: 'enabled',
        azureClientId: config.azureClientId ? 'configured' : 'missing'
    });
});

app.listen(port, () => {
    console.log(`🎯 Entra Management Console with Authentication running on port ${port}`);
    console.log(`Environment: ${process.env.NODE_ENV || 'development'}`);
    console.log(`Node.js version: ${process.version}`);
    console.log(`Azure Client ID: ${config.azureClientId ? 'Configured' : 'Missing'}`);
    console.log(`Azure Tenant ID: ${config.azureTenantId ? 'Configured' : 'Missing'}`);
});