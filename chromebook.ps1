<#
.SYNOPSIS
ChromeOS Device Management Tool using GAM

.REQUIREMENTS
- GAM installed and configured
- Google Workspace admin privileges
#>

# Configure GAM path
$gamPath = "C:\GAM\gam.exe"  # Update with your GAM installation path

# Get asset tag from user
$assetTag = Read-Host "Enter the Chromebook's Asset Tag"

try {
    # Get device ID from asset tag
    $deviceInfo = & $gamPath print cros matchassetid "$assetTag" | Select-Object -Skip 1
    $deviceId = ($deviceInfo -split ",")[0]
    
    if(-not $deviceId) {
        throw "No device found with asset tag: $assetTag"
    }

    Write-Host "`nDevice found!`nDevice ID: $deviceId`n"

    # Show action menu
    $action = Read-Host @"
Select action:
1. Disable Device
2. Powerwash Device
3. Enable Device
4. Lock Device
Enter choice (1-4)
"@

    # Process action
    switch ($action) {
        "1" {
            Write-Host "Disabling device..."
            & $gamPath update cros $deviceId action disable
            Write-Host "Device disabled successfully" -ForegroundColor Green
        }
        "2" {
            Write-Host "Powerwashing device..."
            & $gamPath update cros $deviceId action powerwash
            Write-Host "Powerwash initiated successfully" -ForegroundColor Green
        }
        "3" {
            Write-Host "Enabling device..."
            & $gamPath update cros $deviceId action reenable
            Write-Host "Device enabled successfully" -ForegroundColor Green
        }
        "4" {
            Write-Host "Locking device..."
            & $gamPath update cros $deviceId action lock
            Write-Host "Device locked successfully" -ForegroundColor Green
        }
        default {
            Write-Host "Invalid selection" -ForegroundColor Red
            exit
        }
    }
}
catch {
    Write-Host "`nError: $_" -ForegroundColor Red
    exit
}

Write-Host "`nOperation completed`n"
