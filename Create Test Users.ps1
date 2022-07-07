$DefaultPassword = "P@ssword1"

#code
$domainsuffix = (get-addomain).DNSRoot
$oupath = (get-addomain).UsersContainer
$SecurePass = ConvertTo-SecureString $DefaultPassword -AsPlainText -Force
1..10 | ForEach {
    $firstname = "Test" + $_
    $lastname = "User"
    $firstlastname = $FirstName + " " + $LastName
    $samaccountname = $Firstname + $LastName
    $upn = $samaccountname + "@" + $domainsuffix
    New-ADUser -GivenName $FirstName -Surname $LastName -SamAccountName $samAccountName -UserPrincipalName $upn -Name $firstlastname -DisplayName $firstlastname -path $oupath 
    $newuser = get-aduser $samaccountname 
    Set-ADAccountPassword $newuser -reset -NewPassword $SecurePass
    Set-ADUser $newuser -ChangePasswordAtLogon $False -PasswordNotRequired $false -Enabled $true
}