
# Install Needed Windows Features
if((Get-WindowsFeature -Name Web-FTP-Server).InstallState -ne "Installed"){ Install-WindowsFeature Web-FTP-Server -IncludeManagementTools}
if((Get-WindowsFeature -Name Web-Scripting-Tools).InstallState -ne "Installed"){ Install-WindowsFeature Web-Scripting-Tools }
if((Get-WindowsFeature -Name Web-Basic-Auth).InstallState -ne "Installed"){ Install-WindowsFeature Web-Basic-Auth }


$FTPSiteName = "ShadowProtect_Replication"
$FTPPath = "X:\ReplicatedData"


$Username = "ShadowProtectFTP"
$Password = "(Netcon)Ruadan"




#Requires -Version 4

SSWANK-General-PSVersionCheck 4

# Checks if client version of powershell is less then $ScriptPSminVERSION
Function  SSWANK-General-PSVersionCheck{
param($ScriptPSminVERSION)
$PowershellVersionMajor=($PSVersionTable.PSVersion).Major
if($PowershellVersionMajor -lt $ScriptPSminVERSION){
    "Powershell Version is Less then $ScriptPSminVERSION. Script is Unsupported and will fail"
    "Script will now exit"
    exit
    }
}

$securePwd = ConvertTo-SecureString -AsPlainText -force -String $password
New-Localuser -Name $Username -Password $securePwd -Description "iFTP Replication User" -PasswordNeverExpires

function Validate-Folder {
<# 
 .SYNOPSIS
  Function to validate that a folder exists, creates folder if missing

 .DESCRIPTION
  Function to validate that a folder exists, creates folder if missing
  If the -NoCreate switch is used the function will not create a missing folder
  The function will create missing subfolders as well

 .PARAMETER FolderName
  This can be local like 'c:\folder 1\folder 2' 
  or UNC path like '\\server\share\folder 1\folder 2'
  
 .PARAMETER NoCreate
  This switch will insruct the function to NOT create the folder if missing

 .OUTPUTS 
  The function returns a TRUE/FALSE value
  The function returns TRUE if:
    - The folder exists
    - The folder did not exist but was created by the function
  The function will return FALSE if:
    - The folder doesn't exist and the -NoCreate switch is used
    - The folder doesn't exist and the function failed to create it

 .EXAMPLE
  Validate-Folder -FolderName c:\folder1
  This example checks if folder c:\folder1 exists, creates it if not, 
  returns TRUE if exists or created, returns FALSE if failed to create missing folder

 .EXAMPLE
  Validate-Folder -FolderName 'c:\folder 2' -NoCreate
  This example checks if 'c:\folder 2' exists, return TRUE if it does, FALSE if it doesn't

 .EXAMPLE
  if (Validate-Folder 'c:\folder 1\sub 2') { 'hi' | Out-File 'c:\folder 1\sub 2\file.txt' }
  This example checks if folder 'c:\folder 1\sub 2' exists,
  creates it if it doesn't,
  creates file 'c:\folder 1\sub 2\file.txt', and
  writes 'hi' to it

 .EXAMPLE
  @('c:\folder1','\\server\share\folder 4') | % { Validate-Folder $_ -Verbose }
  This example validates if the folders in the input array exist, creates them if they don't

 .NOTES
  Sam Boutros - 5 August 2016 - v1.0
  For more information see 
  https://superwidgets.wordpress.com/2016/08/05/powershell-script-to-validate-if-a-folder-exists-creates-it-if-not-creates-subfolders-if-needed/

#>

    [CmdletBinding(ConfirmImpact='Low')] 
    Param(
        [Parameter(Mandatory=$true,
                   ValueFromPipeLine=$true,
                   ValueFromPipeLineByPropertyName=$true,
                   Position=0)]
            [String]$FolderName, 
        [Parameter(Mandatory=$false,
                   Position=1)]
            [Switch]$NoCreate = $false
    )

    if ($FolderName.Length -gt 254) {
        Write-Error "Folder name '$FolderName' is too long - ($($FolderName.Length)) characters"
        break
    }
    if (Test-Path $FolderName) {
        Write-Verbose "Confirmed folder '$FolderName' exists"
        $true
    } else {
        Write-Verbose "Folder '$FolderName' does not exist"
        if ($NoCreate) {
            $false
            break  
        } else {
            Write-Verbose "Creating folder '$FolderName'"
            try {
                New-Item -Path $FolderName -ItemType directory -Force -ErrorAction Stop | Out-Null
                Write-Verbose "Successfully created folder '$FolderName'"
                $true
            } catch {
                Write-Error "Failed to create folder '$FolderName'"
                $false
            }
        }
    }
}





