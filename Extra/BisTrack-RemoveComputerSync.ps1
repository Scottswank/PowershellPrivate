$DN=(Get-AdDomain).DistinguishedName
$OU = "OU=BisTrackGroups,$DN"
$OUGroups = Get-ADGroup -SearchBase $OU -Filter {GroupCategory -eq "Security"}


$SqlServer = "CLSTRSQLBISP01"
$SqlCatalog = "BTPROD"
#*************** Query Below*******************************************************************************
# You can organize the querys any way you want. Any Valid Tsql statement should work...
$SqlQuery = "SELECT C.[ComputerID],[Deleted],[Name],[ClientName] FROM [BTPROD].[dbo].[Computer] C LEFT OUTER JOIN [BTPROD].[dbo].[ComputerClientMapping] M ON C.[ComputerID] = M.ComputerID"
#*************** Query Above*******************************************************************************
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
$ClientMapTable = $DataSet.Tables[0]


Function Bistrack-RemoveADUser {
param([parameter(Mandatory=$true)][string]$ComputerName,[parameter(Mandatory=$true)][string]$GroupName)
$NoComputerFound= "0"

try{
$ComputerGroups = Get-ADPrincipalGroupMembership (Get-ADComputer $ComputerName) | Select-Object Name}
catch [Microsoft.ActiveDirectory.Management.ADIdentityNotFoundException]
{
"Computer $ComputerName Not Found"
$NoComputerFound= "1" #Trigger Qualifier
}
if($NoComputerFound -eq "0"){
    try{$trash = Get-AdGroup $GroupName}
    catch{"AD Group $GroupName not found in AD"
    $NoComputerFound= "1" #Trigger Qualifier
    }
    if($NoComputerFound -eq "0"){
        try{ Remove-ADGroupMember -Identity $GroupName -Member $ComputerName -Confirm:$false
}# End of Try
Catch{
    "Was unsuccessful in removing $ComputerName from group $GroupName"}
} # End of If Group Wasn't Found
} # End of If Computer Wasn't Found

} # End of Function





foreach ($OUGroupRow in $OUGroups){
$GroupName = "($OUGroupRow).Name"
$GroupMappings = $ClientMapTable | where {$_.Name -eq $GroupName} 
try{
$GroupMembers = Get-ADGroupMember $OUGroupRow | Select-Object Name}
catch{
    "Group Lookup Failed for $OUGroupRow"}
foreach ($GroupRowMembers in $GroupMembers){
try{$FilterQuery = $GroupMappings | where {$_.ClientName -eq $GroupRowMembers.Name} }
catch{ "SQL Group Lookup Failed"}
$ComputerFound = "0" # Setup Qualifier
foreach ($_ in $FilterQuery){
if($_.ClientName -like $GroupRowMembers.Name){
$ComputerFound = "1" } 
} #End of Foreach FilterQuery
if ($ComputerFound -ne "1"){
$NotFoundPC = $GroupRowMembers.Name
"Computer $NotFoundPC was never found in SQL Group $GroupName!"
Bistrack-RemoveADUser -ComputerName $NotFoundPC -GroupName $GroupName
}
} # End of For Each Group Row Members

} # End of Foreach OUGroup



<#
foreach ($ClientRow in $ClientMapTable){
if ($ClientRow.ClientName -notlike ""){
if ($ClientRow.Deleted -eq 0){ 

} # End of If not deleted
}# End of if ClientName
} # End of Foreach ClientMapTable#>