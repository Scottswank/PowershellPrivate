$CSVPath = "C:\ExportDistribution.csv"
$ErrorPath = "C:\ExportDistributionError.txt"
$DistributionList = Import-Csv -Path $CSVPath


foreach($DistGroup in $DistributionList){

# Create the Group if Group is not already present
   $GroupName = $DistGroup.DisplayName
   $existingGroup = Get-DistributionGroup -Id $GroupName -ErrorAction 'SilentlyContinue'

   if(-not $existingGroup)
   {
      New-DistributionGroup -Name $newGroupName
   }
$GroupADUser = $DistGroup.SamAccountName
try{
Add-DistributionGroupMember -Identity $GroupName -Member $GroupADUser
} # End of Try
catch{
"Unable to add $GroupADUser to Distribution Group: $GroupName"
$Time = Get-Date -Format G
Add-Content $ErrorPath "$env:computername $Time Unable to add $GroupADUser to Distribution Group: $GroupName"
} #End of Catch
}