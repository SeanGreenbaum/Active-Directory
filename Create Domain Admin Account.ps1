#Create a new AD Account and add it to Domain Admins

#Variables you can change
$AdminFirstName = "MyNew"
$AdminLastName = "AdminAccount"
$DefaultPassword = "P@ssword1"

#Building internal variables for scripting
$SecurePass = ConvertTo-SecureString $DefaultPassword -AsPlainText -Force
$domainsuffix = (get-addomain).DNSRoot
$AdminDisplayName = $AdminFirstName + " " +$AdminLastName
$samAccountName = $AdminFirstName + $AdminLastName
$upn = $samAccountName + "@" + $domainsuffix

#Create the new user, set account properties and add to Domain Admins group
New-ADUser -GivenName $AdminFirstName -Surname $AdminLastName -SamAccountName $samAccountName -UserPrincipalName $upn -Name $AdminDisplayName -DisplayName $AdminDisplayName
Set-ADAccountPassword $samaccountname -reset -NewPassword $SecurePass
Set-ADUser $samaccountname -PasswordNotRequired $false -Enabled $True
Add-ADGroupMember -Identity "Domain Admins" -Members $samaccountname
