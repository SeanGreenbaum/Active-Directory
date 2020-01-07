# Find all DNS Zone objects and print them to screen. 
# Optionally, run the second block of code to enable the Protect from Accidental Deletion flag on each that is missing it

# Gets all DNSZone objects from the current domain ForestDnsZones, DomainDnsZones and Domain naming context (Windows 2000 compatibiliy)
# Prints them to the screen

$domaindn = (Get-ADDomain).DistinguishedName
$zones = Get-ADObject -Filter {ObjectClass -like "dnszone"} -SearchScope Subtree -SearchBase "DC=ForestDnsZones,$domaindn" -properties ProtectedFromAccidentalDeletion | Select Name, DistinguishedName, ProtectedFromAccidentalDeletion
$zones += Get-ADObject -Filter {ObjectClass -like "dnszone"} -SearchScope Subtree -SearchBase "DC=DomainDnsZones,$domaindn" -properties ProtectedFromAccidentalDeletion | Select Name, DistinguishedName, ProtectedFromAccidentalDeletion
$zones += Get-ADObject -Filter {ObjectClass -like "dnszone"} -SearchScope Subtree -SearchBase "CN=MicrosoftDNS,CN=System,$domaindn" -properties ProtectedFromAccidentalDeletion | Select Name, DistinguishedName, ProtectedFromAccidentalDeletion
$zones

# Optionally, if you want to enable the protection, then run this code block
# It does require the $zones variable from the previous code block
# Zones printed in Yellow are the ones being changed

$zones | % {
    if ($_.ProtectedFromAccidentalDeletion -eq $false){
        Write-Host $_.Name -ForegroundColor Yellow
        Set-ADObject $_.DistinguishedName -ProtectedFromAccidentalDeletion $true
    }
}
