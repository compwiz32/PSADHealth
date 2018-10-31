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

    Event Source 'PSMonitor' will be created

    EventID Definition:
    17040 - Failure
    17041 - Beginning of test
    17042 - Testing individual systems
    17043 - End of test
    17044 - Alert Email Sent
    #>

    Begin {
        Import-Module activedirectory
        if (![System.Diagnostics.EventLog]::SourceExists("PSMonitor")) {
            write-verbose "Adding Event Source."
            New-EventLog –LogName Application –Source "PSMonitor"
        }#end if
        #$DClist = (Get-ADGroupMember -Identity 'Domain Controllers').name  #For RWDCs only, RODCs are not in this group.
        $PDCEmulator = (Get-ADDomainController -Discover -Service PrimaryDC).name
        $ExternalTimeSvr = '<TIMESERVERNAME>'
        $MaxTimeDrift = 15
        Write-eventlog -logname "Application" -Source "PSMonitor" -EventID 17041 -EntryType Information -message "START of External Time Sync Test Cycle ." -category "17041"
    }#End Begin

    Process {
        $PDCeTime = ([WMI]'').ConvertToDateTime((Get-WmiObject -Class win32_operatingsystem -ComputerName $PDCEmulator).LocalDateTime)
        $ExternalTime = (w32tm /stripchart /dataonly /computer:$Server /samples:1)[-1].split("[")[0]
        $ExternalTimeOutput = [Regex]::Match($ExternalTime, "\d+\:\d+\:\d+").value
        $result = (New-TimeSpan -Start $ExternalTimeOutput -End $PDCeTime).Seconds
        $emailOutput = "$PDCEmulator - Offset:  $result - Time:$PDCeTime  - ReferenceTime: $ExternalTimeOutput `r`n "
        Write-Verbose "ServerName $PDCEmulator - Offset: $result - ExternalTime: $ExternalTimeOutput - PDCE Time: $PDCeTime"
        Write-eventlog -logname "Application" -Source "PSMonitor" -EventID 17042 -EntryType Information -message "CHECKING External Time Sync on Server - $PDCEmulator - $emailOutput" -category "17042"
        $OutputDetails = $null

        #If result is a negative number (ie -6 seconds) convert to positive number
        # for easy comparison
        If ($result -lt 0) { $result = $result * (-1)}
        #test if result is greater than max time drift
        If ($result -gt $MaxTimeDrift) {
            
            Write-Verbose "ALERT - Time drift above maximum allowed threshold on - $server - $emailOutput"
            Write-eventlog -logname "Application" -Source "PSMonitor" -EventID 17040 -EntryType Warning -message "FAILURE External time drift above maximum allowed on $emailOutput `r`n " -category "17040"
            Send-Mail $emailOutput
        }#end if
   }#End Process
   End{
       Write-eventlog -logname "Application" -Source "PSMonitor" -EventID 17043 -EntryType Information -message "END of External Time Sync Test Cycle ." -category "17043"
   }#End End
    
}#End Function

function Send-Mail {
    Param($emailOutput)
    Write-Verbose "Sending Email"
    Write-eventlog -logname "Application" -Source "PSMonitor" -EventID 17044 -EntryType Information -message "ALERT Email Sent" -category "17044"
    Write-Verbose "Output is --  $emailOutput"
    
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
    $msg.From = "ADExternalTimeSync-$NBN@$Domainname"
    $msg.ReplyTo = "ADExternalTimeSync-$NBN@$Domainnname"
    $msg.subject = "$NBN AD External Time Sync Alert!"
    $msg.body = @"
        Time of Event: $((get-date))`r`n $emailOutput
"@

    #Send it
    $smtp.Send($msg)
}

Test-ADExternalTimeSync #-Verbose
    
    #Message:
    $msg.From = "ADExternalTimeSync-$NBN@$Domain"
    $msg.ReplyTo = "ADExternalTimeSync-$NBN@$Domain"
    $msg.subject = "$NBN AD External Time Sync Alert!"
    $msg.body = @"
        Time of Event: $((get-date))`r`n $emailOutput
"@

    #Send it
    $smtp.Send($msg)
}

Test-ADExternalTimeSync #-Verbose