Function Starlumber-S99SQLBIZP01-Shutdown{
if ($env:COMPUTERNAME -eq "S99MGMNTP01"){

$ScriptBlock={
$ServiceName = "Windows Time"
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
$session = New-PSSession -ComputerName $ComputerName
Invoke-Command -Session $session -ScriptBlock $sb                          # Creates Remote Powershell Session, sents commands, for execution, and closes Powershell session
Remove-PSSession $session

} # End of If S99SQLBIZP01 Statement
} # End of Starlumber-S99SQLBIZP01-Shutdown Function

StarLumber-S99SQLBIZP01-Shutdown