#    NEEDED FOR IIS CMDLETS
Import-Module WebAdministration

#Will Validate Folder Patch and Create Folders as needed
Validate-Folder $FTPPath

##    CREATE FTP SITE AND SET C:\inetpub\ftproot AS HOME DIRECTORY
New-WebFtpSite -Name "$FTPSiteName" -Port "21" -PhysicalPath $FTPPath
cmd /c \Windows\System32\inetsrv\appcmd set SITE "$FTPSiteName" "-virtualDirectoryDefaults.physicalPath:$FTPPath"

##    SET PERMISSIONS



     ## Enable Basic Authentication
Set-ItemProperty "IIS:\Sites\$FTPSiteName" -Name ftpServer.security.authentication.basicAuthentication.enabled -Value $true
## Set USer Isolation
# Set-ItemProperty "IIS:\Sites\$FTPSiteName" -Name ftpserver.userisolation.mode -Value 3
#Set-ItemProperty "IIS:\Sites\test" -Name ftpServer.security.userIsolation. -Value $true

New-Webbinding -Name $FTPSiteName -IPAddress "*" -Port 443 -Protocol https

$HostName = [System.Net.Dns]::GetHostEntry($env:COMPUTERNAME) | Select-Object HostName
$SSLDNSName = ($HostName).HostName
$SSLCert = New-SelfSignedCertificate -NotAfter $([datetime]::now.AddYears(10)) -certstorelocation cert:\localmachine\my -dnsname $SSLDNSName 
$cert = "Cert:\LocalMachine\My\" + ($SSLCert).Thumbprint
Push-Location
Set-Location IIS:\SSLBindings
Get-Item $cert | New-Item 0.0.0.0!443
Pop-Location
Set-ItemProperty -PSPath "IIS:\Sites\$FTPSiteName" -Name ftpServer.security.ssl.serverCertHash -Value ($SSLCert).Thumbprint
 
Set-WebConfigurationProperty -PSPath "IIS:\Sites\$FTPSiteName" -Filter system.ftpServer/firewallSupport -Name lowDataChannelPort -Value 5001 
Set-WebConfigurationProperty -PSPath "IIS:\Sites\$FTPSiteName" -Filter system.ftpServer/firewallSupport -Name highDataChannelPort -Value 5001 


     ## Allow SSL connections 
Set-ItemProperty "IIS:\Sites\$FTPSiteName" -Name ftpServer.security.ssl.controlChannelPolicy -Value 1 #Set Value to 0 for Optional SSL / 1 for Required SSL
Set-ItemProperty "IIS:\Sites\$FTPSiteName" -Name ftpServer.security.ssl.dataChannelPolicy -Value 1 #Set Value to 0 for Optional SSL / 1 for Required SSL


     ## Give Authorization to All Users and grant "read"/"write" privileges
$DomainName = (Get-WmiObject Win32_ComputerSystem).Domain
Add-WebConfiguration "/system.ftpServer/security/authorization" -value @{accessType="Allow";roles="$DomainName\Domain Admins";permissions="Read,Write";users=""} -PSPath IIS:\ -location "$FTPSiteName"
Add-WebConfiguration "/system.ftpServer/security/authorization" -value @{accessType="Allow";roles="$env:COMPUTERNAME\$Username";permissions="Read,Write";users=""} -PSPath IIS:\ -location "$FTPSiteName"
## Give Authorization to All Users using CMD
#appcmd set config %ftpsite% /section:system.ftpserver/security/authorization /+[accessType='Allow',permissions='Read,Write',roles='',users='*'] /commit:apphost 

     ## Restart the FTP site for all changes to take effect
Restart-WebItem "IIS:\Sites\$FTPSiteName"