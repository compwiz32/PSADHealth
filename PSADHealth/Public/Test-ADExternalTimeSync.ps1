function Test-ADExternalTimeSync {
    [CmdletBinding()]
    Param()
    <#
    .SYNOPSIS
    Monitor AD External Time Sync
    
    .DESCRIPTION
    This script monitors External NTP to the PDCE for Time Sync Issues

    .EXAMPLE
    Run as a scheduled task.  Use Event Log consolidation tools to pull and alert on issues found.

    .EXAMPLE
    Run in verbose mode if you want on-screen feedback for testing

    .EXAMPLE
    PS C:\> $trigger = New-JobTrigger -Once -At 6:00AM -RepetitionInterval (New-TimeSpan -Hours 24) -RepeatIndefinitely
    PS C:\> $cred = Get-Credential DOMAIN\ServiceAccount
    PS C:\> $opt = New-ScheduledJobOption -RunElevated -RequireNetwork
    PS C:\> Register-ScheduledJob -Name Test-ADExternalTimeSync -Trigger $trigger -Credential $cred -ScriptBlock {(Import-Module -Name PSADHealth); Test-ADExternalTimeSync} -MaxResultCount 5 -ScheduledJobOption $opt

    Creates a scheduled task to run Test-ADExternalTimeSync on a daily basis. NOTE: Service account needs to be a Domain Admin or equivalent (Tier0) and must have the RunAsBatch and RunAsService privilege


    .NOTES
    Authors: Mike Kanakos, Greg Onstot
    Version: 0.7.2
    Version Date: 4/18/2019
        
    Event Source 'PSMonitor' will be created

    EventID Definition:
    17040 - Failure
    17041 - Beginning of test
    17042 - Testing individual systems
    17043 - End of test
    17044 - Alert Email Sent
    17045 - Automated Repair Attempted

    Updated: 05/29/2020
        Silenced the import of ActiveDirectory module because we don't really want to see that
        Added "Silently loaded ActiveDirectory module" statement in its place
        Primarily adding -Message for good code hygiene and expanding any aliases
        File name verse function name is inconsistent. Renamed file to be consistent with function name
        The CurrentFailure notification piece isn't working. I am getting notification every time the script runs that it is no longer failing
        The reason is because it was checking for $server in the error text and it should have been $PDCEmulator. Corrected
    #>

    Begin {
        Import-Module ActiveDirectory -Verbose:$false
        Write-Verbose -Message "Silently loaded ActiveDirectory module"
        $CurrentFailure = $null
        $null = Get-ADConfig
        if (-not ([System.Diagnostics.EventLog]::SourceExists("PSMonitor"))) {
            write-verbose -Message "Adding Event Source."
            New-EventLog -LogName Application -Source "PSMonitor"
        }#end if

        #$DClist = (Get-ADGroupMember -Identity 'Domain Controllers').name  #For RWDCs only, RODCs are not in this group.
        $PDCEmulator = (Get-ADDomainController -Discover -Service PrimaryDC).name
        Write-Verbose -Message "PDC Emulator        : $PDCEmulator"
        $ExternalTimeSvr = $Configuration.ExternalTimeSvr
        Write-Verbose -Message "External Time Server: $ExternalTimeSvr"
        $MaxTimeDrift = $Configuration.MaxExtTimeDrift
        Write-Verbose -Message "Maximum Time Drift  : $MaxTimeDrift"
        Write-eventlog -logname "Application" -Source "PSMonitor" -EventID 17041 -EntryType Information -message "START of External Time Sync Test Cycle ." -category "17041"
    }#End Begin

    Process {
        
        $PDCeTime = ([WMI]'').ConvertToDateTime((Get-WmiObject -Class win32_operatingsystem -ComputerName $PDCEmulator).LocalDateTime)
        $ExternalTime = (w32tm /stripchart /dataonly /computer:$ExternalTimeSvr /samples:1)[-1].split("[")[0]
        $ExternalTimeOutput = [Regex]::Match($ExternalTime, "\d+\:\d+\:\d+").value
        $result = (New-TimeSpan -Start $ExternalTimeOutput -End $PDCeTime).Seconds

        $emailOutput = "$PDCEmulator - Offset:  $result - Time:$PDCeTime  - ReferenceTime: $ExternalTimeOutput `r`n "
        
        Write-Verbose -Message "ServerName $PDCEmulator - Offset: $result - ExternalTime: $ExternalTimeOutput - PDCE Time: $PDCeTime"
        Write-eventlog -logname "Application" -Source "PSMonitor" -EventID 17042 -EntryType Information -message "CHECKING External Time Sync on Server - $PDCEmulator - $emailOutput" -category "17042"

        #If result is a negative number (ie -6 seconds) convert to positive number
        # for easy comparison
        If ($result -lt 0) { $result = $result * (-1)}
        #test if result is greater than max time drift
        If ($result -gt $MaxTimeDrift) {
            
            Write-Verbose -Message "ALERT - Time drift above maximum allowed threshold on - $server - $emailOutput"
            Write-eventlog -logname "Application" -Source "PSMonitor" -EventID 17040 -EntryType Warning -message "FAILURE External time drift above maximum allowed on $emailOutput `r`n " -category "17040"
            
            #attempt to automatically fix the issue
            Invoke-Command -ComputerName $server -ScriptBlock { 'w32tm /resync' }
            Write-eventlog -logname "Application" -Source "PSMonitor" -EventID 17045 -EntryType Information -message "REPAIR External Time Sync Remediation was attempted `r`n " -category "17045"
            $CurrentFailure = $true
            
            
            $mailParams = @{
                To = $Configuration.MailTo
                From = $Configuration.MailFrom
                SmtpServer = $Configuration.SmtpServer
                Subject = "AD External Time Sync Alert!"
                Body = $emailOutput
                BodyAsHtml = $true
            }

            Send-MailMessage @mailParams
            Write-Verbose -Message "Sent email notification for External Time Sync discrepancy"
            #Write-Verbose "Sending Slack Alert"
            #New-SlackPost "Alert - External Time drift above max threashold - $emailOutput"

        }#end if
#<#
        If (-not $CurrentFailure) {
            Write-Verbose -Message "No Issues found in this run"
            $InError = Get-EventLog application -After (Get-Date).AddHours(-24) | Where-Object {($_.InstanceID -Match "17040")} 
            $errtext = $InError | Out-String
            Write-Verbose -Message "$errtext"
            If ($errtext -like "*$PDCEmulator*") {
                Write-Verbose -Message "Previous Errors Seen"
                #Previous run had an alert
                #No errors foun during this test so send email that the previous error(s) have cleared
                
                
                
                $alertParams = @{

                    To = $Configuration.MailTo
                    From = $Configuration.MailFrom
                    SmtpServer = $Configuration.SmtpServer
                    Subject = "AD External Time Sync - Alert Cleared!"
                    Body = "The previous alert for AD External Time Sync has now cleared."
                    BodyAsHtml = $true

                }
                
                Send-MailMessage @alertParams
                Write-Verbose -Message "Sent email notification for External Time Sync recovery"
                #Write-Verbose "Sending Slack Message - Alert Cleared"
                #New-SlackPost "The previous alert, for AD External Time Sync, has cleared."
            
            }#End if
       
        }#End if
#>
    }#End Process
    
    End {
        Write-Verbose -Message "Finished validating External Time Sync"
        Write-eventlog -logname "Application" -Source "PSMonitor" -EventID 17043 -EntryType Information -message "END of External Time Sync Test Cycle ." -category "17043"
        
    }#End End
    
}#End Function