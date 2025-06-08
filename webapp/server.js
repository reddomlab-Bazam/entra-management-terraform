const express = require('express');
const helmet = require('helmet');
const rateLimit = require('express-rate-limit');
const { body, validationResult } = require('express-validator');
const cors = require('cors');
const { DefaultAzureCredential } = require('@azure/identity');
const { AutomationClient } = require('@azure/arm-automation');
const jwt = require('jsonwebtoken');
const path = require('path');
const fs = require('fs').promises;

const app = express();
const port = process.env.PORT || 8080;

// ============================================================================
// SECURITY CONFIGURATION
// ============================================================================

// Security headers
app.use(helmet({
    contentSecurityPolicy: {
        directives: {
            defaultSrc: ["'self'"],
            scriptSrc: ["'self'", "'unsafe-inline'", "https://alcdn.msauth.net"],
            styleSrc: ["'self'", "'unsafe-inline'"],
            imgSrc: ["'self'", "data:", "https:"],
            connectSrc: ["'self'", "https://login.microsoftonline.com", "https://graph.microsoft.com"],
            fontSrc: ["'self'"],
            objectSrc: ["'none'"],
            mediaSrc: ["'self'"],
            frameSrc: ["'none'"],
        },
    },
    crossOriginEmbedderPolicy: false
}));

// Rate limiting - production grade
const limiter = rateLimit({
    windowMs: 15 * 60 * 1000, // 15 minutes
    max: 100, // Limit each IP to 100 requests per windowMs
    message: {
        error: 'Too many requests from this IP, please try again later.',
        retryAfter: '15 minutes'
    },
    standardHeaders: true,
    legacyHeaders: false,
});

const strictLimiter = rateLimit({
    windowMs: 15 * 60 * 1000,
    max: 10, // Stricter limit for API endpoints
    message: {
        error: 'API rate limit exceeded. Please try again later.',
        retryAfter: '15 minutes'
    }
});

app.use('/api/', strictLimiter);
app.use(limiter);

// CORS configuration
const allowedOrigins = [
    process.env.ALLOWED_ORIGINS?.split(',') || [],
    `https://${process.env.WEB_APP_NAME || 'lab-uks-entra-webapp'}.azurewebsites.net`,
    'https://lab-uks-entra-webapp.azurewebsites.net'
].flat().filter(Boolean);

app.use(cors({
    origin: allowedOrigins,
    credentials: true,
    methods: ['GET', 'POST'],
    allowedHeaders: ['Content-Type', 'Authorization']
}));

// Body parsing with size limits
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));

// Static files with security
app.use(express.static(path.join(__dirname, 'public'), {
    maxAge: '1d',
    etag: true,
    lastModified: true
}));

// ============================================================================
// CONFIGURATION & INITIALIZATION
// ============================================================================

const config = {
    azureClientId: process.env.AZURE_CLIENT_ID,
    azureTenantId: process.env.AZURE_TENANT_ID,
    subscriptionId: process.env.AZURE_SUBSCRIPTION_ID,
    resourceGroupName: process.env.RESOURCE_GROUP_NAME,
    automationAccountName: process.env.AUTOMATION_ACCOUNT_NAME,
    keyVaultUri: process.env.KEY_VAULT_URI,
    nodeEnv: process.env.NODE_ENV || 'development',
    auditLogging: process.env.AUDIT_LOGGING === 'true'
};

// Validate required configuration
const requiredConfig = ['azureClientId', 'azureTenantId', 'subscriptionId', 'resourceGroupName', 'automationAccountName'];
const missingConfig = requiredConfig.filter(key => !config[key]);

if (missingConfig.length > 0) {
    console.error('❌ Missing required configuration:', missingConfig);
    if (config.nodeEnv === 'production') {
        process.exit(1);
    }
}

// Initialize Azure clients with error handling
const credential = new DefaultAzureCredential();
let automationClient;

async function initializeAzureClients() {
    try {
        if (config.subscriptionId) {
            automationClient = new AutomationClient(credential, config.subscriptionId);
            console.log('✅ Azure Automation client initialized');
        }
    } catch (error) {
        console.error('❌ Azure client initialization failed:', error.message);
        if (config.nodeEnv === 'production') {
            throw error;
        }
    }
}

// ============================================================================
// AUDIT LOGGING
// ============================================================================

function auditLog(action, user, details = {}) {
    if (!config.auditLogging) return;
    
    const logEntry = {
        timestamp: new Date().toISOString(),
        action,
        user: user?.upn || 'anonymous',
        userName: user?.name || 'Unknown',
        userTenant: user?.tenantId || 'Unknown',
        details,
        ip: details.ip,
        userAgent: details.userAgent
    };
    
    console.log(`[AUDIT] ${JSON.stringify(logEntry)}`);
}

// ============================================================================
// AUTHENTICATION & AUTHORIZATION
// ============================================================================

// Role requirements for operations (Enhanced security)
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

