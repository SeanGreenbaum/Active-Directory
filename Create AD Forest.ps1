#Installs Active Directory Roles
Install-WindowsFeature -Name AD-Domain-Services,RSAT-AD-Tools

#Sets the variables for the new AD Forest
$ADDBPath = "F:\NTDS"
$ADLogPath = "F:\NTDS"
$ADSysVolPath = "F:\SYSVOL"
$ADForestMode = "WinThreshold" #WinThreshold = 2016 Functional Level
$ADDomainMode = "WinThreshold"
$ADDomainFQDN = "contoso.com"
$ADDomainName = "contoso"
$ADSafeModePassword = ConvertTo-SecureString "P@ssword1" -AsPlainText -Force

#Creates the new AD Forest on the local server
Install-ADDSForest -CreateDnsDelegation:$false -DatabasePath $ADDBPath -ForestMode $ADForestMode -DomainMode $ADDomainMode -DomainName $ADDomainFqdn -DomainNetbiosName $ADDomainName -InstallDns:$true -LogPath $ADLogPath -NoRebootOnCompletion:$false -SysvolPath $ADSysVolPath -Force:$true -SafeModeAdministratorPassword $adsafeModePassword
