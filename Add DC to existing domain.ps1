#Add a new domain controller to an existing domain

#Variables
$ADDomainName = "contoso.com"
$ADDBPath = "F:\NTDS"
$ADLogPath = "F:\NTDS"
$ADSysVolPath = "F:\SYSVOL"
$ADSafeModePassword = ConvertTo-SecureString "P@ssword1" -AsPlainText -Force

#Code
Install-ADDSDomainController -DomainName $ADDomainName -SafeModeAdministratorPassword $ADSafeModePassword -DatabasePath $ADDBPath -LogPath $ADLogPath -SysvolPath $ADSysVolPath -InstallDNS -Credential (Get-Credential) -Force
