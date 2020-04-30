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





# This is the Start of the Script
# Checks to Verify Script is Compatible with the Powershell version. If not, it Exits.

$FailoverClusterVMSCounter=0
SSWANK-General-PSVersionCheck 3
SSWANK-General-ServerCheck
SSWANK-General-serverVersCheck "6.2"

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
