#Download and Install SSH Module (Powershell Version 5 Required)
#http://www.thomasmaurer.ch/2016/04/using-ssh-with-powershell/

$FTPServer = "172.16.1.67"
$FTPUsername = "staradmin"
$TFTPServer = "172.16.1.214" #S99ADMINP01

Find-Module Posh-SSH | Install-Module
$Trash = get-module Posh-SSH
$WaitTime = "5" # Measured in Seconds

$Devices = Import-Csv C:\NetworkDevices.txt 

foreach ($Device in $Devices){
$DeviceIP = ($Device).IPAddress
$DeviceType = ($Device).DeviceType
$securePwd = ConvertTo-SecureString -String Sulli01 -AsPlainText -Force
$CredObject = New-Object System.Management.Automation.PSCredential -ArgumentList staradmin, $securePwd
# Makes Sure the Device is Online and Reachable via ICMP before connecting
$Counter=0
Do{
$Counter=$Counter+1
Start-Sleep -Seconds 30
if($Counter -eq 10){
"$DeviceIP never responded to ICMP"
break}
if($Counter -gt 1){"Waiting..."}
}
Until (Test-Connection -ComputerName $DeviceIP -Count 2 -Quiet )

#Creating SSH Session and Login In
$session = New-SSHSession $DeviceIP -Credential $CredObject -AcceptKey:$true
try{
$SSHStream = $session.Session.CreateShellStream("xterm", 1000, 1000, 1000, 1000, 1000)
#$SSHStream = New-SSHShellStream -Index 0
Start-Sleep -Seconds $WaitTime
""
$SSHStream.read()
$SSHStream.WriteLine("")
Start-Sleep -Seconds $WaitTime
$SSHStream.read()

#Commands to Remove VT100/ANSI Escape Characters from HP Switch
if($DeviceType -like "HP1"){
$SSHStream.WriteLine("conf t")
Start-Sleep -Seconds $WaitTime
$SSHStream.WriteLine("console local-terminal none")
Start-Sleep -Seconds $WaitTime
$SSHStream.WriteLine("end")
Start-Sleep -Seconds $WaitTime
$SSHStream.read()
}

#Create Standard Baseline to know if done Exporting
$SSHStream.WriteLine(“”)
Start-Sleep -Seconds $WaitTime
$BaseLineCMD = $SSHStream.read()


#Command to Copy Config if HP1 Switch
if($DeviceType -like "HP1"){
$SSHStream.WriteLine("copy startup-config tftp $TFTPServer $DeviceIP.StartupConfig.txt")
Start-Sleep -Seconds $WaitTime
$SSHStream.read()

#Create a CompareBaseLine to Baseline to know if done Exporting
$SSHStream.WriteLine(“”)
Start-Sleep -Seconds $WaitTime
$CompareBaseLineCMD = $SSHStream.read()
if($CompareBaseLineCMD -notlike $BaseLineCMD){
"FTP Transfer is not completed: Pausing"
$Counter=0
Do{
$Counter=$Counter+1
Start-Sleep -Seconds $WaitTime
$SSHStream.WriteLine(“”)
Start-Sleep -Seconds $WaitTime
$CompareBaseLineCMD = $SSHStream.read()
if($Counter -eq 10){
"FTP Transfer Completion Detection Failed for Exporting Current Config"
break}
} Until ($CompareBaseLineCMD -like $BaseLineCMD)
} #End of if not like
} #End of Export if Device ID os HP1

} #End of Try
Finally {
Get-SSHSession | Remove-SSHSession
}




}#End of For each Device in List