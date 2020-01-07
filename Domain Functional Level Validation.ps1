<#
 SCRIPT: Functional Level Validation.ps1
PURPOSE: Detect the Forest and all domains the current server is joined to.
         Then review the PDC on each domain to get the current Forest and Domain
         functional levels. Then check all DCs in the forest and validate they
         are running at the current forest and domain funcitonal level as
         determined by their PDC.
         
   DATE: January 20th, 2018
 AUTHOR: Sean Greenbaum (Sean.Greenbaum@Microsoft.com)
  USAGE: Functional Level Validation.ps1
         Script should be run from a directory that user has write access to. This
         directory is where the log file will be written. Server should also have
         Active Directory Powershell commmandlets installed and have firewall access
         to all other DCs in the forest.
         The only line you may want to change is line 41, the location and name of the $logfile
         
 REVISION: 2.0
    1/20/18
    - Significantly improved speed by taking advantage of Invoke-Command instead of individual
      query of each DC linearly.
    - Added logging capability

 REVISION: 1.0
    10/18/17
    - Detects forest and all domains. Enumerates all and checks FFL and DFL versions
    - Prints details to screen

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

$now = (Get-Date -Format MMddyy-HHmmss)
$logfile = ("FunctionalCheck-" + $now + ".txt")  #Created this file if it doesn't exist.
$forest = Get-ADForest
$Domains = $forest.Domains
$partition = $forest.PartitionsContainer
$forestpdc = (Get-ADDomain -Server $forest.RootDomain).PDCEmulator
$attr = "msDS-Behavior-Version"
$ffltarget = (Get-ADObject -Identity $partition -Properties $attr -Server $forestpdc | Select $attr).$attr
$tab = [char]9
$ffllevel = $dfllevel = $null
Add-Content $logfile ("Running FFL/DFL Check on Forest $forest at $now")
Add-Content $logfile ("Checking Functional Levels on forest $forest...") -PassThru
ForEach ($Domain in $Domains)
{
    $domainpdc = (Get-ADDomain -Server $domain).PDCEmulator
    $domainnc = (Get-ADDomain -Server $domainpdc).DistinguishedName
    $dfltarget = (Get-ADObject -Identity $domainnc -Properties $attr -Server $domainpdc | Select $attr).$attr
    $servers = (Get-ADDomainController -filter * -Server $domainpdc).Hostname
    $dcsatffltarget = $dcsatdfltarget = @()
    $ffllevel = Invoke-Command $servers -ScriptBlock {(Get-ADObject -Identity $args[0] -Properties $args[1] -Server localhost | Select $args[1])} -ArgumentList $partition,$attr -ErrorAction SilentlyContinue
    $dfllevel = Invoke-Command $servers -ScriptBlock {(Get-ADObject -Identity $args[0] -Properties $args[1] -Server localhost | Select $args[1])} -ArgumentList $domainnc,$attr -ErrorAction SilentlyContinue
    $ffllevel | % {
        if ($_.$attr -eq $ffltarget)
        {
            $dcsatffltarget += $_.PSComputerName
        }
    }
    $dfllevel | % {
        if ($_.$attr -eq $dfltarget)
        {
            $dcsatdfltarget += $_.PSComputerName
        }
    }
    $fflcomp = Compare-Object -ReferenceObject $servers -DifferenceObject $dcsatffltarget -PassThru
    $dflcomp = Compare-Object -ReferenceObject $servers -DifferenceObject $dcsatdfltarget -PassThru
    Add-Content $logfile ("")
    Add-Content $logfile ("")
    Add-Content $logfile ("Results for Domain: $domain") -PassThru
    Write-Host "Domain Controller Count: " -NoNewline -ForegroundColor White
    Write-Host $servers.count -ForegroundColor Green
    Add-Content $logfile ("Domain Contrller Count: " + $servers.count)
    Add-Content $logfile ("Current FFL on PDC detected as $ffltarget")
    Write-Host "Domain Controllers not at current FFL target of $ffltarget :" -NoNewline -ForegroundColor White
    if ($fflcomp.count -gt 0)
    {
        Write-Host ($fflcomp.count) -ForegroundColor Yellow
        Write-Host "Servers not at current version are:" -ForegroundColor White
        Write-Host $fflcomp -ForegroundColor Yellow -Separator "`n"
        Add-Content $logfile ("DCs not at current version count: " + $fflcomp.count)
        Add-Content $logfile ("DCs not current are: $fflcomp")
        Add-Content $logfile ("DCs that are at current version count: " + $dcsatffltarget.count)
        Add-Content $logfile ("DCs that are current are: $dcsatffltarget")
    }
    else
    {
        Write-Host ($fflcomp.count) -ForegroundColor Green
        Add-Content $logfile ("All DCs in this domain at current FFL")
        Add-Content $logfile ("DCs that checked in are: $dcsatffltarget")
    }
    Write-Host "Domain Controllers not at current DFL target of $dfltarget :" -NoNewline -ForegroundColor White
    Add-Content $logfile ("Current DFL on PDC detected as $dfltarget")
    if ($dflcomp.count -gt 0)
    {
        Write-Host ($dflcomp.count) -ForegroundColor Yellow
        Write-Host "Servers not at current version are:" -ForegroundColor White
        Write-Host ($dflcomp) -ForegroundColor Yellow -Separator "`n"
        Add-Content $logfile ("DCs not at current version count: " + $dflcomp.count)
        Add-Content $logfile ("DCs not current are: $dflcomp")
        Add-Content $logfile ("DCs that are at current version count: " + $dcsatdfltarget.count)
        Add-Content $logfile ("DCs that are current are: $dcsatdfltarget")
    }
    else
    {
        Write-Host $dflcomp.count -ForegroundColor Green
        Add-Content $logfile ("All DCs in this domain at current DFL")
        Add-Content $logfile ("DCs that checked in are: $dcsatdfltarget")
    }
}