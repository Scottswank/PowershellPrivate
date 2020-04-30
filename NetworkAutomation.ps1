$ConnectionBroker = "S99RDCBP01.STARLUMBER.COM"
$ADUserNormalDisplayFields = "GivenName","SurName","UserPrincipalName","Name"
$ADGroupNormalDisplayFields = "Name", "GroupCategory"
$ADComputerNormalDisplayFields = "Name","Enabled"

function NetworkAutomation-HomePage-Menu{
     [string]$Title = 'Network Automation'
      cls
      Write-Host "================ $Title ================"
      
      Write-Host "1: Press '1' to Enter Remote Desktop Services."
      Write-Host "2: Press '2' to Enter Active Directory Module."
#      Write-Host "3: Press '3' to Shadow an BisTrack User."
      Write-Host "Q: Press 'Q' to quit."
 }

 function NetworkAutomation-HomePage{
 do
{
      NetworkAutomation-HomePage-Menu
      $input = Read-Host "Please make a selection"
      switch ($input)
      {
            '1' {
                 NetworkAutomation-RemoteDesktop
                 cls
                 "Going back to previous menu"
            } '2' {
                 NetworkAutomation-ActiveDirectory
                 cls
                 "Going back to previous menu"
            }<# '3' {
                 NetworkAutomation-RemoteApp-ShadowUser "BisTrack"
                 cls
                 "Going back to previous menu"
            }#> 'q' {
                 return
            }
      }
      #pause
 }
 until ($input -eq 'q')
 }

 function NetworkAutomation-RemoteDesktop-Menu{
      [string]$Title = 'Network Automation - Remote Desktop Services'
      cls
      Write-Host "================ $Title ================"
      
      Write-Host "1: Press '1' to Lookup Currently Connected Users."
      Write-Host "2: Press '2' to Manage RFMS Remote Desktop Services."
      Write-Host "3: Press '3' to Manage BisTrack Remote Desktop Services."
      Write-Host "Q: Press 'Q' to quit."
 }

  function NetworkAutomation-RemoteDesktop{
 do
{
      NetworkAutomation-RemoteDesktop-Menu
      $input = Read-Host "Please make a selection"
      switch ($input)
      {
            '1' {
                 cls
                 NetworkAutomation-RemoteDesktop-UserLookup
            } '2' {
                 NetworkAutomation-RemoteDesktop-Collections -CollectionName "RFMS"
                 cls
                 "Going back to previous menu"
            } '3' {
                 NetworkAutomation-RemoteDesktop-Collections -CollectionName "BisTrack"
                 cls
                 "Going back to previous menu"
            } 'q' {
                 return
            }
      }
      #pause
 }
 until ($input -eq 'q')
 }

   function NetworkAutomation-RemoteDesktop-Collections-Menu{
    param([string]$CollectionName = "")
      [string]$Title = 'Network Automation - Remote Desktop Services'
      cls
      Write-Host "================ $Title ================"
      
      Write-Host "1: Press '1' to Lookup Currently Connected Users."
      Write-Host "2: Press '2' to Shadow an $CollectionName User."
      Write-Host "3: Press '3' to Remote Control an $CollectionName User."
      Write-Host "4: Press '4' to Log Off an $CollectionName User."
      Write-Host "Q: Press 'Q' to quit."
 }

  function NetworkAutomation-RemoteDesktop-Collections{
 param([string]$CollectionName = "")
 do
{
      NetworkAutomation-RemoteDesktop-Collections-Menu -CollectionName $CollectionName
      $input = Read-Host "Please make a selection"
      switch ($input)
      {
            '1' {
                 cls
                 NetworkAutomation-RemoteDesktop-UserLookup -CollectionName "$CollectionName"
            } '2' {
                 NetworkAutomation-RemoteDesktop-ShadowUser -CollectionName "$CollectionName" -RemoteControl ""
                 cls
                 "Going back to previous menu"
            } '3' {
                 NetworkAutomation-RemoteDesktop-ShadowUser -CollectionName "$CollectionName" -RemoteControl "YES"
                 cls
                 "Going back to previous menu"
            } '4' {
                 NetworkAutomation-RemoteDesktop-UserLogOff -CollectionName "$CollectionName"
                 cls
                 "Going back to previous menu"
            } 'q' {
                 return
            }
      }
      #pause
 }
 until ($input -eq 'q')
 }

