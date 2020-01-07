#This script searches the local ForeignSecurityPrincipals container and looks for items that can not be resolved to the selected target trusted domain.
#This script is ONLY capable of searching one external trusted domain per run. This means if you have multiple trusts you need to run this script multiple times to find all the stale objects
#for deletion.
#Only delete them when you are sure you no longer need them.
#This is a good 2nd to last step before removing the trust permently
#USE WITH CARE

#Change this value to the trusted domain you wish to search
$OtherDomainName = "contoso.com"

$OtherDomainSID = (Get-ADDomain $OtherDomainName).DomainSID.Value
$domainDN = (Get-ADDomain).DistinguishedName
$fsps = Get-ADObject -filter * -SearchBase "CN=ForeignSecurityPrincipals,$domainDN" -Properties msDS-PrincipalName | ? {$_.Name -like "*$OtherDomainSID*" -and $_.'msDS-PrincipalName' -like "S-1-5-21-*"} | Select Name,msDS-PrincipalName
$fsps | ft -AutoSize #Prints them to screen
$fsps | Export-Csv ([Environment]::GetFolderPath("Desktop") + "\FSPs.csv") -NoTypeInformation #Saves a CSV file on your desktop with the same information that was printed to screen

#THIS LINE WILL DELETE WITHOUT CONFIRMATION. BE SURE YOU WANT TO DO THIS BEFORE YOU DO.
#$fsps | % {Get-ADObject ("CN=" + $_.Name + ",CN=ForeignSecurityPrincipals,$domainDN")} | Remove-ADObject -Confirm:$false  #Commented out so you dont accidentally delete anything.

