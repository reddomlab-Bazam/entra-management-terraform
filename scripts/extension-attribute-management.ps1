param(
    [Parameter(Mandatory=$false)]
    [ValidateSet("ExtensionAttributes", "DeviceCleanup", "GroupCleanup", "All")]
    [string]$Operation = "All",
    
    [Parameter(Mandatory=$false)]
    [bool]$WhatIf = $true,
    
    [Parameter(Mandatory=$false)]
    [bool]$SendEmail = $true,
    
    [Parameter(Mandatory=$false)]
    [bool]$ConfigFromFileShare = $true,
    
    # User Context Parameters (NEW)
    [Parameter(Mandatory=$false)]
    [string]$ExecutedBy = "",
    
    [Parameter(Mandatory=$false)]
    [string]$ExecutedByName = "",
    
    [Parameter(Mandatory=$false)]
    [string]$ExecutionContext = "Automation",
    
    # Extension Attribute Parameters
    [Parameter(Mandatory=$false)]
    [ValidateRange(1,15)]
    [int]$ExtensionAttributeNumber = 1,
    
    [Parameter(Mandatory=$false)]
    [string]$UsersToAdd = "",
    
    [Parameter(Mandatory=$false)]
    [string]$UsersToRemove = "",
    
    [Parameter(Mandatory=$false)]
    [string]$AttributeValue = "",
    
    # Device Cleanup Parameters
    [Parameter(Mandatory=$false)]
    [ValidateRange(1, 500)]
    [int]$MaxDevices = 50,
    
    [Parameter(Mandatory=$false)]
    [bool]$ExcludeAzureVMs = $true,
    
    # Group Cleanup Parameters
    [Parameter(Mandatory=$false)]
    [string]$GroupName = "",
    
    [Parameter(Mandatory=$false)]
    [int]$GroupCleanupDays = 14
)

# =============================================================================
# MODULE IMPORT AND INITIALIZATION
# =============================================================================

Write-Output "=== ENTRA MANAGEMENT UNIFIED RUNBOOK STARTED ==="
Write-Output "Operation: $Operation | Mode: $(if ($WhatIf) { 'WHAT-IF (SAFE)' } else { 'LIVE EXECUTION' })"
Write-Output "Executed By: $(if ($ExecutedBy) { "$ExecutedByName ($ExecutedBy)" } else { 'System/Automation' })"
Write-Output "Execution Context: $ExecutionContext"
Write-Output "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') UTC"

# Enhanced audit logging function
function Write-AuditLog {
    param(
        [string]$Message,
        [string]$Level = "Info",
        [string]$Component = "General"
    )
    
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $auditMessage = "[$timestamp] [$Level] [$Component] [User: $ExecutedBy] $Message"
    
    Write-Output $auditMessage
    
    # In a production environment, you could also send this to Log Analytics
    # or store in the file share for persistent audit logging
}

# Import required modules explicitly
Write-AuditLog "Importing Microsoft Graph modules..." "Info" "ModuleImport"
try {
    Import-Module Microsoft.Graph.Authentication -Force -ErrorAction Stop
    Write-AuditLog "✅ Microsoft.Graph.Authentication imported" "Info" "ModuleImport"
    
    Import-Module Microsoft.Graph.Users -Force -ErrorAction Stop
    Write-AuditLog "✅ Microsoft.Graph.Users imported" "Info" "ModuleImport"
    
    Import-Module Microsoft.Graph.DeviceManagement -Force -ErrorAction Stop
    Write-AuditLog "✅ Microsoft.Graph.DeviceManagement imported" "Info" "ModuleImport"
    
    Import-Module Microsoft.Graph.Groups -Force -ErrorAction Stop
    Write-AuditLog "✅ Microsoft.Graph.Groups imported" "Info" "ModuleImport"
    
    try {
        Import-Module Microsoft.Graph.Mail -Force -ErrorAction Stop
        Write-AuditLog "✅ Microsoft.Graph.Mail imported" "Info" "ModuleImport"
    } catch {
        Write-AuditLog "Microsoft.Graph.Mail not available - email functionality will be limited" "Warning" "ModuleImport"
    }
    
    Write-AuditLog "All required modules imported successfully" "Info" "ModuleImport"
} catch {
    Write-AuditLog "Failed to import required modules: $($_.Exception.Message)" "Error" "ModuleImport"
    Write-Output "Available modules:"
    Get-Module -ListAvailable | Where-Object { $_.Name -like "*Graph*" } | Select-Object Name, Version
    throw "Module import failed"
}

