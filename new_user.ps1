# Check if running as administrator
if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Warning "Please run this script as Administrator!"
    Write-Warning "Script will exit in 5 seconds..."
    Start-Sleep -Seconds 5
    exit
}



# Get domain credentials
$domainController = "test-dc2019.test.lan"
$domainName = "test.lan"
$domainCreds = Get-Credential -Message "Enter domain administrator credentials"

$ouPath = "OU=Teachers,OU=Users,OU=test-School,DC=test,DC=lan"

# Get user input and capitalize first letter of each name
$firstName = Read-Host "Enter teacher's first name"
$lastName = Read-Host "Enter teacher's last name"

# Capitalize first letter and make rest lowercase
$firstName = (Get-Culture).TextInfo.ToTitleCase($firstName.ToLower())
$lastName = (Get-Culture).TextInfo.ToTitleCase($lastName.ToLower())

# Create username in format flastname (first letter + lastname)
$username = "$($firstName.Substring(0,1))$lastName"
$userPrincipalName = "$username@$domainName"
$password = ConvertTo-SecureString "password" -AsPlainText -Force

# Display the information before creating
Write-Host "`nCreating user with the following details:"
Write-Host "Full Name: $firstName $lastName"
Write-Host "Username: $username"
Write-Host "User Principal Name: $userPrincipalName"
Write-Host "OU Path: $ouPath`n"

# Create the user account
try {
    New-ADUser -Name "$firstName $lastName" `
               -GivenName $firstName `
               -Surname $lastName `
               -SamAccountName $username `
               -UserPrincipalName $userPrincipalName `
               -Path $ouPath `
               -AccountPassword $password `
               -Enabled $true `
               -ChangePasswordAtLogon $true `
               -Server $domainController `
               -Credential $domainCreds
    Write-Host "User $username created successfully in Teachers OU"
} catch {
    Write-Host "Error creating user: $_"
}


