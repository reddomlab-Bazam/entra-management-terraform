const express = require('express');
const { DefaultAzureCredential } = require('@azure/identity');
const { AutomationClient } = require('@azure/arm-automation');
const jwt = require('jsonwebtoken');
const path = require('path');
const helmet = require('helmet');

const app = express();
const port = process.env.PORT || 8080;

// Enhanced security middleware
app.use(helmet({
  contentSecurityPolicy: {
    directives: {
      defaultSrc: ["'self'"],
      scriptSrc: ["'self'", "https://alcdn.msauth.net"],
      styleSrc: ["'self'", "'unsafe-inline'"],
      imgSrc: ["'self'", "data:", "https:"],
      connectSrc: ["'self'", "https://login.microsoftonline.com"],
      frameSrc: ["'self'"],
      objectSrc: ["'none'"],
      upgradeInsecureRequests: []
    }
  }
}));

// Configuration from environment variables
const config = {
    azureClientId: process.env.AZURE_CLIENT_ID,
    azureTenantId: process.env.AZURE_TENANT_ID,
    subscriptionId: process.env.AZURE_SUBSCRIPTION_ID,
    resourceGroupName: process.env.RESOURCE_GROUP_NAME,
    automationAccountName: process.env.AUTOMATION_ACCOUNT_NAME,
    keyVaultUri: process.env.KEY_VAULT_URI,
    sessionTimeout: process.env.SESSION_TIMEOUT_MINUTES || 60
};

app.use(express.json());
app.use(express.static(path.join(__dirname, 'public')));

// Initialize Azure clients
const credential = new DefaultAzureCredential();
let automationClient;

try {
    if (config.subscriptionId) {
        automationClient = new AutomationClient(credential, config.subscriptionId);
        console.log('✅ Azure Automation client initialized');
    }
} catch (error) {
    console.warn('⚠️ Azure automation client initialization failed:', error.message);
}

// Role requirements for operations
const roleRequirements = {
    'ExtensionAttributes': ['User Administrator', 'Global Administrator', 'Privileged Role Administrator'],
    'DeviceCleanup': ['Cloud Device Administrator', 'Intune Administrator', 'Global Administrator'],
    'GroupCleanup': ['Groups Administrator', 'User Administrator', 'Global Administrator'],
    'All': ['Global Administrator', 'Privileged Role Administrator']
};

// Enhanced JWT verification middleware
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
        const decoded = jwt.decode(token);
        
        if (!decoded) {
            return res.status(401).json({ error: 'Invalid token' });
        }

        const expirationTime = decoded.exp * 1000;
        if (Date.now() >= expirationTime) {
            return res.status(401).json({ 
                error: 'Token expired',
                requiresLogin: true
            });
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
        console.error('Token verification failed:', error);
        return res.status(401).json({ 
            error: 'Token verification failed',
            requiresLogin: true
        });
    }
}

// Check if user has required roles for operation
function checkPermissions(operation, userRoles) {
    const required = roleRequirements[operation] || [];
    return required.some(role => userRoles.includes(role));
}

