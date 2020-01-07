#Using a variable, create related OUs
#This script creates a ParentOU at the root of the domain naming context.
#Then, using the OUs in the $OUs variable it creates a child OU for each, under the ParentOU. 
#All are protected from Accidental Deletion

#Final will look something like:
#
# Domain.Com
# |
# -> ParentOU
#    |
#    -> OU1
#    |
#    -> OU2
#    |
#    -> OU3

#Variables
$ParentOU = "Contoso"
$OUs = "Service Accounts", "Groups", "Staff Accounts", "Servers", "Workstations"

#Code
$domaindn = (Get-ADDomain).DistinguishedName
New-ADOrganizationalUnit $ParentOU -Path $domaindn
Get-ADOrganizationalUnit "OU=$ParentOU,$domaindn" | Set-ADOrganizationalUnit -ProtectedFromAccidentalDeletion $true
$path = "OU=$ParentOU,$domaindn"
ForEach ($ou in $OUs)
{
    New-ADOrganizationalUnit $OU -Path $path
    Get-ADOrganizationalUnit "OU=$ou,$path" | Set-ADOrganizationalUnit -ProtectedFromAccidentalDeletion $true
}
