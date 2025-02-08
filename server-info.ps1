# Define remote script block
$scriptBlock = {
    # Get all user accounts in AD
    $users = Get-ADUser -Filter *  # Get all user accounts in AD
    $userCount = $users.Count     # Count the number of users
    $threeYearsAgo = (Get-Date).AddYears(-3)

    Write-Output "Getting all Group Policy Object and outputting it to a .html file"
    Get-GPOReport -Name "GPOReport" -ReportType HTML -Path "C:\ADreport\GPO.html"

    Write-Output "Getting all Computer that have not been logged into for 3 years"
    # Query AD and filter for PCs that haven't logged in for more than 3 years
    Get-ADComputer -Filter * -Property LastLogonTimestamp | 
        Where-Object { [DateTime]::FromFileTime($_.LastLogonTimestamp) -lt $threeYearsAgo } |
        Select-Object Name, @{Name="LastLogonDate";Expression={[DateTime]::FromFileTime($_.LastLogonTimestamp)}} |
        Export-Csv -Path "C:\ADreport\inactive_computers.csv" -NoTypeInformation

    Write-Output "Get number of users"
    Write-Host "Total number of users in AD: $userCount"

    Write-Output "Getting enabled and disabled users"
    $users = Get-ADUser -Filter * -Property Enabled | 
        Select-Object Name, Enabled

    # Export the results to a CSV file
    $users | Export-Csv -Path "C:\ADreport\AD_Users_Status.csv" -NoTypeInformation

    # Create the directory if it doesn't exist
    $reportPath = "C:\ADreport"
    if (-not (Test-Path $reportPath)) {
        New-Item -ItemType Directory -Path $reportPath
    }

    # Get the password policy
    $passwordPolicy = Get-ADDefaultDomainPasswordPolicy
    $passwordPolicyObject = New-Object PSObject -property @{
        "Max Password Age"        = $passwordPolicy.MaxPasswordAge
        "Min Password Length"     = $passwordPolicy.MinPasswordLength
        "Password History Length" = $passwordPolicy.PasswordHistoryLength
        "Lockout Threshold"       = $passwordPolicy.LockoutThreshold
        "Lockout Duration"        = $passwordPolicy.LockoutDuration
        "Lockout Counter Reset"   = $passwordPolicy.LockoutCounterReset
    }

    # Export the password policy to CSV
    $passwordPolicyObject | Export-Csv -Path "C:\ADreport\PasswordPolicy.csv" -NoTypeInformation

    # Get domain controllers and their IP addresses
    $domainControllers = Get-ADDomainController -Filter *
    $domainControllersInfo = $domainControllers | Select-Object Name, @{Name="IPAddress";Expression={(Resolve-DnsName -Name $_.Name).IPAddress}}

    # Export domain controllers info to CSV
    $domainControllersInfo | Export-Csv -Path "C:\ADreport\DomainControllers.csv" -NoTypeInformation

    # Get all AD groups
    $groups = Get-ADGroup -Filter * 
    $groupPermissions = @()

    foreach ($group in $groups) {
        $members = Get-ADGroupMember -Identity $group -Recursive | Where-Object { $_.Name -ne "Domain Users" }
        $acl = Get-Acl -Path "AD:\$($group.DistinguishedName)"
        $permissions = $acl.Access | Where-Object { $_.IdentityReference -like "*$($group.Name)*" }

        foreach ($member in $members) {
            foreach ($perm in $permissions) {
                $groupPermissions += [PSCustomObject]@{
                    GroupName           = $group.Name
                    UserName            = $member.Name
                    Permission          = $perm.AccessControlType
                    AccessRights        = $perm.FileSystemRights
                    IsInherited         = $perm.IsInherited
                    ObjectType          = $perm.ObjectType
                    ActiveDirectoryPath = $perm.ObjectType
                }
            }
        }
    }

    # Export the results to CSV
    $groupPermissions | Export-Csv -Path "C:\ADreport\GroupMembershipsAndPermissions.csv" -NoTypeInformation

    # Get all members of the Domain Admins group
    $domainAdmins = Get-ADGroupMember -Identity "Domain Admins" -Recursive
    $domainAdminUsers = $domainAdmins | Where-Object { $_.objectClass -eq "user" }

    # Export to a CSV file
    $domainAdminUsers | Select-Object Name, SamAccountName, DistinguishedName | Export-Csv -Path "C:\ADreport\DomainAdmins.csv" -NoTypeInformation

    # Check for backup events
    $backupEventID = 4  # Event ID for successful backup (Windows Server Backup logs)
    $backupResults = @()

    foreach ($dc in $domainControllers) {
        $backupEvent = Get-WinEvent -ComputerName $dc.Name -LogName "Application" -FilterXPath "*[System[EventID=4]]" | 
                        Sort-Object TimeCreated -Descending | 
                        Select-Object -First 1

        if ($backupEvent) {
            $backupResults += [PSCustomObject]@{
                DomainControllerName = $dc.Name
                LastBackupTime       = $backupEvent.TimeCreated
                EventID              = $backupEvent.Id
                Message              = $backupEvent.Message
            }
        }
        else {
            $backupResults += [PSCustomObject]@{
                DomainControllerName = $dc.Name
                LastBackupTime       = "No backup found"
                EventID              = "N/A"
                Message              = "No backup event found in logs"
            }
        }
    }

    # Export the backup information to CSV
    $backupResults | Export-Csv -Path "C:\ADreport\DomainControllers_LastBackup.csv" -NoTypeInformation

    # Display the results to the console
    $backupResults | Format-Table -Property DomainControllerName, LastBackupTime, Message
}

# Define the list of domain controllers
$domainControllers = Get-ADDomainController -Filter *

# Run the script remotely on each domain controller
foreach ($dc in $domainControllers) {
    Invoke-Command -ComputerName $dc.Name -ScriptBlock $scriptBlock
}

Write-Host "Reports have been generated and saved to C:\ADreport on the remote domain controllers."

