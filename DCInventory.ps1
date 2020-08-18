<#
 SCRIPT: DC Inventory.ps1
PURPOSE: Find all Domain Controllers in the current forets, get inventory data about them.
         Find all AD Sites and AD Site Links
         Save all data to 3 CSV files in the current directory
   DATE: August 18th, 2020
 AUTHOR: Sean Greenbaum (Sean.Greenbaum@Microsoft.com)
  USAGE: .\DCInventory.ps1
         Script should be run from a directory that user has write access to. This
         directory is where the files will be written. Server should also have
         Active Directory Powershell commmandlets installed and have firewall access
         to all other DCs in the forest.
         
 REVISION: 1.0
    08/18/2020
    - Initial release

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


$forest = (Get-ADForest).Name
$domains = (Get-ADForest).domains
$domains | % {
    $dcs += Get-ADDomainController -filter * -Server $_ | Select-Object Name,Site,OperatingSystem,IPv4Address,IsGlobalCatalog,IsReadOnly,Forest,Domain
}
$dcs | Export-csv dcs.csv -NoTypeInformation

Get-ADReplicationSite -Filter * -Server $forest | Select-Object Name, Description | Export-Csv ADSites.csv -NoTypeInformation
Get-ADReplicationSiteLink -server $forest -filter * | Select-Object Name,Cost,ReplicationFrequencyInMinutes | Export-Csv ADSiteLinks.csv -NoTypeInformation
