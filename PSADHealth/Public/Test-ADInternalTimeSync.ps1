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
    Version: 0.8.2
    Version Date: 4/18/2019
    
    Event Source 'PSMonitor' will be created

    EventID Definition:
    17030 - Failure
    17031 - Beginning of test
    17032 - Testing individual systems
    17033 - End of test
    17034 - Alert Email Sent
    17035 - Automated Repair Attempted

    Updated: 05/29/2020
        Silenced the import of ActiveDirectory module because we don't really want to see that
        Added "Silently loaded ActiveDirectory module" statement in its place
        Primarily adding -Message for good code hygiene and expanding any aliases
        Added a few extra Verbose statements
        Disabled the Slack Notification since that isn't enabled in any of the other functions
        Send-AlertCleared was not passing the $InError variable (I think this is a Script to Function issue). Corrected
    #>

    Begin {
        Import-Module ActiveDirectory -Verbose:$false
        Write-Verbose -Message "Silently loaded ActiveDirectory module"
        $CurrentFailure = $null
        $null = Get-ADConfig
        $SupportArticle = $Configuration.SupportArticle
        $SlackToken = $Configuration.SlackToken
        if (-not ([System.Diagnostics.EventLog]::SourceExists("PSMonitor"))) {
            write-verbose -Message "Adding Event Source."
            New-EventLog -LogName Application -Source "PSMonitor"
        }#end if
        $DClist = (Get-ADDomainController -Filter *).name  # For ALL DCs
        Write-Verbose -Message "DCList: $DCList"
        $PDCEmulator = (Get-ADDomainController -Discover -Service PrimaryDC).name
        Write-Verbose -Message "PDC Emulator: $PDCEmulator"
        $MaxTimeDrift = $Configuration.MaxIntTimeDrift
        Write-Verbose -Message "Maximum Time Drift: $MaxTimeDrift"

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
            Write-Verbose -Message "CHECKING - $server"
            
            $OutputDetails = $null
            $Remotetime = ([WMI]'').ConvertToDateTime((Get-WmiObject -Class win32_operatingsystem -ComputerName $server).LocalDateTime)
            $Referencetime = ([WMI]'').ConvertToDateTime((Get-WmiObject -Class win32_operatingsystem -ComputerName $PDCEmulator).LocalDateTime)
            $result = (New-TimeSpan -Start $Referencetime -End $Remotetime).Seconds
            Write-Verbose -Message "$server - Offset:  $result - Time:$Remotetime  - ReferenceTime: $Referencetime"
            
            #If result is a negative number (ie -6 seconds) convert to positive number
            # for easy comparison
            If ($result -lt 0) {
                 
                $result = $result * (-1)
            
            }
                
            #test if result is greater than max time drift
            If ($result -gt $MaxTimeDrift) {
                $emailOutput = "$server - Offset:  $result - Time:$Remotetime  - ReferenceTime: $Referencetime `r`n "
                Write-Verbose -Message "ALERT - Time drift above maximum allowed threshold on - $server - $emailOutput"
                Write-eventlog -logname "Application" -Source "PSMonitor" -EventID 17030 -EntryType Warning -message "FAILURE Internal time drift above maximum allowed on $emailOutput `r`n " -category "17030"
                    
                #attempt to automatically fix the issue
                Invoke-Command -ComputerName $server -ScriptBlock { 'w32tm /resync' }
                Write-eventlog -logname "Application" -Source "PSMonitor" -EventID 17035 -EntryType Information -message "REPAIR Internal Time Sync remediation was attempted `r`n " -category "17035"
                $CurrentFailure = $true
                Send-Mail $emailOutput
                Write-Verbose -Message "Sent email notification for Internal Time Sync Discrepancy"
                #Write-Verbose -Message "Sending Slack Alert"
                #New-SlackPost "Alert - Internal Time drift above max threashold - $emailOutput"
            }#end if
            If (-not $CurrentFailure) {
                Write-Verbose "No Issues found in this run"
                $InError = Get-EventLog application -After (Get-Date).AddHours(-24) | where {($_.InstanceID -Match "17030")} 
                $errtext = $InError | Out-String
                Write-Verbose -Message "$errtext"
                If ($errtext -like "*$server*") {
                    Write-Verbose -Message "Previous Errors Seen"
                    #Previous run had an alert
                    #No errors foun during this test so send email that the previous error(s) have cleared
                    Send-AlertCleared -InError $InError
                    Write-Verbose -Message "Sent Alert Cleared notification for Internal Time Sync Discrepancy recovery"
                    #Write-Verbose -Message "Sending Slack Message - Alert Cleared"
                    #New-SlackPost "The previous alert, for AD Internal Time Sync, has cleared."
                    #Write-Output $InError
                }#End if

            }#End if

        }#End Foreach

    }#End Process
    
    End {
        Write-Verbose -Message "Finished processing all Domain Controllers for Internal Time Sync"
        Write-eventlog -logname "Application" -Source "PSMonitor" -EventID 17033 -EntryType Information -message "END of Internal Time Sync Test Cycle ." -category "17033"
    }#End End

}#End Function