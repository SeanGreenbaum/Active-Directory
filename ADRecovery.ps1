<#
 SCRIPT: ADRecovery.ps1
PURPOSE: Combination of PS code to facilitate an AD Forest or Domain Recovery
         AD Forest and/or Domain recovery is a significant task and should be
         performed in strictly controlled environments. Using this script in a
         production environment could cause serious issues.
         
   DATE: October 29th, 2022
 AUTHOR: Sean Greenbaum (Sean.Greenbaum@Microsoft.com)
  USAGE: ADRecovery.ps1 -phase1 -NewAdminPassword
         ADRecovery.ps1 -phase2
         ADRecovery.ps1 -phase3
         
         Phase1 locates the default -500 account, changes its password and adds it to the Domain Admins group. If
         running on the root domain it will also add to the Enterprise Admin and Schema Admins groups. Performs a logoff
         if group membership changed.

         Phase2 Sets DFSR to Authoritative Restore mode and restarts the DFSR service. It then seizes FSMO roles
         based on if this is the root or a child domain. Once FSMOs are captured the script terminates to allow for 
         manual clean up of the old Domain Controller objects. There aer several ways to do this, but are outside the
         scope of this script.

         Phase3 performs a modern version of FixFSMO on the ForestDNSZones and DomainDNSZones partitions on the current
         domain. (ForestDNSZones only done if we are on the root). Next it increases the RID pool and invalidates the existing
         pool. Attempts to create a test user, which fails intentionally but forced the DC to do a new RID pool request. Next
         we reset the computer account password twice, then krbtgt twice, and finally set the NTP service settings to NTP and
         point to an external Time server (if on the root domain).

         These are NOT the only steps involved in a Forest/Domain restore. Be sure to check out the documentation and include
         your own custom steps as needed.
         
 REVISION: 3.0
    Code rewrite to provide better output. Also modified to allow for running against only 1 domain instead of
    all domains in the forest. Useful if only performing a DFL uplift to one domain.

Disclaimer
The sample scripts are not supported under any Microsoft standard support program or service. The sample scripts
are provided AS IS without warranty of any kind. Microsoft further disclaims all implied warranties including, 
without limitation, any implied warranties of merchantability or of fitness for a particular purpose. The entire
risk arising out of the use or performance of the sample scripts and documentation remains with you. In no event
shall Microsoft, its authors, or anyone else involved in the creation, production, or delivery of the scripts be
liable for any damages whatsoever (including, without limitation, damages for loss of business profits, business
interruption, loss of business information, or other pecuniary loss) arising out of the use of or inability to use
the sample scripts or documentation, even if Microsoft has been advised of the  possibility of such damages.
#>

param (
    [Parameter(Mandatory=$false,ParameterSetName="Phase1")][switch]$Phase1,
    [Parameter(Mandatory=$true,ParameterSetName="Phase1")][string]$NewAdminPassword,
    [Parameter(Mandatory=$false,ParameterSetName="Phase2")][switch]$Phase2,
    [Parameter(Mandatory=$false,ParameterSetName="Phase3")][switch]$Phase3
)

