
$CSVPath = "C:\ExportUsers.csv"

$ADUserNormalDisplayFields = "GivenName","SurName","Enabled","Description","Name","EmailAddress"
$List = Get-ADUser -Filter * -Properties * | Select-Object $ADUserNormalDisplayFields

$List = $List | Select-Object *,"Password" 
$List
$List | Export-Csv -Path $CSVPath -NoTypeInformation