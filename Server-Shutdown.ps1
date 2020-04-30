<# General Server Shutdown with Hyper-V, Clustering Support, and SQL AG Sync-Commit Supported
 
 
Last Edited By:Scott Swank
Last Edited: 2/21/2017

Written By: Scott Swank
Written: 2/21/2017
Version 1.1

Tested OS versions: Server 2012 R2; Server 2012; 

Powershell Version must be greater then 3
Server OS must be Server 2012 or newer
SQL version must be SQL 2012 or newer #>


<# Global Variables used in the script below.
You can set the $VMRetryCounter for the amount of times you want it to attempt shutting down a VM before giving up.

Another global variable is the $CheckSQLFailover. 
If you do NOT want this script to check SQL for an Availibility Group Instance, set that value to 0
If you DO want this script to scheck SQL for an Availibility Group Instance, set the value to 1
#>
$VMRetryCounter=3
$CheckSQLFailover=1

$PasswordFile = "\\s99mgmntp01\PDQDeployPackages\Scripts\Dependancy\Key1.key"
$AESKeyFile = "\\s99mgmntp01\PDQDeployPackages\Scripts\Dependancy\key2.key"
$usernameFilePath = "\\s99mgmntp01\PDQDeployPackages\Scripts\Dependancy\key3.key"
$AESKeyFilePath2 = "\\s99mgmntp01\PDQDeployPackages\Scripts\Dependancy\key4.key"

 function SSWANK-General-Read-UNPWKeys{
$AESKey = Get-Content $AESKeyFile
$PwdTxt = Get-Content $PasswordFile 
$Usrtxt = Get-Content $usernameFilePath
$key = Get-Content $AESKeyFilePath2
$securePwd= $pwdtxt | ConvertTo-SecureString -key $AESkey
$Username =  SSWANK-General-Decrypt-String "$Key" "$Usrtxt"
$script:credObject = New-Object System.Management.Automation.PSCredential -ArgumentList $Username, $securePwd 
}

 function SSWANK-General-Decrypt-String($Key, $encryptedStringWithIV) {
    $bytes = [System.Convert]::FromBase64String($encryptedStringWithIV)
    $IV = $bytes[0..15]
    $aesManaged = SSWANK-General-Create-AesManagedObject $key $IV
    $decryptor = $aesManaged.CreateDecryptor();
    $unencryptedData = $decryptor.TransformFinalBlock($bytes, 16, $bytes.Length - 16);
    $aesManaged.Dispose()
    [System.Text.Encoding]::UTF8.GetString($unencryptedData).Trim([char]0)
}

 function SSWANK-General-Create-AesManagedObject($key, $IV) {
    $aesManaged = New-Object "System.Security.Cryptography.AesManaged"
    $aesManaged.Mode = [System.Security.Cryptography.CipherMode]::CBC
    $aesManaged.Padding = [System.Security.Cryptography.PaddingMode]::Zeros
    $aesManaged.BlockSize = 128
    $aesManaged.KeySize = 256
    if ($IV) {
        if ($IV.getType().Name -eq "String") {
            $aesManaged.IV = [System.Convert]::FromBase64String($IV)
        }
        else {
            $aesManaged.IV = $IV
        }
    }
    if ($key) {
        if ($key.getType().Name -eq "String") {
            $aesManaged.Key = [System.Convert]::FromBase64String($key)
        }
        else {
            $aesManaged.Key = $key
        }
    }
    $aesManaged
}


<# Function to Shutdown GuestVMs

Requires the Below global Variables
$VMRetryCounter=3

Requires SSWANK-HyperV-IntergrationServicesShutdown #>
Function SSWANK-HyperV-Shutdown{
$GetVMRunning=Get-VM | Where-Object {$_.State –eq 'Running'}
$GetVMRunning | Foreach{$_.name}{
    $VMName=$_.name
SSWANK-HyperV-IntergrationServicesShutdown "$VMName"}
}

<# Checks that Current Status of the your Current Node
Will Launch ShutdownCluserDrain if Needed

