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
   
    .NOTES
    Authors: Mike Kanakos, Greg Onstot
    Version: 0.7.1
    Version Date: 4/18/2019
        
    Event Source 'PSMonitor' will be created

    EventID Definition:
    17040 - Failure
    17041 - Beginning of test
    17042 - Testing individual systems
    17043 - End of test
    17044 - Alert Email Sent
    17045 - Automated Repair Attempted
    #>

    Begin {
        Import-Module activedirectory
        $CurrentFailure = $null
        $null = Get-ADConfig
        if (![System.Diagnostics.EventLog]::SourceExists("PSMonitor")) {
            write-verbose "Adding Event Source."
            New-EventLog -LogName Application -Source "PSMonitor"
        }#end if

        #$DClist = (Get-ADGroupMember -Identity 'Domain Controllers').name  #For RWDCs only, RODCs are not in this group.
        $PDCEmulator = (Get-ADDomainController -Discover -Service PrimaryDC).name
        $ExternalTimeSvr = $Configuration.ExternalTimeSvr
        $MaxTimeDrift = $Configuration.MaxExtTimeDrift
        Write-eventlog -logname "Application" -Source "PSMonitor" -EventID 17041 -EntryType Information -message "START of External Time Sync Test Cycle ." -category "17041"
    }#End Begin

    Process {
        
        $PDCeTime = ([WMI]'').ConvertToDateTime((Get-WmiObject -Class win32_operatingsystem -ComputerName $PDCEmulator).LocalDateTime)
        $ExternalTime = (w32tm /stripchart /dataonly /computer:$ExternalTimeSvr /samples:1)[-1].split("[")[0]
        $ExternalTimeOutput = [Regex]::Match($ExternalTime, "\d+\:\d+\:\d+").value
        $result = (New-TimeSpan -Start $ExternalTimeOutput -End $PDCeTime).Seconds
        
        $emailOutput = "$PDCEmulator - Offset:  $result - Time:$PDCeTime  - ReferenceTime: $ExternalTimeOutput `r`n "
        
        Write-Verbose "ServerName $PDCEmulator - Offset: $result - ExternalTime: $ExternalTimeOutput - PDCE Time: $PDCeTime"
        Write-eventlog -logname "Application" -Source "PSMonitor" -EventID 17042 -EntryType Information -message "CHECKING External Time Sync on Server - $PDCEmulator - $emailOutput" -category "17042"

        #If result is a negative number (ie -6 seconds) convert to positive number
        # for easy comparison
        If ($result -lt 0) { $result = $result * (-1)}
        #test if result is greater than max time drift
        If ($result -gt $MaxTimeDrift) {
            
            Write-Verbose "ALERT - Time drift above maximum allowed threshold on - $server - $emailOutput"
            Write-eventlog -logname "Application" -Source "PSMonitor" -EventID 17040 -EntryType Warning -message "FAILURE External time drift above maximum allowed on $emailOutput `r`n " -category "17040"
            
            #attempt to automatically fix the issue
            Invoke-Command -ComputerName $server -ScriptBlock { 'w32tm /resync' }
            Write-eventlog -logname "Application" -Source "PSMonitor" -EventID 17045 -EntryType Information -message "REPAIR External Time Sync Remediation was attempted `r`n " -category "17045"
            $CurrentFailure = $true
            
            
            $mailParams = @{
                To = $Configuration.MailTo
                From = $Configuration.MailFrom
                SmtpServer = $Configuration.SmtpServer
                Subject = $"AD External Time Sync Alert!"
                Body = $emailOutput
                BodyAsHtml = $true
            }

            Send-MailMessage @mailParams

        }#end if
        If (!$CurrentFailure) {
            Write-Verbose "No Issues found in this run"
            $InError = Get-EventLog application -After (Get-Date).AddHours(-24) | where {($_.InstanceID -Match "17040")} 
            $errtext = $InError |out-string
            If ($errtext -like "*$server*") {
                Write-Verbose "Previous Errors Seen"
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
                Write-Verbose "Sending Slack Message - Alert Cleared"
            
            }#End if
       
        }#End if
    }#End Process
    
    End {
        Write-eventlog -logname "Application" -Source "PSMonitor" -EventID 17043 -EntryType Information -message "END of External Time Sync Test Cycle ." -category "17043"
        
    }#End End
    
}#End Function