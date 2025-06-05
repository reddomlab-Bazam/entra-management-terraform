#Requires -Modules Microsoft.Graph.Authentication, Microsoft.Graph.DeviceManagement, Microsoft.Graph.Users, Microsoft.Graph.Mail, Microsoft.Graph.Groups

<#
.SYNOPSIS
    Unified Entra Management PowerShell Runbook
.DESCRIPTION
    Combined runbook for Extension Attributes, Device Cleanup, and Group Membership Management.
    Supports all three core functions in a single script for centralized management.
.PARAMETER Operation
    The operation to perform: ExtensionAttributes, DeviceCleanup, GroupCleanup, or All
.PARAMETER WhatIf
    Run in preview mode (no changes made)
.PARAMETER SendEmail
    Send email report after execution
.PARAMETER ConfigFromFileShare
    Read configuration from Azure File Share
#>

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
# GLOBAL CONFIGURATION
# =============================================================================

# Email Settings
$EmailFrom = Get-AutomationVariable -Name "EntraMgmt_FromEmail" -ErrorAction SilentlyContinue
$EmailTo = Get-AutomationVariable -Name "EntraMgmt_ToEmail" -ErrorAction SilentlyContinue

# Storage Configuration
$StorageAccountName = Get-AutomationVariable -Name "EntraMgmt_StorageAccount" -ErrorAction SilentlyContinue
$FileShareName = Get-AutomationVariable -Name "EntraMgmt_FileShare" -ErrorAction SilentlyContinue
$ResourceGroupName = Get-AutomationVariable -Name "EntraMgmt_ResourceGroup" -ErrorAction SilentlyContinue

# Device Cleanup Thresholds
$InactivityDays = 120
$NonCompliantMobileDays = 14
$NonCompliantWindowsDays = 28
$NonCompliantMacOSDays = 28
$UnmanagedDeviceDays = 30
$DisabledDeviceDeletionDays = 30
$DeletionSafetyLimit = 20

# Protected Devices
$ExcludedDevices = @(
    "vitcsasukw00", "vitcsasuks00", "vitavdukw03", "vitavdukw02", "vitavdukw01", "vitavdukw00",
    "vitavduks03", "vitavduks02", "vitavduks01", "vitavduks00", "VCORP-AD-02", "VCORP-AD-01",
    "swift-vm02", "SWIFT-VM01", "ReportingVM", "OctopusVM", "AncillaryVM", "Accurate2VM"
)

# Azure VM Patterns
$AzureVMPatterns = @("^vm-.*", "^az-.*", ".*-vm$", ".*-vm\d+$", "^.*-\d{2,3}$")
$AzureInfraPatterns = @(
    "aks-.*", ".*-vmss-.*", "vmss.*", ".*-scaleset-.*", "k8s-.*", 
    ".*-node-.*", ".*-worker-.*", ".*-master-.*", ".*-pool-.*"
)

# Global Execution Log
$Global:executionLog = @{
    ExtensionAttributes = @{
        ProcessedUsers = @()
        SuccessCount = 0
        ErrorCount = 0
        Errors = @()
    }
    DeviceCleanup = @{
        DisabledDevices = @()
        DeletedDevices = @()
        SkippedDevices = @()
        AzureVMs = @()
        Errors = @()
    }
    GroupCleanup = @{
        ProcessedGroups = @()
        RemovedUsers = @()
        Errors = @()
    }
    General = @{
        StartTime = Get-Date
        Operations = @()
        TotalErrors = 0
    }
}

# =============================================================================
# UTILITY FUNCTIONS
# =============================================================================

function Write-Log {
    param(
        [string]$Message,
        [string]$Level = "Info",
        [string]$Category = "General"
    )
    
    $timestamp = Get-Date -Format "HH:mm:ss"
    $output = "[$timestamp] [$Level] [$Category] $Message"
    
    switch ($Level) {
        "Info" { Write-Output $output }
        "Warning" { Write-Warning $output }
        "Error" { Write-Error $output }
    }
    
    $Global:executionLog.General.Operations += @{
        Timestamp = Get-Date
        Level = $Level
        Category = $Category
        Message = $Message
    }
}

function Connect-ToGraph {
    try {
        Write-Log "Connecting to Microsoft Graph..." -Category "Auth"
        Connect-MgGraph -Identity -NoWelcome -ErrorAction Stop
        
        $context = Get-MgContext
        Write-Log "Connected as: $($context.Account)" -Category "Auth"
        return $true
    }
    catch {
        Write-Log "Failed to connect to Graph: $($_.Exception.Message)" -Level Error -Category "Auth"
        return $false
    }
}

