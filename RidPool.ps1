#Alternative to dcdiag /test:RIDMANAGER
#Use in case the dcdiag test isn't running, or you just want to be cool
#Code provided by Microsoft CE Andreas Michelfeit


function get-rid
{
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
}

function set-globalrid
{
                <#The Next Function Increases the RID Pool to 100.000 more #>
                # DisplayCurrentRID-Pool by calling the get-rid function
                Write-Host "Current RID-Pool:"
                Write-Host ""
                get-rid
                $domaindn = (get-addomain).DistinguishedName
                $DomainDNS = (get-addomain).DnsRoot
                $RIDManagerProperty = Get-ADObject "cn=rid manager$,cn=system,$DomainDN" -property RIDAvailablePool -server ((Get-ADDomain $DomainDNS).RidMaster)
                $RIDInfo = $RIDManagerProperty.RIDAvailablePool
                $ridinfo = $ridinfo + 100000
                Set-ADObject "cn=rid manager$,cn=system,$DomainDN" -Replace @{ RIDavailablepool = $RIDInfo }

                # DisplayCurrentRID-Pool by calling the get-rid function after the RID-Increase
                Write-Host "RID-Pool after increase:"
                Write-Host ""
                get-rid
}

function set-localrid
{
                <#Now the local Rid Pool is invalidated#>
                $Domain = New-Object System.DirectoryServices.DirectoryEntry
                $DomainSid = $Domain.objectSid
                $RootDSE = New-Object System.DirectoryServices.DirectoryEntry("LDAP://RootDSE")
                $RootDSE.UsePropertyCache = $false
                $RootDSE.Put("invalidateRidPool", $DomainSid.Value)
                $RootDSE.SetInfo()
}