#Find the -500 account in a domain

$domainSID = [string](Get-ADDomain).DomainSID + "-500"
$objSID = New-Object System.Security.Principal.SecurityIdentifier ($domainSID)
$objUser = $objSID.Translate( [System.Security.Principal.NTAccount])
$objUser.Value
