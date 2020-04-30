push-location
import-module sqlps
cd SQLServer:\SQL\S99SQLBIZP01\Default\Databases
$DBTable = Get-item .\DBAAdmin
$DBStatus = $DBTable.Status
if($DBStatus -ne "Normal"){
"Database Status is Not Normal"
Start-Sleep -Seconds 180
}
pop-location
Remove-Module sqlps
