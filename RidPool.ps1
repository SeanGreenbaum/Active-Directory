#Alternative to dcdiag /test:RIDMANAGER
#Use in case the dcdiag test isn't running, or you just want to be cool
#Code provided by Microsoft CE Andreas Michelfeit


$domainDN = (get-addomain).DistinguishedName
$de = [ADSI]"LDAP://CN=RID Manager$,CN=System,$domainDN"
$return = new-object system.DirectoryServices.DirectorySearcher($de)
$property = ($return.FindOne()).properties.ridavailablepool
[int32]$totalSIDS = $($property) / ([math]::Pow(2, 32))
[int64]$temp64val = $totalSIDS * ([math]::Pow(2, 32))
[int32]$currentRIDPoolCount = $($property) – $temp64val
$ridsremaining = $totalSIDS – $currentRIDPoolCount
Write-Host "RIDs issued: $($currentRIDPoolCount.ToString('N0'))"
Write-Host "RIDs remaining: $($ridsremaining.ToString('N0'))"