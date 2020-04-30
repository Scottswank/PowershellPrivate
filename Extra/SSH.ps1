#Download and Install SSH Module (Powershell Version 5 Required)
#http://www.thomasmaurer.ch/2016/04/using-ssh-with-powershell/

Find-Module Posh-SSH | Install-Module
get-module Posh-SSH
$securePwd = ConvertTo-SecureString -String Hammar51 -AsPlainText -Force
$CredObject = New-Object System.Management.Automation.PSCredential -ArgumentList staradmin, $securePwd
New-SSHSession 172.16.111.1 -Credential $CredObject
try{
$SSHStream = New-SSHShellStream -Index 0
Start-Sleep -Seconds 8
$SSHStream.read()
$SSHStream.WriteLine("Hammar51")
Start-Sleep -Seconds 8
$SSHStream.WriteLine(“ping 172.16.1.195”)
Start-Sleep -Seconds 8
$SSHStream.read()
$SSHStream.WriteLine(“Restart Now”)
$SSHStream.WriteLine(“Yes”)
#$SSHStream.WriteLine(“commit”)
#$SSHStream.WriteLine("Hammar51")
Start-Sleep -Seconds 5
$SSHStream.read()}
Finally {
Get-SSHSession | Remove-SSHSession}