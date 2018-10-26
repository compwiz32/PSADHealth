<#.NOTES
Author: Greg Onstot
Version: 0.1
Version Date: 10/25/2018
#>

#Automate granting the service account logon as a batch file using Carbon
#http://get-carbon.org/about_Carbon_Installation.html
Import-Module .\Carbon\Carbon
Grant-Privilege -Identity <DOMAIN>\<ServiceAccount> -Privilege SeBatchLogonRight
#Grant-Privilege -Identity <DOMAIN>\<ServiceAccount> -Privilege SeServiceLogonRight

#Define the interval to repeat job
$trigger = New-JobTrigger -Once -At 6:00AM -RepetitionInterval (New-TimeSpan -Hours 24) -RepeatIndefinitely

#Get user credential so that the job has access to the network
$cred = Get-Credential -Credential <DOMAIN>\<ServiceAccount>

#Set job options
$opt = New-ScheduledJobOption -RunElevated -RequireNetwork 

#schedule the monitoring scripts:
Register-ScheduledJob -Name Test-InternalTimeSync -Trigger $trigger -Credential $cred -FilePath "C:\Scripts\Test-ADTimeSync.ps1" -MaxResultCount 5 -scheduledjoboption $opt
Register-ScheduledJob -Name Test-ExternalTimeSync -Trigger $trigger -Credential $cred -FilePath "C:\Scripts\Test-ADTimeSyncToExternalNTP.ps1" -MaxResultCount 5 -scheduledjoboption $opt
Register-ScheduledJob -Name Test-ADLastBackup -Trigger $trigger -Credential $cred -FilePath "C:\Scripts\Test-ADLastBackupDate.ps1" -MaxResultCount 5 -scheduledjoboption $opt

$trigger = New-JobTrigger -Once -At 6:00AM -RepetitionInterval (New-TimeSpan -Hours 1) -RepeatIndefinitely
Register-ScheduledJob -Name Test-ADReplication -Trigger $trigger -Credential $cred -FilePath "C:\Scripts\Test-ADReplication.ps1" -MaxResultCount 5 -scheduledjoboption $opt

$trigger = New-JobTrigger -Once -At 6:00AM -RepetitionInterval (New-TimeSpan -Hours 2) -RepeatIndefinitely
Register-ScheduledJob -Name Test-ADSYSVOLReplication -Trigger $trigger -Credential $cred -FilePath "C:\Scripts\Test-SYSVOL-Replication.ps1" -MaxResultCount 5 -scheduledjoboption $opt
