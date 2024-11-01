# power2-Post-Restart-Config.ps1

# Start transcript for logging
Start-Transcript -Path "C:\Windows\Setup\Scripts\power2-Post-Restart-Config.log" -Append

Write-Host "power2-Post-Restart-Config script started."

# Wait for AD Web Services to be available
$maxAttempts = 60
$attempts = 0
while ($attempts -lt $maxAttempts) {
    try {
        Get-ADDomainController -ErrorAction Stop
        break
    }
    catch {
        Write-Host "Waiting for AD Web Services to be available... Attempt $($attempts + 1) of $maxAttempts"
        Start-Sleep -Seconds 10
        $attempts++
    }
}

if ($attempts -eq $maxAttempts) {
    Write-Error "AD Web Services did not become available in time. Exiting script."
    Stop-Transcript
    Exit 1
}

# Import the Active Directory module
Import-Module ActiveDirectory

# Set variables
$DomainName = "groepjjvg.local"
$NewHostName = "DC01-JJVG"

# Function to create OU structure
function Create-OUStructure {
    Write-Host "Creating OU structure..."

    # Create main OUs
    New-ADOrganizationalUnit -Name "Departments" -Path "DC=$($DomainName.Split('.')[0]),DC=$($DomainName.Split('.')[1])" -ProtectedFromAccidentalDeletion $true
    New-ADOrganizationalUnit -Name "Security Groups" -Path "DC=$($DomainName.Split('.')[0]),DC=$($DomainName.Split('.')[1])" -ProtectedFromAccidentalDeletion $true
    New-ADOrganizationalUnit -Name "Service Accounts" -Path "DC=$($DomainName.Split('.')[0]),DC=$($DomainName.Split('.')[1])" -ProtectedFromAccidentalDeletion $true

    # Create sub-OUs under Departments
    $departments = @("IT", "HR", "Finance", "Marketing", "Sales")
    foreach ($dept in $departments) {
        New-ADOrganizationalUnit -Name $dept -Path "OU=Departments,DC=$($DomainName.Split('.')[0]),DC=$($DomainName.Split('.')[1])" -ProtectedFromAccidentalDeletion $true
    }

    Write-Host "OU structure created successfully."
}

# Create OU structure
Create-OUStructure

# Change the hostname
Write-Host "Changing hostname to $NewHostName..."
try {
    Rename-Computer -NewName $NewHostName -Force -ErrorAction Stop
    Write-Host "Hostname changed successfully."
}
catch {
    Write-Error "Failed to change hostname: $_"
}

# Remove the scheduled task
Unregister-ScheduledTask -TaskName "Complete AD DS Setup" -Confirm:$false

Write-Host "Post-restart configuration complete."
Write-Host "The server will restart immediately to apply the hostname change."
Write-Host "You can check C:\Scripts\power2-Post-Restart-Config.log for execution details."

# Stop transcript
Stop-Transcript

# Force restart the computer immediately
Restart-Computer -Force