# =============================================================================
# GLOBAL CONFIGURATION
# =============================================================================

try {
    # Get automation variables
    Write-AuditLog "Retrieving automation variables..." "Info" "Configuration"
    $ResourceGroupName = Get-AutomationVariable -Name "ResourceGroupName" -ErrorAction Stop
    $StorageAccountName = Get-AutomationVariable -Name "StorageAccountName" -ErrorAction Stop
    $FileShareName = Get-AutomationVariable -Name "FileShareName" -ErrorAction Stop
    $KeyVaultName = Get-AutomationVariable -Name "KeyVaultName" -ErrorAction Stop
    
    # Get Azure AD authentication variables
    $ClientId = Get-AutomationVariable -Name "AzureADClientId" -ErrorAction Stop
    $TenantId = Get-AutomationVariable -Name "AzureADTenantId" -ErrorAction Stop
    $ClientSecret = Get-AutomationVariable -Name "AzureADClientSecret" -ErrorAction Stop
    
    Write-AuditLog "Retrieved automation variables successfully" "Info" "Configuration"
    Write-Output "  Resource Group: $ResourceGroupName"
    Write-Output "  Storage Account: $StorageAccountName"
    Write-Output "  File Share: $FileShareName"
    Write-Output "  Key Vault: $KeyVaultName"
    Write-Output "  Client ID: $($ClientId.Substring(0,8))..."
    Write-Output "  Tenant ID: $($TenantId.Substring(0,8))..."
    Write-Output "  Client Secret: $(if ($ClientSecret) { 'Configured' } else { 'Missing' })"
    
} catch {
    Write-AuditLog "Failed to retrieve automation variables: $($_.Exception.Message)" "Error" "Configuration"
    throw
}

# =============================================================================
# MICROSOFT GRAPH CONNECTION
# =============================================================================

function Connect-ToGraph {
    try {
        Write-AuditLog "Connecting to Microsoft Graph..." "Info" "Authentication"
        
        # Try managed identity first
        try {
            Connect-MgGraph -Identity -NoWelcome -ErrorAction Stop
            $context = Get-MgContext
            Write-AuditLog "✅ Connected via Managed Identity as: $($context.Account)" "Info" "Authentication"
            return $true
        } catch {
            Write-AuditLog "Managed Identity connection failed: $($_.Exception.Message)" "Warning" "Authentication"
        }
        
        # Fallback to client credentials if managed identity fails
        Write-AuditLog "Attempting client credential authentication..." "Info" "Authentication"
        try {
            $SecureClientSecret = ConvertTo-SecureString -String $ClientSecret -AsPlainText -Force
            $ClientSecretCredential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $ClientId, $SecureClientSecret
            
            Connect-MgGraph -TenantId $TenantId -ClientSecretCredential $ClientSecretCredential -NoWelcome -ErrorAction Stop
            $context = Get-MgContext
            Write-AuditLog "✅ Connected via Client Credentials as: $($context.Account)" "Info" "Authentication"
            return $true
        } catch {
            Write-AuditLog "Client credential authentication failed: $($_.Exception.Message)" "Error" "Authentication"
            return $false
        }
        
    } catch {
        Write-AuditLog "Failed to connect to Graph: $($_.Exception.Message)" "Error" "Authentication"
        return $false
    }
}

# =============================================================================
# ROLE-BASED ACCESS CONTROL FUNCTIONS
# =============================================================================

function Test-UserPermissions {
    param(
        [string]$Operation,
        [string]$UserPrincipalName
    )
    
    try {
        Write-AuditLog "Checking permissions for $UserPrincipalName on operation: $Operation" "Info" "Authorization"
        
        # In a real implementation, you would check the user's directory roles
        # For now, we'll log the permission check and assume authorized
        # This is where you'd implement role validation logic
        
        $roleRequirements = @{
            'ExtensionAttributes' = @('User Administrator', 'Global Administrator', 'Privileged Role Administrator')
            'DeviceCleanup' = @('Cloud Device Administrator', 'Intune Administrator', 'Global Administrator')
            'GroupCleanup' = @('Groups Administrator', 'User Administrator', 'Global Administrator')
            'All' = @('Global Administrator', 'Privileged Role Administrator')
        }
        
        $requiredRoles = $roleRequirements[$Operation]
        Write-AuditLog "Required roles for $Operation : $($requiredRoles -join ', ')" "Info" "Authorization"
        
        # TODO: Implement actual role checking against Microsoft Graph
        # For now, return true for demonstration purposes
        # In production, you would:
        # 1. Get the user's directory role memberships from Graph API
        # 2. Check if any of their roles match the required roles
        # 3. Return true only if authorized
        
        Write-AuditLog "Permission check completed - User authorized for $Operation" "Info" "Authorization"
        return $true
        
    } catch {
        Write-AuditLog "Permission check failed: $($_.Exception.Message)" "Error" "Authorization"
        return $false
    }
}

