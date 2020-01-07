# Find all Users and Computers that are inactive based on the specified number of days
# LastLogonTimeStamp is a replicated AD Attribute, but is only accutate to within 9-14 days
# https://docs.microsoft.com/en-us/windows/win32/adschema/a-lastlogontimestamp
# https://docs.microsoft.com/en-us/archive/blogs/askds/the-lastlogontimestamp-attribute-what-it-was-designed-for-and-how-it-works

$DaysActive = 30
$time = (Get-Date).Adddays(-($DaysActive))
Get-ADComputer -Filter {LastLogonTimeStamp -gt $time} -ResultPageSize 2000 -resultSetSize $null -Properties Name, OperatingSystem, SamAccountName, DistinguishedName, LastLogonTimeStamp | ft Name, OperatingSystem, SamAccountName, DistinguishedName, Enabled, @{n='LastLogonTimeStamp';e={[DateTime]::FromFileTime($_.LastLogonTimeStamp)}} -AutoSize
Get-ADUser -Filter {LastLogonTimeStamp -gt $time} -ResultPageSize 2000 -resultSetSize $null -Properties Name, SamAccountName, DistinguishedName, LastLogonTimeStamp | ft Name, SamAccountName, DistinguishedName, Enabled, @{n='LastLogonTimeStamp';e={[DateTime]::FromFileTime($_.LastLogonTimeStamp)}} -AutoSize
