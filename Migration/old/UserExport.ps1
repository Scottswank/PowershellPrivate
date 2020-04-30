Get-ADUser -Filter * | Select-Object Name,UserPrincipalName,GivenName,SurName,SID, | Export-Csv -Path C:\list.csv -NoTypeInformation
