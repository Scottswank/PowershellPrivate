
function LogoffMySelf{
param($Server)
$Userlist2 = qwinsta /server:$Server
$Userlist = convertto-csv -InputObject $Userlist2 | Format-Table -AutoSize
foreach($Sessioninfo in $Userlist){
$Sessionuser = $Sessioninfo.Username
if($Sessionuser -eq $env:USERNAME){
$LineSessionID = $Sessioninfo.ID
logoff $LineSessionID /server:$server
}#End of if LineUser
}#End of for each line
}#End of Function

LogoffMySelf S99RDRFMSP01
LogoffMySelf S99RDRFMSP02
LogoffMySelf S99RDRFMSP03