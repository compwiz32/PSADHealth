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
        if (![System.Diagnostics.EventLog]::SourceExists("PSMonitor")) {
            write-verbose "Adding Event Source."
            New-EventLog –LogName Application –Source "PSMonitor"
        }
        #$DClist = (Get-ADGroupMember -Identity 'Domain Controllers').name  #For RWDCs only, RODCs are not in this group.
        $DClist = (Get-ADDomainController -Filter *).name  # For ALL DCs
        Write-eventlog -logname "Application" -Source "PSMonitor" -EventID 17021 -EntryType Information -message "START of Test Cycle ." -category "17021"
    }#End Begin

    Process {
        Foreach ($server in $DClist) {
            Write-eventlog -logname "Application" -Source "PSMonitor" -EventID 17022 -EntryType Information -message "CHECKING Server - $server" -category "17022"
            Write-Verbose "TESTING - $server"
            $OutputDetails = $null
            $Result = (Get-ADReplicationFailure -Target $server).failurecount
            Write-Verbose "$server - $Result"
            $Details = Get-ADReplicationFailure -Target $server
            $errcount = $Details.FailureCount
            $name = $Details.server
            $Fail = $Details.FirstFailureTime
            $Partner = $Details.Partner
        
            If ($result -ne $null -and $Result -gt 0) {
                $OutputDetails ="ServerName: `r`n  $name `r`n FailureCount: $errcount  `r`n `r`n    FirstFailureTime: `r`n $Fail  `r`n `r`n Error with Partner: `r`n $Partner  `r`n `r`n"
                Write-Verbose "Failure - $OutputDetails"
                Write-eventlog -logname "Application" -Source "PSMonitor" -EventID 17020 -EntryType Warning -message "FAILURE on $server  -  $OutputDetails ." -category "17020"
                Send-Mail $OutputDetails
            } #End if
         }#End Foreach
    }#End Process

    
    End{
        Write-eventlog -logname "Application" -Source "PSMonitor" -EventID 17023 -EntryType Information -message "END of Test Cycle ." -category "17023"
    }#End End
}#End Function


function Send-Mail {
    Param($OutputDetails)
    Write-Verbose "Sending Email"
    Write-eventlog -logname "Application" -Source "PSMonitor" -EventID 17024 -EntryType Information -message "ALERT Email Sent" -category "17024"
    Write-Verbose "Output is --  $OutputDetails"
    
    #Mail Server Config
    $NBN = (Get-ADDomain).NetBIOSName
    $domainname = (Get-ADDomain).dnsroot
    $smtpServer = "<SMTPSERVER>.$Domainname"
    $smtp = new-object Net.Mail.SmtpClient($smtpServer)
    $msg = new-object Net.Mail.MailMessage

    #Send to list:    
    $msg.To.Add("<TargetUSER>@$domainname")
    $msg.To.Add("<TargetDL>@$domainname")
    
    #Message:
    $msg.From = "ADOBJECTREPL-$NBN@$Domainname"
    $msg.ReplyTo = "ADOBJECTREPL-$NBN@$Domainname"
    $msg.subject = "$NBN AD Replication Failure!"
    $msg.body = @"
        Time of Event: $((get-date))`r`n $OutputDetails
"@

    #Send it
    $smtp.Send($msg)
}

Test-ADReplication #-Verbose