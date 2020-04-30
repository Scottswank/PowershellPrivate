    
#Editable Section
#local user account you want to change PW on & PW
$user = "Administrator"
$WRKSTNpassword = "Trn567up"
$ServerPassword = "Trn567up"


#Values needed to determine if user is enabled or disabled
$EnableUser = 512 
$DisableUser = 2 

#Function to determine if PC is workstation or server
 $ProductTypeArray = Get-WmiObject WIN32_OperatingSystem -ComputerName $env:COMPUTERNAME| Select-Object ProductType
 $ProductType = ($ProductTypeArray).ProductType
 if($ProductType -ne 3){
 "Your system is not a server. Applying workstation admin password"

    try {
        $user = [adsi]"WinNT://$env:COMPUTERNAME/$user,user"
        $user.SetPassword($WRKSTNPassword)
        $User.userflags = $EnableUser
        $user.SetInfo()
        }
    catch {
        Write-Warning -Message ('Unable to update {0}: {1}' -f $env:COMPUTERNAME,$_.exception.message)
        }

}
 if($ProductType -eq 3){
 "Your system is a server. Applying server admin password"

    try {
        $user = [adsi]"WinNT://$env:COMPUTERNAME/$user,user"
        $user.SetPassword($ServerPassword)
        $User.userflags = $EnableUser
        $user.SetInfo()
        }
    catch {
        Write-Warning -Message ('Unable to update {0}: {1}' -f $env:COMPUTERNAME,$_.exception.message)
        }

}