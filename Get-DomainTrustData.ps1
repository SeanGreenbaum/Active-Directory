<#
Disclaimer:
This Sample Code is provided for the purpose of illustration only and is not intended to be used in a production environment.

THIS SAMPLE CODE AND ANY RELATED INFORMATION ARE PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND, 
EITHER EXPRESSED OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE IMPLIED WARRANTIES OF MERCHANTABILITY AND/OR FITNESS FOR A PARTICULAR PURPOSE.  

We grant You a nonexclusive, royalty-free right to use and modify the Sample Code and to reproduce and distribute the object code form of the Sample Code,
provided that you agree: 
       (i) to not use Our name, logo, or trademarks to market Your software product in which the Sample Code is embedded; 
       (ii) to include a valid copyright notice on Your software product in which the Sample Code is embedded; and 
       (iii) to indemnify, hold harmless, and defend Us and Our suppliers from and against any claims or lawsuits, including attorneys’ fees, that arise or result from the use or distribution of the Sample Code.

Please note: None of the conditions outlined in the disclaimer above will supersede the terms and conditions contained within the Premier Customer Services Description.
#>try 
{
    # Load Active Directory Cmdlets
    import-module activedirectory -ErrorAction Stop
    $CmdletsAvailable=$True
}
catch
{
    Write-Error 'Active Directory Cmdlets not available'
    $CmdletsAvailable=$False
}

