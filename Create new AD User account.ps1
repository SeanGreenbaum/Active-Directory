#Create a new AD Account

#Variables you can change
$AdminFirstName = "MyNew"
$AdminLastName = "Account"
$DefaultPassword = "P@ssword1"

#Building internal variables for scripting
$SecurePass = ConvertTo-SecureString $DefaultPassword -AsPlainText -Force
$domainsuffix = (get-addomain).DNSRoot
$AdminDisplayName = $AdminFirstName + " " +$AdminLastName
$samAccountName = $AdminFirstName + $AdminLastName
$upn = $samAccountName + "@" + $domainsuffix

#Create the new user, set account properties
New-ADUser -GivenName $AdminFirstName -Surname $AdminLastName -SamAccountName $samAccountName -UserPrincipalName $upn -Name $AdminDisplayName -DisplayName $AdminDisplayName
Set-ADAccountPassword $samaccountname -reset -NewPassword $SecurePass
Set-ADUser $samaccountname -ChangePasswordAtLogon $true -PasswordNotRequired $false -Enabled $True

