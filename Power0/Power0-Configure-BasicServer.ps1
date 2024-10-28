# Configure-BasicServer.ps1

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
$NewHostName = "DC01-JJVG"
$IPAddress = "10.7.220.10"
$PrefixLength = 24
$DefaultGateway = "10.7.220.3"
$DNSServer = "10.7.220.10"  # This will be the IP of the DC itself

# Change the hostname
Write-Host "Changing hostname to $NewHostName..."
Rename-Computer -NewName $NewHostName -Force

# Configure network settings
Write-Host "Configuring network settings..."
$InterfaceIndex = (Get-NetAdapter | Where-Object {$_.Status -eq "Up"}).InterfaceIndex
New-NetIPAddress -InterfaceIndex $InterfaceIndex -IPAddress $IPAddress -PrefixLength $PrefixLength -DefaultGateway $DefaultGateway
Set-DnsClientServerAddress -InterfaceIndex $InterfaceIndex -ServerAddresses $DNSServer

Write-Host "Basic configuration complete. The server will now restart to apply changes."

# Wait for 5 seconds before restarting
Start-Sleep -Seconds 5

# Restart the computer to apply changes
Restart-Computer -Force