$CSVPath = "C:\ExportUserEmail.csv"
$ErrorPath = "C:\ExportUsersEmailError.txt"

$UserEmailList = Import-Csv -Path $CSVPath

foreach ($UserEmail in $UserEmailList){
   $User = $UserEmail.Alias
   $Email =  $UserEmail.EmailAddress
   $ExistingUserMailbox = Get-Recipient -Identity $User -ErrorAction 'SilentlyContinue'
   $MailboxError = 0
   #If user Mailbox doesn't exist
   if(-not $ExistingUserMailbox)
   {
      "$User Does not currently have a mailbox"
      "Creating a mailbox now"
        try{ Enable-Mailbox $User
        } # End of Try
        Catch{
        "Unable to create a mailbox for $user"
        $Time = Get-Date -Format G
        Add-Content $ErrorPath "$env:computername $Time Unable to create a mailbox for $user"
        $MailboxError = 1
        }#End of Catch
   }
   #If the Mailbox exists
   if($MailboxError -eq 0){ #Start of if Mailbox doesn't have an error
   $EmailExisting = Get-Recipient $Email
   #If E-mail Address doesn't exist
   if(-not  $EmailExisting)
   {
      "Setting $Email to $User"
      set-mailbox -Identity $user -EmailAddresses @{add="$Email"}
   }
   else{
    "There is already a recepient for $Email : $EmailExisting"
    $Time = Get-Date -Format G
    Add-Content $ErrorPath "$env:computername $Time There is already a recepient for $Email : $EmailExisting"
    }#End of else e-mail exists
   }#End of if Mailbox doesn't have an error
}