If ($CmdletsAvailable)
{
    $FSPNetBios=(get-adobject -Filter "objectclass -eq 'foreignsecurityprincipal'" -Properties * | Foreach-Object { (New-Object System.Security.Principal.SecurityIdentifier($_.objectSid)).Translate([System.Security.Principal.NTAccount]).tostring().split('\')[0] }) | sort-object -Unique
    $CurrentDomain=([System.DirectoryServices.ActiveDirectory.Domain]::GetCurrentDomain()).Name
    $TrustList=([System.DirectoryServices.ActiveDirectory.Domain]::GetCurrentDomain()).GetAllTrustRelationShips()

    $TrustType='Downlevel','Uplevel','Mit'
    $TrustDirection='Disabled','Inbound','Outbound','Bidirectional'

    # Declare Active Directory Trust Array
    #region
    $TrustAttributes=@()
    
    $TrustAttributes+='0x00000800-CROSS_ORGANIZATION_ENABLE_TGT_DELEGATION'
    $TrustAttributes+='0x00000400-PIM_TRUST'
    $TrustAttributes+='0x00000200-CROSS_ORGANIZATION_NO_TGT_DELEGATION'
    $TrustAttributes+='0x00000080-USES_RC4_ENCRYPTION'
    $TrustAttributes+='0x00000040-TREAT_AS_EXTERNAL'
    $TrustAttributes+='0x00000020-WITHIN_FOREST'
    $TrustAttributes+='0x00000010-CROSS_ORGANIZATION'
    $TrustAttributes+='0x00000008-FOREST_TRANSITIVE'
    $TrustAttributes+='0x00000004-SID_FILTERING_ENABLED'
    $TrustAttributes+='0x00000002-UPLEVEL_ONLY'
    $TrustAttributes+='0x00000001-NON_TRANSITIVE'
    #endregion
        
    $TrustResults=@()
    $Trusts=Get-ADObject -Filter "objectclass -eq 'trustedDomain'" -Properties *
    Foreach ($Trust in $Trusts)
    {
        $SidFiltering='No'
        $SelectiveAuthentication='No'
        $FLATNAME=$Trust.FlatName
        $DomainObject=Get-ADUser -Properties whenchanged,samaccounttype -filter "samaccounttype -eq '805306370' -and Name -eq '$FLATNAME$'"
        $PSobject=New-Object -typename PSCustomObject
    
        $TrustAttributeToConvert=$Trust.TrustAttributes
        $AttributeValueOutput=''
        $TrustAttributeBinary=[convert]::tostring($TrustAttributeToConvert,2).padleft(32,'0')
        
        for ($position=0;$position -lt 32;$position++)
        {
            $AttributeToSearch=$TrustAttributeBinary[$position]
            If ($AttributeToSearch -eq '1')
            {

            $ActualBinaryPosition=31-$position
            $Decimal=[math]::Pow(2,$ActualBinaryPosition)
            $Hex='0x'+([convert]::ToString($Decimal,16).padleft(8,'0'))
            $AttributeValueName=($TrustAttributes | Where-Object { $_ -match $Hex}).split('-')[1]
            If ($AttributeValueName -match 'SID_FILTERING') { $SidFiltering='Yes' } 
            If ($AttributeValueName -match 'CROSS_ORGANIZATION') { $SelectiveAuthentication='Yes' } 

	    $AttributeValueOutput=$AttributeValueName+' '+$AttributeValueOutput
            }
        }

	if ($FSPNetBios -match $Trust.Flatname) {$FSPFound=$True} else {$FSPFound=$False}

	$TrustTypeDetail=($TrustList | Where-object { $_.TargetName -eq $Trust.trustPartner -and $_.TrustDirection -eq $TrustDirection[$Trust.trustDirection]}).TrustType
        $PSobject | Add-Member -MemberType NoteProperty -Name Source -Value $CurrentDomain
        $PSobject | Add-Member -MemberType NoteProperty -Name TrustPartner -Value $Trust.trustPartner
        $PSobject | Add-Member -MemberType NoteProperty -Name TrustType -Value $Trusttype[($Trust.TrustType)-1]
        $PSobject | Add-Member -MemberType NoteProperty -Name TrustDirection -Value $TrustDirection[$Trust.trustDirection]
        $PSobject | Add-Member -MemberType NoteProperty -Name whencreated -Value $Trust.whenCreated
        $PSobject | Add-Member -MemberType NoteProperty -Name whenchanged -Value $Trust.whenChanged
        $PSobject | Add-Member -MemberType NoteProperty -Name DomainNetBiosName -Value $Trust.flatname
        $PSobject | Add-Member -MemberType NoteProperty -Name InstanceAttribute -Value 4
        $PSobject | Add-Member -MemberType NoteProperty -Name TrustAttributesValue -Value $Trust.TrustAttributes
        $PSobject | Add-Member -MemberType NoteProperty -Name pwdlastset -Value $Domainobject.whenchanged
        $PSobject | Add-Member -MemberType NoteProperty -Name TrustAttributes -Value $AttributeValueOutput
        $PSObject | Add-Member -MemberType NoteProperty -Name TrustTypeDetail -Value $TrustTypeDetail
        $PSobject | Add-Member -MemberType NoteProperty -Name ForeignSecurityPrinicipalFound -Value $FSPFound
        $PSObject | Add-Member -MemberType NoteProperty -Name SidFilteringEnabled -Value $SidFiltering
        $PSObject | Add-Member -MemberType NoteProperty -Name SelectiveAuthenticationEnabled -Value $SelectiveAuthentication

        $TrustResults+=$PSObject
    }
    $TrustResults
    $TrustResults | Export-CSV -Path .\$ENV:USERDNSDOMAIN-Trustdata.csv -NoTypeInformation
}
try 
{
    # Load Active Directory Cmdlets
    import-module activedirectory -ErrorAction Stop
    $CmdletsAvailable=$True
}
catch
{
    Write-Error 'Active Directory Cmdlets not available'
    $CmdletsAvailable=$False
}

If ($CmdletsAvailable)
{
    $FSPNetBios=(get-adobject -Filter "objectclass -eq 'foreignsecurityprincipal'" -Properties * | ForEach-Object { (New-Object System.Security.Principal.SecurityIdentifier($_.objectSid)).Translate([System.Security.Principal.NTAccount]).tostring().split('\')[0] }) | sort-object -Unique
    $CurrentDomain=([System.DirectoryServices.ActiveDirectory.Domain]::GetCurrentDomain()).Name
    $TrustList=([System.DirectoryServices.ActiveDirectory.Domain]::GetCurrentDomain()).GetAllTrustRelationShips()

    $TrustType='Downlevel','Uplevel','Mit'
    $TrustDirection='Disabled','Inbound','Outbound','Bidirectional'

    $TrustAttributes=@()
    
    $TrustAttributes+='0x00000800-CROSS_ORGANIZATION_ENABLE_TGT_DELEGATION'
    $TrustAttributes+='0x00000400-PIM_TRUST'
    $TrustAttributes+='0x00000200-CROSS_ORGANIZATION_NO_TGT_DELEGATION'
    $TrustAttributes+='0x00000080-USES_RC4_ENCRYPTION'
    $TrustAttributes+='0x00000040-TREAT_AS_EXTERNAL'
    $TrustAttributes+='0x00000020-WITHIN_FOREST'
    $TrustAttributes+='0x00000010-CROSS_ORGANIZATION'
    $TrustAttributes+='0x00000008-FOREST_TRANSITIVE'
    $TrustAttributes+='0x00000004-SID_FILTERING_ENABLED'
    $TrustAttributes+='0x00000002-UPLEVEL_ONLY'
    $TrustAttributes+='0x00000001-NON_TRANSITIVE'
        
    $TrustResults=@()
    $Trusts=Get-ADObject -Filter "objectclass -eq 'trustedDomain'" -Properties *
    Foreach ($Trust in $Trusts)
    {
        $SidFiltering='No'
        $SelectiveAuthentication='No'
        $FLATNAME=$Trust.FlatName
        $DomainObject=Get-ADUser -Properties whenchanged,samaccounttype -filter "samaccounttype -eq '805306370' -and Name -eq '$FLATNAME$'"
        $PSobject=New-Object -typename PSCustomObject
    
        $TrustAttributeToConvert=$Trust.TrustAttributes
        $AttributeValueOutput=''
        $TrustAttributeBinary=[convert]::tostring($TrustAttributeToConvert,2).padleft(32,'0')
        
        for ($position=0;$position -lt 32;$position++)
        {
            $AttributeToSearch=$TrustAttributeBinary[$position]
            If ($AttributeToSearch -eq '1')
            {

            $ActualBinaryPosition=31-$position
            $Decimal=[math]::Pow(2,$ActualBinaryPosition)
            $Hex='0x'+([convert]::ToString($Decimal,16).padleft(8,'0'))
            $AttributeValueName=($TrustAttributes | Where-Object { $_ -match $Hex}).split('-')[1]
            If ($AttributeValueName -match 'SID_FILTERING') { $SidFiltering='Yes' } 
            If ($AttributeValueName -match 'CROSS_ORGANIZATION') { $SelectiveAuthentication='Yes' } 

	    $AttributeValueOutput=$AttributeValueName+' '+$AttributeValueOutput
            }
        }

	if ($FSPNetBios -match $Trust.Flatname) {$FSPFound=$True} else {$FSPFound=$False}

	$TrustTypeDetail=($TrustList | Where-object { $_.TargetName -eq $Trust.trustPartner -and $_.TrustDirection -eq $TrustDirection[$Trust.trustDirection]}).TrustType
        $PSobject | Add-Member -MemberType NoteProperty -Name Source -Value $CurrentDomain
        $PSobject | Add-Member -MemberType NoteProperty -Name TrustPartner -Value $Trust.trustPartner
        $PSobject | Add-Member -MemberType NoteProperty -Name TrustType -Value $Trusttype[($Trust.TrustType)-1]
        $PSobject | Add-Member -MemberType NoteProperty -Name TrustDirection -Value $TrustDirection[$Trust.trustDirection]
        $PSobject | Add-Member -MemberType NoteProperty -Name whencreated -Value $Trust.whenCreated
        $PSobject | Add-Member -MemberType NoteProperty -Name whenchanged -Value $Trust.whenChanged
        $PSobject | Add-Member -MemberType NoteProperty -Name DomainNetBiosName -Value $Trust.flatname
        $PSobject | Add-Member -MemberType NoteProperty -Name InstanceAttribute -Value 4
        $PSobject | Add-Member -MemberType NoteProperty -Name TrustAttributesValue -Value $Trust.TrustAttributes
        $PSobject | Add-Member -MemberType NoteProperty -Name pwdlastset -Value $Domainobject.whenchanged
        $PSobject | Add-Member -MemberType NoteProperty -Name TrustAttributes -Value $AttributeValueOutput
        $PSObject | Add-Member -MemberType NoteProperty -Name TrustTypeDetail -Value $TrustTypeDetail
        $PSobject | Add-Member -MemberType NoteProperty -Name ForeignSecurityPrinicipalFound -Value $FSPFound
        $PSObject | Add-Member -MemberType NoteProperty -Name SidFilteringEnabled -Value $SidFiltering
        $PSObject | Add-Member -MemberType NoteProperty -Name SelectiveAuthenticationEnabled -Value $SelectiveAuthentication

        $TrustResults+=$PSObject
    }
    $TrustResults
    $TrustResults | Export-CSV -Path .\$ENV:USERDNSDOMAIN-Trustdata.csv -NoTypeInformation
}