function Get-AzureVMList {
    if (-not $ExcludeAzureVMs) { return @() }
    
    try {
        Write-Log "Getting Azure VM list for exclusion..." -Category "Device"
        
        try {
            Import-Module Az.Accounts -Force -ErrorAction SilentlyContinue
            Import-Module Az.Compute -Force -ErrorAction SilentlyContinue
            
            $azContext = Connect-AzAccount -Identity -ErrorAction SilentlyContinue
            if ($azContext) {
                $vms = Get-AzVM -ErrorAction SilentlyContinue
                if ($vms) {
                    Write-Log "Found $($vms.Count) Azure VMs to exclude" -Category "Device"
                    
                    $Global:executionLog.DeviceCleanup.AzureVMs = $vms | ForEach-Object {
                        @{
                            Name = $_.Name
                            ResourceGroup = $_.ResourceGroupName
                            Location = $_.Location
                        }
                    }
                    
                    return $vms.Name
                }
            }
        }
        catch {
            Write-Log "Azure API not available, using pattern-based VM detection only" -Level Warning -Category "Device"
        }
        
        return @()
    }
    catch {
        Write-Log "Error getting Azure VM list: $($_.Exception.Message)" -Level Warning -Category "Device"
        return @()
    }
}

# =============================================================================
# EXTENSION ATTRIBUTES FUNCTIONS
# =============================================================================

function Invoke-ExtensionAttributeManagement {
    Write-Log "Starting Extension Attribute Management..." -Category "Attributes"
    
    if ([string]::IsNullOrWhiteSpace($UsersToAdd) -and [string]::IsNullOrWhiteSpace($UsersToRemove)) {
        Write-Log "No users specified for extension attribute operations" -Level Warning -Category "Attributes"
        return
    }
    
    $AttributeName = "extensionAttribute$ExtensionAttributeNumber"
    Write-Log "Managing $AttributeName with value: '$AttributeValue'" -Category "Attributes"
    
    # Process users to add/set
    if (![string]::IsNullOrWhiteSpace($UsersToAdd)) {
        $AddUsersList = $UsersToAdd -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' }
        Write-Log "Processing $($AddUsersList.Count) users to set attribute" -Category "Attributes"
        
        foreach ($UserEmail in $AddUsersList) {
            try {
                if ($WhatIf) {
                    Write-Log "WHATIF: Would set $AttributeName = '$AttributeValue' for $UserEmail" -Level Warning -Category "Attributes"
                } else {
                    $user = Get-MgUser -UserId $UserEmail -ErrorAction Stop
                    $extensionProperty = @{}
                    $extensionProperty[$AttributeName] = $AttributeValue
                    
                    Update-MgUser -UserId $user.Id -OnPremisesExtensionAttributes $extensionProperty -ErrorAction Stop
                    Write-Log "Successfully set $AttributeName for $UserEmail" -Category "Attributes"
                }
                
                $Global:executionLog.ExtensionAttributes.ProcessedUsers += @{
                    User = $UserEmail
                    Action = "Set"
                    Attribute = $AttributeName
                    Value = $AttributeValue
                    Status = "Success"
                    Timestamp = Get-Date
                }
                $Global:executionLog.ExtensionAttributes.SuccessCount++
            }
            catch {
                Write-Log "Failed to set $AttributeName for $UserEmail: $($_.Exception.Message)" -Level Error -Category "Attributes"
                $Global:executionLog.ExtensionAttributes.Errors += @{
                    User = $UserEmail
                    Action = "Set"
                    Error = $_.Exception.Message
                    Timestamp = Get-Date
                }
                $Global:executionLog.ExtensionAttributes.ErrorCount++
                $Global:executionLog.General.TotalErrors++
            }
        }
    }
    
    # Process users to remove/clear
    if (![string]::IsNullOrWhiteSpace($UsersToRemove)) {
        $RemoveUsersList = $UsersToRemove -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' }
        Write-Log "Processing $($RemoveUsersList.Count) users to clear attribute" -Category "Attributes"
        
        foreach ($UserEmail in $RemoveUsersList) {
            try {
                if ($WhatIf) {
                    Write-Log "WHATIF: Would clear $AttributeName for $UserEmail" -Level Warning -Category "Attributes"
                } else {
                    $user = Get-MgUser -UserId $UserEmail -ErrorAction Stop
                    $extensionProperty = @{}
                    $extensionProperty[$AttributeName] = $null
                    
                    Update-MgUser -UserId $user.Id -OnPremisesExtensionAttributes $extensionProperty -ErrorAction Stop
                    Write-Log "Successfully cleared $AttributeName for $UserEmail" -Category "Attributes"
                }
                
                $Global:executionLog.ExtensionAttributes.ProcessedUsers += @{
                    User = $UserEmail
                    Action = "Clear"
                    Attribute = $AttributeName
                    Value = "(cleared)"
                    Status = "Success"
                    Timestamp = Get-Date
                }
                $Global:executionLog.ExtensionAttributes.SuccessCount++
            }
            catch {
                Write-Log "Failed to clear $AttributeName for $UserEmail: $($_.Exception.Message)" -Level Error -Category "Attributes"
                $Global:executionLog.ExtensionAttributes.Errors += @{
                    User = $UserEmail
                    Action = "Clear"
                    Error = $_.Exception.Message
                    Timestamp = Get-Date
                }
                $Global:executionLog.ExtensionAttributes.ErrorCount++
                $Global:executionLog.General.TotalErrors++
            }
        }
    }
    
    Write-Log "Extension Attribute Management completed. Success: $($Global:executionLog.ExtensionAttributes.SuccessCount), Errors: $($Global:executionLog.ExtensionAttributes.ErrorCount)" -Category "Attributes"
}

