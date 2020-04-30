
$TargetOU = "OU=Staging,OU=Default Computer OU,OU=Company,dc=starlumber,dc=com"
$AccountName ="MDT"
$Password = 'P@SSw0rd'

# Total Guide https://technet.microsoft.com/en-us/itpro/windows/deploy/deploy-a-windows-10-image-using-mdt
# Function from https://gallery.technet.microsoft.com/Configure-permissions-in-2326651a 

Function Set-OUPermission{
Param
(
[parameter(mandatory=$true,HelpMessage="Please, provide the account name.")][ValidateNotNullOrEmpty()]$Account,
[parameter(mandatory=$true,HelpMessage="Please, provide the target OU.")][ValidateNotNullOrEmpty()]$TargetOU
)

# Start logging to screen
Write-host (get-date -Format u)" - Starting"

# This i what we typed in
Write-host "Account to search for is" $Account
Write-Host "OU to search for is" $TargetOU

if ($TargetOU -like '*dc=*')
{ 
    Write-Warning "Oupps, only specify the OU path. We get the domain for you..."
    Break
} 

$CurrentDomain = Get-ADDomain

$OrganizationalUnitDN = $TargetOU+","+$CurrentDomain
$SearchAccount = Get-ADUser $Account

$SAM = $SearchAccount.SamAccountName
$UserAccount = $CurrentDomain.NetBIOSName+"\"+$SAM

Write-Host "Account is = $UserAccount"
Write-host "OU is =" $OrganizationalUnitDN

dsacls.exe $OrganizationalUnitDN /G $UserAccount":CCDC;Computer" /I:T | Out-Null
dsacls.exe $OrganizationalUnitDN /G $UserAccount":LC;;Computer" /I:S | Out-Null
dsacls.exe $OrganizationalUnitDN /G $UserAccount":RC;;Computer" /I:S | Out-Null
dsacls.exe $OrganizationalUnitDN /G $UserAccount":WD;;Computer" /I:S  | Out-Null
dsacls.exe $OrganizationalUnitDN /G $UserAccount":WP;;Computer" /I:S  | Out-Null
dsacls.exe $OrganizationalUnitDN /G $UserAccount":RP;;Computer" /I:S | Out-Null
dsacls.exe $OrganizationalUnitDN /G $UserAccount":CA;Reset Password;Computer" /I:S | Out-Null
dsacls.exe $OrganizationalUnitDN /G $UserAccount":CA;Change Password;Computer" /I:S | Out-Null
dsacls.exe $OrganizationalUnitDN /G $UserAccount":WS;Validated write to service principal name;Computer" /I:S | Out-Null
dsacls.exe $OrganizationalUnitDN /G $UserAccount":WS;Validated write to DNS host name;Computer" /I:S | Out-Null
dsacls.exe $OrganizationalUnitDN

}

Function CreateADUser{
Import-Module ActiveDirectory
$secureStringPwd = $password | ConvertTo-SecureString -AsPlainText -Force 
New-ADUser -Name MDT -AccountPassword $secureStringPwd -CannotChangePassword $True -ChangePasswordAtLogon $False -Description "Used for Imaging PC using WDS / MDT" -Enabled $True
}

Set-OUPermission "$AccountName" "$TargetOU"