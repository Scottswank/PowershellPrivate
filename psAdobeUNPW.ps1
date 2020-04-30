
$PasswordFile = "\\s99mgmntp01\PDQDeployPackages\Scripts\Dependancy\Dependancy.key"
$AESKeyFile = "\\s99mgmntp01\PDQDeployPackages\Scripts\Dependancy\AES.key"
$usernameFilePath = "\\s99mgmntp01\PDQDeployPackages\Scripts\Dependancy\Name.key"
$AESKeyFilePath2 = "\\s99mgmntp01\PDQDeployPackages\Scripts\Dependancy\AES2.key"

$PasswordFilePath2 = "\\s99mgmntp01\PDQDeployPackages\Scripts\Dependancy\key5.Key"
$PWAESKeyFilePath2 = "\\s99mgmntp01\PDQDeployPackages\Scripts\Dependancy\key6.key"
$usernameFilePath2 = "\\s99mgmntp01\PDQDeployPackages\Scripts\Dependancy\key7.Key"
$UNAESKeyFilePath2 = "\\s99mgmntp01\PDQDeployPackages\Scripts\Dependancy\key8.key"

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
$PWdKey = Get-Content $PWAESKeyFilePath2
$PwdTxt = Get-Content $PasswordFilePath2
$Usrtxt = Get-Content $usernameFilePath2
$Usrkey = Get-Content $UNAESKeyFilePath2
$Username2 =  SSWANK-General-Decrypt-String "$Usrkey" "$Usrtxt"
$Password2 =  SSWANK-General-Decrypt-String "$PWdKey" "$PwdTxt"

$arg={-h -accepteula "c:\program files (x86)\Admin Arsenal\PDQ Deploy\pdqdeploy.exe" Deploy -Package "Adobe Reader DC - Install"}
start-Process -FilePath "C:\PsExec.exe"  -Argumentlist "\\S99MGMNTP01 -u $Username2 -password $Password2 $arg -Targets $env:COMPUTERNAME" -verb Runas #-Credential $credObject



