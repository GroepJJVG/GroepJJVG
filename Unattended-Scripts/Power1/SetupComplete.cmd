@echo off
echo Starting SetupComplete.cmd execution >> C:\Windows\Setup\Scripts\SetupComplete.log
powershell.exe -ExecutionPolicy Bypass -Command "Start-Transcript -Path C:\Windows\Setup\Scripts\PowerShell_Transcript.log; & C:\Windows\Setup\Scripts\power1-Install-ADDS-Unattended.ps1; Stop-Transcript"
echo Finished SetupComplete.cmd execution >> C:\Windows\Setup\Scripts\SetupComplete.log