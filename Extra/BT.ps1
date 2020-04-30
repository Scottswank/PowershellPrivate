$RunForever = "1"
$SqlServer = "CLSTRSQLBISP01"
$SqlCatalog = "BTProd"
#*************** Query Below*******************************************************************************
# You can organize the querys any way you want. Any Valid Tsql statement should work...
$SqlQuery = "select count(QueueID) from ReportServerQueue with(nolock) where reportid = 279 and convert(Date, datetimesubmitted) = '2019-02-27' and DateTimeProcessed is not null"
#*************** Query Above*******************************************************************************

function SSWANK-SQL-BTReportStatus {

$SqlConnection = New-Object System.Data.SqlClient.SqlConnection
$SqlConnection.ConnectionString = "Server = $SqlServer; Database = $SqlCatalog; Integrated Security = True"
$SqlCmd = New-Object System.Data.SqlClient.SqlCommand
$SqlCmd.CommandText = $SqlQuery
$SqlCmd.Connection = $SqlConnection
$SqlAdapter = New-Object System.Data.SqlClient.SqlDataAdapter
$SqlAdapter.SelectCommand = $SqlCmd
$DataSet = New-Object System.Data.DataSet
$SqlAdapter.Fill($DataSet) > $null
$SqlConnection.Close()
$BTCount1 = $DataSet.Tables[0]

Start-Sleep -Seconds 30

$SqlConnection2 = New-Object System.Data.SqlClient.SqlConnection
$SqlConnection2.ConnectionString = "Server = $SqlServer; Database = $SqlCatalog; Integrated Security = True"
$SqlCmd2 = New-Object System.Data.SqlClient.SqlCommand
$SqlCmd2.CommandText = $SqlQuery
$SqlCmd2.Connection = $SqlConnection2
$SqlAdapter2 = New-Object System.Data.SqlClient.SqlDataAdapter
$SqlAdapter2.SelectCommand = $SqlCmd2
$DataSet2 = New-Object System.Data.DataSet
$SqlAdapter2.Fill($DataSet2) > $null
$SqlConnection2.Close()
$BTCount2 = $DataSet2.Tables[0]

$BTNum1 = ($BTCount1).Column1
$BTNum2 = ($BTCount2).Column1

$Time = Get-Date
$Content = "$Time First File Count: $BTNum1   Last File Count: $BTNum2"
Add-Content D:\Temp\Log.txt $Content

if($BTNum1 -eq $BTNum2){
$Time = Get-Date
$Content = "$Time First File Count: $BTNum1   Last File Count: $BTNum2"
Add-Content D:\Temp\KillLog.txt $Content
SSWANK-BTReportServerKill

}
}

function SSWANK-BTReportServerKill {

try{Get-Process "Report Server*" | Stop-Process -Force
Start-Sleep -Seconds 1}

catch [Microsoft.PowerShell.Commands.ProcessCommandException]{
Write-Host "Process was not found"
}

$arrService = Get-Service "BistrackReport*" #Get the status of the service
if ($arrService.Status -eq "Stopped"){
Get-Service "BistrackReport*" | Start-Service
Start-Sleep -Seconds 15
$arrService = Get-Service "BistrackReport*" #Get the status of the service
} # End of If service is stopped

if ($arrService.Status -ne "Running"){
Get-Process "Report Server*" | Stop-Process -Force
Start-Sleep -Seconds 3
Get-Service "BistrackReport*" | Start-Service
Start-Sleep -Seconds 15
} # End of if still not running

} # End of Fuction to Kill BTReportServer


Do{
SSWANK-SQL-BTReportStatus}
while($RunForever -eq "1")