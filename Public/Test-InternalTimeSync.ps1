function Test-ADInternalTimeSync {
    [CmdletBinding()]
    Param()
    <#
    .SYNOPSIS
    Monitor AD Internal Time Sync
    
    .DESCRIPTION
    This script monitors DCs for Time Sync Issues

    .EXAMPLE
    Run as a scheduled task.  Use Event Log consolidation tools to pull and alert on issues found.

    .EXAMPLE
    Run in verbose mode if you want on-screen feedback for testing
   
    .NOTES
    Authors: Mike Kanakos, Greg Onstot
    Version: 0.8.1
    Version Date: 4/18/2019
    
    Event Source 'PSMonitor' will be created

    EventID Definition:
    17030 - Failure
    17031 - Beginning of test
    17032 - Testing individual systems
    17033 - End of test
    17034 - Alert Email Sent
    17035 - Automated Repair Attempted
    #>

    Begin {
        Import-Module activedirectory
        $CurrentFailure = $null
        $null = Get-ADConfig
        $SupportArticle = $Configuration.SupportArticle
        $SlackToken = $Configuration.SlackToken
        if (!([System.Diagnostics.EventLog]::SourceExists("PSMonitor"))) {
            write-verbose "Adding Event Source."
            New-EventLog -LogName Application -Source "PSMonitor"
        }#end if
        $DClist = (Get-ADDomainController -Filter *).name  # For ALL DCs
        $PDCEmulator = (Get-ADDomainController -Discover -Service PrimaryDC).name
        $MaxTimeDrift = $Configuration.MaxIntTimeDrift

        $beginEventLog = @{
            LogName   = "Application"
            Source    = "PSMonitor"
            EventID   = 17031
            EntryType = "Information"
            Message   = "START of Internal Time Sync Test Cycle."
            Category  = "17031"
        }

        Write-eventlog  @beginEventLog

    }#End Begin

    Process {

        Foreach ($server in $DClist) {
            
            Write-eventlog -logname "Application" -Source "PSMonitor" -EventID 17032 -EntryType Information -message "CHECKING Internal Time Sync on Server - $server" -category "17032"
            Write-Verbose "CHECKING - $server"
            
            $OutputDetails = $null
            $Remotetime = ([WMI]'').ConvertToDateTime((Get-WmiObject -Class win32_operatingsystem -ComputerName $server).LocalDateTime)
            $Referencetime = ([WMI]'').ConvertToDateTime((Get-WmiObject -Class win32_operatingsystem -ComputerName $PDCEmulator).LocalDateTime)
            $result = (New-TimeSpan -Start $Referencetime -End $Remotetime).Seconds
            Write-Verbose "$server - Offset:  $result - Time:$Remotetime  - ReferenceTime: $Referencetime"
            
            #If result is a negative number (ie -6 seconds) convert to positive number
            # for easy comparison
            If ($result -lt 0) {
                 
                $result = $result * (-1)
            
            }
                
            #test if result is greater than max time drift
            If ($result -gt $MaxTimeDrift) {
                $emailOutput = "$server - Offset:  $result - Time:$Remotetime  - ReferenceTime: $Referencetime `r`n "
                Write-Verbose "ALERT - Time drift above maximum allowed threshold on - $server - $emailOutput"
                Write-eventlog -logname "Application" -Source "PSMonitor" -EventID 17030 -EntryType Warning -message "FAILURE time drift above maximum allowed on $emailOutput `r`n " -category "17030"
                    
                #attempt to automatically fix the issue
                Invoke-Command -ComputerName $server -ScriptBlock { 'w32tm /resync' }
                Write-eventlog -logname "Application" -Source "PSMonitor" -EventID 17035 -EntryType Information -message "REPAIR Remediation script was attempted `r`n " -category "17035"
                CurrentFailure = $true
                Send-Mail $emailOutput
                Write-Verbose "Sending Slack Alert"
                New-SlackPost "Alert - Time drift above max threashold - $emailOutput"
            }#end if
            If (!$CurrentFailure) {
                Write-Verbose "No Issues found in this run"
                $InError = Get-EventLog application -After (Get-Date).AddHours(-24) | where {($_.InstanceID -Match "17030")} 
                $errtext = $InError |out-string
                If ($errtext -like "*$server*") {
                    Write-Verbose "Previous Errors Seen"
                    #Previous run had an alert
                    #No errors foun during this test so send email that the previous error(s) have cleared
                    Send-AlertCleared
                    Write-Verbose "Sending Slack Message - Alert Cleared"
                    New-SlackPost "The previous alert, for AD Internal Time Sync, has cleared."
                    #Write-Output $InError
                }#End if

            }#End if

        }#End Foreach

    }#End Process
    
    End {
        Write-eventlog -logname "Application" -Source "PSMonitor" -EventID 17033 -EntryType Information -message "END of Internal Time Sync Test Cycle ." -category "17033"
    }#End End

}#End Function