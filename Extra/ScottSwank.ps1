<#
Created by: Scott Swank
E-mail: scottswank@cox.net
Cell: 316-347-4000
#>

$ComputerListPath = "C:\Temp\Computerlist.csv"
$FirefoxInstallPath = "\\Remoteserver\Share\"


function Get-RemoteProgram{ # Source https://gallery.technet.microsoft.com/scriptcenter/Get-RemoteProgram-Get-list-de9fd2b4
   [CmdletBinding(SupportsShouldProcess=$true)]
    param(
        [Parameter(ValueFromPipeline              =$true,
                   ValueFromPipelineByPropertyName=$true,
                   Position=0
        )]
        [string[]]
            $ComputerName = $env:COMPUTERNAME,
        [Parameter(Position=0)]
        [string[]]
            $Property,
        [switch]
            $ExcludeSimilar,
        [int]
            $SimilarWord
    )

    begin {
        $RegistryLocation = 'SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\',
                            'SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\'
        $HashProperty = @{}
        $SelectProperty = @('ProgramName','ComputerName')
        if ($Property) {
            $SelectProperty += $Property
        }
    }

    process {
        foreach ($Computer in $ComputerName) {
            $RegBase = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey([Microsoft.Win32.RegistryHive]::LocalMachine,$Computer)
            $RegistryLocation | ForEach-Object {
                $CurrentReg = $_
                if ($RegBase) {
                    $CurrentRegKey = $RegBase.OpenSubKey($CurrentReg)
                    if ($CurrentRegKey) {
                        $CurrentRegKey.GetSubKeyNames() | ForEach-Object {
                            if ($Property) {
                                foreach ($CurrentProperty in $Property) {
                                    $HashProperty.$CurrentProperty = ($RegBase.OpenSubKey("$CurrentReg$_")).GetValue($CurrentProperty)
                                }
                            }
                            $HashProperty.ComputerName = $Computer
                            $HashProperty.ProgramName = ($DisplayName = ($RegBase.OpenSubKey("$CurrentReg$_")).GetValue('DisplayName'))
                            if ($DisplayName) {
                                New-Object -TypeName PSCustomObject -Property $HashProperty |
                                Select-Object -Property $SelectProperty
                            } 
                        }
                    }
                }
            } | ForEach-Object -Begin {
                if ($SimilarWord) {
                    $Regex = [regex]"(^(.+?\s){$SimilarWord}).*$|(.*)"
                } else {
                    $Regex = [regex]"(^(.+?\s){3}).*$|(.*)"
                }
                [System.Collections.ArrayList]$Array = @()
            } -Process {
                if ($ExcludeSimilar) {
                    $null = $Array.Add($_)
                } else {
                    $_
                }
            } -End {
                if ($ExcludeSimilar) {
                    $Array | Select-Object -Property *,@{
                        name       = 'GroupedName'
                        expression = {
                            ($_.ProgramName -split $Regex)[1]
                        }
                    } |
                    Group-Object -Property 'GroupedName' | ForEach-Object {
                        $_.Group[0] | Select-Object -Property * -ExcludeProperty GroupedName
                    }
                }
            }
        }
    }
}


