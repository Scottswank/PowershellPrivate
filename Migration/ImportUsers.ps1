$CSVPath = "C:\ExportUsers.csv"
$ErrorPath = "C:\ExportUsersError.txt"


function GetRandomPassword ([int] $length=10) {
 if ($length -lt 4) {return $null}

# Define list of numbers, this will be CharType 1
 $numbers=$null
 For ($a=48;$a –le 57;$a++) {$numbers+=,[char][byte]$a }

# Define list of uppercase letters, this will be CharType 2
 $uppercase=$null
 For ($a=65;$a –le 90;$a++) {$uppercase+=,[char][byte]$a }

# Define list of lowercase letters, this will be CharType 3
 $lowercase=$null
 For ($a=97;$a –le 122;$a++) {$lowercase+=,[char][byte]$a }

# Define list of special characters, this will be CharType 4
 $specialchars=$null
 For ($a=33;$a –le 47;$a++) {$specialchars+=,[char][byte]$a }
 For ($a=58;$a –le 64;$a++) {$specialchars+=,[char][byte]$a }
 For ($a=123;$a –le 126;$a++) {$specialchars+=,[char][byte]$a }

# Need to ensure that result contains at least one of each CharType
 # Initialize buffer for each character in the password
 $Buffer = @()
 For ($a=1;$a –le $length;$a++) {$Buffer+=0 }

# Randomly chose one character to be number
 while ($true) {
 $CharNum = (Get-Random -minimum 0 -maximum $length)
 if ($Buffer[$CharNum] -eq 0) {$Buffer[$CharNum] = 1; break}
 }

# Randomly chose one character to be uppercase
 while ($true) {
 $CharNum = (Get-Random -minimum 0 -maximum $length)
 if ($Buffer[$CharNum] -eq 0) {$Buffer[$CharNum] = 2; break}
 }

# Randomly chose one character to be lowercase
 while ($true) {
 $CharNum = (Get-Random -minimum 0 -maximum $length)
 if ($Buffer[$CharNum] -eq 0) {$Buffer[$CharNum] = 3; break}
 }

# Randomly chose one character to be special
 while ($true) {
 $CharNum = (Get-Random -minimum 0 -maximum $length)
 if ($Buffer[$CharNum] -eq 0) {$Buffer[$CharNum] = 4; break}
 }

# Cycle through buffer to get a random character from the available types
 # if the buffer already contains the CharType then use that type
 $Password = ""
 foreach ($CharType in $Buffer) {
 if ($CharType -eq 0) {$CharType = ((1,2,3,4)|Get-Random)}
 switch ($CharType) {
 1 {$Password+=($numbers | GET-RANDOM)}
 2 {$Password+=($uppercase | GET-RANDOM)}
 3 {$Password+=($lowercase | GET-RANDOM)}
 4 {$Password+=($specialchars | GET-RANDOM)}
 }
 }
 return $Password
 }




#Loop to Add each User in the list
Function AddUserLoop {
foreach ($User in $UserList){
    $Displayname = $User.GivenName + " " + $User.SurName           
    $UserFirstname = $User.GivenName            
    $UserLastname = $User.SurName                                
    $Description = $User.Description            
    $Password = $User.Password
    $Enabled = $User.Enabled
    $Username = $UserFirstname.substring(0,1)+$UserLastname
    $DN=(Get-AdDomain).DistinguishedName
    $Netbios=(Get-AdDomain).NetBIOSName
    $OU = "OU=USERS,OU=$Netbios,$DN"
    if($Enabled -Match "True"){
        $Enabled = $true}
    elseif($Enabled -match "False"){
        $Enabled = $false}
    else{"Enabled is neither True or False for $User, creating enabled account"
        $Enabled = $true
        $Time = Get-Date -Format G
        Add-Content $ErrorPath "$env:computername $Time Enabled is neither True or False for $User, creating enabled account"}
    if($Password -Match ""){
    $Password = GetRandomPassword -length 8
    $User.Password = $Password
    $User | Export-Csv -Path $CSVPath -NoTypeInformation
    }
    "Creating Account for $Displayname"       
    New-ADUser -Name "$Username" -DisplayName "$Displayname" -GivenName "$UserFirstname" -Surname "$UserLastname" -Description "$Description" -Path "$OU" -Enabled $true -AccountPassword (ConvertTo-SecureString $Password -AsPlainText -Force) -WhatIf
}
}
$UserList = Import-Csv -Path $CSVPath
AddUserLoop