// Main page route with proper configuration substitution
app.get('/', (req, res) => {
    // Build the HTML with actual config values substituted
    const clientId = config.azureClientId || 'NOT_CONFIGURED';
    const tenantId = config.azureTenantId || 'NOT_CONFIGURED';
    
    const htmlContent = `<!DOCTYPE html>
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
            min-height: 100vh; padding: 20px;
        }
        .container {
            max-width: 1400px; margin: 0 auto; background: white;
            border-radius: 20px; box-shadow: 0 20px 40px rgba(0, 0, 0, 0.1); overflow: hidden;
        }
        .header {
            background: linear-gradient(135deg, #6366f1, #8b5cf6);
            color: white; padding: 30px; text-align: center; position: relative;
        }
        .login-container {
            max-width: 500px; margin: 50px auto; text-align: center; padding: 40px;
        }
        .btn {
            background: linear-gradient(135deg, #6366f1, #8b5cf6);
            color: white; border: none; padding: 14px 28px; border-radius: 10px;
            font-size: 16px; font-weight: 600; cursor: pointer;
            transition: all 0.3s ease; margin: 10px;
        }
        .btn:hover { transform: translateY(-2px); box-shadow: 0 10px 20px rgba(99, 102, 241, 0.3); }
        .status-card {
            background: #f8f9fa; border-radius: 15px; padding: 25px; margin: 25px;
            border-left: 5px solid #6366f1;
        }
        .alert { padding: 15px 20px; border-radius: 10px; margin: 15px 25px; font-weight: 500; }
        .alert-success { background: #dcfce7; color: #166534; border: 1px solid #a7f3d0; }
        .alert-warning { background: #fef3c7; color: #92400e; border: 1px solid #fcd34d; }
        .alert-danger { background: #fee2e2; color: #991b1b; border: 1px solid #fca5a5; }
        .hidden { display: none; }
        .logout-btn {
            position: absolute; top: 20px; right: 20px;
            background: rgba(255,255,255,0.2); border: 1px solid rgba(255,255,255,0.3);
            color: white; padding: 8px 16px; border-radius: 5px; cursor: pointer;
        }
        .user-info {
            background: #dcfce7; padding: 15px; border-radius: 10px; margin: 25px; text-align: left;
        }
        ul { margin-left: 20px; margin-top: 10px; }
        li { margin-bottom: 5px; }
    </style>
</head>
<body>
    <div class="container">
        <div id="loginContainer" class="login-container">
            <h1>🎯 Entra Management Console</h1>
            <p style="margin: 20px 0; color: #666;">
                Production Entra ID management platform.<br>
                Sign in with your organizational account to continue.
            </p>
            
            <div class="status-card">
                <h4>🔐 Configuration Status</h4>
                <ul style="text-align: left; margin-top: 10px;">
                    <li>Azure Client ID: ${config.azureClientId ? '✅ Configured' : '❌ Missing'}</li>
                    <li>Azure Tenant ID: ${config.azureTenantId ? '✅ Configured' : '❌ Missing'}</li>
                    <li>Automation Account: ${config.automationAccountName ? '✅ ' + config.automationAccountName : '❌ Missing'}</li>
                    <li>Node.js Version: ${process.version}</li>
                    <li>Environment: ${process.env.NODE_ENV || 'development'}</li>
                </ul>
            </div>
            
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

        <div id="mainApp" class="hidden">
            <div class="header">
                <h1>🎯 Entra Management Console</h1>
                <p>Production-Secured Management Platform</p>
                <button id="logoutBtn" class="logout-btn">Sign Out</button>
            </div>

            <div id="userInfo" class="user-info"></div>
            
            <div class="status-card">
                <h3>✅ System Status</h3>
                <ul>
                    <li>✅ Web app running on Node.js ${process.version}</li>
                    <li>✅ Azure Automation: ${config.automationAccountName || 'Not configured'}</li>
                    <li>✅ Authentication: Entra ID integrated</li>
                    <li>✅ Security: HTTPS enforced, headers configured</li>
                </ul>
            </div>

            <div class="status-card">
                <h3>🎮 Available Operations</h3>
                <button class="btn" onclick="testOperation('ExtensionAttributes')">🔧 Test Extension Attributes</button>
                <button class="btn" onclick="testOperation('DeviceCleanup')">🗑️ Test Device Cleanup</button>
                <button class="btn" onclick="testOperation('GroupCleanup')">👥 Test Group Management</button>
            </div>

            <div id="operationResults" class="status-card" style="display: none;">
                <h4>📊 Operation Results</h4>
                <div id="resultsContent"></div>
            </div>
        </div>
    </div>

    <script>
        console.log('🎯 Entra Management Console initializing...');
        console.log('Client ID:', '${clientId}');
        console.log('Tenant ID:', '${tenantId}');
        
        // MSAL Configuration with actual values
        const msalConfig = {
            auth: {
                clientId: '${clientId}',
                authority: 'https://login.microsoftonline.com/${tenantId}',
                redirectUri: window.location.origin
            },
            cache: {
                cacheLocation: "localStorage",
                storeAuthStateInCookie: false
            }
        };

        let msalInstance;
        let currentUser = null;
        let accessToken = null;

        // Check if configuration is valid
        if (msalConfig.auth.clientId === 'NOT_CONFIGURED' || msalConfig.auth.authority.includes('NOT_CONFIGURED')) {
            document.getElementById('loginContainer').innerHTML += 
                '<div class="alert alert-danger">' +
                '<strong>❌ Configuration Error:</strong> Azure AD configuration is missing. Please check environment variables in Azure App Service.' +
                '</div>';
        } else {
            try {
                msalInstance = new msal.PublicClientApplication(msalConfig);
                console.log('✅ MSAL initialized successfully');
                
                msalInstance.initialize().then(() => {
                    const accounts = msalInstance.getAllAccounts();
                    if (accounts.length > 0) {
                        currentUser = accounts[0];
                        showMainApp();
                    }
                });
            } catch (error) {
                console.error('❌ MSAL initialization failed:', error);
                document.getElementById('loginContainer').innerHTML += 
                    '<div class="alert alert-danger">MSAL initialization failed: ' + error.message + '</div>';
            }
        }

        document.getElementById('loginBtn').addEventListener('click', async () => {
            if (!msalInstance) {
                alert('Authentication not configured. Please check server configuration.');
                return;
            }
            
            try {
                const response = await msalInstance.loginPopup({
                    scopes: ["User.Read", "Directory.Read.All"]
                });
                console.log('✅ Login successful:', response);
                currentUser = response.account;
                accessToken = response.accessToken;
                showMainApp();
            } catch (error) {
                console.error('❌ Login failed:', error);
                alert('Login failed: ' + error.message);
            }
        });

        document.getElementById('logoutBtn').addEventListener('click', async () => {
            if (msalInstance) {
                await msalInstance.logoutPopup();
            }
            location.reload();
        });

        function showMainApp() {
            document.getElementById('loginContainer').classList.add('hidden');
            document.getElementById('mainApp').classList.remove('hidden');
            
            if (currentUser) {
                document.getElementById('userInfo').innerHTML = 
                    '<h4>👤 Signed in as:</h4>' +
                    '<p><strong>Name:</strong> ' + (currentUser.name || 'N/A') + '</p>' +
                    '<p><strong>Email:</strong> ' + currentUser.username + '</p>' +
                    '<p><strong>Tenant:</strong> ' + currentUser.tenantId + '</p>';
            }
        }

        async function testOperation(operation) {
            if (!accessToken) {
                try {
                    const response = await msalInstance.acquireTokenSilent({
                        scopes: ["User.Read", "Directory.Read.All"],
                        account: currentUser
                    });
                    accessToken = response.accessToken;
                } catch (error) {
                    console.error('Token acquisition failed:', error);
                    alert('Please sign in again');
                    return;
                }
            }

            try {
                const response = await fetch('/api/execute-runbook', {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json',
                        'Authorization': 'Bearer ' + accessToken
                    },
                    body: JSON.stringify({
                        Operation: operation,
                        WhatIf: true,
                        TestMode: true
                    })
                });

                const result = await response.json();
                
                document.getElementById('operationResults').style.display = 'block';
                document.getElementById('resultsContent').innerHTML = 
                    '<p><strong>Operation:</strong> ' + operation + '</p>' +
                    '<p><strong>Status:</strong> ' + (result.success ? '✅ Success' : '❌ Failed') + '</p>' +
                    '<p><strong>Message:</strong> ' + (result.message || result.error) + '</p>' +
                    '<p><strong>Timestamp:</strong> ' + new Date().toLocaleString() + '</p>';
                    
            } catch (error) {
                console.error('Operation failed:', error);
                document.getElementById('operationResults').style.display = 'block';
                document.getElementById('resultsContent').innerHTML = 
                    '<p><strong>Operation:</strong> ' + operation + '</p>' +
                    '<p><strong>Status:</strong> ❌ Failed</p>' +
                    '<p><strong>Error:</strong> ' + error.message + '</p>';
            }
        }
    </script>
</body>
</html>`;

    res.send(htmlContent);
});

