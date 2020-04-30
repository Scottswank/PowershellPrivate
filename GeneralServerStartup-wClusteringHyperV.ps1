# General Server Statup with Hyper-V and Clustering Support
# 
# 
# Last Edited By:Scott Swank
# Last Edited: 1/3/2017
#
# Written By: Scott Swank
# Written: 1/3/2017
# Version 1.0
#
# Tested OS versions: Server 2012 R2; Server 2012;
#
# Powershell Version must be greater then 3
# Server OS must be Server 2012 or newer
#
# Requires the Below global Variables
#
# $VMRetryCounter=3
#
# Requires SSWANK-HyperV-RetryStart-ALLVM
# Requires SSWANK-HyperV-RetryStart-OffVM
# Requires SSWANK-HyperV-RetryStartVM
# 
Function  SSWANK-HyperV-Startup-Instructions{
$ComputerNameCounter=0
#EDITABLE SECTION

#
#
# This is where you setup what you want each specific server to do.
# There have been a few Fuctions setup for your specific Hyper-V fuctions
#
# SSWANK-HyperV-RetryStart-ALLVM              - Attempts to start ALL Hyper-V servers Running or Not - not recommended in most cases
# SSWANK-HyperV-RetryStart-OffVM              - Attempts to start all Hyper-V servers that are not running
# SSWANK-HyperV-RetryStartVM %vmname%        - Attempts to start %vmname%. It will verify it is not running before starting.
#
# Powershell Also Provides:
# Start-Sleep -Seconds #        - Will Pause the Powershell for # number of secounds
#
# Example:
# 
# If($env:COMPUTERNAME -eq "SERVER1"){
# "Starting Startup Process for SERVER1"
# $ComputerNameCounter=$ComputerNameCounter+1
# SSWANK-HyperV-RetryStartVM "ImagingPC"
# Start-Sleep -Seconds 5
# SSWANK-HyperV-RetryStart-OffVM
# }
# 
# 
# This will run for SERVER1
# It will attempt to start ImagingPC
# After starting the virtual server, it will pause for an additional 5 seconds
# Then it will attempt to start any other running virtual machines running on the server
# 
# At the bottom, there is a place to change the default behavior is no name is found. To change the default behavior
# add your lines of codes below the Output line. The below code will start all VMs on the host which are off.
#
#     If($ComputerNameCounter -eq 0){
# "No specific computer policy was found. Starting general Hyper-V startup process for $env:COMPUTERNAME"
# SSWANK-HyperV-RetryStart-OffVM
# }

If($env:COMPUTERNAME -eq "S99VMSP04"){
"Starting Startup Process for S99VMSP04"
$ComputerNameCounter=$ComputerNameCounter+1
    SSWANK-HyperV-RetryStartVM "ImagingPC"
}

If($env:COMPUTERNAME -eq "S99VMSP03"){
"Starting Startup Process for S99VMSP03"
$ComputerNameCounter=$ComputerNameCounter+1
SSWANK-HyperV-RetryStartVM "S99ADP03"
Start-Sleep -Seconds 5
}

If($env:COMPUTERNAME -eq "S70VMSP01"){
"Starting Startup Process for S70VMSP01"
$ComputerNameCounter=$ComputerNameCounter+1
SSWANK-HyperV-RetryStartVM "S70ADP01"
Start-Sleep -Seconds 180
SSWANK-HyperV-RetryStartVM "S70SQLP01"
SSWANK-HyperV-RetryStartVM "S70WSUSP01"
SSWANK-HyperV-RetryStartVM "S70FILEP01"
Start-Sleep -Seconds 15
SSWANK-HyperV-RetryStartVM "s70tsp01"
}

If($env:COMPUTERNAME -eq "S05vmsp01"){
"Starting Startup Process for S05VMSP01"
$ComputerNameCounter=$ComputerNameCounter+1
SSWANK-HyperV-RetryStartVM "S05ADP01"
Start-Sleep -Seconds 180
SSWANK-HyperV-RetryStartVM "S05FILEP01"
SSWANK-HyperV-RetryStartVM "S05PRINTP01"
SSWANK-HyperV-RetryStart-OffVM
}

If($env:COMPUTERNAME -eq "S05vmsp02"){
"Starting Startup Process for S05VMSP02"
$ComputerNameCounter=$ComputerNameCounter+1
SSWANK-HyperV-RetryStartVM "S05WSUSP01"
Start-Sleep -Seconds 5
SSWANK-HyperV-RetryStart-OffVM
}

If($env:COMPUTERNAME -eq "S30VMSP01"){
"Starting Startup Process for S30VMSP01"
$ComputerNameCounter=$ComputerNameCounter+1
SSWANK-HyperV-RetryStartVM "S30ADP01"
Start-Sleep -Seconds 180
SSWANK-HyperV-RetryStartVM "S30SQLP01"
SSWANK-HyperV-RetryStartVM "s30wsusp01"
Start-Sleep -Seconds 15
SSWANK-HyperV-RetryStartVM "s30filep01"
SSWANK-HyperV-RetryStartVM "s30printp01"
Start-Sleep -Seconds 15
SSWANK-HyperV-RetryStartVM "s30aaap01"
SSWANK-HyperV-RetryStart-OffVM
}

If($env:COMPUTERNAME -eq "S71VMSP01"){
"Starting Startup Process for S71VMSP01"
$ComputerNameCounter=$ComputerNameCounter+1
SSWANK-HyperV-RetryStartVM "S71ADP01"
Start-Sleep -Seconds 5
SSWANK-HyperV-RetryStart-OffVM
}
#General Policy if no other Policies are found
    If($ComputerNameCounter -eq 0){
    "No specific computer policy was found. Starting general Hyper-V startup process for $env:COMPUTERNAME"
    SSWANK-HyperV-RetryStart-OffVM
    }
#
#
#END OF EDITABLE SECTION
#
#
}
#
# Number of Times you want the Virtual Machines Attemped to be Restarted
#
$VMRetryCounter=3
# Function Called to Start Virtual Machines
#
# Requires the Below global Variables
#
# $VMRetryCounter=3
# Requires SSWANK-HyperV-Startup-Instructions
#
Function SSWANK-HyperV-RetryStartVM {
    Param ($VMName)
    if((get-vm -Name $VMName).state -eq "Running"){
    "Virtual Server $VMName is already Running"
    }
    if((get-vm -Name $VMName).state -eq "OffCritical"){
    "Virtual Server $VMName is in a Off Critical state"
    "Script will pause waiting for the VM to enter Off state"
    $counter=0
    Do{
            if($counter -eq "10"){
                "Unable to start $VMName. Tried $counter times."
                 Break}
            $counter=$counter+1
            Start-Sleep -Seconds 30
    }
    Until((get-vm -Name $VMName).state -eq "Off")}
    if((get-vm -Name $VMName).state -eq "Off"){
    "Attempting to Start Virtual Server $VMName"
    start-vm $VMName
    Start-Sleep -Seconds 5
    $counter=1
    if((get-vm -Name $VMName).state -eq "Off"){
        Do{
            if($counter -eq "$VMRetryCounter"){
                "Unable to start $VMName. Tried $counter times."
                 Break}
            start-vm $VMName
            $counter=$counter+1
            Start-Sleep -Seconds 15}
         Until((get-vm -Name $VMName).state -eq "Running") 
    } "Attempt  to Start $VMName was Successful"
 } 
}