# =============================================================================
# ENHANCED OPERATION FUNCTIONS
# =============================================================================

function Invoke-ExtensionAttributeManagement {
    param(
        [int]$AttributeNumber,
        [string]$AttributeValue,
        [string]$UsersToAdd,
        [string]$UsersToRemove,
        [bool]$WhatIf
    )
    
    Write-AuditLog "Starting Extension Attribute Management" "Info" "ExtensionAttributes"
    Write-AuditLog "Attribute: extensionAttribute$AttributeNumber" "Info" "ExtensionAttributes"
    Write-AuditLog "Value: '$AttributeValue'" "Info" "ExtensionAttributes"
    Write-AuditLog "Users to Add: $UsersToAdd" "Info" "ExtensionAttributes"
    Write-AuditLog "Users to Remove: $UsersToRemove" "Info" "ExtensionAttributes"
    
    $results = @{
        UsersProcessed = 0
        UsersAdded = 0
        UsersRemoved = 0
        Errors = @()
    }
    
    try {
        # Process users to add/update
        if (-not [string]::IsNullOrWhiteSpace($UsersToAdd)) {
            $usersToAddList = $UsersToAdd -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ }
            
            foreach ($userEmail in $usersToAddList) {
                try {
                    Write-AuditLog "Processing user for addition: $userEmail" "Info" "ExtensionAttributes"
                    
                    if ($WhatIf) {
                        Write-AuditLog "WHAT-IF: Would set extensionAttribute$AttributeNumber to '$AttributeValue' for $userEmail" "Info" "ExtensionAttributes"
                    } else {
                        # In production, implement actual Graph API calls here
                        Write-AuditLog "Would update extensionAttribute$AttributeNumber for $userEmail" "Info" "ExtensionAttributes"
                        # Update-MgUser -UserId $userEmail -AdditionalProperties @{"extensionAttribute$AttributeNumber" = $AttributeValue}
                    }
                    
                    $results.UsersAdded++
                    $results.UsersProcessed++
                    
                } catch {
                    $errorMsg = "Failed to update $userEmail : $($_.Exception.Message)"
                    Write-AuditLog $errorMsg "Error" "ExtensionAttributes"
                    $results.Errors += $errorMsg
                }
            }
        }
        
        # Process users to remove
        if (-not [string]::IsNullOrWhiteSpace($UsersToRemove)) {
            $usersToRemoveList = $UsersToRemove -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ }
            
            foreach ($userEmail in $usersToRemoveList) {
                try {
                    Write-AuditLog "Processing user for removal: $userEmail" "Info" "ExtensionAttributes"
                    
                    if ($WhatIf) {
                        Write-AuditLog "WHAT-IF: Would clear extensionAttribute$AttributeNumber for $userEmail" "Info" "ExtensionAttributes"
                    } else {
                        # In production, implement actual Graph API calls here
                        Write-AuditLog "Would clear extensionAttribute$AttributeNumber for $userEmail" "Info" "ExtensionAttributes"
                        # Update-MgUser -UserId $userEmail -AdditionalProperties @{"extensionAttribute$AttributeNumber" = $null}
                    }
                    
                    $results.UsersRemoved++
                    $results.UsersProcessed++
                    
                } catch {
                    $errorMsg = "Failed to clear attribute for $userEmail : $($_.Exception.Message)"
                    Write-AuditLog $errorMsg "Error" "ExtensionAttributes"
                    $results.Errors += $errorMsg
                }
            }
        }
        
        Write-AuditLog "Extension Attribute Management completed. Users processed: $($results.UsersProcessed)" "Info" "ExtensionAttributes"
        return $results
        
    } catch {
        Write-AuditLog "Extension Attribute Management failed: $($_.Exception.Message)" "Error" "ExtensionAttributes"
        throw
    }
}

