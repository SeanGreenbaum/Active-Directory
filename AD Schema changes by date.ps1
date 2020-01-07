#AD Schema changes by date

$schema = Get-ADObject -SearchBase ((Get-ADRootDSE).SchemaNamingContext) -SearchScope OneLevel -Filter * -Property objectClass, name, whenChanged,whenCreated | Select-Object objectClass, name, whenCreated, whenChanged, @{name="event";expression={($_.whenCreated).Date.ToShortDateString()}} | Sort-Object whenCreated

"`nDetails of schema objects changed by date:" 
$schema | Format-Table objectClass, name, whenCreated, whenChanged -GroupBy event -AutoSize

"`nCount of schema objects changed by date:" 
$schema | Group-Object event | Format-Table Count, Name, Group –AutoSize 