# =============================================================================
# DEVICE CLEANUP FUNCTIONS
# =============================================================================

function Test-DeviceExclusion {
    param([object]$Device, [string[]]$AzureVMs = @())
    
    # Check explicit exclusion list
    if ($ExcludedDevices -contains $Device.DisplayName) {
        return $true
    }
    
    # Skip Windows Server and Linux Server
    if ($Device.OperatingSystem -match "WindowsServer|Server|Linux") {
        return $true
    }
    
    # Check Azure VM list
    if ($AzureVMs -contains $Device.DisplayName) {
        return $true
    }
    
    # Check VM patterns
    foreach ($pattern in $AzureVMPatterns) {
        if ($Device.DisplayName -match $pattern) {
            return $true
        }
    }
    
    # Check Azure infrastructure patterns
    foreach ($pattern in $AzureInfraPatterns) {
        if ($Device.DisplayName -match $pattern) {
            Write-Log "Excluding Azure infrastructure: $($Device.DisplayName)" -Category "Device"
            return $true
        }
    }
    
    # Check for VM indicators
    if ($Device.Model -match "Virtual Machine|Hyper-V" -or 
        $Device.Manufacturer -match "Microsoft Corporation" -or
        $Device.DeviceCategory -eq "Virtual Machine") {
        return $true
    }
    
    return $false
}

function Invoke-DeviceAction {
    param([object]$Device, [string]$Action, [string]$Reason)
    
    try {
        $logEntry = @{
            DeviceName = $Device.DisplayName
            DeviceId = $Device.Id
            OS = $Device.OperatingSystem
            LastSignIn = $Device.ApproximateLastSignInDateTime
            Compliance = $Device.ComplianceState
            Management = $Device.ManagementType
            Reason = if ($WhatIf) { "$Reason (What-If)" } else { $Reason }
            Timestamp = Get-Date
        }
        
        if ($WhatIf) {
            Write-Log "WHATIF: Would $Action device '$($Device.DisplayName)' - $Reason" -Level Warning -Category "Device"
        } else {
            switch ($Action) {
                "Disable" {
                    Update-MgDevice -DeviceId $Device.Id -BodyParameter @{ accountEnabled = $false } -ErrorAction Stop
                    Write-Log "DISABLED device: '$($Device.DisplayName)' - $Reason" -Category "Device"
                }
                "Delete" {
                    Remove-MgDevice -DeviceId $Device.Id -ErrorAction Stop
                    Write-Log "DELETED device: '$($Device.DisplayName)' - $Reason" -Category "Device"
                }
            }
        }
        
        switch ($Action) {
            "Disable" { $Global:executionLog.DeviceCleanup.DisabledDevices += $logEntry }
            "Delete" { $Global:executionLog.DeviceCleanup.DeletedDevices += $logEntry }
        }
        
        return $true
    }
    catch {
        Write-Log "Failed to $Action device '$($Device.DisplayName)': $($_.Exception.Message)" -Level Error -Category "Device"
        
        $Global:executionLog.DeviceCleanup.Errors += @{
            Device = $Device.DisplayName
            Action = $Action
            Error = $_.Exception.Message
            Timestamp = Get-Date
        }
        $Global:executionLog.General.TotalErrors++
        
        return $false
    }
}

function Get-DevicesForCleanup {
    param([string]$Description, [string]$Filter)
    
    try {
        Write-Log "Querying: $Description" -Category "Device"
        
        $devices = Get-MgDevice -Filter $Filter -All -Property "Id,DisplayName,OperatingSystem,ApproximateLastSignInDateTime,ComplianceState,ManagementType,TrustType,Model,Manufacturer,DeviceCategory,AccountEnabled" -ErrorAction Stop
        
        Write-Log "Found $($devices.Count) devices matching criteria" -Category "Device"
        return $devices
    }
    catch {
        Write-Log "Error querying devices: $($_.Exception.Message)" -Level Error -Category "Device"
        $Global:executionLog.DeviceCleanup.Errors += @{
            Query = $Description
            Error = $_.Exception.Message
            Timestamp = Get-Date
        }
        $Global:executionLog.General.TotalErrors++
        return @()
    }
}