Requires SSWANK-FailoverCluster-ShutdownCheckDrain
Requires SSWANK-FailoverCluster-ShutdownCheck
Requires SSWANK-FailoverCluster-Shutdown
Requires SSWANK-FailoverCluster-ClusterStatusInfoCheck {Requires $FailoverClusterVMSCounter=0} #>
Function SSWANK-FailoverCluster-ShutdownCheckDrain{
    If((get-ClusterNode -Name "$env:COMPUTERNAME").drainstatus -eq 'InProgress'){
    "Live Migration In Progress on $env:COMPUTERNAME : Aborting"
    exit
    }
    If((get-ClusterNode -Name "$env:COMPUTERNAME").drainstatus -eq 'Completed'){
    "Pausing of Failover Clustering Roles is not needed on $env:COMPUTERNAME"
    }
    If((get-ClusterNode -Name "$env:COMPUTERNAME").drainstatus -eq 'Paused'){
    "Pausing of Failover Clustering Roles is not needed on $env:COMPUTERNAME"
    }
    If((get-ClusterNode -Name "$env:COMPUTERNAME").drainstatus -eq 'NotInitiated'){
    "Pausing Failover Clustering Roles on $env:COMPUTERNAME"
    SSWANK-FailoverCluster-Shutdown
    "Failover Clustering Roles Successfully Paused on $env:COMPUTERNAME"
    }
}

# Stops Hyper-V machines and checks Intergration Services to see which options are best
function SSWANK-HyperV-IntergrationServicesShutdown{
param($VMName)
$VMIntServices = get-VMIntegrationService –VMName $VMName -Name shutdown
$VMIntSerShutdownStatus = ($VMIntServices).enabled
if($VMIntSerShutdownStatus -eq "True"){
"VM Intergrations Services are Enabled. Will continue trying to shut down $VMName"
    stop-vm $VMName -force -Passthru
    $counter=1
    if((get-vm -Name $VMName).state -eq 'Running'){
    Do{
            if($counter -eq "$VMRetryCounter"){
                "Unable to Stop $VMName. Tried $counter times."
                "Attempting to Turn Off $VMName"
                 Stop-VM $VMName -TurnOff
            if((get-vm -Name $VMName).state -eq 'Off'){
            "Successfully forced off $VMName"
            }
            Break}
            stop-vm $VMName -force
            $counter=$counter+1
            Start-Sleep -Seconds 15}
         Until((get-vm -Name $VMName).state -eq 'Off') 
    } if((get-vm -Name $VMName).state -eq 'Off') {"Stopped $VMName"}
}

if($VMIntSerShutdownStatus -ne "True"){
"VM Intergrations Services are disabled."
Stop-VM $VMName -TurnOff
if((get-vm -Name $VMName).state -eq 'Off') {"Turned Off $VMName"}
}
}

Function SSWANK-FailoverCluster-ShutdownCheck{
    If((get-ClusterNode -Name "$env:COMPUTERNAME").state -eq 'Paused'){
    "Failover Cluster Node $env:COMPUTERNAME is Paused. Checking Drain Status"
    SSWANK-FailoverCluster-ShutdownCheckDrain
    }
    If((get-ClusterNode -Name "$env:COMPUTERNAME").state -eq 'Up'){
    "Pausing failover Clustering Roles on $env:COMPUTERNAME"
    SSWANK-FailoverCluster-Shutdown
    If((get-ClusterNode -Name "$env:COMPUTERNAME").state -eq 'Paused'){ "Failover Clustering Roles Successfully Paused on $env:COMPUTERNAME" }
    } # End of If State is Up
} # End of Fuction

# Function to Drain Failover Clustering Roles
Function SSWANK-FailoverCluster-Shutdown{
SSWANK-FailoverCluster-ClusterStatusInfoCheck
"Attempting to Pause Failover Clustering Roles on $env:COMPUTERNAME"
Suspend-ClusterNode -Drain
$Counter=0
:ClusterLoop   while($Counter -lt 20){
                    $a = (get-ClusterNode -Name "$env:COMPUTERNAME").drainstatus
                    If((get-ClusterNode -Name "$env:COMPUTERNAME").drainstatus -eq 'Completed') {
                    "Failover Cluster Drain Status for $env:COMPUTERNAME is Completed"
                    break ClusterLoop
                    }
                    "Failover Cluster Drain Status for $env:COMPUTERNAME is $a, Waiting..."
                $Counter=$Counter+1
                 Start-Sleep -seconds 60}
}


