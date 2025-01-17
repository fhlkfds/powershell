# Import the Active Directory module
Import-Module ActiveDirectory

# Define the path for the CSV output
$csvPath = "C:\path\to\output\user_logon_info.csv"

# Create an array to store user logon details
$userLogonInfo = @()

# Get all users from Active Directory
$users = Get-ADUser -Filter * -Property *

foreach ($user in $users) {
    # Get the user's first name, last name, and username (SamAccountName)
    $firstName = $user.GivenName
    $lastName = $user.Surname
    $userName = $user.SamAccountName

    # Get the last login computer from the user's logon events in the event log
    $logonHistory = Get-WinEvent -FilterHashtable @{LogName='Security'; ID=4624; ProviderName='Microsoft-Windows-Security-Auditing'} -ComputerName $user.Name -MaxEvents 10 | 
                    Where-Object { $_.Properties[5].Value -eq $userName } |
                    Select-Object -First 1

    # If logon events are found, get the last computer the user logged into
    if ($logonHistory) {
        $lastPC = $logonHistory.Properties[18].Value  # This contains the computer name (Logon Workstation)
    } else {
        $lastPC = "No login history found"
    }

    # Create an object with the user's data
    $userInfo = New-Object PSObject -property @{
        FirstName     = $firstName
        LastName      = $lastName
        UserName      = $userName
        LastPC        = $lastPC
    }

    # Add the user info object to the array
    $userLogonInfo += $userInfo
}

# Export the array of user logon info to a CSV file
$userLogonInfo | Export-Csv -Path $csvPath -NoTypeInformation

Write-Host "User logon information has been exported to $csvPath"