# Restarts All Virtual Machines on the System
# Requires SSWANK-HyperV-Startup-Instructions

Function SSWANK-HyperV-RetryStart-ALLVM{
    Get-VM | Foreach{$_.name}{
    $VMName=$_.name
    "AllVM:Attempting to Start $VMName"
    SSWANK-HyperV-RetryStartVM $VMName
    "AllVM:Attempt to Start $VMName was Successful"
    Start-Sleep -Seconds 5
    }
}

# Restarts All Off Virtual Machines on the System
# Requires SSWANK-HyperV-Startup-Instructions

Function SSWANK-HyperV-RetryStart-OffVM{
    $GetVMOff=Get-VM | Where-Object {$_.State –eq "Off"}
    $GetVMOff | Foreach{$_.name}{
    $VMName=$_.name
    "AllOffVM:Attempting to Start $VMName"
    SSWANK-HyperV-RetryStartVM $VMName
    "AllOffVM:Attempt to Start $VMName was Successful"
    Start-Sleep -Seconds 5
    }
}

# Checks that Current Status of the your Current Node
# Will Launch Resume-FailoverClustering if Needed

Function SSWANK-FailoverCluster-DrainResume-CheckDrain{
    $FailoverDrainStatus=(get-ClusterNode -Name "$env:COMPUTERNAME").drainstatus
    If($FailoverDrainStatus -eq 'NotInitiated'){
        "Resuming Failover Clustering Roles on $env:COMPUTERNAME"
    SSWANK-FailoverCluster-DrainResume
    "Failover Clustering Roles resumed on $env:COMPUTERNAME"
    }
       
    If($FailoverDrainStatus -eq "InProgress"){
    "Live Migration In Progress on $env:COMPUTERNAME : Aborting"
    }

    If($FailoverDrainStatus -eq "Completed"){
    "Drain Status is Completed on $env:COMPUTERNAME : Resuming Failover Clustering Roles"
    SSWANK-FailoverCluster-DrainResume
    "Failover Clustering Roles resumed on $env:COMPUTERNAME"
    }

    If($FailoverDrainStatus -eq "Paused"){
    "Resuming Failover Clustering Roles on $env:COMPUTERNAME"
    SSWANK-FailoverCluster-DrainResume
    }
    If((get-ClusterNode -Name "$env:COMPUTERNAME").status -eq "Paused"){
    "Resuming Failover Clustering Roles on $env:COMPUTERNAME - No Drain Status"
    SSWANK-FailoverCluster-DrainResume
    "Failover Clustering Roles resumed on $env:COMPUTERNAME - No Drain Status"
    }
}

