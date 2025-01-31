<#
.SYNOPSIS
ChromeOS Device Management Tool using GAM

.REQUIREMENTS
- GAM installed and configured
- Google Workspace admin privileges
#>

# Configure GAM path
$gamPath = "C:\GAM\gam.exe"  # Update with your GAM installation path

# Validate if GAM exists
if (!(Test-Path $gamPath)) {
    Write-Host "Error: GAM not found at $gamPath. Please check the installation path." -ForegroundColor Red
    exit
}

# Get asset tag from user
$assetTag = Read-Host "Enter the Chromebook's Asset Tag"

try {
    # Get device info from asset tag
    $deviceInfo = & $gamPath print cros matchassetid "$assetTag" | Select-Object -Skip 1
    $deviceData = $deviceInfo -split ","
    $deviceId = $deviceData[0] -replace "`r", ""  # Clean up carriage returns
    $deviceOU = $deviceData[1] -replace "`r", ""  # Fetch the organizational unit

    if (-not $deviceId -or $deviceId -match "No matching") {
        throw "No device found with asset tag: $assetTag"
    }

    Write-Host "`nDevice found!`nDevice ID: $deviceId`nOrganizational Unit: $deviceOU`n"

    # Verify the device is in "Devices -> Cadet -> Chromebooks" (or its sub-OUs)
    $allowedOU = "/Cadet/Chromebooks"
    if ($deviceOU -notmatch "^$allowedOU") {
        throw "Device is in an unauthorized OU: $deviceOU. Only devices in $allowedOU (including sub-OUs) can be managed."
    }

    # Show action menu
    $actions = @{
        "1" = "disable"
        "2" = "powerwash"
        "3" = "reenable"
        "4" = "lock"
    }

    $action = Read-Host @"
Select action:
1. Disable Device
2. Powerwash Device
3. Enable Device
4. Lock Device
Enter choice (1-4)
"@

    if ($actions.ContainsKey($action)) {
        $actionType = $actions[$action]
        Write-Host "`nExecuting: $actionType on device $deviceId in $deviceOU..." -ForegroundColor Yellow

        & $gamPath update cros $deviceId action $actionType

        Write-Host "Device action '$actionType' executed successfully!" -ForegroundColor Green
    } else {
        Write-Host "Invalid selection. Please enter a number between 1-4." -ForegroundColor Red
    }
}
catch {
    Write-Host "`nError: $_" -ForegroundColor Red
}

Write-Host "`nOperation completed`n"

