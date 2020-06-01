#Requires -RunAsAdministrator
#Requires -Version 5.0
<#

.NOTES
Author: Greg Onstot
Version: 0.4
Version Date: 04/26/2019

The expectation is that you run these scripts on a separate Tier0 Tool server, to monitor your AD.  
It must be a Tier0 systems as the service account monitoring AD should be in Domain Admin to perform a number of these tasks.
This tool server must have the RSAT tools installed.  Run the following command to install the tools if you have not done so previously.
Add-WindowsFeature RSAT-AD-PowerShell,RSAT-AD-AdminCenter

Here are some references in case you are unfamiliar with the Tier Model:
https://docs.microsoft.com/en-us/windows-server/identity/securing-privileged-access/securing-privileged-access-reference-material
https://blogs.technet.microsoft.com/askpfeplat/2017/09/11/securing-privileged-access-for-the-ad-admin-part-1/
https://www.microsoft.com/en-us/download/details.aspx?id=36036
https://www.irongeek.com/i.php?page=videos/derbycon8/track-2-01-from-workstation-to-domain-admin-why-secure-administration-isnt-secure-and-how-to-fix-it-sean-metcalf


The service account must also be granted the Logon as Batch right.
If you don't want to configure that manually you can use a module like Carbon to grant the service account logon as a batch file:
http://get-carbon.org/about_Carbon_Installation.html
Import-Module .\Carbon\Carbon
Grant-Privilege -Identity Domain\ServiceAccount -Privilege SeBatchLogonRight
Grant-Privilege -Identity Domain\ServiceAccount -Privilege SeServiceLogonRight

alternatively you could use the following, or one of many other options:
https://gallery.technet.microsoft.com/scriptcenter/Grant-Revoke-Query-user-26e259b0

This is not an endorsement of those modules, just inclduing for awareness.

Updated: 06/01/2020
    Removed old commented out command lines for running as scripts
    Fixed Get-ADLastBackup to Get-ADLastBackupDate as that is the function name
    Change Test-ADObjectReplication from every 2 hours (12 new computer objects created and deleted daily) to daily (1 computer object daily)
    Added Register-ScheduledJob commands for the rest of the functions:
        Get-DCDiskSpace - hourly
        Test-ADServices - hourly
        Test-DCsOnline - hourly
        Test-ExternalDNSServers - hourly
        Test-SRVRecords - hourly
#>
#Create the EventLog Source here that will be used by all the other scripts, so they don't need to be run as administrator.
New-EventLog -LogName Application -Source "PSMonitor"

#Get user credential so that the job has access to the network
$cred = Get-Credential #-Credential DOMAIN\Serviceaccount

#Set job options
$opt = New-ScheduledJobOption -RunElevated -RequireNetwork 

#Items scheduled to run Daily
#Define the interval to repeat job
$trigger = New-JobTrigger -Once -At 6:00AM -RepetitionInterval (New-TimeSpan -Hours 24) -RepeatIndefinitely
Register-ScheduledJob -name Test-ADInternalTimeSync -Trigger $trigger -Credential $cred -ScriptBlock { (Import-Module -name PSADHealth) ; Test-ADInternalTimeSync }  -MaxResultCount 5 -scheduledjoboption $opt
Register-ScheduledJob -name Test-ADExternalTimeSync -Trigger $trigger -Credential $cred -ScriptBlock { (Import-Module -name PSADHealth) ; Test-ADExternalTimeSync }  -MaxResultCount 5 -scheduledjoboption $opt
Register-ScheduledJob -name Get-ADLastBackupDate -Trigger $trigger -Credential $cred -ScriptBlock { (Import-Module -name PSADHealth) ; Get-ADLastBackupDate }  -MaxResultCount 5 -scheduledjoboption $opt
#Shifting schedule half hour off
$trigger = New-JobTrigger -Once -At 6:30AM -RepetitionInterval (New-TimeSpan -Hours 24) -RepeatIndefinitely
Register-ScheduledJob -name Test-ADObectReplication  -Trigger $trigger -Credential $cred -ScriptBlock { (Import-Module -name PSADHealth) ; Test-ADObectReplication }  -MaxResultCount 5 -scheduledjoboption $opt

#Items scheduled to run hourly
$trigger = New-JobTrigger -Once -At 6:00AM -RepetitionInterval (New-TimeSpan -Hours 1) -RepeatIndefinitely
Register-ScheduledJob -name Test-ADReplication  -Trigger $trigger -Credential $cred -ScriptBlock { (Import-Module -name PSADHealth) ; Test-ADReplication }  -MaxResultCount 5 -scheduledjoboption $opt
Register-ScheduledJob -Name Get-DCDiskSpace -Trigger $trigger -Credential $cred -ScriptBlock { (Import-Module -name PSADHealth); Get-DCDiskSpace } -MaxResultCount 5 -scheduledjoboption $opt
Register-ScheduledJob -Name Test-ADServices -Trigger $trigger -Credential $cred -ScriptBlock { (Import-Module -name PSADHealth); Test-ADServices } -MaxResultCount 5 -scheduledjoboption $opt
Register-ScheduledJob -Name Test-DCsOnline -Trigger $trigger -Credential $cred -ScriptBlock { (Import-Module -name PSADHealth); Test-DCsOnline } -MaxResultCount 5 -scheduledjoboption $opt
Register-ScheduledJob -Name Test-ExternalDNSServers -Trigger $trigger -Credential $cred -ScriptBlock { (Import-Module -name PSADHealth); Test-ExternalDNSServers } -MaxResultCount 5 -scheduledjoboption $opt
Register-ScheduledJob -Name Test-SRVRecords -Trigger $trigger -Credential $cred -ScriptBlock { (Import-Module -name PSADHealth); Test-SRVRecords } -MaxResultCount 5 -scheduledjoboption $opt

#Items scheduled to run every two hours
$trigger = New-JobTrigger -Once -At 6:00AM -RepetitionInterval (New-TimeSpan -Hours 2) -RepeatIndefinitely
Register-ScheduledJob -name Test-SYSVOLReplication  -Trigger $trigger -Credential $cred -ScriptBlock { (Import-Module -name PSADHealth) ; Test-SYSVOLReplication }  -MaxResultCount 5 -scheduledjoboption $opt
