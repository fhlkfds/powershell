# Check if running as administrator
function Test-Administrator {
	$currentUser = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
	$isAdmin = $currentUser.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
	return $isAdmin
}

# Check if RSAT AD tools are installed
function Test-RSATInstalled {
	$rsatStatus = Get-WindowsCapability -Name "Rsat.ActiveDirectory*" -Online
	return $rsatStatus.State -eq "Installed"
}

# Install RSAT AD tools
function Install-RSAT {
	try {
    	Write-Host "Installing RSAT Active Directory tools..." -ForegroundColor Yellow
    	Add-WindowsCapability -Name "Rsat.ActiveDirectory.DS-LDS.Tools~~~~0.0.1.0" -Online
    	Write-Host "RSAT tools installed successfully." -ForegroundColor Green
    	return $true
	}
	catch {
    	Write-Host "Error installing RSAT tools: $_" -ForegroundColor Red
    	return $false
	}
}

# Main script
if (-not (Test-Administrator)) {
	Write-Host "This script must be run as Administrator. Please restart PowerShell as Administrator." -ForegroundColor Red
	Start-Sleep -Seconds 2
	exit
}

# Check and install RSAT if needed
if (-not (Test-RSATInstalled)) {
	Write-Host "RSAT Active Directory tools are not installed." -ForegroundColor Yellow
	$installConfirm = Read-Host "Would you like to install them now? (Y/N)"
	if ($installConfirm -eq 'Y') {
    	if (-not (Install-RSAT)) {
        	Write-Host "Failed to install RSAT tools. Script cannot continue." -ForegroundColor Red
        	Start-Sleep -Seconds 2
        	exit
    	}
	}
	else {
    	Write-Host "RSAT tools are required for this script. Exiting." -ForegroundColor Red
    	Start-Sleep -Seconds 2
    	exit
	}
}

# Prompt for domain credentials with admin rights
$credential = Get-Credential -Message "Enter Domain Admin Credentials"

# Set domain
$domainName = "test.lan"

# Prompt for search term (username or name)
$searchTerm = Read-Host -Prompt "Enter username or name to search for"

try {
	# Create DirectoryEntry object with provided credentials
	$directoryEntry = New-Object System.DirectoryServices.DirectoryEntry("LDAP://$domainName", $credential.UserName, $credential.GetNetworkCredential().Password)
    
	# Create DirectorySearcher object
	$searcher = New-Object System.DirectoryServices.DirectorySearcher($directoryEntry)
	$searcher.SearchScope = "Subtree"
    
	# Search by either username or name
	$searcher.Filter = "(|(samAccountName=*$searchTerm*)(cn=*$searchTerm*))"
    
	# Find all matching users
	$users = $searcher.FindAll()
    
	if ($users.Count -gt 0) {
    	Write-Host "`nFound $($users.Count) matching users:" -ForegroundColor Yellow
    	$userList = @()
    	$index = 1
   	 
    	foreach ($user in $users) {
        	$userName = $user.Properties["samaccountname"][0]
        	$displayName = $user.Properties["displayname"][0]
        	$userList += [PSCustomObject]@{
            	Index = $index
            	UserName = $userName
            	DisplayName = $displayName
        	}
        	Write-Host "$index. $userName ($displayName)"
        	$index++
    	}
   	 
    	# Let user select which account to reset
    	$selection = Read-Host "`nEnter the number of the account to reset (or 'C' to cancel)"
   	 
    	if ($selection -ne 'C') {
        	$selectedUser = $userList[$selection - 1]
       	 
        	# Confirm password reset
        	$confirm = Read-Host "Are you sure you want to reset the password for $($selectedUser.UserName)? (Y/N)"
        	if ($confirm -eq 'Y') {
            	$user = $users[$selection - 1]
            	$user.GetDirectoryEntry().SetPassword("password")
            	$user.GetDirectoryEntry().psbase.InvokeSet("pwdLastSet", 0)
            	$user.GetDirectoryEntry().CommitChanges()
           	 
            	Write-Host "`nPassword reset successfully for user: $($selectedUser.UserName)" -ForegroundColor Green
            	Write-Host "User will be required to change password at next logon." -ForegroundColor Yellow
           	 
            	# Log the password reset
            	$logEntry = "$(Get-Date) - Password reset for user: $($selectedUser.UserName) by $($env:USERNAME)"
            	$logPath = "C:\PasswordResetLog.txt"
            	Add-Content -Path $logPath -Value $logEntry
        	} else {
            	Write-Host "Password reset cancelled." -ForegroundColor Yellow
        	}
    	} else {
        	Write-Host "Operation cancelled." -ForegroundColor Yellow
    	}
	} else {
    	Write-Host "No users found matching: $searchTerm" -ForegroundColor Red
	}
} catch {
	Write-Host "Error: $_" -ForegroundColor Red
}

# Keep window open if there's an error
if ($error.Count -gt 0) {
	Write-Host "`nPress any key to exit..."
	$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}


