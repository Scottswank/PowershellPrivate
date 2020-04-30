$PasswordFile = "\\s99mgmntp01\PDQDeployPackages\Scripts\Dependancy\Dependancy.key"
$AESKeyFile = "\\s99mgmntp01\PDQDeployPackages\Scripts\Dependancy\AES.key"
$usernameFilePath = "\\s99mgmntp01\PDQDeployPackages\Scripts\Dependancy\Name.key"
$AESKeyFilePath2 = "\\s99mgmntp01\PDQDeployPackages\Scripts\Dependancy\AES2.key"


 function SSWANK-General-Read-UNPWKeys{
$AESKey = Get-Content $AESKeyFile
$PwdTxt = Get-Content $PasswordFile 
$Usrtxt = Get-Content $usernameFilePath
$key = Get-Content $AESKeyFilePath2
$securePwd= $pwdtxt | ConvertTo-SecureString -key $AESkey
$Username =  SSWANK-General-Decrypt-String "$Key" "$Usrtxt"
$script:credObject = New-Object System.Management.Automation.PSCredential -ArgumentList $Username, $securePwd 
}

SSWANK-General-Read-UNPWKeys
Reset-ComputerMachinePassword -Credential $credObject -Server "starlumber.com"