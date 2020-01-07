# Find computer objects in AD that have a value in the Operating System attribute that is from an unsupported objects


Get-ADcomputer -Filter {(operatingsystem -like "*xp*") -or 
                        (operatingsystem -like "*vista*") -or 
                        (operatingsystem -like "*Windows NT*")-or 
                        (operatingsystem -like "*2000*") -or 
                        (operatingsystem -like "*2003*") -or
                        (operatingsystem -like "*2008*") -or
                        (operatingsystem -like "*Windows 7*")} `
                        -Property Name,OperatingSystem,lastlogontimestamp,enabled | Format-Table Name,OperatingSystem,enabled,@{name="lastlogontimestamp"; expression={[datetime]::fromfiletime($_.lastlogontimestamp)}} -Wrap -AutoSize
