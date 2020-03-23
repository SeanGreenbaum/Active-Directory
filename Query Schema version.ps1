#Query for the current schema version

$dn = (get-addomain).DistinguishedName
$schemadn = "CN=Schema,CN=Configuration," + $dn
(get-adobject $schemadn -Properties objectversion).objectversion