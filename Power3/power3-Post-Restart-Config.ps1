# power3-Post-Restart-Config.ps1

# Start transcript for logging
Start-Transcript -Path "C:\Scripts\power3-Post-Restart-Config.log" -Append

Write-Host "power3-Post-Restart-Config script started."

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
$IPAddress = "10.7.220.10"
$DHCPScope = "10.7.220.0"
$DHCPStartRange = "10.7.220.100"
$DHCPEndRange = "10.7.220.200"
$DHCPSubnetMask = "255.255.255.0"
$DefaultGateway = "10.7.220.3"
$DNSServer = "10.7.220.10"

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

# Install DHCP role
Write-Host "Installing DHCP role..."
Install-WindowsFeature -Name DHCP -IncludeManagementTools

# Authorize DHCP server in Active Directory
Write-Host "Authorizing DHCP server in Active Directory..."
Add-DhcpServerInDC -DnsName $NewHostName -IPAddress $IPAddress

# Configure DHCP
Write-Host "Configuring DHCP..."
try {
    # Add DHCP scope
    Add-DhcpServerv4Scope -Name "Client Scope" -StartRange $DHCPStartRange -EndRange $DHCPEndRange -SubnetMask $DHCPSubnetMask -State Active

    # Set DHCP scope options
    Set-DhcpServerv4OptionValue -ScopeId $DHCPScope -Router $DefaultGateway
    Set-DhcpServerv4OptionValue -ScopeId $DHCPScope -DnsServer $DNSServer
    Set-DhcpServerv4OptionValue -ScopeId $DHCPScope -DnsDomain $DomainName

    # Configure server-level options
    Set-DhcpServerv4OptionValue -ComputerName $NewHostName -DnsDomain $DomainName -DnsServer $DNSServer

    Write-Host "DHCP configuration completed successfully."
}
catch {
    Write-Error "Failed to configure DHCP: $_"
}

# Remove the scheduled task
Unregister-ScheduledTask -TaskName "Complete AD DS Setup" -Confirm:$false

Write-Host "Post-restart configuration complete, including DHCP installation and configuration."
Write-Host "The server will restart immediately to apply all changes."
Write-Host "You can check C:\Scripts\power3-Post-Restart-Config.log for execution details."

# Stop transcript
Stop-Transcript

# Force restart the computer immediately
Restart-Computer -Force