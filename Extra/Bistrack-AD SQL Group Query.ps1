$SqlServer = "CLSTRSQLBISP01"
$SqlCatalog = "BTTRN"
#*************** Query Below*******************************************************************************
# You can organize the querys any way you want. Any Valid Tsql statement should work...
$SqlQuery = "SELECT C.[ComputerID],[Deleted],[Name],[Description],[ComputerClientMappingID],M.[ComputerID] as compid,[ClientName] FROM [BTTRN].[dbo].[Computer] C LEFT OUTER JOIN [BTTRN].[dbo].[ComputerClientMapping] M ON C.[ComputerID] = M.ComputerID"
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
$DN=(Get-AdDomain).DistinguishedName
$Netbios=(Get-AdDomain).NetBIOSName
$OU = "OU=BisTrackGroups,$DN"

foreach ($ClientRow in $ClientMapTable){
if ($ClientRow.ClientName -notlike ""){
if ($ClientRow.Deleted -eq 0){
$NoComputerFound="0" #Set up Qualifier
try{
$ComputerGroups = Get-ADPrincipalGroupMembership (Get-ADComputer ($ClientRow).ClientName).DistinguishedName | Select-Object Name}
catch [Microsoft.ActiveDirectory.Management.ADIdentityNotFoundException]
{
$CompName=($ClientRow).ClientName
"Computer $CompName Not Found"
$NoComputerFound= "1" #Trigger Qualifier
}
if($NoComputerFound -eq "0"){
    $PrintGroups = $ClientRow.Name
    If ($ComputerGroups -match $PrintGroups) {
    $CompName=($ClientRow).ClientName
    "Computer $CompName is already a member of the group $PrintGroups"}
    else{
        try{Get-AdGroup $ClientRow.Name}
        catch{
        New-ADGroup $ClientRow.Name -GroupScope Global -Path $OU
         } # End of Catch
        finally{
        $CompName = $ClientRow.ClientName +"$"
        Add-AdGroupMember $ClientRow.Name -Members $CompName}
        } # End of Else Statement
} # End of ComputerNotFound Qualifier
}# End of If Deleted Not 0 (0 is Active, 1 Is Deleted)
} #End of ClientName not blank
} #End of For each Clientname in ClientMapTable
