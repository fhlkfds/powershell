# Define Variables
$VMNames = @("VM1", "VM2", "VM3")  # Change to your VM names
$BackupRoot = "D:\HyperV-Backups"
$Today = Get-Date -Format "yyyy-MM-dd"

# Email Configuration
$EmailTo = "your@email.com"        # Replace with your email
$EmailFrom = "your@email.com"       # Sender email (must match SMTP authentication)
$SMTPServer = "smtp.office365.com"  # Change to your mail provider's SMTP server
$SMTPPort = 587                     # Usually 587 for TLS, 465 for SSL
$SMTPUser = "your@email.com"        # SMTP authentication username
$SMTPPassword = "your-email-password" # Use App Password for Gmail or OAuth methods

# Google Drive Path
$GoogleDrivePath = "GoogleDrive:HyperV-Backups"

# Email Body
$EmailBody = @"
Hello,

The Hyper-V backup for multiple VMs has been successfully completed on **$Today**.

Backup details:
"@

# Loop through each VM
foreach ($VMName in $VMNames) {
    Write-Host "Processing backup for VM: $VMName"

    # Define Backup Paths
    $WeeklyBackupPath = "$BackupRoot\Weekly\$VMName-$Today"
    $MonthlyBackupPath = "$BackupRoot\Monthly\$VMName-$Today"
    $YearlyBackupPath = "$BackupRoot\Yearly\$VMName-$Today"

    # Create Backup Directories
    New-Item -ItemType Directory -Path $WeeklyBackupPath -Force | Out-Null
    New-Item -ItemType Directory -Path $MonthlyBackupPath -Force | Out-Null
    New-Item -ItemType Directory -Path $YearlyBackupPath -Force | Out-Null

    # Export the VM
    Write-Host "Exporting VM: $VMName..."
    Export-VM -Name $VMName -Path $WeeklyBackupPath

    # Determine if it's the first backup of the month
    if ((Get-Date).Day -eq 1) {
        Write-Host "First day of the month! Creating Monthly Backup for $VMName..."
        Copy-Item -Path $WeeklyBackupPath -Destination $MonthlyBackupPath -Recurse
    }

    # Determine if it's the first backup of the year
    if ((Get-Date).Month -eq 1 -and (Get-Date).Day -eq 1) {
        Write-Host "First day of the year! Creating Yearly Backup for $VMName..."
        Copy-Item -Path $WeeklyBackupPath -Destination $YearlyBackupPath -Recurse
    }

    # Upload to Google Drive with Rclone
    Write-Host "Uploading Weekly Backup for $VMName to Google Drive..."
    rclone copy "$WeeklyBackupPath" "$GoogleDrivePath/Weekly/" --progress

    Write-Host "Uploading Monthly Backup for $VMName to Google Drive (if applicable)..."
    rclone copy "$MonthlyBackupPath" "$GoogleDrivePath/Monthly/" --progress

    Write-Host "Uploading Yearly Backup for $VMName to Google Drive (if applicable)..."
    rclone copy "$YearlyBackupPath" "$GoogleDrivePath/Yearly/" --progress

    # Add VM details to email
    $EmailBody += @"
- VM: **$VMName**
  - Weekly Backup: $WeeklyBackupPath
  - Monthly Backup: $MonthlyBackupPath
  - Yearly Backup: $YearlyBackupPath

"@
}

# Delete Old Backups in Google Drive
Write-Host "Deleting old backups in Google Drive..."
rclone delete --min-age 8d "$GoogleDrivePath/Weekly/"
rclone delete --min-age 32d "$GoogleDrivePath/Monthly/"
rclone delete --min-age 366d "$GoogleDrivePath/Yearly/"
rclone rmdirs "$GoogleDrivePath/" --leave-root  # Remove empty folders

# Delete Local Old Backups (optional)
Write-Host "Cleaning up local old backups..."
Get-ChildItem "$BackupRoot\Weekly" -Directory | Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-8) } | Remove-Item -Recurse -Force
Get-ChildItem "$BackupRoot\Monthly" -Directory | Where-Object { $_.LastWriteTime -lt (Get-Date).AddMonths(-1) } | Remove-Item -Recurse -Force
Get-ChildItem "$BackupRoot\Yearly" -Directory | Where-Object { $_.LastWriteTime -lt (Get-Date).AddYears(-1) } | Remove-Item -Recurse -Force

Write-Host "Backup and upload process completed!"

# Finalize Email Body
$EmailBody += @"

Backups have been uploaded to Google Drive and old backups have been deleted as per retention policy.

Best regards,
Hyper-V Backup System
"@

# Send Email Notification
$SMTPMessage = @{
    From       = $EmailFrom
    To         = $EmailTo
    Subject    = "Hyper-V Backup Completed Successfully - $Today"
    Body       = $EmailBody
    SmtpServer = $SMTPServer
    Port       = $SMTPPort
    Credential = New-Object System.Management.Automation.PSCredential ($SMTPUser, (ConvertTo-SecureString $SMTPPassword -AsPlainText -Force))
    UseSsl     = $true
}

Send-MailMessage @SMTPMessage

Write-Host "Email notification sent to $EmailTo!"

