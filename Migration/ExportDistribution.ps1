$CSVPath = "C:\ExportDistribution.csv"

$dist = foreach ($group in (Get-DistributionGroup -Filter {name -like "*"})) {Get-DistributionGroupMember $group | Select @{Label="Group";Expression={$Group.Name}},@{Label="User";Expression={$_.Name}},SamAccountName,@{“name”=”Primarysmtpaddress”;”expression”={$Group.Primarysmtpaddress -join “;”}}}
$dist | Sort Group,User | Export-Csv -Path $CSVPath -NoTypeInformation