# Using a CSV file, create new AD Users and store them in the configured default Users Container
# Default Users container can be changed per domain using the command (change the OU path to your chosen path)
#    redirusr "OU=Users,OU=Contoso,DC=contoso,DC=com"

# CSV file needs the following columns in it:
# FirstName, LastName

# This script creates the SAM Account name based on first character of first name, then the lastname. 
# If you want to provide the sam account name in the CSV file, add another column called samaccountname to the CSV file
# Then edit the code before changing from 
#     $samaccountname = $user.Firstname[0] + $user.LastName
# to
#     $samaccountname = $user.samaccountname

#variables
$filename = "FictitiousNames.csv"
$DefaultPassword = "P@ssword1"

#code
$import = Import-CSV $filename
$domainsuffix = (get-addomain).DNSRoot
$oupath = (get-addomain).UsersContainer
$SecurePass = ConvertTo-SecureString $DefaultPassword -AsPlainText -Force
foreach ($user in $import)
{
    $firstlastname = $user.FirstName + " " + $user.LastName
    $samaccountname = $user.Firstname[0] + $user.LastName
    $upn = $samaccountname + "@" + $domainsuffix
    New-ADUser -GivenName $user.FirstName -Surname $user.LastName -SamAccountName $samAccountName -UserPrincipalName $upn -Name $firstlastname -DisplayName $firstlastname -path $oupath 
    $newuser = get-aduser $samaccountname 
    Set-ADAccountPassword $newuser -reset -NewPassword $SecurePass
    Set-ADUser $newuser -ChangePasswordAtLogon $False -PasswordNotRequired $false -Enabled $true
}