# Function to Check to see if a Service is Running, and Launch Failover Cluster Shutdown 
function SSWANK-General-CheckServiceRunning{
 param($ServiceName)
 $arrService = Get-Service -Name $ServiceName
 if ($arrService.Status -ne "Running"){
 $ServiceStatus=$arrService.Status
"The service $ServiceName is not running"
 }
 if ($arrService.Status -eq "running"){
 "The service $ServiceName is running"
 SSWANK-FailoverCluster-ShutdownCheck
 }
 }

# Checks if Server OS is 2012 or newer
 function SSWANK-General-serverVersCheck{
 param($RequiredWMIVers)
 $VersionArray = Get-WmiObject WIN32_OperatingSystem -ComputerName $env:COMPUTERNAME| Select-Object Version
 $Version = ($VersionArray).Version
 if($RequiredWMIVers -ge $Version){
 "The Version of your PC is lower then $RequiredWMIVers. This script is not supported"
 exit}
 }

# Checks if client is a server OS or not
 function SSWANK-General-ServerCheck{
 $ProductTypeArray = Get-WmiObject WIN32_OperatingSystem -ComputerName $env:COMPUTERNAME| Select-Object ProductType
 $ProductType = ($ProductTypeArray).ProductType
 if($ProductType -ne 3){
 "Your system is not a server. Checks will not be performed"
 exit}
 }

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

#
# Checks and sees if an acceptable amount of Failover Cluster Nodes are Available, If so it calls the Drain Check
# Requires $FailoverClusterVMSCounter=0
Function SSWANK-FailoverCluster-ClusterStatusInfoCheck{
$TotalVMS=0
$TotalVMSUP=0
Get-Clusternode  | Foreach{$_.Name} {
$TotalVMS=$TotalVMS+1
$TotalVMS=$TotalVMS
If((get-ClusterNode -Name "$_").state -eq 'Up'){
$TotalVMSUp = $TotalVMSUP+1
}
}
$AcceptableVMSUp = ($TotalVMS/2)
$AcceptableVMSUp = [int]($AcceptableVMSUp+.000000001)
if($AcceptableVMSUp -eq "1"){$AcceptableVMSUp = "2"}
if($TotalVMSUP -ge $AcceptableVMSUp){
"There are $TotalVMSUP out of $TotalVMS Cluster Nodes Up"
}
if($TotalVMSUP -lt $AcceptableVMSUp){
if($FailoverClusterVMSCounter -eq 3)
{"System waited maximum amount of time. Script will Continue"
break}
$FailoverClusterVMSCounter=$FailoverClusterVMSCounter+1
$script:FailoverClusterVMSCounter = $FailoverClusterVMSCounter
"There are $TotalVMSUP out of $TotalVMS Cluster Nodes Up"
"Script will Pause and Re-Evaluate"
Start-Sleep -Seconds 180
SSWANK-FailoverCluster-ClusterStatusInfoCheck
}
}


#Checks to see what Instances are installed
function SSWANK-SQL-SQLInstanceLookup{
cd  SQLSERVER:\SQL\$env:COMPUTERNAME\
$Instances = Get-ChildItem -Name -Path .\ 
$Instances | ForEach{$_}{
SSWANK-SQL-AGEnabledCheck "$_"
}
}

