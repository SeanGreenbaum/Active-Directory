#Set this server DFSR to Non-Authoritative restore mode
$thisDC = Get-ADComputer -Identity $env:computername
$SysVOLSubDN = "CN=SYSVOL Subscription,CN=Domain System Volume,CN=DFSR-LocalSettings," + $thisDC.DistinguishedName
$SysVolSub = Get-ADObject -Identity $SysVOLSubDN -Properties *
Set-ADObject -Identity $SysVolSub -Add @{'msDFSR-Options'=1}
Restart-Service dfsr

#Seize FSMO Roles
$thisDC = Get-ADComputer -Identity $env:computername
Write-Host "Seizing FSMO roles. This may take a few minutes." -ForegroundColor Yellow
Move-ADDirectoryServerOperationMasterRole -Identity $thisDC.Name -OperationMasterRole 0,1,2,3,4 -force -confirm:$False

#FixFSMOs on other partitions
#references the FixFSMO.VBS script. Must be in the current directory.
if (Test-Path fixfsmo.vbs)
{
    Write-Host "FixFSMO.vbs found. Executing." -ForegroundColor Green
    $domain = Get-ADDomain
    $dn = "DC=DomainDNSZones," + $domain.DistinguishedName
    Write-Host "Fixing DomainDNSZones"
    cmd /c cscript fixfsmo.vbs $dn
    $forest = Get-ADForest
    if ($thisDC.DNSHostName.Substring($thisDC.DNSHostName.IndexOf(".")+1) -eq $forest.Name) #Currently in the root, fix ForestDNSZones too
    {
        $dn = "DC=ForestDNSZones," + $domain.DistinguishedName
        Write-Host "Fixing ForestDNSZones"
        cmd /c cscript fixfsmo.vbs $dn
    }
}
else
{
    Write-Host "FixFSMO.vbs NOT found. Skipping. You will need to run this manually." -ForegroundColor Yellow
}

#Fix RIDs
Write-Host "Resetting RID Pool"
$domain = Get-ADDomain
$RIDMasterDN = "CN=RID Manager$,CN=System," + $domain.DistinguishedName
$RID = Get-ADObject $RIDMasterDN -Properties rIDAvailablePool
$newRID = $RID.rIDAvailablePool + 100000
Set-ADObject -Identity $RIDMasterDN -Replace @{'rIDAvailablePool'=$newRID}
$Domain = New-Object System.DirectoryServices.DirectoryEntry
$DomainSid = $Domain.objectSid
$RootDSE = New-Object System.DirectoryServices.DirectoryEntry("LDAP://RootDSE")
$RootDSE.UsePropertyCache = $false
$RootDSE.Put("invalidateRidPool", $DomainSid.Value)
$RootDSE.SetInfo()
Write-Host "Expecting next command to fail. Ignore."
New-ADUser -Name RIDTest #Expected to fail but forces DC to get new RID Pool

#Reset Machine Account Password twice
Reset-ComputerMachinePassword
Reset-ComputerMachinePassword

#Reset KRBTGT twice
net user krbtgt Password123456789 /domain
net user krbtgt Password123456789 /domain

#Set time source for server and type
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\W32Time\Parameters" -Name "Type" -Value "NTP"
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\W32Time\Parameters" -Name "NtpServer" -Value "time.windows.com,0x9"
Restart-Service W32Time