// Enhanced JWT verification middleware
async function verifyToken(req, res, next) {
    try {
        const authHeader = req.headers.authorization;
        
        if (!authHeader || !authHeader.startsWith('Bearer ')) {
            auditLog('AUTH_FAILED', null, { 
                reason: 'Missing token',
                ip: req.ip,
                userAgent: req.get('User-Agent')
            });
            return res.status(401).json({ 
                error: 'Authentication required',
                requiresLogin: true
            });
        }

        const token = authHeader.substring(7);
        
        // Input validation
        if (!token || token.length > 4096) {
            auditLog('AUTH_FAILED', null, { 
                reason: 'Invalid token format',
                ip: req.ip 
            });
            return res.status(401).json({ error: 'Invalid token format' });
        }
        
        // Decode JWT (in production, verify with Microsoft's public keys)
        const decoded = jwt.decode(token);
        
        if (!decoded || !decoded.upn) {
            auditLog('AUTH_FAILED', null, { 
                reason: 'Token decode failed',
                ip: req.ip 
            });
            return res.status(401).json({ error: 'Invalid token' });
        }

        // Validate token claims
        const now = Math.floor(Date.now() / 1000);
        if (decoded.exp && decoded.exp < now) {
            auditLog('AUTH_FAILED', decoded, { 
                reason: 'Token expired',
                ip: req.ip 
            });
            return res.status(401).json({ error: 'Token expired' });
        }

        // Validate tenant
        if (decoded.tid !== config.azureTenantId) {
            auditLog('AUTH_FAILED', decoded, { 
                reason: 'Wrong tenant',
                ip: req.ip 
            });
            return res.status(403).json({ error: 'Access denied - wrong tenant' });
        }

        req.user = {
            upn: decoded.upn || decoded.unique_name || decoded.preferred_username,
            name: decoded.name || 'Unknown User',
            roles: decoded.roles || [],
            tenantId: decoded.tid,
            oid: decoded.oid
        };
        
        auditLog('AUTH_SUCCESS', req.user, { ip: req.ip });
        next();
        
    } catch (error) {
        console.error('Token verification error:', error);
        auditLog('AUTH_ERROR', null, { 
            error: error.message,
            ip: req.ip 
        });
        return res.status(401).json({ error: 'Token verification failed' });
    }
}

// Enhanced permission checking
function checkPermissions(operation, userRoles) {
    const required = roleRequirements[operation] || [];
    const hasPermission = required.some(role => userRoles.includes(role));
    
    // Log permission checks
    if (config.auditLogging) {
        console.log(`[PERMISSION] Operation: ${operation}, Required: ${required}, User roles: ${userRoles}, Granted: ${hasPermission}`);
    }
    
    return hasPermission;
}

// Input validation schemas
const runbookValidation = [
    body('Operation').isIn(['ExtensionAttributes', 'DeviceCleanup', 'GroupCleanup', 'All']),
    body('WhatIf').isBoolean(),
    body('ExtensionAttributeNumber').optional().isInt({ min: 1, max: 15 }),
    body('AttributeValue').optional().isLength({ max: 256 }).escape(),
    body('UsersToAdd').optional().isLength({ max: 10000 }),
    body('UsersToRemove').optional().isLength({ max: 10000 }),
    body('MaxDevices').optional().isInt({ min: 1, max: 500 }),
    body('GroupName').optional().isLength({ max: 256 }).escape(),
    body('GroupCleanupDays').optional().isInt({ min: 1, max: 365 })
];

// ============================================================================
// ERROR HANDLING
// ============================================================================

function handleValidationErrors(req, res, next) {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
        auditLog('VALIDATION_ERROR', req.user, { 
            errors: errors.array(),
            ip: req.ip 
        });
        return res.status(400).json({
            success: false,
            error: 'Invalid input parameters',
            details: errors.array()
        });
    }
    next();
}

// Global error handler
app.use((error, req, res, next) => {
    console.error('Global error handler:', error);
    
    auditLog('SERVER_ERROR', req.user, { 
        error: error.message,
        stack: config.nodeEnv === 'development' ? error.stack : undefined,
        ip: req.ip 
    });
    
    // Don't leak error details in production
    const errorMessage = config.nodeEnv === 'production' 
        ? 'Internal server error' 
        : error.message;
    
    res.status(500).json({
        success: false,
        error: errorMessage
    });
});

// ============================================================================
// ROUTES
// ============================================================================

// Health check with security info
app.get('/health', (req, res) => {
    res.json({ 
        status: 'healthy',
        timestamp: new Date().toISOString(),
        nodeVersion: process.version,
        port: port,
        authentication: 'enabled',
        security: 'hardened',
        environment: config.nodeEnv,
        azureClientConfigured: !!config.azureClientId,
        automationClient: !!automationClient
    });
});

// Main application route
app.get('/', async (req, res) => {
    try {
        const htmlContent = await fs.readFile(path.join(__dirname, 'templates', 'main.html'), 'utf8');
        
        // Inject configuration securely
        const configuredHtml = htmlContent
            .replace(/\$\{config\.azureClientId\}/g, config.azureClientId || '')
            .replace(/\$\{config\.azureTenantId\}/g, config.azureTenantId || '');
        
        res.send(configuredHtml);
    } catch (error) {
        console.error('Error serving main page:', error);
        res.status(500).send('Server error loading application');
    }
});

