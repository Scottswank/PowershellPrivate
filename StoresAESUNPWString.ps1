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
$username = "starlumber\MDT"
$password = ""
$PasswordFilePath2 = "\\s99mgmntp01\PDQDeployPackages\Scripts\Dependancy\key5.Key"
$PWAESKeyFilePath2 = "\\s99mgmntp01\PDQDeployPackages\Scripts\Dependancy\key6.key"
$usernameFilePath2 = "\\s99mgmntp01\PDQDeployPackages\Scripts\Dependancy\key7.Key"
$UNAESKeyFilePath2 = "\\s99mgmntp01\PDQDeployPackages\Scripts\Dependancy\key8.key"

#
# Function to create an encrypted password and AES Key on a network share
#

# Requires the Below global Variables
#
# $username = "%Domain%\%username"
# $password = "%password"
# $credentialFilePath = "\\%Server%\%Share%\%Folder%\Dependancy.key"
# $AESKeyFilePath = "\\%Server%\%Share%\%Folder%\AES.key"
# $usernameFilePath = "\\%Server%\%Share%\%Folder%\Name.key"
# $AESKeyFilePath2 = "\\%Server%\%Share%\%Folder%\AES2.key"
#
# Requires SSWANK-General-Create-AuthKey
# Requires SSWANK-General-Create-AesManagedObject
# Requires SSWANK-General-Create-AesKey
# Requires SSWANK-General-Encrypt-String
#
function SSWANK-General-Create-AuthKey{
 $secureStringPwd = $password | ConvertTo-SecureString -AsPlainText -Force    
 # Generate a random AES Encryption Key for the Password. 
 $AESKey = New-Object Byte[] 16
 # Generate a random AES Encryption Key for the UserName. 
 $Key = SSWANK-General-Create-AesKey
 $IV = get-random
[Security.Cryptography.RNGCryptoServiceProvider]::Create().GetBytes($AESKey) 
 # Store the AESKey into a file. This file should be protected!  (e.g. ACL on the file to allow only select people to read)

 Set-Content $AESKeyFilePath $AESKey   # Any existing AES Key file will be overwritten		 
 $password = $secureStringPwd | ConvertFrom-SecureString -Key $AESKey 
 set-Content $credentialFilePath $password
 $encryptedString = SSWANK-General-Encrypt-String "$Key" "$username"
 Set-Content $usernameFilePath $encryptedString
 Set-Content $AESKeyFilePath2 $Key
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

function SSWANK-General-Create-AesKey() {
    $aesManaged = SSWANK-General-Create-AesManagedObject
    $aesManaged.GenerateKey()
    $Key = [System.Convert]::ToBase64String($aesManaged.Key)
    $key
}

function SSWANK-General-Encrypt-String($Key, $unencryptedString) {
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($unencryptedString)
    $aesManaged = SSWANK-General-Create-AesManagedObject $key
    $encryptor = $aesManaged.CreateEncryptor()
    $encryptedData = $encryptor.TransformFinalBlock($bytes, 0, $bytes.Length);
    [byte[]] $fullData = $aesManaged.IV + $encryptedData
    $aesManaged.Dispose()
    [System.Convert]::ToBase64String($fullData)
}


 $IV = get-random
 $Key = SSWANK-General-Create-AesKey
 $encryptedPWString = SSWANK-General-Encrypt-String "$Key" "$password"
 Set-Content $PasswordFilePath2 $encryptedPWString
 Set-Content $PWAESKeyFilePath2 $Key

 $IV = get-random
 $Key = SSWANK-General-Create-AesKey
 $encryptedUNString = SSWANK-General-Encrypt-String "$Key" "$username"
 Set-Content $usernameFilePath2 $encryptedUNString
 Set-Content $UNAESKeyFilePath2 $Key
