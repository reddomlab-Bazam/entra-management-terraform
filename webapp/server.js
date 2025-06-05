const express = require('express');
const { DefaultAzureCredential } = require('@azure/identity');
const { AutomationClient } = require('@azure/arm-automation');
const { StorageSharedKeyCredential, ShareServiceClient } = require('@azure/storage-file-share');
const path = require('path');
const archiver = require('archiver');
require('dotenv').config();

const app = express();
const port = process.env.PORT || 3000;

// Middleware
app.use(express.json());
app.use(express.static('public'));

// Azure credentials and clients
const credential = new DefaultAzureCredential();
let automationClient;
let shareServiceClient;

// Configuration from environment variables
const config = {
    subscriptionId: process.env.AZURE_SUBSCRIPTION_ID,
    resourceGroupName: process.env.RESOURCE_GROUP_NAME,
    automationAccountName: process.env.AUTOMATION_ACCOUNT_NAME,
    storageAccountName: process.env.STORAGE_ACCOUNT_NAME,
    fileShareName: process.env.FILE_SHARE_NAME,
    runbookName: 'Extension-Attribute-Management'
};

// Initialize Azure clients
async function initializeClients() {
    try {
        automationClient = new AutomationClient(credential, config.subscriptionId);
        
        // For storage, we'll use managed identity
        const storageCredential = new DefaultAzureCredential();
        const storageAccountUrl = `https://${config.storageAccountName}.file.core.windows.net`;
        shareServiceClient = new ShareServiceClient(storageAccountUrl, storageCredential);
        
        console.log('Azure clients initialized successfully');
    } catch (error) {
        console.error('Failed to initialize Azure clients:', error);
        process.exit(1);
    }
}

// API Routes