function FirefoxTests{
param($ComputerName)
$table | ForEach-Object {                                               #Sets Reporting Table Values
if ($_.Computername = "$Computername"){                                 #Sets Reporting Table Values
$_.Status = "online"                                                    #Sets Reporting Table Values
$Script:table = $table}}                                                 #Sets Reporting Table Values

$ProgramList = Get-RemoteProgram -ComputerName $ComputerName -Property DisplayVersion,Publisher | Where-Object {$_.ProgramName -like "*Mozilla Firefox*"} # Gets remote Programs and Filters to Mozill
if(($ProgramList).ProgramName -like "*Mozilla Firefox*"){          # sees if program is installed / record exists by comparing same value  
                                                                                      
if(($ProgramList).DisplayVersion -lt "50.1.0"){                     # Sees what Version is installed
 #$AppVersion = ($ProgramList).DisplayVersion                          # Sets value for log  file

 $sb = {
 $Copypath = "$env:temp\Files\"                                             # Sets local copy path
 Robocopy $FirefoxInstallPath $Copypath *.*                                 # Copys Files
 cd $Copypath                                                               # Change File Path
 start-process "Firefox Setup 50.1.0.exe" -Argumentlist '/INI="%CD%\Firefox.ini"' # Run installer with arguements
 if(TestTest-Path "C:\Program Files (x86)\Mozilla Firefox\firefox.exe"){    #Checks to see if the 32 bit firefox got installed
 $TargetFile = "C:\Program Files (x86)\Mozilla Firefox\firefox.exe"}        #Sets $Target Path to 32 bit .exe path
 if(TestTest-Path "C:\Program Files\Mozilla Firefox\firefox.exe"){          #Checks to see if the 64 bit firefox got installed
 $TargetFile = "C:\Program Files\Mozilla Firefox\firefox.exe"}              #Sets $Target Path to 64 bit .exe path
 $ShortcutFile = "$env:Public\Desktop\Mozilla Firefox.lnk"
 $WScriptShell = New-Object -ComObject WScript.Shell
 $Shortcut = $WScriptShell.CreateShortcut($ShortcutFile)                    #Creates Shortcut
 $Shortcut.TargetPath = $TargetFile                                         #Sets Shortuct Path
 $Shortcut.Save()                                                           #Saves the shortcut
 REG ADD "HKCU\SOFTWARE\MICROSOFT\MOZILLA FIREFOX\MAIN" /V "START PAGE" /D "http://www.google.com/" /F # Sets the homepage to google
 del $Copypath -Recurse                                                     #Deletes the files we copied from the server
  }                                                                         # End of Script Block

 $sb = [scriptblock]::Create($ScriptBlock)                                  # Configures the scriptblock format
 $session = New-PSSession -ComputerName $ComputerName
 Invoke-Command -Session $session -ScriptBlock $sb                          # Creates Remote Powershell Session, sents commands, for execution, and closes Powershell session
 Remove-PSSession $session
}                                                                           # End of Version is Less Then  Statement
else{
    $table | ForEach-Object {                                                     #Update Reporting Table                              
    if ($_.Computername = "$Computername"){                                       #Update Reporting Table
    $_.FireFoxAllReadyCurrent = "True"                                                   #Update Reporting Table
    $Script:table = $table}}                                                      #Update Reporting Table
 #$AppVersion = ($ProgramList).DisplayVersion
 #"$Computername Doesn't need an update of Mozilla Firefox. Current Version is $AppVersion" } 
}                                                                           # End of a record Exists statements                                              
}
else{ 
   $table | ForEach-Object {                                                #Update Reporting Table
    if ($_.Computername = "$Computername"){                                 #Update Reporting Table
    $_.FirefoxNotInstalled = "True"                                  #Update Reporting Table No records found
    $Script:table = $table}                                                 #Update Reporting Table
    }   # If it couldn't even find any version installed, then it is not installed, so log it
}
}

Function OfflineComputers{
param($ComputerName)
if(Test-Connection -Cn $ComputerName -BufferSize 16 -Count 2 -ea 0 -quiet){    # Computer is already online
    $ComputerList | ForEach-Object {                                           # Update .CSV Table
    if ($_.Computername = "$Computername"){                                    # Update .CSV Table
    $_.Status = "Online"}                                                      # Update .CSV Table                                       
    $Script:ComputerList = $ComputerList}                                      # Update .CSV Table
FirefoxTests "$ComputerName"
}
  if(!(Test-Connection -Cn $ComputerName -BufferSize 16 -Count 2 -ea 0 -quiet)){
   ipconfig /flushdns | out-null
   ipconfig /registerdns | out-null
   nslookup $ComputerName
   if(!(Test-Connection -Cn $ComputerName -BufferSize 16 -Count 2 -ea 0 -quiet)){
   “Problem still exists in connecting to $ComputerName”}
 ELSE {
    $ComputerList | ForEach-Object {                                            # Update .CSV Table
    if ($_.Computername = "$Computername"){                                     # Update .CSV Table
    $_.Status = "Online"}                                                       # Update .CSV Table
    $Script:ComputerList = $ComputerList}                                       # Update .CSV Table
    FirefoxTests "$ComputerName"} 
    } # end if
} # end foreach



