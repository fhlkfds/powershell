# Import the Active Directory module
Import-Module ActiveDirectory

# Get all computers from AD
$computers = Get-ADComputer -Filter * -Property *

foreach ($computer in $computers) {
    # Get the last logon for the computer from the 'lastLogon' attribute
    $lastLogon = Get-ADComputer $computer -Property lastLogon | Select-Object -ExpandProperty lastLogon
    $lastLogonDate = [DateTime]::FromFileTime($lastLogon)

    # Find the last two users that logged in
    $logonHistory = Get-WinEvent -ComputerName $computer.Name -LogName "Security" | 
                    Where-Object { $_.Id -eq 4624 } |  # Event ID 4624 indicates a successful login
                    Select-Object -First 2

    # Output the computer and the last two users who logged in
    Write-Host "Computer: $($computer.Name)"
    Write-Host "Last Logon Time: $lastLogonDate"

    foreach ($event in $logonHistory) {
        $user = $event.Properties[5].Value  # Extract the account name from the event log
        Write-Host "User: $user"
    }

    Write-Host "--------------------------------------"
}