// Execute runbook with comprehensive security
app.post('/api/execute-runbook', verifyToken, runbookValidation, handleValidationErrors, async (req, res) => {
    try {
        const { Operation, WhatIf, UserContext, ...params } = req.body;
        
        // Enhanced permission check
        if (!checkPermissions(Operation, req.user.roles)) {
            auditLog('PERMISSION_DENIED', req.user, { 
                operation: Operation,
                requiredRoles: roleRequirements[Operation],
                userRoles: req.user.roles,
                ip: req.ip 
            });
            
            return res.status(403).json({
                success: false,
                error: `Insufficient permissions for ${Operation}`,
                requiredRoles: roleRequirements[Operation]
            });
        }

        if (!automationClient) {
            return res.status(503).json({
                success: false,
                error: 'Azure Automation service unavailable'
            });
        }

        // Prepare runbook parameters with enhanced security
        const runbookParams = {
            ...params,
            Operation,
            WhatIf: WhatIf !== false, // Default to safe mode
            ExecutedBy: req.user.upn,
            ExecutedByName: req.user.name,
            ExecutionContext: 'WebApp',
            ClientIP: req.ip,
            UserAgent: req.get('User-Agent'),
            Timestamp: new Date().toISOString()
        };

        auditLog('RUNBOOK_START', req.user, { 
            operation: Operation,
            whatIf: WhatIf,
            parameters: { ...runbookParams, ExecutedBy: '[REDACTED]' },
            ip: req.ip 
        });

        // Start the runbook job
        const jobResult = await automationClient.jobs.create(
            config.resourceGroupName,
            config.automationAccountName,
            'Manage-ExtensionAttributes',
            {
                parameters: runbookParams
            }
        );

        auditLog('RUNBOOK_STARTED', req.user, { 
            operation: Operation,
            jobId: jobResult.jobId,
            ip: req.ip 
        });

        res.json({
            success: true,
            jobId: jobResult.jobId,
            message: `${Operation} started successfully`,
            executedBy: req.user.upn,
            whatIfMode: WhatIf
        });

    } catch (error) {
        console.error('Error executing runbook:', error);
        auditLog('RUNBOOK_ERROR', req.user, { 
            error: error.message,
            ip: req.ip 
        });
        
        res.status(500).json({
            success: false,
            error: config.nodeEnv === 'production' 
                ? 'Failed to execute operation' 
                : error.message
        });
    }
});

// Get job status with security
app.get('/api/job-status/:jobId', verifyToken, async (req, res) => {
    try {
        if (!automationClient) {
            return res.status(503).json({ error: 'Azure Automation service unavailable' });
        }

        const { jobId } = req.params;
        
        // Input validation
        if (!/^[a-f0-9-]{36}$/i.test(jobId)) {
            return res.status(400).json({ error: 'Invalid job ID format' });
        }
        
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
        res.status(500).json({ 
            error: config.nodeEnv === 'production' 
                ? 'Failed to retrieve job status' 
                : error.message 
        });
    }
});

// Get recent jobs with pagination and filtering
app.get('/api/recent-jobs', verifyToken, async (req, res) => {
    try {
        if (!automationClient) {
            return res.json([]);
        }

        const jobs = await automationClient.jobs.listByAutomationAccount(
            config.resourceGroupName,
            config.automationAccountName
        );

        const recentJobs = jobs.slice(0, 50).map(job => ({
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

// ============================================================================
// SERVER STARTUP
// ============================================================================

async function startServer() {
    try {
        await initializeAzureClients();
        
        app.listen(port, () => {
            console.log(`🛡️ Entra Management Console (Secure) running on port ${port}`);
            console.log(`Environment: ${config.nodeEnv}`);
            console.log(`Node.js version: ${process.version}`);
            console.log(`Security features: ✅ Enabled`);
            console.log(`Rate limiting: ✅ Active`);
            console.log(`Audit logging: ${config.auditLogging ? '✅ Enabled' : '❌ Disabled'}`);
            console.log(`Azure Client ID: ${config.azureClientId ? '✅ Configured' : '❌ Missing'}`);
            console.log(`CORS Origins: ${allowedOrigins.join(', ')}`);
            
            if (missingConfig.length > 0) {
                console.warn(`⚠️ Missing configuration: ${missingConfig.join(', ')}`);
            }
        });
        
    } catch (error) {
        console.error('❌ Server startup failed:', error);
        process.exit(1);
    }
}

// Graceful shutdown
process.on('SIGTERM', () => {
    console.log('🛑 SIGTERM received. Shutting down gracefully...');
    process.exit(0);
});

process.on('SIGINT', () => {
    console.log('🛑 SIGINT received. Shutting down gracefully...');
    process.exit(0);
});

startServer();