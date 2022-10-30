<#
 SCRIPT: CheckADFL.ps1
PURPOSE: Detect the Forest and all domains the current server is joined to.
         Then review the PDC on each domain to get the current Forest and Domain
         functional levels. Then check all DCs in the forest and validate they
         are running at the current forest and domain funcitonal level as
         determined by their PDC.
         
   DATE: October 29th, 2022
 AUTHOR: Sean Greenbaum (Sean.Greenbaum@Microsoft.com)
  USAGE: CheckADFL.ps1
         Script should be run from a directory that user has write access to. This
         directory is where the log file will be written. Server should also have
         Active Directory Powershell commmandlets installed and have firewall access
         to all other DCs in the forest.

         CheckADFL.ps1 -DomainFQDN root.contoso.com
         Use this format if you only want to check one of the domains instead of all domains in the forest.
         
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
    [Parameter(Mandatory=$false)][string]$DomainFQDN = ""
)

$now = (Get-Date -Format MMddyy-HHmmss)
Start-Transcript -Path ($PSScriptRoot + "\CheckADFL-$now.txt") -ErrorAction Stop
$forest = Get-ADForest
$Domains = $forest.Domains
$partition = $forest.PartitionsContainer
$forestpdc = (Get-ADDomain -Server $forest.RootDomain).PDCEmulator
$attr = "msDS-Behavior-Version"
$ffltarget = (Get-ADObject -Identity $partition -Properties $attr -Server $forestpdc | Select $attr).$attr

if ($domains.Contains($DomainFQDN))
{
    $domainlist = $DomainFQDN
}
else
{
    if ($DomainFQDN.Length -gt 0)
    {
        Write-Host "Specified Domain not found. Please check your entry and try again." -ForegroundColor Yellow
        break
    }
    $domainlist = $Domains
}

$AllDCReport=@()
$AllDomainReport=@()
ForEach ($Domain in $domainlist)
{

    Write-Host "Checking Domain Controllers in Domain $Domain" -ForegroundColor Yellow
    $mydomain = Get-ADDomain -Identity $Domain
    $ThisDomain = New-Object -TypeName PSCustomObject
    $mypdc = ($mydomain).PDCEmulator
    $dfltarget = (Get-ADObject -Identity $mydomain.DistinguishedName -Properties $attr -Server $mypdc).$attr
    $ThisDomain | Add-Member -MemberType NoteProperty -Name Name -Value $mydomain.DNSRoot
    $ThisDomain | Add-Member -MemberType NoteProperty -Name DFLtarget -Value $dfltarget
    $AllDomainReport += $ThisDomain
    $mydcs = Get-ADDomainController -filter * -Server $mypdc
    $i = 0
    if (-not $mydcs.count) {$count = 1} else {$count = $mydcs.count}
    ForEach ($dc in $mydcs)
    {
        Write-Progress -Activity "Connected to DCs in Domain $($mydomain.Name)" -Status "Scanning DC $($dc.Hostname)" -PercentComplete ($i / $count*100)
        $ThisDC = New-Object -TypeName PSCustomObject
        $ThisDC | Add-Member -MemberType NoteProperty -Name Name -Value $dc.Name
        $ThisDC | Add-Member -MemberType NoteProperty -Name Domain -Value $dc.Domain
        $ThisDC | Add-Member -MemberType NoteProperty -Name IPv4Address -Value $dc.IPv4Address
        $ThisDC | Add-Member -MemberType NoteProperty -Name Site -Value $dc.Site
        $ThisDC | Add-Member -MemberType NoteProperty -Name FFL -Value ((Get-ADObject -Identity $partition -Properties $attr -Server $dc | Select $attr).$attr)
        $ThisDC | Add-Member -MemberType NoteProperty -Name DFL -Value ((Get-ADObject -Identity $mydomain.DistinguishedName -Properties $attr -Server $dc).$attr)
        $AllDCReport += $ThisDC
        $i++
    }
}
Write-Progress -Completed -Activity "Scanning Domain Controllers"

Write-Host "`n`nCurrent Forest $($forest.Name)" -ForegroundColor Green
Write-Host "FFL Value $($ffltarget)" -ForegroundColor Green

$AllDomainReport | Format-Table -AutoSize
$AllDCReport | Format-Table -AutoSize

#Process results
Write-Host "`nThe following DCs are not yet updated with the correct FFL or DFL:"
$printany = $false
ForEach ($Domain in $AllDomainReport)
{
    $myDCs = $AllDCReport | Where-Object {$_.Domain -eq $Domain.Name}
    $myDCs | ForEach {
        $printme = $false
        $fflcolor = $dflcolor = "Green"
        if ($_.DFL -ne $Domain.DFLTarget)
        {
            $printme = $true
            $printany = $true
            $dflcolor = "Yellow"
        }
        if ($_.FFL -ne $ffltarget)
        {
            $printme = $true
            $printany = $true
            $fflcolor = "Yellow"
        }
        if ($printme)
        {
            Write-Host "`t$($_.Name)" -ForegroundColor White -NoNewLine
            Write-Host "`tFFL:$($_.FFL)" -ForegroundColor $fflcolor -NoNewline
            Write-Host "`tDFL:$($_.DFL)" -ForegroundColor $dflcolor
        }
    }
}
if (-not $printany)
{
    Write-Host "All Domain Controllers found to be correct" -ForegroundColor Green
}
Stop-Transcript