# Start of Functions to Check the status of the Cluster Node, and Ultimately resume the cluster node
# 
# Requires SSWANK-FailoverCluster-DrainResume
# Requires SSWANK-FailoverCluster-DrainResume-CheckDrain
#
Function SSWANK-FailoverCluster-DrainResume-Check{
    If((get-ClusterNode -Name "$env:COMPUTERNAME").state -eq 'Up'){
    "Failover Clustering Node $env:COMPUTERNAME is already in Up State"
    }
    If((get-ClusterNode -Name "$env:COMPUTERNAME").state -eq 'Paused'){
    SSWANK-FailoverCluster-DrainResume-CheckDrain
    }
}

# Checks to see if a Service is Running, and Resumes Failover Clustering and Fails Roles Back

Function SSWANK-FailoverCluster-DrainResume{
     Resume-ClusterNode –Failback Immediate
            $Counter=0
 :ClusterLoop   while($Counter -lt 60){
                If((get-ClusterNode -Name "$env:COMPUTERNAME").drainstatus -eq "NotInitiated") {
                break}
            $Counter=$Counter+1
            Start-Sleep -seconds 15
            break}
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

# Function to Check to see if a Service is Running, and Launch Failover Cluster Resume
function SSWANK-General-CheckServiceRunning{
 param($ServiceName)
 $arrService = Get-Service -Name $ServiceName
 if ($arrService.Status -ne "Running"){
 $ServiceStatus=$arrService.Status
"The service $ServiceName is not running"
 }
 if ($arrService.Status -eq "running"){
 "The service $ServiceName is running"
 SSWANK-FailoverCluster-DrainResume-Check
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

# Checks if client is a server OS
 function SSWANK-General-ServerCheck{
 $ProductTypeArray = Get-WmiObject WIN32_OperatingSystem -ComputerName $env:COMPUTERNAME| Select-Object ProductType
 $ProductType = ($ProductTypeArray).ProductType
 if($ProductType -ne 3){
 "Your system is not a server. Checks will not be performed"
 exit}
 }

# This is the Start of the Script
# Checks to Verify Script is Compatible with the Powershell and is Server OS. If not, it Exits.

SSWANK-General-PSVersionCheck 3
SSWANK-General-ServerCheck
SSWANK-General-serverVersCheck "6.2"
#Checks to see if Hyper-V is installed If so, it launches the Hyper-V Instructions
if((Get-WindowsFeature -Name Hyper-V).InstallState -eq "Installed"){
"$env:COMPUTERNAME is a Hyper-V Host"
SSWANK-HyperV-Startup-Instructions
}
else{
"$env:COMPUTERNAME is not a Hyper-V Host"
}


# If the Server is a part of a Failover Cluster, Run the Services Check Function, Linked to Failover Clustering

if((Get-WindowsFeature -Name Failover-Clustering).InstallState -eq "Installed"){
    "$env:COMPUTERNAME is part of a Cluster"
    SSWANK-General-CheckServiceRunning "ClusSvc"
    }
else{
    "$env:COMPUTERNAME is not part of a Cluster"}
exit
# SIG # Begin signature block
# MIIHBwYJKoZIhvcNAQcCoIIG+DCCBvQCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUEJdftkhJedwIPUNrJP/Jrara
# ZG6gggT7MIIE9zCCA9+gAwIBAgIKGXz8zQAAAAAIXzANBgkqhkiG9w0BAQUFADBI
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
# BDEWBBQlobNzM6p6gFOivp39ELyxevoW8DANBgkqhkiG9w0BAQEFAASBgJrsXlLK
# 9v407B5Px37gBeYlYJID6CV7xYaqwxiyhYmCA3CSETb9Uzgyx/iMWXl19S5WZtg8
# XM8uO0etrdarCaoiCc8365FfhI2zy/bFdKu6z1HbUKhLHzC+CKdm6fhlxwm7OrXx
# wTFfAM/03zR7yb/pqarA1TxNJUL5FRv9hLcZ
# SIG # End signature block
