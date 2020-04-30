# Last Edited By:Scott Swank
# Last Edited: 1/3/2017
#
# Written By: Scott Swank
# Written: 1/3/2017
# Version 1.0
#
# Tested OS versions: Server 2012 R2; Server 2012; 
#
#
#
#

$PasswordFile = "\\s99mgmntp01\PDQDeployPackages\Scripts\Dependancy\Dependancy.key"
$AESKeyFile = "\\s99mgmntp01\PDQDeployPackages\Scripts\Dependancy\AES.key"
$usernameFilePath = "\\s99mgmntp01\PDQDeployPackages\Scripts\Dependancy\Name.key"
$AESKeyFilePath2 = "\\s99mgmntp01\PDQDeployPackages\Scripts\Dependancy\AES2.key"

# Function to Read an encrypted password and AES Key on a network share
#
# Requires the Below global Variable
# $PasswordFile = "\\%Server%\%Share%\%Folder%\Dependancy.key"
# $AESKeyFile = "\\%Server%\%Share%\%Folder%\AES.key"
# $usernameFilePath = "\\%Server%\%Share%\%Folder%\Name.key"
# $AESKeyFilePath2 = "\\%Server%\%Share%\%Folder%\AES2.key"
#
#
# Requires SSWANK-General-Decrypt-String
# Requires SSWANK-General-Create-AesManagedObject
#
# Creates $credObject which are your PowerShell Credentials
#
 function SSWANK-General-Read-UNPWKeys{
$AESKey = Get-Content $AESKeyFile
$PwdTxt = Get-Content $PasswordFile 
$Usrtxt = Get-Content $usernameFilePath
$key = Get-Content $AESKeyFilePath2
$securePwd= $pwdtxt | ConvertTo-SecureString -key $AESkey
$Username =  SSWANK-General-Decrypt-String "$Key" "$Usrtxt"
$script:credObject = New-Object System.Management.Automation.PSCredential -ArgumentList $Username, $securePwd 
}


 function SSWANK-General-Decrypt-String($Key, $encryptedStringWithIV) {
    $bytes = [System.Convert]::FromBase64String($encryptedStringWithIV)
    $IV = $bytes[0..15]
    $aesManaged = SSWANK-General-Create-AesManagedObject $key $IV
    $decryptor = $aesManaged.CreateDecryptor();
    $unencryptedData = $decryptor.TransformFinalBlock($bytes, 16, $bytes.Length - 16);
    $aesManaged.Dispose()
    [System.Text.Encoding]::UTF8.GetString($unencryptedData).Trim([char]0)
}

 function SSWANK-General-Create-AesManagedObject($key, $IV) {
    $aesManaged = New-Object "System.Security.Cryptography.AesManaged"
    $aesManaged.Mode = [System.Security.Cryptography.CipherMode]::CBC
    $aesManaged.Padding = [System.Security.Cryptography.PaddingMode]::Zeros
    $aesManaged.BlockSize = 128
    $aesManaged.KeySize = 256
    if ($IV) {
        if ($IV.getType().Name -eq "String") {
            $aesManaged.IV = [System.Convert]::FromBase64String($IV)
        }
        else {
            $aesManaged.IV = $IV
        }
    }
    if ($key) {
        if ($key.getType().Name -eq "String") {
            $aesManaged.Key = [System.Convert]::FromBase64String($key)
        }
        else {
            $aesManaged.Key = $key
        }
    }
    $aesManaged
}




SSWANK-General-Read-UNPWKeys
Start-Process -Credential $credObject "c:\program files (x86)\Admin Arsenal\PDQ Deploy\pdqdeploy.exe" -ArgumentList 'Deploy -Package "Adobe Reader DC - Install" -Targets S99MGMNTP01'
