# Joins the local computer to the specified AD Domain
# It will prompt the user to enter their password for the domain join

$domainname = "contoso.com"
$username = "contoso\Administrator"
Add-Computer -DomainName $domainname -Credential $username -Restart
