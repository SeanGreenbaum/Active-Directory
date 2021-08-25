'-------fixfsmo.vbs------------------
const ADS_NAME_INITTYPE_GC = 3
const ADS_NAME_TYPE_1779 = 1
const ADS_NAME_TYPE_CANONICAL = 2

set inArgs = WScript.Arguments

if (inArgs.Count = 1) then
    ' Assume the command line argument is the NDNC (in DN form) to use.
    NdncDN = inArgs(0)
Else
    Wscript.StdOut.Write "usage: cscript fixfsmo.vbs NdncDN"
End if

if (NdncDN <> "") then

    ' Convert the DN form of the NDNC into DNS dotted form.
    Set objTranslator = CreateObject("NameTranslate")
    objTranslator.Init ADS_NAME_INITTYPE_GC, ""
    objTranslator.Set ADS_NAME_TYPE_1779, NdncDN
    strDomainDNS = objTranslator.Get(ADS_NAME_TYPE_CANONICAL)
    strDomainDNS = Left(strDomainDNS, len(strDomainDNS)-1)
     
    Wscript.Echo "DNS name: " & strDomainDNS

    ' Find a domain controller that hosts this NDNC and that is online.
    set objRootDSE = GetObject("LDAP://" & strDomainDNS & "/RootDSE")
    strDnsHostName = objRootDSE.Get("dnsHostName")
    strDsServiceName = objRootDSE.Get("dsServiceName")
    Wscript.Echo "Using DC " & strDnsHostName

    ' Get the current infrastructure fsmo.
    strInfraDN = "CN=Infrastructure," & NdncDN
    set objInfra = GetObject("LDAP://" & strInfraDN)
    Wscript.Echo "infra fsmo is " & objInfra.fsmoroleowner

    ' If the current fsmo holder is deleted, set the fsmo holder to this domain controller.

    if (InStr(objInfra.fsmoroleowner, "\0ADEL:") > 0) then

        ' Set the fsmo holder to this domain controller.
        objInfra.Put "fSMORoleOwner",  strDsServiceName
        objInfra.SetInfo

        ' Read the fsmo holder back.
        set objInfra = GetObject("LDAP://" & strInfraDN)
        Wscript.Echo "infra fsmo changed to:" & objInfra.fsmoroleowner

    End if

End if