function NetworkAutomation-RemoteDesktop-UserLogOff{
param($CollectionName)
$result = Get-RDUserSession -ConnectionBroker $ConnectionBroker -CollectionName $CollectionName | Select-Object -Property Username,HostServer,UnifiedSessionID
$users = $result.UserName

#Set popup box settings
$Form = New-Object System.Windows.Forms.Form    
$Form.Size = New-Object System.Drawing.Size(40,20)  
$Form.Text = "Logoff RDS User"
$Form.AutoSize = $True
$Form.AutoSizeMode = "GrowOnly"
$Form.StartPosition = "CenterScreen"


function remoteConnect-UserLogoff {
    $selectedUser = $ListBox.SelectedItem.ToString()
    $newResult = $result | where {$_.UserName -like $selectedUser}
#    $SessionID = $newResult.UnifiedSessionId
    logoff /server $($newResult.HostServer) $newResult.UnifiedSessionId
    #Start-Process mstsc -Credential $credentials -ArgumentList "/shadow: $($newResult.UnifiedSessionId) /control /v: $($newResult.HostServer) /noConsentPrompt"
}

#Create Listbox
$ListBox = New-Object System.Windows.Forms.ListBox
$ListBox.Location = New-Object System.Drawing.Size(5,5) 
$ListBox.Size = New-Object System.Drawing.Size(180,20) 
$ListBox.Height = 200 
$Form.Controls.Add($ListBox) 

#Add users to listbox
foreach ($user in $users) {
    $ListBox.Items.Add("$user")
}

#Create Connect button
$Button = New-Object System.Windows.Forms.Button 
$Button.Location = New-Object System.Drawing.Size(210,60) 
$Button.Size = New-Object System.Drawing.Size(110,80) 
$Button.Text = "Logoff"
$Button.Add_Click({
remoteConnect-UserLogoff
$form.Close()})
$Form.Controls.Add($Button) 
$Form.Add_Shown({$Form.Activate()})
[void] $Form.ShowDialog()
}


function NetworkAutomation-RemoteDesktop-UserLookup{
param([string]$CollectionName = "")
if($CollectionName -eq ""){
$table = Get-RDUserSession -ConnectionBroker $ConnectionBroker | Select-Object -Property CollectionName,Username,HostServer | format-table -AutoSize | Out-String
$table} #End of If Collection Name is NULL
else{
$table = Get-RDUserSession -ConnectionBroker $ConnectionBroker -CollectionName $CollectionName | Select-Object -Property CollectionName,Username,HostServer,SessionState  | format-table -AutoSize | Out-String
$table
} #End of If Collection Name is not NULL
pause
}