// Execute runbook
app.post('/api/execute-runbook', async (req, res) => {
    try {
        const { 
            Operation, 
            WhatIf, 
            ExtensionAttributeNumber, 
            AttributeValue, 
            UsersToAdd, 
            UsersToRemove,
            MaxDevices,
            ExcludeAzureVMs,
            GroupName,
            GroupCleanupDays,
            SendEmail 
        } = req.body;

        // Validate inputs
        if (!Operation) {
            return res.status(400).json({ success: false, error: 'Operation is required' });
        }

        // Prepare runbook parameters
        const parameters = {
            Operation: Operation,
            WhatIf: WhatIf || true,
            SendEmail: SendEmail || true
        };

        // Add operation-specific parameters
        if (Operation === 'ExtensionAttributes' || Operation === 'All') {
            if (ExtensionAttributeNumber) parameters.ExtensionAttributeNumber = ExtensionAttributeNumber;
            if (AttributeValue) parameters.AttributeValue = AttributeValue;
            if (UsersToAdd) parameters.UsersToAdd = UsersToAdd;
            if (UsersToRemove) parameters.UsersToRemove = UsersToRemove;
        }

        if (Operation === 'DeviceCleanup' || Operation === 'All') {
            if (MaxDevices) parameters.MaxDevices = MaxDevices;
            if (ExcludeAzureVMs !== undefined) parameters.ExcludeAzureVMs = ExcludeAzureVMs;
        }

        if (Operation === 'GroupCleanup' || Operation === 'All') {
            if (GroupName) parameters.GroupName = GroupName;
            if (GroupCleanupDays) parameters.GroupCleanupDays = GroupCleanupDays;
        }

        // Start the runbook job
        const jobResponse = await automationClient.job.create(
            config.resourceGroupName,
            config.automationAccountName,
            generateJobId(),
            {
                runbook: { name: config.runbookName },
                parameters: parameters
            }
        );

        console.log(`Started runbook job: ${jobResponse.name}`);
        
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

// Get job status
app.get('/api/job-status/:jobId', async (req, res) => {
    try {
        const { jobId } = req.params;
        
        const job = await automationClient.job.get(
            config.resourceGroupName,
            config.automationAccountName,
            jobId
        );

        // Get job output if available
        let output = '';
        try {
            if (job.status === 'Completed' || job.status === 'Failed' || job.status === 'Running') {
                const outputResponse = await automationClient.jobStream.listByJob(
                    config.resourceGroupName,
                    config.automationAccountName,
                    jobId
                );
                
                output = outputResponse.map(stream => stream.summary).join('\n');
            }
        } catch (outputError) {
            console.warn('Could not fetch job output:', outputError.message);
        }

        res.json({
            jobId: job.name,
            status: job.status,
            startTime: job.startTime,
            endTime: job.endTime,
            output: output
        });

    } catch (error) {
        console.error('Error getting job status:', error);
        res.status(500).json({ error: error.message });
    }
});

// Get recent jobs
app.get('/api/recent-jobs', async (req, res) => {
    try {
        const jobs = await automationClient.job.listByAutomationAccount(
            config.resourceGroupName,
            config.automationAccountName,
            {
                filter: `properties/runbook/name eq '${config.runbookName}'`
            }
        );

        const recentJobs = [];
        for await (const job of jobs) {
            recentJobs.push({
                jobId: job.name,
                runbookName: job.runbook?.name,
                status: job.status,
                startTime: job.startTime,
                endTime: job.endTime
            });
        }

        // Sort by start time (most recent first)
        recentJobs.sort((a, b) => new Date(b.startTime) - new Date(a.startTime));

        res.json(recentJobs.slice(0, 20)); // Return last 20 jobs

    } catch (error) {
        console.error('Error getting recent jobs:', error);
        res.status(500).json({ error: error.message });
    }
});

// Download logs
app.get('/api/download-logs', async (req, res) => {
    try {
        const shareClient = shareServiceClient.getShareClient(config.fileShareName);
        const logsDirectoryClient = shareClient.getDirectoryClient('logs');
        
        // Create zip archive
        const archive = archiver('zip', { zlib: { level: 9 } });
        
        res.setHeader('Content-Type', 'application/zip');
        res.setHeader('Content-Disposition', `attachment; filename="entra-logs-${new Date().toISOString().split('T')[0]}.zip"`);
        
        archive.pipe(res);

        try {
            // List files in logs directory
            const filesIterator = logsDirectoryClient.listFilesAndDirectories();
            
            for await (const item of filesIterator) {
                if (item.kind === 'file') {
                    try {
                        const fileClient = logsDirectoryClient.getFileClient(item.name);
                        const downloadResponse = await fileClient.download();
                        
                        if (downloadResponse.readableStreamBody) {
                            archive.append(downloadResponse.readableStreamBody, { name: item.name });
                        }
                    } catch (fileError) {
                        console.warn(`Could not download file ${item.name}:`, fileError.message);
                    }
                }
            }
        } catch (listError) {
            console.warn('Could not list log files:', listError.message);
            // Add a notice file to the zip
            archive.append('No log files found or logs directory not accessible', { name: 'notice.txt' });
        }

        await archive.finalize();

    } catch (error) {
        console.error('Error downloading logs:', error);
        res.status(500).json({ error: error.message });
    }
});

// Update schedule
app.post('/api/update-schedule', async (req, res) => {
    try {
        const { enableSchedule, scheduleFrequency } = req.body;
        
        const scheduleName = 'weekly-extension-attribute-update';
        
        if (enableSchedule) {
            // Create or update schedule
            const scheduleParams = {
                frequency: scheduleFrequency || 'Week',
                interval: 1,
                timeZone: 'Europe/London',
                startTime: new Date(Date.now() + 24 * 60 * 60 * 1000), // Start tomorrow
                description: 'Automated Entra management execution'
            };

            if (scheduleFrequency === 'Week') {
                scheduleParams.weekDays = ['Sunday'];
            }

            await automationClient.schedule.createOrUpdate(
                config.resourceGroupName,
                config.automationAccountName,
                scheduleName,
                scheduleParams
            );

            // Link schedule to runbook
            await automationClient.jobSchedule.create(
                config.resourceGroupName,
                config.automationAccountName,
                generateJobScheduleId(),
                {
                    schedule: { name: scheduleName },
                    runbook: { name: config.runbookName },
                    parameters: {
                        Operation: 'All',
                        WhatIf: false,
                        SendEmail: true
                    }
                }
            );

        } else {
            // Disable schedule by deleting job schedule link
            try {
                const jobSchedules = await automationClient.jobSchedule.listByAutomationAccount(
                    config.resourceGroupName,
                    config.automationAccountName
                );

                for await (const jobSchedule of jobSchedules) {
                    if (jobSchedule.schedule?.name === scheduleName && 
                        jobSchedule.runbook?.name === config.runbookName) {
                        await automationClient.jobSchedule.delete(
                            config.resourceGroupName,
                            config.automationAccountName,
                            jobSchedule.jobScheduleId
                        );
                    }
                }
            } catch (deleteError) {
                console.warn('Error deleting job schedule:', deleteError.message);
            }
        }

        res.json({ success: true, message: 'Schedule updated successfully' });

    } catch (error) {
        console.error('Error updating schedule:', error);
        res.status(500).json({ error: error.message });
    }
});

// Get current schedule
app.get('/api/current-schedule', async (req, res) => {
    try {
        const scheduleName = 'weekly-extension-attribute-update';
        
        try {
            const schedule = await automationClient.schedule.get(
                config.resourceGroupName,
                config.automationAccountName,
                scheduleName
            );

            // Check if schedule is linked to runbook
            const jobSchedules = await automationClient.jobSchedule.listByAutomationAccount(
                config.resourceGroupName,
                config.automationAccountName
            );

            let isLinked = false;
            for await (const jobSchedule of jobSchedules) {
                if (jobSchedule.schedule?.name === scheduleName && 
                    jobSchedule.runbook?.name === config.runbookName) {
                    isLinked = true;
                    break;
                }
            }

            res.json({
                enabled: isLinked,
                frequency: schedule.frequency,
                nextRun: schedule.nextRun,
                lastModified: schedule.lastModifiedTime
            });

        } catch (getError) {
            // Schedule doesn't exist
            res.json({
                enabled: false,
                frequency: 'Week',
                nextRun: null,
                lastModified: null
            });
        }

    } catch (error) {
        console.error('Error getting current schedule:', error);
        res.status(500).json({ error: error.message });
    }
});

// Serve the main HTML file
app.get('/', (req, res) => {
    res.sendFile(path.join(__dirname, 'public', 'index.html'));
});

// Health check endpoint
app.get('/health', (req, res) => {
    res.json({ 
        status: 'healthy', 
        timestamp: new Date().toISOString(),
        config: {
            resourceGroup: config.resourceGroupName,
            automationAccount: config.automationAccountName,
            runbook: config.runbookName
        }
    });
});

// Utility functions
function generateJobId() {
    return `job-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
}

function generateJobScheduleId() {
    return `jobschedule-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
}

// Error handling middleware
app.use((error, req, res, next) => {
    console.error('Unhandled error:', error);
    res.status(500).json({ error: 'Internal server error' });
});

// Initialize and start server
async function startServer() {
    await initializeClients();
    
    app.listen(port, () => {
        console.log(`Entra Management Web Interface running on port ${port}`);
        console.log(`Resource Group: ${config.resourceGroupName}`);
        console.log(`Automation Account: ${config.automationAccountName}`);
        console.log(`Storage Account: ${config.storageAccountName}`);
    });
}

// Handle graceful shutdown
process.on('SIGINT', () => {
    console.log('Shutting down gracefully...');
    process.exit(0);
});

process.on('SIGTERM', () => {
    console.log('Received SIGTERM, shutting down gracefully...');
    process.exit(0);
});

// Start the server
startServer().catch(error => {
    console.error('Failed to start server:', error);
    process.exit(1);
});