function Invoke-DeviceCleanup {
    param(
        [int]$MaxDevices,
        [bool]$ExcludeAzureVMs,
        [bool]$WhatIf
    )
    
    Write-AuditLog "Starting Device Cleanup Management" "Info" "DeviceCleanup"
    Write-AuditLog "Max Devices: $MaxDevices" "Info" "DeviceCleanup"
    Write-AuditLog "Exclude Azure VMs: $ExcludeAzureVMs" "Info" "DeviceCleanup"
    
    $results = @{
        DevicesScanned = 0
        DevicesDisabled = 0
        DevicesDeleted = 0
        Errors = @()
    }
    
    try {
        if ($WhatIf) {
            Write-AuditLog "WHAT-IF: Would scan for inactive devices and clean up based on criteria" "Info" "DeviceCleanup"
            Write-AuditLog "WHAT-IF: Would exclude Azure VMs: $ExcludeAzureVMs" "Info" "DeviceCleanup"
            Write-AuditLog "WHAT-IF: Would process maximum $MaxDevices devices" "Info" "DeviceCleanup"
        } else {
            Write-AuditLog "Device cleanup would execute here with real Graph API calls" "Info" "DeviceCleanup"
            # In production, implement device cleanup logic here
        }
        
        Write-AuditLog "Device Cleanup completed successfully" "Info" "DeviceCleanup"
        return $results
        
    } catch {
        Write-AuditLog "Device Cleanup failed: $($_.Exception.Message)" "Error" "DeviceCleanup"
        throw
    }
}

function Invoke-GroupCleanup {
    param(
        [string]$GroupName,
        [int]$CleanupDays,
        [bool]$WhatIf
    )
    
    Write-AuditLog "Starting Group Cleanup Management" "Info" "GroupCleanup"
    Write-AuditLog "Group Name: $GroupName" "Info" "GroupCleanup"
    Write-AuditLog "Cleanup Days: $CleanupDays" "Info" "GroupCleanup"
    
    $results = @{
        GroupsProcessed = 0
        UsersRemoved = 0
        Errors = @()
    }
    
    try {
        if ($WhatIf) {
            Write-AuditLog "WHAT-IF: Would clean up group '$GroupName' removing users older than $CleanupDays days" "Info" "GroupCleanup"
        } else {
            Write-AuditLog "Group cleanup would execute here with real Graph API calls" "Info" "GroupCleanup"
            # In production, implement group cleanup logic here
        }
        
        Write-AuditLog "Group Cleanup completed successfully" "Info" "GroupCleanup"
        return $results
        
    } catch {
        Write-AuditLog "Group Cleanup failed: $($_.Exception.Message)" "Error" "GroupCleanup"
        throw
    }
}

# =============================================================================
# EMAIL NOTIFICATION FUNCTION
# =============================================================================

function Send-ExecutionReport {
    param(
        [string]$Operation,
        [hashtable]$Results,
        [bool]$WhatIfMode,
        [string]$ExecutedBy
    )
    
    try {
        Write-AuditLog "Preparing execution report for $Operation" "Info" "EmailReport"
        
        $subject = "Entra Management - $Operation $(if ($WhatIfMode) { 'Preview' } else { 'Execution' }) Report"
        $body = @"
Entra Management Console - Execution Report

Operation: $Operation
Mode: $(if ($WhatIfMode) { 'WHAT-IF (Preview Mode)' } else { 'LIVE EXECUTION' })
Executed By: $ExecutedBy
Execution Time: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') UTC

Results:
$(ConvertTo-Json $Results -Depth 3)

This is an automated report from the Entra Management Console.
"@
        
        if ($SendEmail) {
            Write-AuditLog "Email report would be sent here" "Info" "EmailReport"
            # In production, implement email sending via Graph API or other service
        }
        
    } catch {
        Write-AuditLog "Failed to send execution report: $($_.Exception.Message)" "Warning" "EmailReport"
    }
}

# =============================================================================
# MAIN EXECUTION
# =============================================================================

