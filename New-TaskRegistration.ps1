#Requires -RunAsAdministrator
<#

.NOTES
Author: Greg Onstot
Version: 0.2
Version Date: 10/31/2018

The expectation is that you run these scripts on a separate Tier0 Tool server, to monitor your AD.  
It must be a Tier0 systems as the service account monitoring AD should be in Domain Admin to perform a number of these tasks.

Here are some references in case you are unfamiliar with the Tier Model:
https://docs.microsoft.com/en-us/windows-server/identity/securing-privileged-access/securing-privileged-access-reference-material
https://blogs.technet.microsoft.com/askpfeplat/2017/09/11/securing-privileged-access-for-the-ad-admin-part-1/
https://www.microsoft.com/en-us/download/details.aspx?id=36036
https://www.irongeek.com/i.php?page=videos/derbycon8/track-2-01-from-workstation-to-domain-admin-why-secure-administration-isnt-secure-and-how-to-fix-it-sean-metcalf


The service account must also be granted the Logon as Batch right.
If you don't want to configure that manually you can use a module like Carbon to grant the service account logon as a batch file:
http://get-carbon.org/about_Carbon_Installation.html
Import-Module .\Carbon\Carbon
Grant-Privilege -Identity starbucksdev\s-adscan -Privilege SeBatchLogonRight
Grant-Privilege -Identity starbucksdev\s-adscan -Privilege SeServiceLogonRight

alternatively you could use the following, or one of many other options:
https://gallery.technet.microsoft.com/scriptcenter/Grant-Revoke-Query-user-26e259b0

This is not an endorsement of those modules, just inclduing for awareness.
#>
#Create the EventLog Source here that will be used by all the other scripts, so they don't need to be run as administrator.
New-EventLog -LogName Application -Source "PSMonitor"

#Define the interval to repeat job
$trigger = New-JobTrigger -Once -At 6:00AM -RepetitionInterval (New-TimeSpan -Hours 24) -RepeatIndefinitely

#Get user credential so that the job has access to the network
$cred = Get-Credential -Credential DOMAIN\Serviceaccount

#Set job options
$opt = New-ScheduledJobOption -RunElevated -RequireNetwork 

Register-ScheduledJob -Name Test-InternalTimeSync -Trigger $trigger -Credential $cred -FilePath "C:\Scripts\Test-ADTimeSync.ps1" -MaxResultCount 5 -scheduledjoboption $opt
Register-ScheduledJob -Name Test-ExternalTimeSync -Trigger $trigger -Credential $cred -FilePath "C:\Scripts\Test-ADTimeSyncToExternalNTP.ps1" -MaxResultCount 5 -scheduledjoboption $opt
Register-ScheduledJob -Name Test-ADLastBackup -Trigger $trigger -Credential $cred -FilePath "C:\Scripts\Test-ADLastBackupDate.ps1" -MaxResultCount 5 -scheduledjoboption $opt

$trigger = New-JobTrigger -Once -At 6:00AM -RepetitionInterval (New-TimeSpan -Hours 1) -RepeatIndefinitely
Register-ScheduledJob -Name Test-ADReplication -Trigger $trigger -Credential $cred -FilePath "C:\Scripts\Test-ADReplication.ps1" -MaxResultCount 5 -scheduledjoboption $opt

$trigger = New-JobTrigger -Once -At 6:30AM -RepetitionInterval (New-TimeSpan -Hours 2) -RepeatIndefinitely
Register-ScheduledJob -Name Test-ADObectReplication -Trigger $trigger -Credential $cred -FilePath "C:\Scripts\Test-ADObjectReplication.ps1" -MaxResultCount 5 -scheduledjoboption $opt

$trigger = New-JobTrigger -Once -At 6:00AM -RepetitionInterval (New-TimeSpan -Hours 2) -RepeatIndefinitely
Register-ScheduledJob -Name Test-ADSYSVOLReplication -Trigger $trigger -Credential $cred -FilePath "C:\Scripts\Test-SYSVOL-Replication.ps1" -MaxResultCount 5 -scheduledjoboption $opt
