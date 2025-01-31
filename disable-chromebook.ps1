<#
.SYNOPSIS
Bulk disable all ChromeOS devices in a Google Workspace domain

.DESCRIPTION
This script will:
1. Retrieve all ChromeOS devices
2. Disable them sequentially
3. Provide progress reporting
4. Log results to a file

.NOTES
Requires GAM configured with appropriate admin privileges
#>

# Configuration
$gamPath = "C:\GAM\gam.exe"  # Update with your GAM path
$logFile = "C:\Logs\ChromebookDisable_$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
$operationDelay = 1  # Seconds between operations to avoid rate limiting

# Safety confirmation
Write-Host "WARNING: This will disable ALL Chromebooks in your domain!" -ForegroundColor Red
$confirmation = Read-Host "Are you absolutely sure? (Type 'DISABLE ALL' to continue)"

if ($confirmation -ne "DISABLE ALL") {
    Write-Host "Operation cancelled" -ForegroundColor Yellow
    exit
}

# Create log directory if needed
if (-not (Test-Path (Split-Path $logFile -Parent))) {
    New-Item -ItemType Directory -Path (Split-Path $logFile -Parent) | Out-Null
}

# Get all ChromeOS devices
try {
    Write-Host "`nRetrieving Chromebook inventory..."
    $devices = & $gamPath print cros | Select-Object -Skip 1
}
catch {
    Write-Host "Error retrieving devices: $_" -ForegroundColor Red
    exit
}

if (-not $devices) {
    Write-Host "No Chromebooks found in domain" -ForegroundColor Yellow
    exit
}

# Process devices
$totalDevices = $devices.Count
$counter = 0
$successCount = 0
$failCount = 0

Write-Host "`nFound $totalDevices Chromebook(s)`n"

foreach ($device in $devices) {
    $counter++
    $deviceId = ($device -split ",")[0]
    $assetId = ($device -split ",")[1]
    $status = ($device -split ",")[-1].Trim()

    Write-Progress -Activity "Disabling Chromebooks" -Status "Processing $deviceId" `
        -PercentComplete (($counter / $totalDevices) * 100)

    # Skip already disabled devices
    if ($status -eq "DISABLED") {
        Write-Host "[$counter/$totalDevices] $deviceId ($assetId) is already disabled" -ForegroundColor Gray
        Add-Content $logFile "[SKIPPED] $deviceId,$assetId,Already disabled"
        $successCount++
        continue
    }

    # Attempt disable
    try {
        Write-Host "[$counter/$totalDevices] Disabling $deviceId ($assetId)..."
        & $gamPath update cros $deviceId action disable | Out-Null
        
        Add-Content $logFile "[SUCCESS] $deviceId,$assetId"
        $successCount++
        Write-Host "Successfully disabled $deviceId" -ForegroundColor Green
    }
    catch {
        Add-Content $logFile "[FAILED] $deviceId,$assetId,$_"
        $failCount++
        Write-Host "Error disabling $deviceId : $_" -ForegroundColor Red
    }

    Start-Sleep -Seconds $operationDelay
}

# Summary report
Write-Host "`nOperation Complete:`n"
Write-Host "Total Devices: $totalDevices"
Write-Host "Successfully disabled: $successCount" -ForegroundColor Green
Write-Host "Failed attempts: $failCount" -ForegroundColor Red
Write-Host "Log file created: $logFile`n"

if ($failCount -gt 0) {
    Write-Host "Note: Some devices failed to disable. Check the log file for details." -ForegroundColor Yellow
}
