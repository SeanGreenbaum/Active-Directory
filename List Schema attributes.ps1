#Lists all Schema attributes by LDAPName, Name and GUID

Get-ADObject -SearchBase (Get-ADRootDSE).SchemaNamingContext -Filter * -Properties ldapdisplayname,Name,SchemaIDGuid | Select ldapdisplayname,name, @{Label="Guid"; Expression={[System.GUID]$_.SchemaIDGUID}}