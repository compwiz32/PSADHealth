<#A simplified re-write of a script published by Jorge de Almeida Pinto, to be used as a non-interactive monitoring/alerting script.

The original can be found here:
https://jorgequestforknowledge.wordpress.com/2014/02/17/testing-sysvol-replication-latencyconvergence-through-powershell-update-3/

#>

$continue = $true
$domainname = (Get-ADDomain).dnsroot
$DCList = (Get-ADDomainController -Filter *).name
$SourceSystem = (Get-ADDomain).pdcemulator

if (Test-NetConnection $SourceSystem -Port 445) {
    Write-Output 'PDCE is online'
    $TempObjectLocation = "\\$SourceSystem\SYSVOL\$domainname\Scripts"
    $tempObjectName = "sysvolReplTempObject" + (Get-Date -f yyyyMMddHHmmss) + ".txt"
    "...!!!...TEMP OBJECT TO TEST AD REPLICATION LATENCY/CONVERGENCE...!!!..." | Out-File -FilePath $($TempObjectLocation + "\" + $tempObjectName)
    $startDateTime = Get-Date
    $i = 0
}
else {
    Write-Output 'PDCE is offline.  You should really resolve that before continuing.'
    break
}

While ($continue) {
    $i++
    Start-Sleep 60
    $replicated = $true
    Write-Output "Cycle - $i"

    Foreach ($dc in $DCList) {
        if (Test-NetConnection $dc -Port 445) {
            Write-Output "Online - $dc"
            $objectPath = "\\$dc\SYSVOL\$domainname\Scripts\$tempObjectName"
            $connectionResult = "SUCCESS"
        }
        else {
            Write-Output "!!!!!OFFLINE - $dc !!!!!"
            $connectionResult = "FAILURE"
        }
        # If The Connection To The DC Is Successful
        If ($connectionResult -eq "SUCCESS") {
            If (Test-Path -Path $objectPath) {
                # If The Temp Object Already Exists
                Write-Host "     - Object [$tempObjectName] Now Does Exist In The NetLogon Share" (" " * 3) -ForeGroundColor Green
            }
            Else {
                # If The Temp Object Does Not Yet Exist
                Write-Host "     - Object [$tempObjectName] Does NOT Exist Yet In The NetLogon Share" -ForeGroundColor Red
                $replicated = $false
            }
        }
		
        # If The Connection To The DC Is Unsuccessful
        If ($connectionResult -eq "FAILURE") {
            Write-Host "     - Unable To Connect To DC/GC And Check For The Temp Object..." -ForeGroundColor Red
        }
    }
    If ($replicated) {
        $continue = $false
    } 

    If ($i -gt 50) {
        $continue = $false
        Write-Output "Cycle has run 50 times, and replication hasn't finished.  Need to generate an alert."
    } 

}	

# Show The Start Time, The End Time And The Duration Of The Replication
$endDateTime = Get-Date
$duration = "{0:n2}" -f ($endDateTime.Subtract($startDateTime).TotalSeconds)
Write-Host "`n  Start Time......: $(Get-Date $startDateTime -format "yyyy-MM-dd HH:mm:ss")" -ForeGroundColor Yellow
Write-Host "  End Time........: $(Get-Date $endDateTime -format "yyyy-MM-dd HH:mm:ss")" -ForeGroundColor Yellow
Write-Host "  Duration........: $duration Seconds" -ForeGroundColor Yellow

# Delete The Temp Object On The RWDC
Write-Host "  Deleting Temp Text File... `n" -ForeGroundColor Yellow
Remove-Item "$TempObjectLocation\$tempObjectName" -Force
Write-Host "  Temp Text File [$tempObjectName] Has Been Deleted On The Source System `n" -ForeGroundColor Yellow

# Output The Table [B] Containing The Information Of Each Directory Server And How Long It Took To Reach That Directory Server After The Creation On The Source RWDC
$TableOfDSServersB | Sort-Object Time | FT -AutoSize