Function SSWANK-SQL-Get-SQLSvrVer {
<#
    .SYNOPSIS
        Checks remote registry for SQL Server Edition and Version.

    .DESCRIPTION
        Checks remote registry for SQL Server Edition and Version.

    .PARAMETER  ComputerName
        The remote computer your boss is asking about.

    .EXAMPLE
        PS C:\> Get-SQLSvrVer -ComputerName mymssqlsvr 

    .EXAMPLE
        PS C:\> $list = cat .\sqlsvrs.txt
        PS C:\> $list | % { Get-SQLSvrVer $_ | select ServerName,Edition }

    .INPUTS
        System.String,System.Int32

    .OUTPUTS
        System.Management.Automation.PSCustomObject

    .LINK
        about_functions_advanced

#>
[CmdletBinding()]
param(
    # a computer name
    [Parameter(Position=0, Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [System.String]
    $ComputerName
)


    # create an empty psobject (hashtable)
    $SqlVer = New-Object PSObject
    # add the remote server name to the psobj
    $SqlVer | Add-Member -MemberType NoteProperty -Name ServerName -Value $ComputerName
    # set key path for reg data
    $key = "SOFTWARE\Microsoft\Microsoft SQL Server\Instance Names\SQL"
    $type = [Microsoft.Win32.RegistryHive]::LocalMachine
    # set up a .net call, uses the .net thingy above as a reference, could have just put 
    # 'LocalMachine' here instead of the $type var (but this looks fancier :D )
    $regKey = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey($type, $ComputerName)

    # make the call 
    $SqlKey = $regKey.OpenSubKey($key)
        # parse each value in the reg_multi InstalledInstances 
        Foreach($instance in $SqlKey.GetValueNames()){
        $instName = $SqlKey.GetValue("$instance") # read the instance name
        $instKey = $regKey.OpenSubkey("SOFTWARE\Microsoft\Microsoft SQL Server\$instName\Setup") # sub in instance name
        # add stuff to the psobj
        $SqlVer | Add-Member -MemberType NoteProperty -Name Edition -Value $instKey.GetValue("Edition") -Force # read Ed value
        $SqlVer | Add-Member -MemberType NoteProperty -Name Version -Value $instKey.GetValue("Version") -Force # read Ver value
        # return an object, useful for many things
        $SqlVer
    }
    }


#Checks to see if Availability Groups are enabled
function SSWANK-SQL-AGEnabledCheck{
param($InstanceName)
cd  SQLSERVER:\SQL\$env:COMPUTERNAME\$InstanceName
$AGEnabled = Get-Item .| select IsHadrEnabled
if (($AGEnabled).IsHadrEnabled -eq "True"){
"The Availability Group for Instance $InstanceName is Enabled"
SSWANK-SQL-AGReplicaCheck "$InstanceName"}
if (($AGEnabled).IsHadrEnabled -ne "True"){
"The Availability Group for Instance $InstanceName is Disabled"}
}

#Checks and see who is the Primary Replica and if any migration is needed
function SSWANK-SQL-AGReplicaCheck{
param($InstanceName)
$AGGroupsTable = Get-ChildItem AvailabilityGroups
$AGGroupsTable | ForEach{$_.Name}{
$AGName = $_.Name
$PRServerName = $_.PrimaryReplicaServerName
if("$PRServerName" -eq $env:COMPUTERNAME){
"This server is $env:COMPUTERNAME which also is the Primary Replica for $AGName"
$script:AGReplicaLoop = 0
SSWANK-SQL-AGReplicaMemberCheck "$AGName" "$InstanceName"
}
if("$PRServerName" -ne $env:COMPUTERNAME){
"This server is $env:COMPUTERNAME"
"The Primary Replica for $AGName is $PRServerName"
}}}

#Checks and Fails the AG over to a secondary AG Member Server who is in a Synchronized State
# Required $script:AGReplicaLoop = 0 before it is called
function SSWANK-SQL-AGReplicaMemberCheck{
param($AGName,$InstanceName)
cd SQLServer:\SQL\$env:COMPUTERNAME\$InstanceName\AvailabilityGroups\$AGName\
$AGMembers = Get-ChildItem .\AvailabilityReplicas
$MigrationCounter=0
$AGMembers | ForEach{$_.Name}{
    $Name = $_.Name
        if($MigrationCounter -eq 0){
        if($env:COMPUTERNAME -ne "$Name"){
        cd SQLSERVER:\SQL\$Name\$InstanceName\AvailabilityGroups\$AGName\AvailabilityReplicas\$Name\
        $AGMemberState = Get-Item .
        if(($AGMemberState).Role -eq "Secondary"){
   if(($AGMemberState).RollupSynchronizationState -eq "Synchronized"){
   $MigrationCounter=$MIgrationCounter+1
   "$Name is a Secondary Replica in the $AGName Availability Group with a state of Synchronized. Migrating Roles to it now."
   Switch-SqlAvailabilityGroup -Path SQLSERVER:\SQL\$Name\Default\AvailabilityGroups\$AGName
   Start-Sleep -Seconds 10
   dir SQLSERVER:\SQL\$Name\$InstanceName\AvailabilityGroups\$AGName\availabilityreplicas | foreach { $_.Refresh() }
   cd SQLSERVER:\SQL\$Name\$InstanceName\AvailabilityGroups\$AGName\AvailabilityReplicas\$Name\
   $AGMemberState = Get-Item .
   if(($AGMemberState).Role -eq "Primary"){
   "SQL Availability Group Migration Completed Successfully on $Name"} # End of Verification Nofication
  } # end of If Syncronization State is Syncronized
  } # End of If Role is Secondary
    } # End of if Computername is not the same
        } # End of MigrationCounter
    } # End of For Each $AGMembers
if($MigrationCounter -eq "0"){ # If migration happened when it was called
if($AGReplicaLoop -lt "2"){ # See if it should attempt migration again
$AGReplicaLoop = $AGReplicaLoop+1
$Script:AGReplicaLoop = $AGReplicaLoop
Start-Sleep -Seconds 180
dir SQLSERVER:\SQL\$env:COMPUTERNAME\$InstanceName\AvailabilityGroups\$AGName\availabilityreplicas | foreach { $_.Refresh() }
SSWANK-SQL-AGReplicaMemberCheck "$AGName" "$InstanceName"  # Calls itself for another try if no migration happened
}
if($AGReplicaLoop -eq "3"){
"Loop reached 3"
Switch-SqlAvailabilityGroup -Path SQLSERVER:\SQL\$Name\Default\AvailabilityGroups\$AGName
}
} # End of if no migration happened
} # End of Function




<# Checks the Registry of the local machine to see if SQL is installed, if so it continues
 
Requires SSWANK-SQL-AGReplicaMemberCheck
Requires SSWANK-SQL-AGReplicaCheck
Requires SSWANK-SQL-AGEnabledCheck
Requires SSWANK-SQL-Get-SQLSvrVer #>
function SSWANK-SQL-SQLCheck{
if (Test-Path “HKLM:\Software\Microsoft\Microsoft SQL Server\Instance Names\SQL”) {
    $SQLVersion = SSWANK-SQL-Get-SQLSvrVer "$env:ComputerName"
    $SQLVersion = ($SQLVersion).Version
    if($SQLVersion -ge "11"){
    "SQL on $env:ComputerName  is Version $SQLVersion"
    "The minimum version is Version 11 (SQL 2012)"
    "Loading SQL Powershell Scripts"
Push-Location
import-module sqlps  -DisableNameChecking
SSWANK-SQL-SQLInstanceLookup
Pop-Location 
Remove-Module sqlps}
else{
    "SQL on $env:ComputerName  is Version $SQLVersion"
    "The minimum version is Version 11 (SQL 2012)"
    }
}
else{ "$env:ComputerName is not a SQL server"}
}

Function Starlumber-S99SQLBIZP01-Shutdown{
if ($env:COMPUTERNAME -eq "S99SQLBIZP01"){
SSWANK-General-Read-UNPWKeys #Returns $CredObject
$ScriptBlock={
$ServiceName = "bisTrack eConnect Agent"
$arrService = Get-Service -Name $ServiceName
if ($arrService.Status -ne "Stopped"){                                     # Stop Attempt #1
"Attempting to stop $ServiceName on $env:Computername"
Stop-Service $ServiceName
Start-Sleep -Seconds 20
$arrService = Get-Service -Name $ServiceName
if ($arrService.Status -ne "Stopped"){                                     # Stop Attempt #2
"Attempting to stop $ServiceName on $env:Computername"
Stop-Service $ServiceName
Start-Sleep -Seconds 20
$arrService = Get-Service -Name $ServiceName
if ($arrService.Status -ne "Stopped"){                                     # Notification
"Attempt to stop $ServiceName on $env:Computername Failed"
} # End of Notification
} # End of Stop Attempt #2
} # End of Stop Attempt #1
if ($arrService.Status -eq "Stopped"){ 
"$ServiceName Is Stopped on $env:Computername"
} #End of Stopped Statement
} #End of Scriptblock

$sb = [scriptblock]::Create($ScriptBlock)                                  # Configures the scriptblock format
$ComputerName = "S99BISTP01"
$session = New-PSSession -ComputerName $ComputerName -Credential $CredObject
Invoke-Command -Session $session -ScriptBlock $sb                          # Creates Remote Powershell Session, sents commands, for execution, and closes Powershell session
Remove-PSSession $session

} # End of If S99SQLBIZP01 Statement
} # End of Starlumber-S99SQLBIZP01-Shutdown Function





# This is the Start of the Script
# Checks to Verify Script is Compatible with the Powershell version. If not, it Exits.

$FailoverClusterVMSCounter=0
SSWANK-General-PSVersionCheck 3
SSWANK-General-ServerCheck
SSWANK-General-serverVersCheck "6.2"

StarLumber-S99SQLBIZP01-Shutdown #Handles S99SQLBIZP01 1 off scenario
if($CheckSQLFailover -eq 1){ SSWANK-SQL-SQLCheck} #Shuts Down any SQL Services

# Looks up to see if Failover-Clustering Role is installed
# if role is installed, Launch Shutdown Clustering Fuctions
if((Get-WindowsFeature -Name Failover-Clustering).InstallState -eq "Installed"){
    "$env:COMPUTERNAME is part of a Cluster"
    "Verifying Cluster Service is Running"
    SSWANK-General-CheckServiceRunning "ClusSvc" 
    }
else{
    "$env:COMPUTERNAME is not part of a Cluster"}


# Looks up to see if Hyper-V Role is installed
# if role is installed, Launch Shutdown Hyper-v Fuctions

if((Get-WindowsFeature -Name Hyper-V).InstallState -eq "Installed"){
"$env:COMPUTERNAME is a Hyper-V Host"
SSWANK-HyperV-Shutdown
}
else{
"$env:COMPUTERNAME is not a Hyper-V Host"
}
# SIG # Begin signature block
# MIIHBwYJKoZIhvcNAQcCoIIG+DCCBvQCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQU7gBy65qn+hOEmKUfEIRY9T9s
# wmagggT7MIIE9zCCA9+gAwIBAgIKGXz8zQAAAAAIXzANBgkqhkiG9w0BAQUFADBI
# MRMwEQYKCZImiZPyLGQBGRYDY29tMRowGAYKCZImiZPyLGQBGRYKc3Rhcmx1bWJl
# cjEVMBMGA1UEAxMMUzk5VUFHUDAxLUNBMB4XDTE2MTEwMTE4MDczMloXDTE3MTEw
# MTE4MDczMlowVTETMBEGCgmSJomT8ixkARkWA2NvbTEaMBgGCgmSJomT8ixkARkW
# CnN0YXJsdW1iZXIxDjAMBgNVBAMTBVVzZXJzMRIwEAYDVQQDEwlzdGFyYWRtaW4w
# gZ8wDQYJKoZIhvcNAQEBBQADgY0AMIGJAoGBAK+X2qp4qXz1aSWHV/SGIEj85qep
# /LYEGOSRGY1gjtlRc3+vXIVPfEQRH0H2Rwtl8wh+Q03Usbb6xg2GP0s5VfnWZVbL
# 163/9VbA/RkP7S1qCBaUJHjJRW+y6AvoD/Mj3cV1pg9aIk35PoQxGv+xGk6QXohJ
# +acGGHT/zDONu6MpAgMBAAGjggJYMIICVDAlBgkrBgEEAYI3FAIEGB4WAEMAbwBk
# AGUAUwBpAGcAbgBpAG4AZzATBgNVHSUEDDAKBggrBgEFBQcDAzALBgNVHQ8EBAMC
# B4AwHQYDVR0OBBYEFMn81sFZ7LlU8InmgTEyYIpzUkUPMB8GA1UdIwQYMBaAFJQK
# 8vmBQMHU0jDkCwGN+e2dSimeMIHPBgNVHR8EgccwgcQwgcGggb6ggbuGgbhsZGFw
# Oi8vL0NOPVM5OVVBR1AwMS1DQSxDTj1TOTlVQUdQMDEsQ049Q0RQLENOPVB1Ymxp
# YyUyMEtleSUyMFNlcnZpY2VzLENOPVNlcnZpY2VzLENOPUNvbmZpZ3VyYXRpb24s
# REM9c3Rhcmx1bWJlcixEQz1jb20/Y2VydGlmaWNhdGVSZXZvY2F0aW9uTGlzdD9i
# YXNlP29iamVjdENsYXNzPWNSTERpc3RyaWJ1dGlvblBvaW50MIHBBggrBgEFBQcB
# AQSBtDCBsTCBrgYIKwYBBQUHMAKGgaFsZGFwOi8vL0NOPVM5OVVBR1AwMS1DQSxD
# Tj1BSUEsQ049UHVibGljJTIwS2V5JTIwU2VydmljZXMsQ049U2VydmljZXMsQ049
# Q29uZmlndXJhdGlvbixEQz1zdGFybHVtYmVyLERDPWNvbT9jQUNlcnRpZmljYXRl
# P2Jhc2U/b2JqZWN0Q2xhc3M9Y2VydGlmaWNhdGlvbkF1dGhvcml0eTAzBgNVHREE
# LDAqoCgGCisGAQQBgjcUAgOgGgwYc3RhcmFkbWluQHN0YXJsdW1iZXIuY29tMA0G
# CSqGSIb3DQEBBQUAA4IBAQBGoPfs/TXDfqxrNYxaTcGWD3gOAiMA2w8MioAmCfEK
# lOdRnZFZb+w76FCHI+pKH8LiPq4bSwpEsIeSvNW1VkAcTOiMEBpGL3RjDg2Mo5yB
# vZsbrgS3ZOaBStG1FnRIfzr2lL4pK0sdv0nXlqeX8co+QrmiieZfI6jO+htHqUND
# pJ+WKJWXAN+NhnkZpAXjRWma+PsVhUAdggKb3X2a9dNXCyQJ7z42GgB4dird6WLP
# 2DuBNihi+AYSxa5SQ2CxszK4if370b8vyFdBFOINa5wGSfrjiEXwAifZqIfi9giC
# JLpiAAES+Wts78QgWE9QsoSn2ZH3+vy+h0+jSWocJ1fdMYIBdjCCAXICAQEwVjBI
# MRMwEQYKCZImiZPyLGQBGRYDY29tMRowGAYKCZImiZPyLGQBGRYKc3Rhcmx1bWJl
# cjEVMBMGA1UEAxMMUzk5VUFHUDAxLUNBAgoZfPzNAAAAAAhfMAkGBSsOAwIaBQCg
# eDAYBgorBgEEAYI3AgEMMQowCKACgAChAoAAMBkGCSqGSIb3DQEJAzEMBgorBgEE
# AYI3AgEEMBwGCisGAQQBgjcCAQsxDjAMBgorBgEEAYI3AgEVMCMGCSqGSIb3DQEJ
# BDEWBBQf/yf5wPccsspjfzq8t/YKM9z6qTANBgkqhkiG9w0BAQEFAASBgHf63ni2
# 2HWVHEo8zmvcpZJtp9mfR0kLS0T9kr3wMzxxzkQdjoj8G9pSgQEWxH0XI6g2VJEQ
# utEb4sFERNoIP+gfRqkHo7vllXkFRB8lQoq2E87vHZ1vS86NbjCHTiu43YBHKEAI
# k0ZiMYUxwj+EDgY7M+DJ0r580F3i7x/dxIki
# SIG # End signature block