function Invoke-DeviceCleanup {
    Write-Log "Starting Device Cleanup..." -Category "Device"
    
    $azureVMs = Get-AzureVMList
    
    $dateThresholds = @{
        InactivityCutoff = (Get-Date).AddDays(-$InactivityDays).ToString("yyyy-MM-ddTHH:mm:ssZ")
        MobileNonCompliantCutoff = (Get-Date).AddDays(-$NonCompliantMobileDays).ToString("yyyy-MM-ddTHH:mm:ssZ")
        WindowsNonCompliantCutoff = (Get-Date).AddDays(-$NonCompliantWindowsDays).ToString("yyyy-MM-ddTHH:mm:ssZ")
        MacOSNonCompliantCutoff = (Get-Date).AddDays(-$NonCompliantMacOSDays).ToString("yyyy-MM-ddTHH:mm:ssZ")
        UnmanagedDeviceCutoff = (Get-Date).AddDays(-$UnmanagedDeviceDays).ToString("yyyy-MM-ddTHH:mm:ssZ")
        DisabledDeletionCutoff = (Get-Date).AddDays(-($InactivityDays + $DisabledDeviceDeletionDays)).ToString("yyyy-MM-ddTHH:mm:ssZ")
    }
    
    $deviceQueries = @(
        @{
            Description = "Non-managed mobile devices"
            Filter = "(operatingSystem eq 'iOS' or operatingSystem eq 'Android') and managementType eq 'None'"
            Action = "Delete"
            Reason = "Non-managed mobile device"
        },
        @{
            Description = "Unmanaged desktop devices (Windows/macOS/Linux)"
            Filter = "(operatingSystem eq 'Windows' or operatingSystem eq 'MacOS' or operatingSystem eq 'Linux') and managementType eq 'None' and approximateLastSignInDateTime le $($dateThresholds.UnmanagedDeviceCutoff)"
            Action = "Disable"
            Reason = "Unmanaged desktop device (not in Intune, >$UnmanagedDeviceDays days)"
        },
        @{
            Description = "Inactive devices"
            Filter = "approximateLastSignInDateTime le $($dateThresholds.InactivityCutoff) and accountEnabled eq true"
            Action = "Disable"
            Reason = "Inactive device (>$InactivityDays days)"
        }
    )
    
    $totalProcessed = 0
    $processedDeviceIds = @{}
    
    foreach ($query in $deviceQueries) {
        if ($totalProcessed -ge $MaxDevices) {
            Write-Log "Reached maximum devices limit: $MaxDevices" -Level Warning -Category "Device"
            break
        }
        
        $devices = Get-DevicesForCleanup -Description $query.Description -Filter $query.Filter
        
        foreach ($device in $devices) {
            if ($processedDeviceIds.ContainsKey($device.Id)) { continue }
            $processedDeviceIds[$device.Id] = $true
            
            if (Test-DeviceExclusion -Device $device -AzureVMs $azureVMs) {
                $Global:executionLog.DeviceCleanup.SkippedDevices += @{
                    DeviceName = $device.DisplayName
                    OS = $device.OperatingSystem
                    Reason = "Excluded device"
                }
                continue
            }
            
            $success = Invoke-DeviceAction -Device $device -Action $query.Action -Reason $query.Reason
            if ($success) { $totalProcessed++ }
            
            if ($totalProcessed -ge $MaxDevices) {
                Write-Log "Reached processing limit: $MaxDevices" -Level Warning -Category "Device"
                break
            }
        }
    }
    
    # Handle deletion of long-disabled devices
    Write-Log "Processing long-disabled devices for deletion..." -Category "Device"
    $disabledDevices = Get-DevicesForCleanup -Description "Long-disabled devices" -Filter "approximateLastSignInDateTime le $($dateThresholds.DisabledDeletionCutoff) and accountEnabled eq false"
    
    if ($disabledDevices.Count -ge $DeletionSafetyLimit) {
        Write-Log "SAFETY STOP: Found $($disabledDevices.Count) disabled devices, safety limit is $DeletionSafetyLimit" -Level Warning -Category "Device"
    } else {
        foreach ($device in $disabledDevices) {
            if (Test-DeviceExclusion -Device $device -AzureVMs $azureVMs) {
                $Global:executionLog.DeviceCleanup.SkippedDevices += @{
                    DeviceName = $device.DisplayName
                    OS = $device.OperatingSystem
                    Reason = "Excluded from deletion"
                }
                continue
            }
            
            Invoke-DeviceAction -Device $device -Action "Delete" -Reason "Long-disabled device cleanup (>$DisabledDeviceDeletionDays days)"
        }
    }
    
    Write-Log "Device Cleanup completed. Disabled: $($Global:executionLog.DeviceCleanup.DisabledDevices.Count), Deleted: $($Global:executionLog.DeviceCleanup.DeletedDevices.Count), Skipped: $($Global:executionLog.DeviceCleanup.SkippedDevices.Count)" -Category "Device"
}

# =============================================================================
# GROUP CLEANUP FUNCTIONS
# =============================================================================