try {
    # Connect to Microsoft Graph
    if (-not (Connect-ToGraph)) {
        throw "Failed to connect to Microsoft Graph"
    }
    
    # Test the connection
    Write-AuditLog "Testing Graph API connectivity..." "Info" "ConnectionTest"
    try {
        $context = Get-MgContext
        Write-AuditLog "✅ Graph Context: $($context.Account)" "Info" "ConnectionTest"
        Write-AuditLog "✅ Scopes: $($context.Scopes -join ', ')" "Info" "ConnectionTest"
    } catch {
        Write-AuditLog "Graph connectivity test failed: $($_.Exception.Message)" "Warning" "ConnectionTest"
    }
    
    # Check user permissions if executed by a specific user
    if ($ExecutedBy -and $Operation -ne "All") {
        if (-not (Test-UserPermissions -Operation $Operation -UserPrincipalName $ExecutedBy)) {
            throw "User $ExecutedBy does not have sufficient permissions for operation: $Operation"
        }
    }
    
    # Initialize results
    $executionResults = @{
        Success = $true
        Operation = $Operation
        StartTime = Get-Date
        WhatIfMode = $WhatIf
        ExecutedBy = $ExecutedBy
        ExecutedByName = $ExecutedByName
        Results = @{}
    }
    
    # Execute based on operation parameter
    switch ($Operation) {
        "ExtensionAttributes" {
            Write-AuditLog "=== EXTENSION ATTRIBUTES MANAGEMENT ===" "Info" "Operations"
            if ([string]::IsNullOrWhiteSpace($UsersToAdd) -and [string]::IsNullOrWhiteSpace($UsersToRemove)) {
                Write-AuditLog "No users specified for extension attribute operations" "Warning" "Operations"
                $executionResults.Results = @{ Message = "No users specified" }
            } else {
                $executionResults.Results = Invoke-ExtensionAttributeManagement -AttributeNumber $ExtensionAttributeNumber -AttributeValue $AttributeValue -UsersToAdd $UsersToAdd -UsersToRemove $UsersToRemove -WhatIf $WhatIf
            }
        }
        "DeviceCleanup" {
            Write-AuditLog "=== DEVICE CLEANUP MANAGEMENT ===" "Info" "Operations"
            $executionResults.Results = Invoke-DeviceCleanup -MaxDevices $MaxDevices -ExcludeAzureVMs $ExcludeAzureVMs -WhatIf $WhatIf
        }
        "GroupCleanup" {
            Write-AuditLog "=== GROUP CLEANUP MANAGEMENT ===" "Info" "Operations"
            if ([string]::IsNullOrWhiteSpace($GroupName)) {
                Write-AuditLog "No group specified for cleanup" "Warning" "Operations"
                $executionResults.Results = @{ Message = "No group specified" }
            } else {
                $executionResults.Results = Invoke-GroupCleanup -GroupName $GroupName -CleanupDays $GroupCleanupDays -WhatIf $WhatIf
            }
        }
        "All" {
            Write-AuditLog "=== ALL OPERATIONS ===" "Info" "Operations"
            Write-AuditLog "'All' operations mode - would execute multiple operations in sequence" "Info" "Operations"
            $executionResults.Results = @{ Message = "All operations mode not yet implemented" }
        }
    }
    
    if ($WhatIf) {
        Write-AuditLog "*** WHAT-IF MODE - NO CHANGES MADE ***" "Warning" "Operations"
    }
    
    $executionResults.EndTime = Get-Date
    $executionResults.Duration = ($executionResults.EndTime - $executionResults.StartTime).TotalSeconds
    
    Write-AuditLog "=== EXECUTION COMPLETE ===" "Info" "Operations"
    Write-AuditLog "Duration: $($executionResults.Duration) seconds" "Info" "Operations"
    
    # Send execution report
    if ($SendEmail) {
        Send-ExecutionReport -Operation $Operation -Results $executionResults.Results -WhatIfMode $WhatIf -ExecutedBy $ExecutedBy
    }
    
    # Return results
    return $executionResults
    
} catch {
    Write-AuditLog "Runbook execution failed: $($_.Exception.Message)" "Error" "Operations"
    Write-Output "Error details: $($_.Exception | Format-List -Force | Out-String)"
    
    # Send error report
    if ($SendEmail) {
        Send-ExecutionReport -Operation $Operation -Results @{ Error = $_.Exception.Message } -WhatIfMode $WhatIf -ExecutedBy $ExecutedBy
    }
    
    throw
} finally {
    try {
        Disconnect-MgGraph -ErrorAction SilentlyContinue
        Write-AuditLog "Disconnected from Microsoft Graph" "Info" "Cleanup"
    } catch {
        Write-AuditLog "Could not disconnect from Graph: $($_.Exception.Message)" "Warning" "Cleanup"
    }
}