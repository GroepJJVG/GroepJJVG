$Source = “C:\Users\jaimy\Desktop\School\VMWARE\ISO\en-us_windows-server_2022”
$Destination = “C:\Users\jaimy\Downloads\WindowsServer2022ISO.iso”
cd "C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\amd64\Oscdimg"
cmd /c oscdimg.exe -bC:\Users\jaimy\Desktop\School\VMWARE\ISO\en-us_windows-server_2022\efi\microsoft\boot\efisys.bin -u2 -h -m -lWinSrv2022 $Source $Destination # Don't use spaces in the "-b" parameter.