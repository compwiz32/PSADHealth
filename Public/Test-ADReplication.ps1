function Test-ADReplication {
    [CmdletBinding()]
    Param()
    <#
    .SYNOPSIS
    Monitor AD Object Replication
    
    .DESCRIPTION
    This script monitors DCs for Replication Failures

    .EXAMPLE
    Run as a scheduled task.  Use Event Log consolidation tools to pull and alert on issues found.

    .EXAMPLE
    Run in verbose mode if you want on-screen feedback for testing
   
    .NOTES
    Authors: Mike Kanakos, Greg Onstot
    Version: 0.6.1
    Version Date: 04/18/2018

    Event Source 'PSMonitor' will be created

    EventID Definition:
    17020 - Failure
    17021 - Beginning of test
    17022 - Testing individual systems
    17023 - End of test
    17024 - Alert Email Sent
    #>

    Begin {
        Import-Module activedirectory
        $null = Get-ADConfig
        $SupportArticle = $Configuration.SupportArticle
        if (![System.Diagnostics.EventLog]::SourceExists("PSMonitor")) {
            write-verbose "Adding Event Source."
            New-EventLog -LogName Application -Source "PSMonitor"
        }
        #$DClist = (Get-ADGroupMember -Identity 'Domain Controllers').name  #For RWDCs only, RODCs are not in this group.
        $DClist = (Get-ADDomainController -Filter *).name  # For ALL DCs
        Write-eventlog -logname "Application" -Source "PSMonitor" -EventID 17021 -EntryType Information -message "START AD Replication Test Cycle ." -category "17021"
    }#End Begin

    Process {
        Foreach ($server in $DClist) {
            Write-eventlog -logname "Application" -Source "PSMonitor" -EventID 17022 -EntryType Information -message "CHECKING AD Replication - Server - $server" -category "17022"
            Write-Verbose "TESTING - $server"
            $OutputDetails = $null
            $Result = (Get-ADReplicationFailure -Target $server).failurecount
            Write-Verbose "$server - $Result"
            $Details = Get-ADReplicationFailure -Target $server
            $errcount = $Details.FailureCount
            $name = $Details.server
            $Fail = $Details.FirstFailureTime
            $Partner = $Details.Partner
        
            If ($result -ne $null -and $Result -gt 1) {
                $OutputDetails = "ServerName: `r`n  $name `r`n FailureCount: $errcount  `r`n `r`n    FirstFailureTime: `r`n $Fail  `r`n `r`n Error with Partner: `r`n $Partner  `r`n `r`n -  See the following support article $SupportArticle"
                Write-Verbose "Failure - $OutputDetails"
                Write-eventlog -logname "Application" -Source "PSMonitor" -EventID 17020 -EntryType Warning -message "FAILURE AD Replicaion on $server  -  $OutputDetails ." -category "17020"
                $global:CurrentFailure = $true
                Send-Mail $OutputDetails
            } #End if
        }#End Foreach
    }#End Process

    
    End {
        Write-eventlog -logname "Application" -Source "PSMonitor" -EventID 17023 -EntryType Information -message "END of AD Replication Test Cycle ." -category "17023"
        If (!$CurrentFailure){
            Write-Verbose "No Issues found in this run"
            $InError = Get-EventLog application -After (Get-Date).AddHours(-1) | where {($_.InstanceID -Match "17020")} 
            If ($InError.Count -gt 1) {
                Write-Verbose "Previous Errors Seen"
                #Previous run had an alert
                #No errors foun during this test so send email that the previous error(s) have cleared
                Send-AlertCleared
                #Write-Output $InError
            }#End if
        }#End if
    }#End End
}#End Function