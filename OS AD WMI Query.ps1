#Queries AD looking for computer objects that show an OS value of *2008*
#Then looks up its IP address and performs a WMI query against the object to determine its actual OS value
#Outputs to a csv file


function Get-ComputerInformation {
    [cmdletbinding()]
    param (
        [Parameter(Mandatory = $true)]
        [String]$computerName
    )
    
    Write-Host `n"Looking up information for: [$computerName]"`n
    $IPAddress = $null
    $WMIOS = $null

    $tipadd = (Resolve-DnsName $computername -ErrorAction SilentlyContinue).IPAddress
    if ($tipadd) {
        $IPAddress = $tipadd
        $tWMIOS = (Get-WmiObject -ComputerName $computername Win32_OperatingSystem -ErrorAction SilentlyContinue ).Caption
        if ($tWMIOS) {$WMIOS = $tWMIOS }
        else {$WMIOS = "Unable to detect."} }
    else { 
        $IPAddress = "Not Found"
        $WMIOS = "Unable to detect." }

    #Create the object, cleanly!
    $computerObject = [PSCustomObject]@{
        ComputerName = $computerName
        IPAddress = $IPAddress
        WMIOS = $WMIOS
   }
   Return $computerObject
}

[System.Collections.ArrayList]$computerArray = @()
$InactiveDays = 30
$day = (Get-Date).AddDays(-($InactiveDays))
$computers = get-adcomputer -filter {(OperatingSystem -like "*2008*") -and (LastLogonTimeStamp -gt $day)} -Properties OperatingSystem

ForEach($computer in $computers) {
    $computerArray.Add((Get-ComputerInformation -computerName $computer.DNSHostName)) | Out-Null
}

$computerArray | Export-csv computergrid.csv -NoTypeInformation
