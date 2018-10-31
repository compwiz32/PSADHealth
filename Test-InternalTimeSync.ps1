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

    Event Source 'PSMonitor' will be created

    EventID Definition:
    17030 - Failure
    17031 - Beginning of test
    17032 - Testing individual systems
    17033 - End of test
    17034 - Alert Email Sent
    #>

    Begin {
        Import-Module activedirectory
        if (![System.Diagnostics.EventLog]::SourceExists("PSMonitor")) {
            write-verbose "Adding Event Source."
            New-EventLog –LogName Application –Source "PSMonitor"
        }#end if
        #$DClist = (Get-ADGroupMember -Identity 'Domain Controllers').name  #For RWDCs only, RODCs are not in this group.
        $DClist = (Get-ADDomainController -Filter *).name  # For ALL DCs
        $PDCEmulator = (Get-ADDomainController -Discover -Service PrimaryDC).name
        $MaxTimeDrift = 45
        Write-eventlog -logname "Application" -Source "PSMonitor" -EventID 17031 -EntryType Information -message "START of Internal Time Sync Test Cycle ." -category "17031"
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
            If ($result -lt 0) { $result = $result * (-1)}
                #test if result is greater than max time drift
                If ($result -gt $MaxTimeDrift) {
                    $emailOutput = "$server - Offset:  $result - Time:$Remotetime  - ReferenceTime: $Referencetime `r`n "
                    Write-Verbose "ALERT - Time drift above maximum allowed threshold on - $server - $emailOutput"
                    Write-eventlog -logname "Application" -Source "PSMonitor" -EventID 17030 -EntryType Warning -message "FAILURE time drift above maximum allowed on $emailOutput `r`n " -category "17030"
                    Send-Mail $emailOutput
                }#end if
            }#End Foreach
         }#End Process
    End{
        Write-eventlog -logname "Application" -Source "PSMonitor" -EventID 17033 -EntryType Information -message "END of Internal Time Sync Test Cycle ." -category "17033"
    }#End End
}#End Function

function Send-Mail {
    Param($emailOutput)
    Write-Verbose "Sending Email"
    Write-eventlog -logname "Application" -Source "PSMonitor" -EventID 17034 -EntryType Information -message "ALERT Email Sent" -category "17034"
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
    $msg.From = "ADInternalTimeSync-$NBN@$Domainname"
    $msg.ReplyTo = "ADInternalTimeSync-$NBN@$Domainname"
    $msg.subject = "$NBN AD Internal Time Sync Alert!"
    $msg.body = @"
        Time of Event: $((get-date))`r`n $emailOutput
"@

    #Send it
    $smtp.Send($msg)
}

Test-ADInternalTimeSync #-Verbose