function SendEmail{
$From = "YourEmail@gmail.com"
$To = "AnotherEmail@YourDomain.com"
$Cc = "YourBoss@YourDomain.com"
$Attachment = $ComputerListPath
$Subject = "Firefox Program Updates"
$Body = "Here is the status of your systems. Let me know if you need clarification 
        $Messagetable"
$SMTPServer = "smtp.gmail.com"
$SMTPPort = "587"
Send-MailMessage -From $From -to $To -Cc $Cc -Subject $Subject -Body $Body -SmtpServer $SMTPServer -port $SMTPPort -UseSsl -Credential (Get-Credential) -Attachments $Attachment
}



<# My Test SMTP Info
function SendEmail{
$From = "sswank@starlumber.com"
$To = "sswank@starlumber.com"
$Attachment = $ComputerListPath
$Subject = "Firefox Program Updates"
$Body = "Here is the status of your systems. Let me know if you need clarification 
        $Messagetable"
$SMTPServer = "mail.starlumber.com"
$SMTPPort = "25"
Send-MailMessage -Credential (Get-Credential) -From $From -to $To -Subject $Subject -Body $Body -SmtpServer $SMTPServer -port $SMTPPort -Attachments $Attachment
}
#>

#Imports .CSV Computer List with Headers

$ComputerList = Get-Content -path $ComputerListPath | Convertfrom-Csv # Gets the Computer Information Array

#Creates Reporing Tables
$tabName = “ReportingTable”

#Create Table object
$table = New-Object system.Data.DataTable “$tabName”

#Define Columns
$col1 = New-Object system.Data.DataColumn ComputerName,([string])
$col2 = New-Object system.Data.DataColumn Status,([string])
$col3 = New-Object system.Data.DataColumn FirefoxAllReadyCurrent,([string])
$col4 = New-Object system.Data.DataColumn FirefoxUpdated,([string])
$col5 = New-Object system.Data.DataColumn FirefoxNotInstalled,([string])

#Add the Columns
$table.columns.add($Col1)
$table.columns.add($col2)
$table.columns.add($col3)
$table.columns.add($col4)
$table.columns.add($col5)

#Add the row to the table


$ComputerList | Foreach{$_.ComputerName}{                            # Create loop for computer name
    $ComputerName = $_.Computername
    $table.Rows.Add($Computername)                              #Addes a row to the reporting table
    if($_.status -eq "Online"){                                       # If status is Onlne Do your requirements
    $table | ForEach-Object {                                               #Sets Reporting Table Values
    if ($_.Computername = "$Computername"){                                 #Sets Reporting Table Values
    $_.Status = "online"                                                    #Sets Reporting Table Values
    $Script:table = $table}}                                                  #Sets Reporting Table Values
    FirefoxTests "$ComputerName"
    }
    if($_.status -eq "Offline"){                                     # If status is Offline, Do your requirements
    $table | ForEach-Object {                                             #Sets Reporting Table Values
    if ($_.Computername = "$Computername"){                               #Sets Reporting Table Values
    $_.Status = "Offline"                                                 #Sets Reporting Table Values
    $Script:table = $table}}                                                #Sets Reporting Table Values
    OfflineComputers "$Computername"}
}

$ComputerList  |Export-Csv -Path $ComputerListPath -NoTypeInformation
$Messagetable = $table | format-table -AutoSize | Out-String

SendEmail