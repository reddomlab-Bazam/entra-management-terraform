const express = require('express');
const { DefaultAzureCredential } = require('@azure/identity');
const { AutomationClient } = require('@azure/arm-automation');
const path = require('path');
const fs = require('fs');

const app = express();
const port = process.env.PORT || 8080;

// Middleware
app.use(express.json());
app.use(express.static('public')); // Serve static files from public directory

// Azure configuration from environment variables
const subscriptionId = process.env.AZURE_SUBSCRIPTION_ID;
const resourceGroupName = process.env.RESOURCE_GROUP_NAME;
const automationAccountName = process.env.AUTOMATION_ACCOUNT_NAME;

// Initialize Azure clients
const credential = new DefaultAzureCredential();
let automationClient;

try {
    automationClient = new AutomationClient(credential, subscriptionId);
} catch (error) {
    console.warn('Azure automation client initialization failed:', error.message);
}

// Routes

// Main page - serve the management interface
app.get('/', (req, res) => {
    const htmlPath = path.join(__dirname, 'attribute-management.html');
    if (fs.existsSync(htmlPath)) {
        res.sendFile(htmlPath);
    } else {
        // Fallback to basic status page
        res.send(`
        <h1>🎯 Entra Management Console</h1>
        <div style="background: #d4edda; padding: 15px; border-radius: 5px; margin: 20px 0;">
            <h3>✅ Infrastructure Status</h3>
            <ul>
                <li>✅ Azure infrastructure deployed</li>
                <li>✅ Web app running on Node.js ${process.version}</li>
                <li>✅ IP restrictions active</li>
                <li>✅ Ready for configuration</li>
            </ul>
        </div>
        <div style="background: #fff3cd; padding: 15px; border-radius: 5px; margin: 20px 0;">
            <h3>⏳ Next Steps</h3>
            <ol>
                <li>Upload attribute-management.html to enable full interface</li>
                <li>Configure authentication variables</li>
                <li>Test runbook execution</li>
            </ol>
        </div>
        `);
    }
});

// Health check endpoint
app.get('/health', (req, res) => {
    res.json({ 
        status: 'healthy',
        timestamp: new Date().toISOString(),
        nodeVersion: process.version,
        port: port,
        azureConfig: {
            subscriptionId: subscriptionId ? 'configured' : 'missing',
            resourceGroup: resourceGroupName ? 'configured' : 'missing',
            automationAccount: automationAccountName ? 'configured' : 'missing'
        }
    });
});

// API endpoint to execute runbook
app.post('/api/execute-runbook', async (req, res) => {
    try {
        if (!automationClient) {
            return res.status(500).json({ 
                success: false, 
                error: 'Azure automation client not available' 
            });
        }

        const parameters = req.body;
        const runbookName = 'Manage-ExtensionAttributes';

        // Start the runbook job
        const jobResponse = await automationClient.job.create(
            resourceGroupName,
            automationAccountName,
            crypto.randomUUID(),
            {
                runbook: { name: runbookName },
                parameters: parameters
            }
        );

        res.json({
            success: true,
            jobId: jobResponse.name,
            message: 'Runbook started successfully'
        });

    } catch (error) {
        console.error('Error executing runbook:', error);
        res.status(500).json({
            success: false,
            error: error.message
        });
    }
});

// API endpoint to check job status
app.get('/api/job-status/:jobId', async (req, res) => {
    try {
        if (!automationClient) {
            return res.status(500).json({ error: 'Azure automation client not available' });
        }

        const jobId = req.params.jobId;
        
        const job = await automationClient.job.get(
            resourceGroupName,
            automationAccountName,
            jobId
        );

        // Get job output if available
        let output = '';
        try {
            const outputResponse = await automationClient.jobStream.listByJob(
                resourceGroupName,
                automationAccountName,
                jobId
            );
            
            if (outputResponse && outputResponse.length > 0) {
                output = outputResponse.map(stream => stream.text).join('\n');
            }
        } catch (outputError) {
            console.warn('Could not retrieve job output:', outputError.message);
        }

        res.json({
            status: job.status,
            startTime: job.startTime,
            endTime: job.endTime,
            output: output
        });

    } catch (error) {
        console.error('Error checking job status:', error);
        res.status(500).json({ error: error.message });
    }
});

// API endpoint to get recent jobs
app.get('/api/recent-jobs', async (req, res) => {
    try {
        if (!automationClient) {
            return res.status(500).json([]);
        }

        const jobs = await automationClient.job.listByAutomationAccount(
            resourceGroupName,
            automationAccountName
        );

        const recentJobs = jobs.slice(0, 10).map(job => ({
            jobId: job.name,
            runbookName: job.runbook ? job.runbook.name : 'Unknown',
            status: job.status,
            startTime: job.startTime,
            endTime: job.endTime
        }));

        res.json(recentJobs);

    } catch (error) {
        console.error('Error fetching recent jobs:', error);
        res.status(500).json([]);
    }
});

// API endpoint to download logs (placeholder)
app.get('/api/download-logs', (req, res) => {
    // This would typically create a zip file of logs
    // For now, return a simple text file
    res.setHeader('Content-Type', 'application/octet-stream');
    res.setHeader('Content-Disposition', 'attachment; filename="logs.txt"');
    res.send('Log download functionality - to be implemented');
});

// API endpoint to update schedule (placeholder)
app.post('/api/update-schedule', (req, res) => {
    // This would update the automation account schedule
    console.log('Schedule update requested:', req.body);
    res.json({ success: true, message: 'Schedule update functionality - to be implemented' });
});

// API endpoint to get current schedule (placeholder)
app.get('/api/current-schedule', (req, res) => {
    res.json({
        enabled: false,
        frequency: 'Week'
    });
});

// Error handling middleware
app.use((error, req, res, next) => {
    console.error('Server error:', error);
    res.status(500).json({ error: 'Internal server error' });
});

// Start server
app.listen(port, () => {
    console.log(`🎯 Entra Management Console running on port ${port}`);
    console.log(`Environment: ${process.env.NODE_ENV || 'development'}`);
    console.log(`Node.js version: ${process.version}`);
});

module.exports = app;