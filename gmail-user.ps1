# User Creation Script
# Requirements: RSAT-AD-PowerShell, GAM, Google Sheet with headers: Email,FirstName,LastName,Username

# Configuration
$sheetURL = "https://docs.google.com/spreadsheets/d/YOUR_SHEET_ID/export?format=csv"
$outputCSV = "C:\temp\users.csv"
$gamPath = "C:\GAM\gam.exe"  # Update to your GAM path
$domain = "yourdomain.com"   # Update with your domain
$password = "Password@1"

# Download Google Sheet
try {
    Invoke-WebRequest -Uri $sheetURL -OutFile $outputCSV
    $users = Import-Csv $outputCSV
} catch {
    Write-Error "Failed to download/parse Google Sheet: $_"
    exit
}

# Import AD Module
try {
    Import-Module ActiveDirectory -ErrorAction Stop
} catch {
    Write-Error "Failed to load AD module: $_"
    exit
}

foreach ($user in $users) {
    # Create AD User
    try {
        $newUserParams = @{
            Name = "$($user.FirstName) $($user.LastName)"
            GivenName = $user.FirstName
            Surname = $user.LastName
            SamAccountName = $user.Username
            UserPrincipalName = "$($user.Username)@$domain"
            AccountPassword = ConvertTo-SecureString $password -AsPlainText -Force
            Enabled = $true
            PasswordNeverExpires = $false
            ChangePasswordAtLogon = $true
        }
        
        New-ADUser @newUserParams -ErrorAction Stop
        Write-Host "Created AD user: $($user.Username)"
    } catch {
        Write-Warning "Failed to create AD user $($user.Username): $_"
        continue
    }

    # Create Google Workspace User
    try {
        & $gamPath create user $user.Email `
            firstname $user.FirstName `
            lastname $user.LastName `
            password '"""'$password'"""'  # Triple quotes for special characters
        Write-Host "Created Google user: $($user.Email)"
    } catch {
        Write-Warning "Failed to create Google user $($user.Email): $_"
        continue
    }

    # Send Notification Email
    $emailBody = @"
New user created:
Username: $($user.Username)
Email: $($user.Email)
Temporary Password: $password
"@

    try {
        & $gamPath sendemail to "test@test.lan" `
            subject "New User Created - $($user.Email)" `
            message "$emailBody"
        Write-Host "Sent notification for $($user.Email)"
    } catch {
        Write-Warning "Failed to send email for $($user.Email): $_"
    }
}

# Cleanup
Remove-Item $outputCSV -ErrorAction SilentlyContinue
