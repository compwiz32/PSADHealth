
function Copy-Files ($scriptToDeploy)
{
    $targets = Get-Content "C:\Scripts\RemotePSMonitorServers.txt"
    
    foreach ($Server in $Targets)
    {
        Write-output "Copying to $Server..."
        Copy-Item  $scriptToDeploy -Destination "\\$Server\Scripts\"
    }
    
}

$scriptToDeploy = "C:\Scripts\Test-ADReplication.ps1"
Copy-Files $scriptToDeploy

$scriptToDeploy = "C:\Scripts\ADConfig.json"
Copy-Files $scriptToDeploy

$scriptToDeploy = "C:\Scripts\Test-ADLastBackupDate.ps1"
Copy-Files $scriptToDeploy

$scriptToDeploy = "C:\Scripts\Test-ADObjectReplication.ps1"
Copy-Files $scriptToDeploy

$scriptToDeploy = "C:\Scripts\Test-ADTimeSync.ps1"
Copy-Files $scriptToDeploy

$scriptToDeploy = "C:\Scripts\Test-ADTimeSyncToExternalNTP.ps1"
Copy-Files $scriptToDeploy

$scriptToDeploy = "C:\Scripts\Test-SYSVOL-Replication.ps1"
Copy-Files $scriptToDeploy