function NetworkAutomation-RemoteDesktop-ShadowUser{
param($CollectionName, [string]$RemoteControl = "")
[void] [System.Reflection.Assembly]::LoadWithPartialName("System.Drawing") 
[void] [System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms")  


$result = Get-RDUserSession -ConnectionBroker $ConnectionBroker -CollectionName $CollectionName | Select-Object -Property Username,HostServer,UnifiedSessionID
$users = $result.UserName

#Set popup box settings
$Form = New-Object System.Windows.Forms.Form    
$Form.Size = New-Object System.Drawing.Size(40,20)  
$Form.Text = "Shadow RDS Session"
$Form.AutoSize = $True
$Form.AutoSizeMode = "GrowOnly"
$Form.StartPosition = "CenterScreen"

#Function to run mstsc.exe with required parameters
function remoteConnect-Shadow {
    $selectedUser = $ListBox.SelectedItem.ToString()
    $newResult = $result | where {$_.UserName -like $selectedUser}
    Start-Process mstsc -Credential $credentials -ArgumentList "/shadow: $($newResult.UnifiedSessionId) /v: $($newResult.HostServer) /noConsentPrompt"
}

function remoteConnect-RemoteControl {
    $selectedUser = $ListBox.SelectedItem.ToString()
    $newResult = $result | where {$_.UserName -like $selectedUser}
    Start-Process mstsc -Credential $credentials -ArgumentList "/shadow: $($newResult.UnifiedSessionId) /control /v: $($newResult.HostServer) /noConsentPrompt"
}

#Create Listbox
$ListBox = New-Object System.Windows.Forms.ListBox
$ListBox.Location = New-Object System.Drawing.Size(5,5) 
$ListBox.Size = New-Object System.Drawing.Size(180,20) 
$ListBox.Height = 200 
$Form.Controls.Add($ListBox) 

#Add users to listbox
foreach ($user in $users) {
    $ListBox.Items.Add("$user")
}

#Create Connect button
$Button = New-Object System.Windows.Forms.Button 
$Button.Location = New-Object System.Drawing.Size(210,60) 
$Button.Size = New-Object System.Drawing.Size(110,80) 
$Button.Text = "Connect"
if($RemoteControl -eq ""){
$Button.Add_Click({
remoteConnect-Shadow
$form.Close()})
}else{
$Button.Add_Click({
remoteConnect-RemoteControl
$form.Close()})
}
$Form.Controls.Add($Button) 


$Form.Add_Shown({$Form.Activate()})
[void] $Form.ShowDialog()
}

Function  SSWANK-General-PSVersionCheck{
param($ScriptPSminVERSION)
$PowershellVersionMajor=($PSVersionTable.PSVersion).Major
if($PowershellVersionMajor -lt $ScriptPSminVERSION){
    "Powershell Version is Less then $ScriptPSminVERSION. Script is Unsupported and will fail"
    "Script will now exit"
    exit
    }
}

function NetworkAutomation-ActiveDirectory-Menu{
      [string]$Title = 'Network Automation - Active Directory'
      cls
      Write-Host "================ $Title ================"
      
      Write-Host "1: Press '1' to Show All AD Users."
      Write-Host "2: Press '2' to Lookup a User Account by Account Properties."
      Write-Host "3: Press '3' to Show All AD Groups."
      Write-Host "4: Press '4' to Lookup a Group by Group Properties."
      Write-Host "5: Press '5' to Show All AD Computers."
      Write-Host "6: Press '6' to Lookup a Computer by Computer Properties."
      Write-Host "Q: Press 'Q' to quit."
 }

  function NetworkAutomation-ActiveDirectory{
 do
{
      NetworkAutomation-ActiveDirectory-Menu
      $input = Read-Host "Please make a selection"
      switch ($input)
      {
            '1' {
                 cls
                 NetworkAutomation-ActiveDirectory-AllUsers
            }'2' {
                 cls
                 $Script:SelectedFilter = ""
                 $Script:UserInput = ""
                 NetworkAutomation-ActiveDirectory-LookupUser-GUI
                 NetworkAutomation-ActiveDirectory-LookupUser
            }'3' {
                 cls
                 NetworkAutomation-ActiveDirectory-AllGroups
            }'4' {
                 cls
                 $Script:SelectedFilter = ""
                 $Script:UserInput = ""
                 NetworkAutomation-ActiveDirectory-LookupGroup-GUI
                 NetworkAutomation-ActiveDirectory-LookupGroup
            }'5' { 
                 cls
                 NetworkAutomation-ActiveDirectory-AllComputers
            }'6' {
                 cls
                 $Script:SelectedFilter = ""
                 $Script:UserInput = ""
                 NetworkAutomation-ActiveDirectory-LookupComputer-GUI
                 NetworkAutomation-ActiveDirectory-LookupComputer
            }'q' {
                 return
            }
      }
 }
 until ($input -eq 'q')
 }

 function NetworkAutomation-ActiveDirectory-LookupUser-Menu{
      [string]$Title = 'Network Automation - Active Directory - User Lookup'
      cls
      Write-Host "================ $Title ================"
      
      Write-Host "1: Press '1' to Show all accounts meeting the filter."
      Write-Host "2: Press '2' to Create a New User Filter."
      Write-Host "3: Press '3' to Show Group membership."
      Write-Host "Q: Press 'Q' to go back to the main AD menu."
 }

function NetworkAutomation-ActiveDirectory-LookupUser{
 do
{
      NetworkAutomation-ActiveDirectory-LookupUser-Menu
      $input = Read-Host "Please make a selection"
      switch ($input)
      {
            '1' {
                 cls
                 NetworkAutomation-ActiveDirectory-UserLookup
            }'2' {
                 cls
                 NetworkAutomation-ActiveDirectory-LookupUser-GUI
            } '3' {
                 cls
                 NetworkAutomation-ActiveDirectory-LookupUser-GroupMembership
            } 'q' {
                 return
            }
      }
 }
 until ($input -eq 'q')
 }

 function NetworkAutomation-ActiveDirectory-UserLookup{
 $UserInput = "*$UserInput*"
Get-ADUser -Filter {($SelectedFilter -like $UserInput)} | ft $ADUserNormalDisplayFields
pause
 }

 function NetworkAutomation-ActiveDirectory-AllUsers{
 Get-ADUser -Filter * | ft $ADUserNormalDisplayFields 
 pause
 }

 function NetworkAutomation-ActiveDirectory-LookupUser-GroupMembership{
 $UserInput = "*$UserInput*"
 $Userlist = Get-ADUser -Filter {($SelectedFilter -like $UserInput)}
 foreach ($DNName in $Userlist){
 $Name = $DNName.Name
 "$Name : Group Membership"
 ""
 Get-ADPrincipalGroupMembership $DNName | ft Name
 }#End of for each
 pause
 }

<# 
 function NetworkAutomation-ActiveDirectory-User-Inactive{
[void] [System.Reflection.Assembly]::LoadWithPartialName("System.Drawing") 
[void] [System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms")  


#Set popup box settings
$Form = New-Object System.Windows.Forms.Form    
$Form.Size = New-Object System.Drawing.Size(200,50)  
$Form.Text = "AD User Inactive Lookup"
$Form.AutoSize = $True
$Form.AutoSizeMode = "GrowOnly"
$Form.StartPosition = "CenterScreen"

$objTextBox = New-Object System.Windows.Forms.TextBox 
$objTextBox.Location = New-Object System.Drawing.Size(50,50) 
$objTextBox.Size = New-Object System.Drawing.Size(80,40) 
$Form.Controls.Add($objTextBox)

$Label = New-Object System.Windows.Forms.Label
$Label.Text = 
"Input the # of days since
last logon date"
$Label.AutoSize = $True
$Label.TextAlign = "MiddleCenter"
$Label.Location = New-Object System.Drawing.Size(30,10)
$Form.Controls.Add($Label)

$OKButton = New-Object System.Windows.Forms.Button
$OKButton.Location = New-Object System.Drawing.Size(50,75)
$OKButton.Size = New-Object System.Drawing.Size(75,23)
$OKButton.Text = "OK"
$OKButton.Add_Click({
$UserInput=$objTextBox.Text;
$Script:UserInput = $UserInput
$Form.Close()})
$Form.Controls.Add($OKButton)
$Form.AcceptButton = $OKButton
$Form.Add_Shown({$Form.Activate()})
cls
[void] $Form.ShowDialog()
 
$time = (Get-Date).Adddays(-($UserInput))
Write-Host "Looking for users with a last logon date older then $UserInput days:"
Write-Host ""
Get-ADUser -Filter {($SelectedFilter -like $UserInput)} | ft $ADUserNormalDisplayFields -Filter {LastLogonTimeStamp -lt $time} -Properties LastLogonTimeStamp,LastLogonDate | ft "Name","Enabled","LastLogonDate" -Autosize
pause
} #>

 function NetworkAutomation-ActiveDirectory-LookupUser-GUI{
[void] [System.Reflection.Assembly]::LoadWithPartialName("System.Drawing") 
[void] [System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms")  


#Set popup box settings
$Form = New-Object System.Windows.Forms.Form    
$Form.Size = New-Object System.Drawing.Size(300,200)  
$Form.Text = "AD User Lookup"
$Form.AutoSize = $True
$Form.AutoSizeMode = "GrowOnly"
$Form.StartPosition = "CenterScreen"

#Create Listbox
$ListBox = New-Object System.Windows.Forms.ListBox
$ListBox.Location = New-Object System.Drawing.Size(5,5) 
$ListBox.Size = New-Object System.Drawing.Size(150,20) 
$ListBox.Height = 200 
$Form.Controls.Add($ListBox)

<#Add users to listbox
foreach ($user in $users) {
    $ListBox.Items.Add("$user")
} #>
#Add users to listbox
$UserProperties = $ADUserNormalDisplayFields
foreach ($userproperties in $userproperties) {
$ListBox.Items.Add("$userproperties")
}
$objTextBox = New-Object System.Windows.Forms.TextBox 
$objTextBox.Location = New-Object System.Drawing.Size(200,160) 
$objTextBox.Size = New-Object System.Drawing.Size(80,40) 
$Form.Controls.Add($objTextBox)

$Label = New-Object System.Windows.Forms.Label
$Label.Text = "Input your search request"
$Label.AutoSize = $True
$Label.TextAlign = "MiddleCenter"
$Label.Location = New-Object System.Drawing.Size(160,130)
$Form.Controls.Add($Label)

$OKButton = New-Object System.Windows.Forms.Button
$OKButton.Location = New-Object System.Drawing.Size(200,200)
$OKButton.Size = New-Object System.Drawing.Size(75,23)
$OKButton.Text = "OK"
$OKButton.Add_Click({
$UserInput=$objTextBox.Text;
$Script:UserInput = $UserInput
$SelectedFilter = $ListBox.SelectedItem.ToString()
$Script:SelectedFilter = $SelectedFilter
$Form.Close()})
$Form.Controls.Add($OKButton)
$Form.AcceptButton = $OKButton
$Form.Add_Shown({$Form.Activate()})
cls
[void] $Form.ShowDialog()

if($UserInput -eq ""){
$Script:UserInput = "*"
}
if($SelectedFilter -eq ""){

}
 }

  function NetworkAutomation-ActiveDirectory-LookupGroup-Menu{
      [string]$Title = 'Network Automation - Active Directory - Group Lookup'
      cls
      Write-Host "================ $Title ================"
      
      Write-Host "1: Press '1' to Show all Group meeting the filter."
      Write-Host "2: Press '2' to Create a New Group Filter."
      Write-Host "3: Press '3' to Show User membership."
      Write-Host "Q: Press 'Q' to go back to the main AD menu."
 }

function NetworkAutomation-ActiveDirectory-LookupGroup{
 do
{
      NetworkAutomation-ActiveDirectory-LookupGroup-Menu
      $input = Read-Host "Please make a selection"
      switch ($input)
      {
            '1' {
                 cls
                 NetworkAutomation-ActiveDirectory-GroupLookup
            }'2' {
                 cls
                 NetworkAutomation-ActiveDirectory-LookupGroup-GUI
            } '3' {
                 cls
                 NetworkAutomation-ActiveDirectory-Group-UserMembership
            } 'q' {
                 return
            }
      }
 }
 until ($input -eq 'q')
 }

 function NetworkAutomation-ActiveDirectory-GroupLookup{
$UserInput = "*$UserInput*"
Get-ADGroup -Filter {($SelectedFilter -like $UserInput)} | ft $ADGroupNormalDisplayFields
pause
 }

 function NetworkAutomation-ActiveDirectory-AllGroups{
 Get-ADGroup -Filter * | ft $ADGroupNormalDisplayFields
 pause
 }

 function NetworkAutomation-ActiveDirectory-Group-UserMembership{
 if ($Userinput -eq "*"){
 Get-ADGroup -Filter * | ft $ADGroupNormalDisplayFields
 foreach ($DNName in $Grouplist){
 $Name = $DNName.Name
 "$Name : User Membership"
 ""
 Get-ADGroupMember $DNName | ft Name
 }#End of for each
 }
 else{
 $UserInput = "*$UserInput*"
 $grouplist = Get-AdGroup -Filter {($SelectedFilter -like $UserInput)}
 foreach ($DNName in $Grouplist){
 $Name = $DNName.Name
 "$Name : User Membership"
 ""
 Get-ADGroupMember $DNName | ft Name
 }#End of for each
 }
 pause
 }


 function NetworkAutomation-ActiveDirectory-LookupGroup-GUI{
[void] [System.Reflection.Assembly]::LoadWithPartialName("System.Drawing") 
[void] [System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms")  


#Set popup box settings
$Form = New-Object System.Windows.Forms.Form    
$Form.Size = New-Object System.Drawing.Size(300,200)  
$Form.Text = "AD Group Lookup"
$Form.AutoSize = $True
$Form.AutoSizeMode = "GrowOnly"
$Form.StartPosition = "CenterScreen"

#Create Listbox
$ListBox = New-Object System.Windows.Forms.ListBox
$ListBox.Location = New-Object System.Drawing.Size(5,5) 
$ListBox.Size = New-Object System.Drawing.Size(150,20) 
$ListBox.Height = 200 
$Form.Controls.Add($ListBox)

#Add users to listbox
$GroupProperties = $ADGroupNormalDisplayFields
foreach ($groupproperties in $groupproperties) {
$ListBox.Items.Add("$groupproperties")
}
$objTextBox = New-Object System.Windows.Forms.TextBox 
$objTextBox.Location = New-Object System.Drawing.Size(200,160) 
$objTextBox.Size = New-Object System.Drawing.Size(80,40) 
$Form.Controls.Add($objTextBox)

$Label = New-Object System.Windows.Forms.Label
$Label.Text = "Input your search request"
$Label.AutoSize = $True
$Label.TextAlign = "MiddleCenter"
$Label.Location = New-Object System.Drawing.Size(160,130)
$Form.Controls.Add($Label)

$OKButton = New-Object System.Windows.Forms.Button
$OKButton.Location = New-Object System.Drawing.Size(200,200)
$OKButton.Size = New-Object System.Drawing.Size(75,23)
$OKButton.Text = "OK"
$OKButton.Add_Click({
$UserInput=$objTextBox.Text;
$Script:UserInput = $UserInput
$SelectedFilter = $ListBox.SelectedItem.ToString()
$Script:SelectedFilter = $SelectedFilter
$Form.Close()})
$Form.Controls.Add($OKButton)
$Form.AcceptButton = $OKButton
$Form.Add_Shown({$Form.Activate()})
cls
[void] $Form.ShowDialog()

if($UserInput -eq ""){
$Script:UserInput = "*"
}
if($SelectedFilter -eq ""){

}
 }


  function NetworkAutomation-ActiveDirectory-LookupComputer-Menu{
      [string]$Title = 'Network Automation - Active Directory - Computer Lookup'
      cls
      Write-Host "================ $Title ================"
      
      Write-Host "1: Press '1' to Show all Computers meeting the filter."
      Write-Host "2: Press '2' to Create a New Computer Filter."
      Write-Host "2: Press '3' to Look for Inactive Computers."
      Write-Host "Q: Press 'Q' to go back to the main AD menu."
 }

function NetworkAutomation-ActiveDirectory-LookupComputer{
 do
{
      NetworkAutomation-ActiveDirectory-LookupComputer-Menu
      $input = Read-Host "Please make a selection"
      switch ($input)
      {
            '1' {
                 cls
                 NetworkAutomation-ActiveDirectory-ComputerLookup
            }'2' {
                 cls
                 NetworkAutomation-ActiveDirectory-LookupComputer-GUI
            } '3' {
                 cls
                 NetworkAutomation-ActiveDirectory-Computers-Inactive
            } 'q' {
                 return
            }
      }
 }
 until ($input -eq 'q')
 }

 function NetworkAutomation-ActiveDirectory-ComputerLookup{
if($SelectedFilter -eq "Enabled"){
Get-ADComputer -Filter {($SelectedFilter -eq $UserInput)} | ft $ADComputerNormalDisplayFields
}
else{
$UserInput = "*$UserInput*"
if($UserInput -ne "***"){Get-ADComputer -Filter {($SelectedFilter -like $UserInput)} | ft $ADComputerNormalDisplayFields -Autosize}
if($UserInput -eq "***"){Get-ADComputer -Filter * | ft $ADComputerNormalDisplayFields  -Autosize}
}
pause
 }

 function NetworkAutomation-ActiveDirectory-AllComputers{
 Get-ADComputer -Filter * | ft $ADComputerNormalDisplayFields -Autosize
 pause
 }

function NetworkAutomation-ActiveDirectory-Computers-Inactive{
[void] [System.Reflection.Assembly]::LoadWithPartialName("System.Drawing") 
[void] [System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms")  


#Set popup box settings
$Form = New-Object System.Windows.Forms.Form    
$Form.Size = New-Object System.Drawing.Size(200,50)  
$Form.Text = "Inactive Computer Lookup"
$Form.AutoSize = $True
$Form.AutoSizeMode = "GrowOnly"
$Form.StartPosition = "CenterScreen"

$objTextBox = New-Object System.Windows.Forms.TextBox 
$objTextBox.Location = New-Object System.Drawing.Size(50,50) 
$objTextBox.Size = New-Object System.Drawing.Size(80,40) 
$Form.Controls.Add($objTextBox)

$Label = New-Object System.Windows.Forms.Label
$Label.Text = 
"Input the # of days since
last logon date"
$Label.AutoSize = $True
$Label.TextAlign = "MiddleCenter"
$Label.Location = New-Object System.Drawing.Size(30,10)
$Form.Controls.Add($Label)

$OKButton = New-Object System.Windows.Forms.Button
$OKButton.Location = New-Object System.Drawing.Size(50,75)
$OKButton.Size = New-Object System.Drawing.Size(75,23)
$OKButton.Text = "OK"
$OKButton.Add_Click({
$UserInput=$objTextBox.Text;
$Script:UserInput = $UserInput
$Form.Close()})
$Form.Controls.Add($OKButton)
$Form.AcceptButton = $OKButton
$Form.Add_Shown({$Form.Activate()})
cls
[void] $Form.ShowDialog()
 
$time = (Get-Date).Adddays(-($UserInput))
Write-Host "Looking for computers with a last logon date older then $UserInput days:"
Write-Host ""
Get-ADComputer -Filter {LastLogonTimeStamp -lt $time} -Properties LastLogonTimeStamp,LastLogonDate | ft "Name","Enabled","LastLogonDate" -Autosize
pause
}

 function NetworkAutomation-ActiveDirectory-LookupComputer-GUI{
[void] [System.Reflection.Assembly]::LoadWithPartialName("System.Drawing") 
[void] [System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms")  


#Set popup box settings
$Form = New-Object System.Windows.Forms.Form    
$Form.Size = New-Object System.Drawing.Size(300,200)  
$Form.Text = "AD Computer Lookup"
$Form.AutoSize = $True
$Form.AutoSizeMode = "GrowOnly"
$Form.StartPosition = "CenterScreen"

#Create Listbox
$ListBox = New-Object System.Windows.Forms.ListBox
$ListBox.Location = New-Object System.Drawing.Size(5,5) 
$ListBox.Size = New-Object System.Drawing.Size(150,20) 
$ListBox.Height = 200 
$Form.Controls.Add($ListBox)

#Add users to listbox
$GroupProperties = $ADComputerNormalDisplayFields
foreach ($groupproperties in $groupproperties) {
$ListBox.Items.Add("$groupproperties")
}
$objTextBox = New-Object System.Windows.Forms.TextBox 
$objTextBox.Location = New-Object System.Drawing.Size(200,160) 
$objTextBox.Size = New-Object System.Drawing.Size(80,40) 
$Form.Controls.Add($objTextBox)

$Label = New-Object System.Windows.Forms.Label
$Label.Text = "Input your search request"
$Label.AutoSize = $True
$Label.TextAlign = "MiddleCenter"
$Label.Location = New-Object System.Drawing.Size(160,130)
$Form.Controls.Add($Label)

$OKButton = New-Object System.Windows.Forms.Button
$OKButton.Location = New-Object System.Drawing.Size(200,200)
$OKButton.Size = New-Object System.Drawing.Size(75,23)
$OKButton.Text = "OK"
$OKButton.Add_Click({
$UserInput=$objTextBox.Text;
$Script:UserInput = $UserInput
$SelectedFilter = $ListBox.SelectedItem.ToString()
$Script:SelectedFilter = $SelectedFilter
$Form.Close()})
$Form.Controls.Add($OKButton)
$Form.AcceptButton = $OKButton
$Form.Add_Shown({$Form.Activate()})
cls
[void] $Form.ShowDialog()

if($UserInput -eq ""){
$Script:UserInput = "*"

}
if($SelectedFilter -eq ""){

}
 }


 function Automated-Email {
"Welcome, $givenName!

Welcome to AcmeCorp, from the IT Team.
If you're reading this email, it means you've successfully logged on and have access to your mailbox.
First, a bit about you...

We have you listed as being based in our Amsterdam office, with extension number $ext, which has a direct dial of $ddi. You can access your voicemail by calling $nlvoicemailext from your desk phone, or $nlvoicemailddi from anywhere else. You'll need to set a PIN in order to do this.
Your email address is set to $emailaddr, and it will appear as $displayName in most modern email applications. If you'd like to change this, let us know.
We have your line manager recorded as $lineManager, in the $department department. Again, if this is incorrect, please do let us know.

Now, about us.
For your first month here, you can contact us using the newhirehelp@example.com address, which will get you some additional attention to help you get up and running quickly. After this, you can use the it.servicedesk@example.com address to raise issues.
You can also log tickets at https://it.example.com/. You'll need to login with the same username and password that you use to login to your computer.
Alternatively, you can call $helpdeskext from your desk phone, or $nlhelpdeskddi from anywhere else. If you need to report an urgent issue, such as an outage affecting an entire team or site, please call if possible.
If you are unable to login to your account, you can either call the ServiceDesk, or use the 'forgot my password' link at https://it.example.com/.

We also have lots of Getting Started Guides, which will explain how to do useful things like setting a voicemail PIN, connecting remotely and requesting help. These are available at https://$countrycode.example.com/IT/GSG/.

Finally, as an ISO:27001 accredited organisation, AcmeCorp takes information security very seriously. IT staff will NEVER ask you for any password or PIN, and this should never be given out. If this is ever requested of you, please notify infosec@example.com. This address can also be used for reporting any information security concerns. As a leader in our field, we are often targeted by other organisations who wish to gain insider information, and we must all be vigilant to keep our data secure. Occasionally, exercises are carried out to test both our systems and our staff, to ensure that information is kept secure. Additionally, monitoring systems are in place to detect misuse of the company infrastructure. This will mostly have been covered in your induction session, but in any case, you can find the acceptable use and privacy policies at https://$countrycode.example.com/HR/policies/IT/.

Once again, welcome to AcmeCorp!

Best regards,

$regionalITMgr"
}

 SSWANK-General-PSVersionCheck 2
 $credentials = Get-Credential -UserName "$(whoami)" -Message "Enter your admin account details"

 NetworkAutomation-HomePage