function Invoke-GroupCleanup {
    Write-Log "Starting Group Cleanup..." -Category "Group"
    
    if ([string]::IsNullOrWhiteSpace($GroupName)) {
        Write-Log "No group specified for cleanup" -Level Warning -Category "Group"
        return
    }
    
    try {
        $group = Get-MgGroup -Filter "displayName eq '$GroupName'" -ErrorAction Stop
        if (-not $group) {
            Write-Log "Group '$GroupName' not found" -Level Error -Category "Group"
            return
        }
        
        Write-Log "Found group: $($group.DisplayName) (ID: $($group.Id))" -Category "Group"
        
        # Get group members
        $members = Get-MgGroupMember -GroupId $group.Id -All
        Write-Log "Group has $($members.Count) members" -Category "Group"
        
        $cutoffDate = (Get-Date).AddDays(-$GroupCleanupDays)
        $removedCount = 0
        
        foreach ($member in $members) {
            try {
                # Get user details
                $user = Get-MgUser -UserId $member.Id -Property "CreatedDateTime,UserPrincipalName" -ErrorAction Stop
                
                # Check if user should be removed based on creation date (as an example)
                if ($user.CreatedDateTime -lt $cutoffDate) {
                    if ($WhatIf) {
                        Write-Log "WHATIF: Would remove $($user.UserPrincipalName) from $GroupName (created: $($user.CreatedDateTime))" -Level Warning -Category "Group"
                    } else {
                        Remove-MgGroupMemberByRef -GroupId $group.Id -DirectoryObjectId $user.Id -ErrorAction Stop
                        Write-Log "Removed $($user.UserPrincipalName) from $GroupName" -Category "Group"
                    }
                    
                    $Global:executionLog.GroupCleanup.RemovedUsers += @{
                        UserPrincipalName = $user.UserPrincipalName
                        UserId = $user.Id
                        GroupName = $GroupName
                        GroupId = $group.Id
                        CreatedDate = $user.CreatedDateTime
                        RemovedDate = Get-Date
                        Reason = "User older than $GroupCleanupDays days"
                    }
                    $removedCount++
                }
            }
            catch {
                Write-Log "Failed to process member $($member.Id): $($_.Exception.Message)" -Level Error -Category "Group"
                $Global:executionLog.GroupCleanup.Errors += @{
                    MemberId = $member.Id
                    GroupName = $GroupName
                    Error = $_.Exception.Message
                    Timestamp = Get-Date
                }
                $Global:executionLog.General.TotalErrors++
            }
        }
        
        $Global:executionLog.GroupCleanup.ProcessedGroups += @{
            GroupName = $GroupName
            GroupId = $group.Id
            TotalMembers = $members.Count
            RemovedMembers = $removedCount
            CleanupDays = $GroupCleanupDays
            ProcessedDate = Get-Date
        }
        
        Write-Log "Group Cleanup completed for $GroupName. Removed: $removedCount members" -Category "Group"
    }
    catch {
        Write-Log "Failed to process group cleanup: $($_.Exception.Message)" -Level Error -Category "Group"
        $Global:executionLog.GroupCleanup.Errors += @{
            GroupName = $GroupName
            Error = $_.Exception.Message
            Timestamp = Get-Date
        }
        $Global:executionLog.General.TotalErrors++
    }
}

# =============================================================================
# EMAIL REPORTING
# =============================================================================

