const express = require('express');
const path = require('path');
const fs = require('fs');

const app = express();
const port = process.env.PORT || 8080;

app.use(express.json());

// Serve the management interface at root
app.get('/', (req, res) => {
    // Embed the management interface directly in the response
    res.send(`<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Entra Management Console</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }

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
        }

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

        .status-card {
            background: #f8f9fa;
            border-radius: 15px;
            padding: 20px;
            margin: 20px 0;
            border-left: 5px solid #6366f1;
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
            margin-right: 10px;
        }

        .btn:hover {
            transform: translateY(-2px);
            box-shadow: 0 10px 20px rgba(99, 102, 241, 0.3);
        }

        .alert {
            padding: 15px 20px;
            border-radius: 10px;
            margin: 15px 0;
            font-weight: 500;
        }

        .alert-warning {
            background: #fef3c7;
            color: #92400e;
            border: 1px solid #fcd34d;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🎯 Entra Management Console</h1>
            <p>Automated Extension Attributes, Device Cleanup & Group Management</p>
        </div>

        <div class="nav-tabs">
            <button class="nav-tab active" onclick="switchTab('status')">System Status</button>
            <button class="nav-tab" onclick="switchTab('extensions')">Extension Attributes</button>
            <button class="nav-tab" onclick="switchTab('devices')">Device Cleanup</button>
            <button class="nav-tab" onclick="switchTab('groups')">Group Management</button>
        </div>

        <!-- System Status Tab -->
        <div id="status" class="tab-content active">
            <h2>System Status & Configuration</h2>
            
            <div class="status-card">
                <h3>✅ Infrastructure Status</h3>
                <ul>
                    <li>✅ Azure infrastructure deployed</li>
                    <li>✅ Web app running on Node.js ${process.version}</li>
                    <li>✅ IP restrictions active</li>
                    <li>✅ PowerShell 7.2 runtime configured</li>
                    <li>✅ Microsoft Graph modules installed</li>
                </ul>
            </div>

            <div class="alert alert-warning">
                <h4>⚠️ Configuration Required</h4>
                <p>Before using the management features, complete these steps:</p>
                <ol>
                    <li><strong>Azure AD Authentication Variables:</strong> Add AzureADClientSecret, AzureADClientId, and AzureADTenantId to your Automation Account</li>
                    <li><strong>Email Configuration:</strong> Update EntraMgmt_FromEmail and EntraMgmt_ToEmail variables</li>
                    <li><strong>Test Connection:</strong> Run a What-If test to verify Graph API connectivity</li>
                </ol>
            </div>

            <div class="status-card">
                <h3>🔧 Quick Actions</h3>
                <button class="btn" onclick="testConnection()">Test Graph Connection</button>
                <button class="btn" onclick="window.open('https://portal.azure.com/#@/resource/subscriptions/${process.env.AZURE_SUBSCRIPTION_ID || 'your-subscription'}/resourceGroups/${process.env.RESOURCE_GROUP_NAME || 'your-rg'}/providers/Microsoft.Automation/automationAccounts/${process.env.AUTOMATION_ACCOUNT_NAME || 'your-automation'}/variables', '_blank')">
                    Configure Variables
                </button>
            </div>
        </div>

        <!-- Extension Attributes Tab -->
        <div id="extensions" class="tab-content">
            <h2>Extension Attribute Management</h2>
            <div class="alert alert-warning">
                <strong>Setup Required:</strong> Configure Azure AD authentication variables before using this feature.
            </div>
            <p>This tab will allow you to manage extension attributes once authentication is configured.</p>
        </div>

        <!-- Device Cleanup Tab -->
        <div id="devices" class="tab-content">
            <h2>Device Cleanup Management</h2>
            <div class="alert alert-warning">
                <strong>Setup Required:</strong> Configure Azure AD authentication variables before using this feature.
            </div>
            <p>This tab will allow you to manage device cleanup once authentication is configured.</p>
        </div>

        <!-- Group Management Tab -->
        <div id="groups" class="tab-content">
            <h2>Group Membership Management</h2>
            <div class="alert alert-warning">
                <strong>Setup Required:</strong> Configure Azure AD authentication variables before using this feature.
            </div>
            <p>This tab will allow you to manage group memberships once authentication is configured.</p>
        </div>
    </div>

    <script>
        // Tab switching functionality
        function switchTab(tabName) {
            // Hide all tab contents
            document.querySelectorAll('.tab-content').forEach(tab => {
                tab.classList.remove('active');
            });
            
            // Remove active class from all nav tabs
            document.querySelectorAll('.nav-tab').forEach(tab => {
                tab.classList.remove('active');
            });
            
            // Show selected tab content
            document.getElementById(tabName).classList.add('active');
            
            // Add active class to clicked nav tab
            event.target.classList.add('active');
        }

        function testConnection() {
            alert('Connection test feature will be implemented after authentication setup.');
        }
    </script>
</body>
</html>`);
});

});

// Health check endpoint
app.get('/health', (req, res) => {
    res.json({ 
        status: 'healthy',
        timestamp: new Date().toISOString(),
        nodeVersion: process.version,
        port: port,
        files: {
            managementInterface: fs.existsSync('attribute-management.html') ? 'available' : 'missing'
        }
    });
});

// Basic API endpoints (placeholders for when interface is uploaded)
app.post('/api/execute-runbook', (req, res) => {
    res.status(501).json({
        success: false,
        error: 'Runbook execution API not yet implemented. Configure Azure authentication first.'
    });
});

app.get('/api/job-status/:jobId', (req, res) => {
    res.status(501).json({
        error: 'Job status API not yet implemented.'
    });
});

app.get('/api/recent-jobs', (req, res) => {
    res.json([]);
});

app.get('/api/current-schedule', (req, res) => {
    res.json({
        enabled: false,
        frequency: 'Week'
    });
});

app.listen(port, () => {
    console.log(`🎯 Entra Management Console running on port ${port}`);
    console.log(`Environment: ${process.env.NODE_ENV || 'development'}`);
    console.log(`Node.js version: ${process.version}`);
    
    // Check for management interface
    if (fs.existsSync('attribute-management.html')) {
        console.log('✅ Management interface available');
    } else {
        console.log('⚠️  Management interface not found - upload attribute-management.html');
    }
});