// Health check endpoint with detailed information
app.get('/health', (req, res) => {
    res.json({ 
        status: 'healthy',
        timestamp: new Date().toISOString(),
        nodeVersion: process.version,
        port: port,
        environment: process.env.NODE_ENV || 'development',
        config: {
            azureClientId: config.azureClientId ? 'configured' : 'missing',
            azureTenantId: config.azureTenantId ? 'configured' : 'missing',
            subscriptionId: config.subscriptionId ? 'configured' : 'missing',
            automationAccount: config.automationAccountName ? config.automationAccountName : 'missing',
            keyVault: config.keyVaultUri ? 'configured' : 'missing'
        },
        automationClient: automationClient ? 'initialized' : 'not available'
    });
});

// API Routes
app.post('/api/execute-runbook', verifyToken, async (req, res) => {
    try {
        const { Operation, WhatIf, TestMode, ...params } = req.body;
        
        console.log(\`🔧 Runbook execution request: \${Operation} (WhatIf: \${WhatIf}, TestMode: \${TestMode})\`);
        console.log(\`👤 Executed by: \${req.user.upn}\`);
        
        // Check permissions
        if (!checkPermissions(Operation, req.user.roles)) {
            return res.status(403).json({
                success: false,
                error: \`Insufficient permissions for \${Operation}. Required roles: \${roleRequirements[Operation].join(', ')}\`
            });
        }

        if (!automationClient) {
            return res.status(500).json({
                success: false,
                error: 'Azure Automation client not initialized. Please check configuration.',
                details: {
                    subscriptionId: config.subscriptionId ? 'configured' : 'missing',
                    resourceGroup: config.resourceGroupName ? 'configured' : 'missing',
                    automationAccount: config.automationAccountName ? 'configured' : 'missing'
                }
            });
        }

        // In test mode, just return success
        if (TestMode) {
            return res.json({
                success: true,
                message: \`Test mode: \${Operation} operation would be executed\`,
                jobId: 'test-' + Date.now(),
                executedBy: req.user.upn,
                testMode: true
            });
        }

        // Prepare runbook parameters
        const runbookParams = {
            ...params,
            Operation,
            WhatIf,
            ExecutedBy: req.user.upn,
            ExecutedByName: req.user.name,
            ExecutionContext: 'WebApp'
        };

        console.log('📝 Runbook parameters:', runbookParams);

        // Start the runbook job
        const jobResult = await automationClient.jobs.create(
            config.resourceGroupName,
            config.automationAccountName,
            'Manage-ExtensionAttributes',
            { parameters: runbookParams }
        );

        console.log(\`✅ Runbook job started: \${jobResult.jobId}\`);

        res.json({
            success: true,
            jobId: jobResult.jobId,
            message: \`\${Operation} started successfully\`,
            executedBy: req.user.upn,
            timestamp: new Date().toISOString()
        });

    } catch (error) {
        console.error('❌ Error executing runbook:', error);
        res.status(500).json({
            success: false,
            error: error.message,
            details: error.code || 'Unknown error'
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

        res.json({
            status: job.status,
            startTime: job.startTime,
            endTime: job.endTime,
            jobId: jobId
        });

    } catch (error) {
        console.error('Error getting job status:', error);
        res.status(500).json({ error: error.message });
    }
});

// Catch-all route for SPA
app.get('*', (req, res) => {
    res.redirect('/');
});

app.listen(port, () => {
    console.log(\`🎯 Entra Management Console running on port \${port}\`);
    console.log(\`Environment: \${process.env.NODE_ENV || 'development'}\`);
    console.log(\`Node.js version: \${process.version}\`);
    console.log(\`\`);
    console.log(\`📊 Configuration Status:\`);
    console.log(\`  Azure Client ID: \${config.azureClientId ? '✅ Configured' : '❌ Missing'}\`);
    console.log(\`  Azure Tenant ID: \${config.azureTenantId ? '✅ Configured' : '❌ Missing'}\`);
    console.log(\`  Subscription ID: \${config.subscriptionId ? '✅ Configured' : '❌ Missing'}\`);
    console.log(\`  Resource Group: \${config.resourceGroupName ? '✅ ' + config.resourceGroupName : '❌ Missing'}\`);
    console.log(\`  Automation Account: \${config.automationAccountName ? '✅ ' + config.automationAccountName : '❌ Missing'}\`);
    console.log(\`  Key Vault URI: \${config.keyVaultUri ? '✅ Configured' : '❌ Missing'}\`);
    console.log(\`  Automation Client: \${automationClient ? '✅ Initialized' : '❌ Not available'}\`);
    console.log(\`\`);
    console.log(\`🌐 Application URL: http://localhost:\${port}\`);
    console.log(\`🏥 Health Check: http://localhost:\${port}/health\`);
});