function Send-UnifiedReport {
    try {
        if (-not $EmailFrom -or -not $EmailTo) {
            Write-Log "Email configuration not found in Automation Variables" -Level Warning -Category "Email"
            return
        }
        
        $duration = [math]::Round(((Get-Date) - $Global:executionLog.General.StartTime).TotalMinutes, 2)
        $modeIndicator = if ($WhatIf) { " [WHAT-IF]" } else { "" }
        
        $htmlBody = @"
<!DOCTYPE html>
<html>
<head>
    <style>
        body { font-family: 'Inter', Arial, sans-serif; margin: 20px; background: #f8f9fa; }
        .container { max-width: 1200px; margin: 0 auto; background: white; padding: 30px; border-radius: 16px; box-shadow: 0 4px 6px rgba(0,0,0,0.1); }
        .header { background: linear-gradient(135deg, #6366f1, #8b5cf6, #d946ef); color: white; padding: 30px; border-radius: 16px; margin-bottom: 30px; }
        .summary { background: #f8f9fa; padding: 25px; margin: 25px 0; border-radius: 12px; border-left: 6px solid #6366f1; }
        .metrics { display: flex; flex-wrap: wrap; gap: 15px; margin: 20px 0; }
        .metric { flex: 1; min-width: 140px; padding: 20px; border-radius: 12px; text-align: center; }
        .metric-value { font-size: 32px; font-weight: bold; display: block; margin-bottom: 5px; }
        .metric-label { font-size: 14px; color: #666; font-weight: 500; }
        .success { background: #dcfce7; color: #166534; }
        .warning { background: #fef3c7; color: #92400e; }
        .error { background: #fee2e2; color: #991b1b; }
        .info { background: #dbeafe; color: #1e40af; }
        table { border-collapse: collapse; width: 100%; margin: 20px 0; border-radius: 8px; overflow: hidden; }
        th, td { border: 1px solid #e5e7eb; padding: 12px; text-align: left; font-size: 13px; }
        th { background: #f9fafb; font-weight: 600; }
        tr:nth-child(even) { background: #f9fafb; }
        .section-title { color: #6366f1; border-bottom: 2px solid #e5e7eb; padding-bottom: 10px; margin: 30px 0 15px 0; font-size: 18px; font-weight: 600; }
        .whatif-notice { background: #fef3c7; border: 3px solid #f59e0b; padding: 20px; margin: 20px 0; border-radius: 12px; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🎯 Entra Management Report$modeIndicator</h1>
            <p>$(Get-Date -Format "dddd, MMMM dd, yyyy 'at' HH:mm") UTC | Duration: $duration minutes</p>
            <p>Operations: $Operation</p>
        </div>
        
        $(if ($WhatIf) { '<div class="whatif-notice"><strong>⚠️ WHAT-IF MODE</strong><br>This report shows what WOULD happen. No actual changes were made.</div>' })
        
        <div class="summary">
            <h3>📊 Execution Summary</h3>
            <div class="metrics">
                <div class="metric warning">
                    <span class="metric-value">$($Global:executionLog.DeviceCleanup.DisabledDevices.Count + $Global:executionLog.DeviceCleanup.DeletedDevices.Count)</span>
                    <span class="metric-label">Devices Processed</span>
                </div>
                <div class="metric info">
                    <span class="metric-value">$($Global:executionLog.GroupCleanup.RemovedUsers.Count)</span>
                    <span class="metric-label">Users Removed from Groups</span>
                </div>
                <div class="metric $(if ($Global:executionLog.General.TotalErrors -gt 0) { 'error' } else { 'success' })">
                    <span class="metric-value">$($Global:executionLog.General.TotalErrors)</span>
                    <span class="metric-label">Total Errors</span>
                </div>
            </div>
        </div>
"@

        # Extension Attributes Section
        if ($Operation -in @("ExtensionAttributes", "All") -and ($Global:executionLog.ExtensionAttributes.ProcessedUsers.Count -gt 0 -or $Global:executionLog.ExtensionAttributes.Errors.Count -gt 0)) {
            $htmlBody += "<h3 class='section-title'>⚙️ Extension Attributes ($($Global:executionLog.ExtensionAttributes.ProcessedUsers.Count) processed)</h3>"
            
            if ($Global:executionLog.ExtensionAttributes.ProcessedUsers.Count -gt 0) {
                $htmlBody += "<table><tr><th>User</th><th>Action</th><th>Attribute</th><th>Value</th><th>Status</th></tr>"
                foreach ($user in $Global:executionLog.ExtensionAttributes.ProcessedUsers) {
                    $htmlBody += "<tr><td>$($user.User)</td><td>$($user.Action)</td><td>$($user.Attribute)</td><td>$($user.Value)</td><td>$($user.Status)</td></tr>"
                }
                $htmlBody += "</table>"
            }
        }

        # Device Cleanup Section
        if ($Operation -in @("DeviceCleanup", "All") -and ($Global:executionLog.DeviceCleanup.DisabledDevices.Count -gt 0 -or $Global:executionLog.DeviceCleanup.DeletedDevices.Count -gt 0)) {
            if ($Global:executionLog.DeviceCleanup.DisabledDevices.Count -gt 0) {
                $htmlBody += "<h3 class='section-title'>🔒 Disabled Devices ($($Global:executionLog.DeviceCleanup.DisabledDevices.Count))</h3>"
                $htmlBody += "<table><tr><th>Device</th><th>OS</th><th>Last Sign-In</th><th>Reason</th></tr>"
                foreach ($device in $Global:executionLog.DeviceCleanup.DisabledDevices) {
                    $lastSignIn = if ($device.LastSignIn) { 
                        try { (Get-Date $device.LastSignIn).ToString("MMM dd, yyyy") } catch { "Unknown" }
                    } else { "Never" }
                    $htmlBody += "<tr><td>$($device.DeviceName)</td><td>$($device.OS)</td><td>$lastSignIn</td><td>$($device.Reason)</td></tr>"
                }
                $htmlBody += "</table>"
            }

            if ($Global:executionLog.DeviceCleanup.DeletedDevices.Count -gt 0) {
                $htmlBody += "<h3 class='section-title'>🗑️ Deleted Devices ($($Global:executionLog.DeviceCleanup.DeletedDevices.Count))</h3>"
                $htmlBody += "<table><tr><th>Device</th><th>OS</th><th>Last Sign-In</th><th>Reason</th></tr>"
                foreach ($device in $Global:executionLog.DeviceCleanup.DeletedDevices) {
                    $lastSignIn = if ($device.LastSignIn) { 
                        try { (Get-Date $device.LastSignIn).ToString("MMM dd, yyyy") } catch { "Unknown" }
                    } else { "Never" }
                    $htmlBody += "<tr><td>$($device.DeviceName)</td><td>$($device.OS)</td><td>$lastSignIn</td><td>$($device.Reason)</td></tr>"
                }
                $htmlBody += "</table>"
            }

            if ($Global:executionLog.DeviceCleanup.AzureVMs.Count -gt 0) {
                $htmlBody += "<h3 class='section-title'>☁️ Azure VMs Excluded ($($Global:executionLog.DeviceCleanup.AzureVMs.Count))</h3>"
                $htmlBody += "<table><tr><th>VM Name</th><th>Resource Group</th><th>Location</th></tr>"
                foreach ($vm in $Global:executionLog.DeviceCleanup.AzureVMs) {
                    $htmlBody += "<tr><td>$($vm.Name)</td><td>$($vm.ResourceGroup)</td><td>$($vm.Location)</td></tr>"
                }
                $htmlBody += "</table>"
            }
        }

        # Group Cleanup Section
        if ($Operation -in @("GroupCleanup", "All") -and ($Global:executionLog.GroupCleanup.RemovedUsers.Count -gt 0 -or $Global:executionLog.GroupCleanup.ProcessedGroups.Count -gt 0)) {
            if ($Global:executionLog.GroupCleanup.ProcessedGroups.Count -gt 0) {
                $htmlBody += "<h3 class='section-title'>👥 Group Processing Summary</h3>"
                $htmlBody += "<table><tr><th>Group</th><th>Total Members</th><th>Removed Members</th><th>Cleanup Days</th></tr>"
                foreach ($group in $Global:executionLog.GroupCleanup.ProcessedGroups) {
                    $htmlBody += "<tr><td>$($group.GroupName)</td><td>$($group.TotalMembers)</td><td>$($group.RemovedMembers)</td><td>$($group.CleanupDays)</td></tr>"
                }
                $htmlBody += "</table>"
            }

            if ($Global:executionLog.GroupCleanup.RemovedUsers.Count -gt 0) {
                $htmlBody += "<h3 class='section-title'>👤 Removed Users ($($Global:executionLog.GroupCleanup.RemovedUsers.Count))</h3>"
                $htmlBody += "<table><tr><th>User</th><th>Group</th><th>Created Date</th><th>Reason</th></tr>"
                foreach ($removal in $Global:executionLog.GroupCleanup.RemovedUsers) {
                    $createdDate = try { (Get-Date $removal.CreatedDate).ToString("MMM dd, yyyy") } catch { "Unknown" }
                    $htmlBody += "<tr><td>$($removal.UserPrincipalName)</td><td>$($removal.GroupName)</td><td>$createdDate</td><td>$($removal.Reason)</td></tr>"
                }
                $htmlBody += "</table>"
            }
        }

        # Errors Section
        if ($Global:executionLog.General.TotalErrors -gt 0) {
            $htmlBody += "<h3 class='section-title' style='color: #dc2626;'>❌ Errors ($($Global:executionLog.General.TotalErrors))</h3>"
            $htmlBody += "<table><tr><th>Category</th><th>Item</th><th>Error</th><th>Time</th></tr>"
            
            foreach ($error in $Global:executionLog.ExtensionAttributes.Errors) {
                $htmlBody += "<tr><td>Extension Attributes</td><td>$($error.User)</td><td>$($error.Error)</td><td>$($error.Timestamp.ToString('HH:mm:ss'))</td></tr>"
            }
            
            foreach ($error in $Global:executionLog.DeviceCleanup.Errors) {
                $item = if ($error.Device) { $error.Device } else { $error.Query }
                $htmlBody += "<tr><td>Device Cleanup</td><td>$item</td><td>$($error.Error)</td><td>$($error.Timestamp.ToString('HH:mm:ss'))</td></tr>"
            }
            
            foreach ($error in $Global:executionLog.GroupCleanup.Errors) {
                $item = if ($error.GroupName) { $error.GroupName } elseif ($error.MemberId) { $error.MemberId } else { "Unknown" }
                $htmlBody += "<tr><td>Group Cleanup</td><td>$item</td><td>$($error.Error)</td><td>$($error.Timestamp.ToString('HH:mm:ss'))</td></tr>"
            }
            
            $htmlBody += "</table>"
        }

        $htmlBody += @"
        <div style="margin-top: 30px; padding: 20px; background: #f9fafb; border-radius: 12px; font-size: 12px; color: #6b7280;">
            <strong>🔧 Configuration:</strong><br>
            Device Cleanup: Inactivity ${InactivityDays}d | Mobile ${NonCompliantMobileDays}d | Windows ${NonCompliantWindowsDays}d | macOS ${NonCompliantMacOSDays}d | Max ${MaxDevices} devices<br>
            Group Cleanup: ${GroupCleanupDays} days threshold<br>
            Extension Attributes: Attribute ${ExtensionAttributeNumber} | Value: '$AttributeValue'
        </div>
        
        <div style="margin-top: 20px; text-align: center; font-size: 12px; color: #9ca3af;">
            <strong>ENTRA MANAGEMENT</strong> | Vitesse PSP Limited | Powered by Azure Automation & Microsoft Graph
        </div>
    </div>
</body>
</html>
"@

        # Prepare recipients
        $recipients = @()
        $emailAddresses = if ($EmailTo -contains ";") {
            $EmailTo -split ";" | ForEach-Object { $_.Trim() }
        } elseif ($EmailTo -contains ",") {
            $EmailTo -split "," | ForEach-Object { $_.Trim() }
        } else {
            @($EmailTo.Trim())
        }
        
        foreach ($email in $emailAddresses) {
            if ($email -and $email -match "^[^@]+@[^@]+\.[^@]+$") {
                $recipients += @{ emailAddress = @{ address = $email } }
            }
        }
        
        if ($recipients.Count -eq 0) {
            Write-Log "No valid email recipients found" -Level Warning -Category "Email"
            return
        }
        
        $subject = if ($WhatIf) {
            "Entra Management Analysis - $(Get-Date -Format "MMM dd, HH:mm")"
        } else {
            "Entra Management Report - $(Get-Date -Format "MMM dd, HH:mm")"
        }
        
        $emailMessage = @{
            message = @{
                subject = $subject
                body = @{ contentType = "HTML"; content = $htmlBody }
                toRecipients = $recipients
                importance = if ($Global:executionLog.General.TotalErrors -gt 0) { "high" } else { "normal" }
            }
            saveToSentItems = $true
        }

        Send-MgUserMail -UserId $EmailFrom -BodyParameter $emailMessage -ErrorAction Stop
        Write-Log "Email report sent to: $($emailAddresses -join ', ')" -Category "Email"
        
    }
    catch {
        Write-Log "Failed to send email: $($_.Exception.Message)" -Level Error -Category "Email"
        
        if ($_.Exception.Message -match "Forbidden|Unauthorized|403") {
            Write-Log "Check that Managed Identity has Mail.Send permission" -Level Warning -Category "Email"
        }
    }
}

# =============================================================================
# MAIN EXECUTION
# =============================================================================

try {
    Write-Log "=== ENTRA MANAGEMENT UNIFIED RUNBOOK STARTED ===" -Category "Main"
    Write-Log "Operation: $Operation | Mode: $(if ($WhatIf) { 'WHAT-IF (SAFE)' } else { 'LIVE EXECUTION' })" -Category "Main"
    
    # Connect to Microsoft Graph
    if (-not (Connect-ToGraph)) {
        throw "Failed to connect to Microsoft Graph"
    }
    
    # Execute based on operation parameter
    switch ($Operation) {
        "ExtensionAttributes" {
            Invoke-ExtensionAttributeManagement
        }
        "DeviceCleanup" {
            Invoke-DeviceCleanup
        }
        "GroupCleanup" {
            Invoke-GroupCleanup
        }
        "All" {
            # Execute all operations
            if (![string]::IsNullOrWhiteSpace($UsersToAdd) -or ![string]::IsNullOrWhiteSpace($UsersToRemove)) {
                Invoke-ExtensionAttributeManagement
            }
            
            Invoke-DeviceCleanup
            
            if (![string]::IsNullOrWhiteSpace($GroupName)) {
                Invoke-GroupCleanup
            }
        }
    }
    
    # Calculate summary statistics
    $endTime = Get-Date
    $duration = [math]::Round(($endTime - $Global:executionLog.General.StartTime).TotalMinutes, 2)
    
    Write-Log "=== EXECUTION COMPLETE ===" -Category "Main"
    Write-Log "Duration: $duration minutes" -Category "Main"
    Write-Log "Extension Attributes - Success: $($Global:executionLog.ExtensionAttributes.SuccessCount), Errors: $($Global:executionLog.ExtensionAttributes.ErrorCount)" -Category "Main"
    Write-Log "Device Cleanup - Disabled: $($Global:executionLog.DeviceCleanup.DisabledDevices.Count), Deleted: $($Global:executionLog.DeviceCleanup.DeletedDevices.Count), Skipped: $($Global:executionLog.DeviceCleanup.SkippedDevices.Count)" -Category "Main"
    Write-Log "Group Cleanup - Processed Groups: $($Global:executionLog.GroupCleanup.ProcessedGroups.Count), Removed Users: $($Global:executionLog.GroupCleanup.RemovedUsers.Count)" -Category "Main"
    Write-Log "Total Errors: $($Global:executionLog.General.TotalErrors)" -Category "Main"
    
    if ($WhatIf) {
        Write-Log "*** WHAT-IF MODE - NO CHANGES MADE ***" -Level Warning -Category "Main"
    }
    
    # Send email report
    if ($SendEmail) {
        Send-UnifiedReport
    }
    
    # Return results
    $results = @{
        Success = ($Global:executionLog.General.TotalErrors -eq 0)
        Operation = $Operation
        StartTime = $Global:executionLog.General.StartTime
        EndTime = $endTime
        DurationMinutes = $duration
        WhatIfMode = $WhatIf
        ExtensionAttributes = @{
            SuccessCount = $Global:executionLog.ExtensionAttributes.SuccessCount
            ErrorCount = $Global:executionLog.ExtensionAttributes.ErrorCount
            ProcessedUsers = $Global:executionLog.ExtensionAttributes.ProcessedUsers.Count
        }
        DeviceCleanup = @{
            DisabledCount = $Global:executionLog.DeviceCleanup.DisabledDevices.Count
            DeletedCount = $Global:executionLog.DeviceCleanup.DeletedDevices.Count
            SkippedCount = $Global:executionLog.DeviceCleanup.SkippedDevices.Count
            ErrorCount = $Global:executionLog.DeviceCleanup.Errors.Count
        }
        GroupCleanup = @{
            ProcessedGroups = $Global:executionLog.GroupCleanup.ProcessedGroups.Count
            RemovedUsers = $Global:executionLog.GroupCleanup.RemovedUsers.Count
            ErrorCount = $Global:executionLog.GroupCleanup.Errors.Count
        }
        TotalErrors = $Global:executionLog.General.TotalErrors
    }
    
    return $results
    
} catch {
    Write-Log "Critical error: $($_.Exception.Message)" -Level Error -Category "Main"
    $Global:executionLog.General.TotalErrors++
    
    if ($SendEmail) {
        try { Send-UnifiedReport } catch { }
    }
    
    throw
} finally {
    try {
        Disconnect-MgGraph -ErrorAction SilentlyContinue
        Write-Log "Disconnected from Microsoft Graph" -Category "Main"
    } catch { }
} success">
                    <span class="metric-value">$($Global:executionLog.ExtensionAttributes.SuccessCount)</span>
                    <span class="metric-label">Attributes Updated</span>
                </div>
                <div class="metric