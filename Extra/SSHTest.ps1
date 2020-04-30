#Download and Install SSH Module (Powershell Version 5 Required)
#http://www.thomasmaurer.ch/2016/04/using-ssh-with-powershell/

$FTPServer = "172.16.1.67"
$FTPUsername = "staradmin"
$FTPPassword = "Magna(1215"
$SonicWALLDeviceIP = "172.16.111.1"
$DoFirmwareUpdate = $False #should be $True or $False
$FirmwareFile = "firmware.bin.sig"

function SendEmail{
$From = "ScriptAutomation@network-consultants.com"
$To = "sswank@starlumber.com"
$TSR | Out-File -FilePath "$env:temp\TSRReport$SonicWALLDeviceIP.Txt"
$Attachment = "$env:temp\TSRReport$SonicWALLDeviceIP.Txt"
$Subject = "SonicWALL System Info"
$Body = "System Info:  $SonicWALLDeviceIP
        $Version"
$SMTPServer = "192.168.1.15"
$SMTPPort = "25"
Send-MailMessage -From $From -to $To -Subject $Subject -Body $Body -SmtpServer $SMTPServer -port $SMTPPort -Attachments $Attachment
del "$env:temp\TSRReport$SonicWALLDeviceIP.Txt"
}



Find-Module Posh-SSH | Install-Module
$Trash = get-module Posh-SSH
$securePwd = ConvertTo-SecureString -String Hammar51 -AsPlainText -Force
$CredObject = New-Object System.Management.Automation.PSCredential -ArgumentList staradmin, $securePwd
$WaitTime = "5" # Measured in Seconds

# Makes Sure the Device is Online and Reachable via ICMP before connecting
$Counter=0
Do{
$Counter=$Counter+1
Start-Sleep -Seconds 30
if($Counter -eq 10){
"$SonicWALLDeviceIP never responded to ICMP"
break}
}
Until (Test-Connection -ComputerName $SonicWALLDeviceIP -Count 2 -Quiet )

#Creating SSH Session and Login In
New-SSHSession $SonicWALLDeviceIP -Credential $CredObject -AcceptKey:$true
try{
$SSHStream = New-SSHShellStream -Index 0
Start-Sleep -Seconds $WaitTime
""
$SSHStream.read()
$SSHStream.WriteLine("Hammar51")
Start-Sleep -Seconds $WaitTime
$Trash = $SSHStream.read()

#Create Standard Baseline to know if done Exporting
$SSHStream.WriteLine(“”)
Start-Sleep -Seconds $WaitTime
$BaseLineCMD = $SSHStream.read()


#Showing Version
$SSHStream.WriteLine(“show version”)
Start-Sleep -Seconds $WaitTime
""
$Version = $SSHStream.read()
$Version
""

#Saving TSR Report as Powershell Object
$SSHStream.WriteLine(“show tech-support-report”)
Start-Sleep -Seconds $WaitTime
$TSR = $SSHStream.read()



# Makes Sure the Device is Online and Reachable via ICMP before connecting
$Counter=0
Do{
$Counter=$Counter+1
Start-Sleep -Seconds 30
if($Counter -eq 10){
"$FTPServer never responded to ICMP"
break}
}
Until (Test-Connection -ComputerName $FTPServer -Count 2 -Quiet)

#Exporting Current Configuration to FTP Server
$SSHStream.WriteLine(“export current-config sonicos ftp ftp://$FTPUsername" + ":" + "$FTPPassword@$FTPServer/$SonicWALLDeviceIP.exp”)
Start-Sleep -Seconds $WaitTime
Start-Sleep -Seconds $WaitTime
Start-Sleep -Seconds $WaitTime
""
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

# Done with Normal Commands, Going to Config Mode
$SSHStream.WriteLine(“configure”)
Start-Sleep -Seconds $WaitTime
$SSHStream.read()

#Create Standard Config Baseline to know if done Exporting
$SSHStream.WriteLine(“”)
Start-Sleep -Seconds $WaitTime
$ConfigBaseLineCMD = $SSHStream.read()

$SSHStream.WriteLine(“export firmware current ftp ftp://$FTPUsername" + ":" + "$FTPPassword@$FTPServer/$SonicWALLDeviceIP.bin.sig”)
Start-Sleep -Seconds $WaitTime
Start-Sleep -Seconds $WaitTime
Start-Sleep -Seconds $WaitTime
""
$SSHStream.read()

#Create a CompareBaseLine to Baseline to know if done Exporting
$SSHStream.WriteLine(“”)
Start-Sleep -Seconds $WaitTime
$CompareBaseLineCMD = $SSHStream.read()
if($CompareBaseLineCMD -notlike $ConfigBaseLineCMD){
"FTP Transfer is not completed: Pausing"
$Counter=0
Do{
$Counter=$Counter+1
Start-Sleep -Seconds $WaitTime
$SSHStream.WriteLine(“”)
Start-Sleep -Seconds $WaitTime
$CompareBaseLineCMD = $SSHStream.read()
if($Counter -eq 10){
"FTP Transfer Completion Detection Failed for Exporting Firmware"
break}
} Until ($CompareBaseLineCMD -like $ConfigBaseLineCMD)
} #End of if not like


if($DoFirmwareUpdate){
$SSHStream.WriteLine(“import firmware ftp ftp://$FTPUsername" + ":" + "$FTPPassword@$FTPServer/$FirmwareFile”)
Start-Sleep -Seconds $WaitTime
Start-Sleep -Seconds $WaitTime
Start-Sleep -Seconds $WaitTime
""
$SSHStream.read()

#Create a CompareBaseLine to Baseline to know if done Exporting
$SSHStream.WriteLine(“”)
Start-Sleep -Seconds $WaitTime
$CompareBaseLineCMD = $SSHStream.read()
if($CompareBaseLineCMD -notlike $ConfigBaseLineCMD){
"FTP Transfer is not completed: Pausing"
$Counter=0
Do{
$Counter=$Counter+1
Start-Sleep -Seconds $WaitTime
$SSHStream.WriteLine(“”)
Start-Sleep -Seconds $WaitTime
$CompareBaseLineCMD = $SSHStream.read()
if($Counter -eq 10){
"FTP Transfer Completion Detection Failed for Importing Firmware"
break}
} Until ($CompareBaseLineCMD -like $ConfigBaseLineCMD)
} #End of if not like 
} #End of Firmware Update is Needed


} # End of Try
Finally {
Get-SSHSession | Remove-SSHSession
SendEmail
}