Start-Transcript -Path ($PSScriptRoot + "\ADForestRecovery-$now.txt") -ErrorAction Stop
if ($Phase1)
{
    Write-Host "Loading Forest and Domain information" -ForegroundColor Green
    $domain = Get-ADDomain

    Write-Host "Looking up -500 account" -ForegroundColor Green
    $adminUser = (New-Object System.Security.Principal.SecurityIdentifier($domain.DomainSID.ToString() + "-500")).Translate([System.Security.Principal.NTAccount])
    $adminUser.Value  #In format domain\username
    $adminUserName = $adminUser.value.Substring($adminUser.Value.IndexOf("\")+1)   #In format username only (no Domain)

    Write-Host "Changing $($adminUser.Value) password to $NewAdminPassword" -ForegroundColor Green
    $command = "net user $adminUserName $NewAdminPassword /domain"
    cmd /c $command

    Write-Host "Looking up $($adminUser.Value) groups" -ForegroundColor Green
    $admingroups = whoami /groups | findstr -i "admin"
    $groupchangemade = $false
    if (-not ($admingroups | Select-String -Pattern "$($domain.NetBiosName)\\Domain Admins"))
    {
        Write-Host "Adding $($adminUser.Value) to Domain Admins" -ForegroundColor Yellow
        Add-ADGroupMember -Identity "Domain Admins" -Members $adminUsername
        $groupchangemade = $true
    }
    if ((-not ($admingroups | Select-String -Pattern "$($domain.NetBiosName)\\Enterprise Admins")) -and (-not $domain.ParentDomain)) #Only root gets this group
    {
        Write-Host "Adding $($adminUser.Value) to Enterprise Admins" -ForegroundColor Yellow
        Add-ADGroupMember -Identity "Enterprise Admins" -Members $adminUsername
        $groupchangemade = $true
    }
    if ((-not ($admingroups | Select-String -Pattern "$($domain.NetBiosName)\\Schema Admins")) -and (-not $domain.ParentDomain)) #Only root gets this group
    {
        Write-Host "Adding $($adminUser.Value) to Schema Admins" -ForegroundColor Yellow
        Add-ADGroupMember -Identity "Schema Admins" -Members $adminUsername
        $groupchangemade = $true
    }

    if ($groupchangemade)
    {
        Write-Host "Group changes made." -ForegroundColor White -BackgroundColor Red
        Write-Host "On next logon proceed with Phase2." -ForegroundColor White -BackgroundColor Red
        $message = "Press any key to proceed with Logoff"
        if ($psISE) #Workaround for PowerShell ISE vs regular PowerShell
        {
            Add-Type -AssemblyName System.Windows.Forms
            [System.Windows.Forms.MessageBox]::Show("$message")
        }
        else
        {
            Write-Host "$message" -ForegroundColor Yellow
            $x = $host.ui.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        }
        Stop-Transcript
        logoff
    }
}

if ($Phase2)
{
    #Reset variables
    $domain = Get-ADDomain
    $adminUser = (New-Object System.Security.Principal.SecurityIdentifier($domain.DomainSID.ToString() + "-500")).Translate([System.Security.Principal.NTAccount])
    $adminUserName = $adminUser.value.Substring($adminUser.Value.IndexOf("\")+1)   #In format username only (no Domain)

    Write-Host "Setting DFSR to Authoritiative Restore mode" -ForegroundColor Green
    $DCDFSRObjectPath = "CN=SYSVOL Subscription,CN=Domain System Volume,CN=DFSR-LocalSettings,CN=$($env:COMPUTERNAME),$($domain.DomainControllersContainer)"
    $SysSub=Get-ADObject $DCDFSRObjectPath -Properties msDFSR-Options
    $SysSub.'msDFSR-Options'=1
    Set-ADObject -Instance $SysSub
    Get-ADObject $DCDFSRObjectPath -Properties msDFSR-Options 

    Write-Host "Restarting DFSR Service" -ForegroundColor Green
    Restart-Service DFSR -PassThru

    Start-Sleep 2  #Wait for Event log to get record
    Get-WinEvent -LogName "DFS Replication" |Where-Object ID -EQ 4602 | Format-Table -AutoSize -Wrap

    Write-Host "Starting FSMO role Seize. This may take a few seconds" -ForegroundColor Green
    netdom query fsmo
    if ((Get-ADDomain).ParentDomain) #Not the root domain
    {
    	Move-ADDirectoryServerOperationMasterRole -Identity $($env:COMPUTERNAME) –OperationMasterRole 0,1,2, -force
    }
    else #We are at the root
    {
    	Move-ADDirectoryServerOperationMasterRole -Identity $($env:COMPUTERNAME) –OperationMasterRole 0,1,2,3,4 -force
    }
    netdom query fsmo

    Write-Host "Proceed with Domain Controller cleanup. Return to this script for Phase3 when complete." -ForegroundColor White -BackgroundColor Red
    Stop-Transcript
}

If ($Phase3)
{
    $domain = Get-ADDomain
    #FixFSMO, but with PowerShell
    Write-Host "Looking up current Infrastructure Master FSMO" -ForegroundColor Green
    $IMFSMOntds = (Get-ADDomainController -Identity $domain.InfrastructureMaster).NTDSSettingsObjectDN
    
    if ($domain.DNSRoot -eq $domain.forest) #Currently in the Forest root
    {
        Write-Host "Verifying ForestDNSZones fSMORoleOwner" -ForegroundColor Green
        $obj = Get-ADObject -Identity ("CN=Infrastructure,DC=ForestDNSZones," + $Domain.DistinguishedName) -Properties *
        if ($obj.fSMORoleOwner -ne $IMFSMOntds)
        {
            Write-Host "Setting fSMORoleOwner on ForestDNSZones" -ForegroundColor Green
            Write-Host "Current fSMORoleOwner: $($obj.fSMORoleOwner)" -ForegroundColor White
            Set-ADObject -Identity ("CN=Infrastructure,DC=ForestDNSZones," + $Domain.DistinguishedName) -Replace @{fSMORoleOwner=$IMFSMOntds}
            $obj = Get-ADObject -Identity ("CN=Infrastructure,DC=ForestDNSZones," + $Domain.DistinguishedName) -Properties *
            Write-Host "    New fSMORoleOwner: $($obj.fSMORoleOwner)" -ForegroundColor White
        }
    }
    Write-Host "Verifying DomainDNSZones fSMORoleOwner" -ForegroundColor Green
    $obj = Get-ADObject -Identity ("CN=Infrastructure,DC=DomainDNSZones," + $Domain.DistinguishedName) -Properties *
    if ($obj.fSMORoleOwner -ne $IMFSMOntds)
    {
        Write-Host "Setting fSMORoleOwner on DomainDNSZones" -ForegroundColor Green
        Write-Host "Current fSMORoleOwner: $($obj.fSMORoleOwner)" -ForegroundColor White
        Set-ADObject -Identity ("CN=Infrastructure,DC=DomainDNSZones," + $Domain.DistinguishedName) -Replace @{fSMORoleOwner=$IMFSMOntds}
        $obj = Get-ADObject -Identity ("CN=Infrastructure,DC=DomainDNSZones," + $Domain.DistinguishedName) -Properties *
        Write-Host "`tNew fSMORoleOwner: $($obj.fSMORoleOwner)" -ForegroundColor White
    }
    #Increase RID pool and invalidate existing RID pool
    Write-Host "Increasing RID Pool" -ForegroundColor Green
    $ridPath = “CN=RID Manager$,CN=System," + $domain.DistinguishedName
    $rid=get-adobject $ridPath –properties *
    Write-Host "RID AvailablePool Before:" $rid.rIDAvailablePool -ForegroundColor Yellow
    $rid.rIDAvailablePool=$rid.rIDAvailablePool+100000
    Set-adobject –instance $rid
    Write-Host "RID AvailablePool After: " $rid.rIDAvailablePool  -ForegroundColor Green

    Write-Host "Invalidating RID Pool" -ForegroundColor Green
    $Domain = New-Object System.DirectoryServices.DirectoryEntry
    $DomainSid = $Domain.objectSid
    $RootDSE = New-Object System.DirectoryServices.DirectoryEntry("LDAP://RootDSE")
    $RootDSE.UsePropertyCache = $false
    $RootDSE.Put("invalidateRidPool", $DomainSid.Value)
    $RootDSE.SetInfo()

    Write-Host "Invalid RID Pool" -ForegroundColor Green
    DCDiag /test:ridmanager /v | findstr /i "RID"

    Write-Host "Attempting to generate new RID Pool" -ForegroundColor Green
    Write-Host "Expect an error to display. This is NORMAL." -ForegroundColor White -BackgroundColor Green
    New-ADUser -Name “PullRidPool” -AccountPassword (ConvertTo-SecureString -AsPlainText “accountPassword1” -Force) -WarningAction SilentlyContinue -ErrorAction SilentlyContinue > $null

    Write-Host "Valid RID Pool" -ForegroundColor Green
    DCDiag /test:ridmanager /v | findstr /i "RID"

    #Rotate Machine password twice
    Write-Host "Resetting Computer Account Password" -ForegroundColor Green
    Reset-ComputerMachinePassword
    Reset-ComputerMachinePassword

    #Rotate KRBTGT twice
    Write-Host "Resetting KRBTGT account password" -ForegroundColor Green
    $command = "net user krbtgt $(-join ((65..90) + (97..122) + (48..57) | Get-Random -Count 50 | % {[char]$_})) /domain"
    cmd /c $command
    $command = "net user krbtgt $(-join ((65..90) + (97..122) + (48..57) | Get-Random -Count 50 | % {[char]$_})) /domain"
    cmd /c $command

    #Set time source for server and type (use your own time server or a public internet time server)
    if (-not $domain.ParentDomain) #Only if on the root
    {
        Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\W32Time\Parameters" -Name "Type" -Value "NTP"
        Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\W32Time\Parameters" -Name "NtpServer" -Value "time.windows.com,0x9"
        Restart-Service W32Time
    }

    Stop-Transcript
}