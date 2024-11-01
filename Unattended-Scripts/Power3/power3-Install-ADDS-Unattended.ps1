# power3-Install-ADDS-Unattended.ps1

# Start transcript for logging
Start-Transcript -Path "C:\Windows\Setup\Scripts\power3-Install-ADDS-Unattended.log" -Append

# Check if running as administrator
if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Warning "This script requires administrator privileges. Attempting to elevate..."
    
    # Get the current script path
    $scriptPath = $MyInvocation.MyCommand.Path
    
    # Start a new PowerShell process with elevated privileges
    Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`"" -Verb RunAs
    
    # Exit the current (non-elevated) instance of the script
    Exit
}

# The rest of the script continues here, now with administrator privileges

# Set variables
$DomainName = "groepjjvg.local"
$NetbiosName = "GROEPJJVG"
$AdminPassword = "P@ssw0rd123!"
$SafeModeAdminPassword = ConvertTo-SecureString $AdminPassword -AsPlainText -Force
$IPAddress = "10.7.220.10"
$PrefixLength = 24
$DefaultGateway = "10.7.220.3"
$DNSServer = "10.7.220.10"  # This will be the IP of the DC itself
$NewHostName = "DC01-JJVG"
$ForwarderIP = $DefaultGateway  # Using the default gateway as DNS forwarder


# Set local administrator password
$AdminUser = [ADSI]"WinNT://./Administrator,User"
$AdminUser.SetPassword($AdminPassword)
$AdminUser.SetInfo()
Write-Host "Local administrator password has been set."

# Configure network settings
$InterfaceIndex = (Get-NetAdapter | Where-Object {$_.Status -eq "Up"}).InterfaceIndex
New-NetIPAddress -InterfaceIndex $InterfaceIndex -IPAddress $IPAddress -PrefixLength $PrefixLength -DefaultGateway $DefaultGateway
Set-DnsClientServerAddress -InterfaceIndex $InterfaceIndex -ServerAddresses $DNSServer

# Install the required Windows features
Write-Host "Installing ADDS and DNS features..."
Install-WindowsFeature -Name AD-Domain-Services, DNS -IncludeManagementTools

# Import the AD DS deployment module
Import-Module ADDSDeployment

# Install AD DS, create the forest, and promote the server to a domain controller
Write-Host "Installing AD DS, creating the forest, and promoting to domain controller..."
$ADDSParams = @{
    CreateDnsDelegation = $false
    DatabasePath = "C:\Windows\NTDS"
    DomainMode = "WinThreshold"
    DomainName = $DomainName
    DomainNetbiosName = $NetbiosName
    ForestMode = "WinThreshold"
    InstallDns = $true
    LogPath = "C:\Windows\NTDS"
    NoRebootOnCompletion = $true
    SysvolPath = "C:\Windows\SYSVOL"
    Force = $true
    SafeModeAdministratorPassword = $SafeModeAdminPassword
}

try {
    Install-ADDSForest @ADDSParams
}
catch {
    Write-Error "Failed to install AD DS: $_"
    Stop-Transcript
    Exit 1
}

# Configure DNS after AD DS promotion
Write-Host "Configuring DNS..."
try {
    # Set DNS forwarders
    Set-DnsServerForwarder -IPAddress $ForwarderIP -PassThru

    # Create reverse lookup zone
    $NetworkID = $IPAddress.Substring(0, $IPAddress.LastIndexOf("."))
    Add-DnsServerPrimaryZone -NetworkID "$NetworkID.0/$PrefixLength" -ReplicationScope "Forest" -DynamicUpdate "Secure"

    # Enable DNS scavenging
    Set-DnsServerScavenging -ScavengingState $true -ScavengingInterval 7.00:00:00 -RefreshInterval 7.00:00:00 -NoRefreshInterval 7.00:00:00

    Write-Host "DNS configuration completed successfully."
}
catch {
    Write-Error "Failed to configure DNS: $_"
}

# Create a scheduled task to run the post-restart script with administrator privileges
$postRestartScriptPath = "C:\Windows\Setup\Scripts\power3-Post-Restart-Config.ps1"
$Action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-ExecutionPolicy Bypass -WindowStyle Hidden -File `"$postRestartScriptPath`""
$Trigger = New-ScheduledTaskTrigger -AtStartup
$Settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -RunOnlyIfNetworkAvailable -WakeToRun
$Principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
$Task = New-ScheduledTask -Action $Action -Trigger $Trigger -Settings $Settings -Principal $Principal
Register-ScheduledTask -TaskName "Complete AD DS Setup" -InputObject $Task -Force

Write-Host "AD DS installation, promotion, and DNS configuration complete. The server will now restart to apply changes."
Write-Host "After restart, the post-restart script will run to complete the setup, including DHCP installation and configuration."

# Stop transcript
Stop-Transcript

# Restart the computer to apply changes
Restart-Computer -Force
