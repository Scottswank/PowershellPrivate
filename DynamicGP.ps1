

function StarLumber-S99SQLBIZP01 {

if ($env:COMPUTERNAME -eq "S99MGMNTP01"){
$ScriptBlock={
$ServiceName = "Windows Time"
$arrService = Get-Service -Name $ServiceName
if ($arrService.Status -ne "Running"){ #Start1
"Attempting to start $ServiceName on $env:Computername"
Start-Service $ServiceName
Start-Sleep -Seconds 20
$arrService = Get-Service -Name $ServiceName
if ($arrService.Status -ne "Running"){ #start2
"Attempting to start $ServiceName attempts 2 on $env:Computername"
Start-Service $ServiceName
Start-Sleep -Seconds 20
$arrService = Get-Service -Name $ServiceName
if ($arrService.Status -ne "Running"){ #Notification
"Starting of Service $ServiceName failed on $env:Computername"

}#End of Notification
}#End of Start2
}#End of Start1

$arrService = Get-Service -Name $ServiceName
if ($arrService.Status -eq "running"){ 
"$ServiceName Is Running on $env:Computername"
} #End of Running Statement

} #End of Scriptblock

$sb = [scriptblock]::Create($ScriptBlock)                                  # Configures the scriptblock format
$ComputerName = "S99BISTP01"
$session = New-PSSession -ComputerName $ComputerName
Invoke-Command -Session $session -ScriptBlock $sb                          # Creates Remote Powershell Session, sents commands, for execution, and closes Powershell session
Remove-PSSession $session
} #End of If S99MGMNTP01 Statement
}






StarLumber-S99SQLBIZP01