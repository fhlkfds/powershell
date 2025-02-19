<#
    Example PowerShell Script: Remove Built-In Windows Apps
    for a K12 "clean" image.
    
    Customize to your environment’s needs. 
    Use at your own risk—always test first!
#>
Write-Host "Disable Bitlocker for imaging"
manage-bde -off c:


Write-Host "Removing built-in bloat apps. Please wait..."

# --- 1. Remove Apps for All Current Users ---
#    We'll target many known consumer/bloat packages.

# Examples you might consider removing:
# Candy Crush, Xbox, Bing, Mixed Reality, etc.
# If there's an app you *want* to keep, just comment out its line.

$appsToRemove = @(
    "*CandyCrush*",
    "*king.com.CandyCrushSaga*",
    "*king.com.CandyCrushSodaSaga*",
    "*Microsoft.BingWeather*",
    "*Microsoft.GetHelp*",
    "*Microsoft.Getstarted*",
    "*Microsoft.Microsoft3DViewer*",
    "*Microsoft.MicrosoftOfficeHub*",
    "*Microsoft.MicrosoftSolitaireCollection*",
    "*Microsoft.MixedReality.Portal*",
    "*Microsoft.Office.OneNote*",
    "*Microsoft.OneConnect*",
    "*Microsoft.People*",
    "*Microsoft.Print3D*",
    "*Microsoft.SkypeApp*",
    "*Microsoft.Wallet*",
    "*Microsoft.WindowsFeedbackHub*",
    "*Microsoft.WindowsMaps*",
    "*Microsoft.WindowsSoundRecorder*",
    "*Microsoft.Xbox.TCUI*",
    "*Microsoft.XboxApp*",
    "*Microsoft.XboxGameOverlay*",
    "*Microsoft.XboxGamingOverlay*",
    "*Microsoft.XboxIdentityProvider*",
    "*Microsoft.XboxSpeechToTextOverlay*",
    "*Microsoft.YourPhone*",
    "*Microsoft.ZuneMusic*",
    "*Microsoft.ZuneVideo*",
    "*Microsoft.MinecraftUWP*",
    "*Microsoft.MicrosoftNews*"
)

foreach ($app in $appsToRemove) {
    Get-AppxPackage -AllUsers -Name $app | ForEach-Object {
        Write-Host "Removing AppX Package: $($app)"
        Remove-AppxPackage -Package $_.PackageFullName -AllUsers
    }
}

Write-Host "`n--- Removing provisioning packages (prevents reinstallation for new users) ---`n"
# --- 2. Remove Provisioned Appx Packages from the OS Image ---
# This prevents them from installing again for *new* user accounts.

foreach ($app in $appsToRemove) {
    Get-AppxProvisionedPackage -Online |
        Where-Object DisplayName -like $app |
        ForEach-Object {
            Write-Host "Removing Provisioned Package: $($app)"
            Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName
        }
}

Write-Host "`nAll specified apps have been removed (or attempted)."
Write-Host "Script complete!"

