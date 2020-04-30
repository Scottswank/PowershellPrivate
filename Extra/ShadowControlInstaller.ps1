#REQUIRES -Version 2.0

<#
.SYNOPSIS
    This is an automated installer for StorageCraft Shadow Control agent version 2.6.0 
.DESCRIPTION
    uses the .Net frameworks webclient class to get the Shadow Control agent from the $URL variable, this can be updated to support future versions of the shadow CMD agent.
.NOTES
    File Name      : SCCMD.ps1
    Author         : Tommy Venenga Systems Administrator @ Winxnet Inc.
    Prerequisite   : PowerShell V2 or above, .net framework 
    written		   : 4-15-2015
.LINK
	About		   :https://www.storagecraft.com/downloads/shadowcontrol
    
.EXAMPLE
    all you need to do is open Power shell as administrator, make sure the execution policy is set to bypass or unrestrticted, change to the directory the script is located in and run .\SCCMD.ps1
.EXAMPLE
    PS C:\> .\SCCMD.ps1
#>
# We need to be able to run this script so we need to change the execution policy level

Set-ExecutionPolicy Unrestricted -force
# We need to tell the script where our appliance is located
$appliance = "Backups.Network-Consultants.com"

# call .net webclient class to get the file in $URL and save it to $File
$webclient = New-Object System.Net.WebClient
$url = "https://$($appliance):8443/api/installer/msi/download/"
$file = "C:\ShadowControl_Installer_2_6_en.msi"
[System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true} #Added to ignore SSL Errors as recommended in Comments
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::tls12

$webclient.DownloadFile($url,$file)#}

#now that we have the agent we need to install it without any user interaction required
msiexec /i "c:\ShadowControl_Installer_2_6_en.msi" /qn /norestart

#ive noticed some times the script continues too quickly so i added a 10 second sleep period
Start-Sleep -s 50

#now we need to know if we are on a 32 or 64 bit machine so we use some basic logic
If((Test-Path -Path "C:\program files\storageCraft") -eq $true) { cd "C:\program files\StorageCraft\CMD\"}
Else {cd "C:\Program files (x86)\storagecraft\CMD\"}

#we cant be sure that there isnt a CMD agent already registerd so we will unsubscribe and re subscribe the endpoint

#.\stccmd unsubscribe
# Removed line due to -f option being used
.\stccmd subscribe -a -f $appliance
#-a parameter was added to specify to connect on port 8443
#-f parameter was added to unsubscribe and subscribe as needed
# https://www.storagecraft.com/support/book/shadowcontrol-user-guide/subscribing-endpoint/subscribing-command-line

# Now the the script is done we need to "secure" powershell again
del $file
Set-ExecutionPolicy remote -force