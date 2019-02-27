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
    Version: 0.7
    Version Date: 2/15/2019
        
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
        $ConfigFile = Get-Content C:\Scripts\ADConfig.json |ConvertFrom-Json
        $SupportArticle = $ConfigFile.SupportArticle
        $SlackToken = $ConfigFile.SlackToken
        if (![System.Diagnostics.EventLog]::SourceExists("PSMonitor")) {
            write-verbose "Adding Event Source."
            New-EventLog -LogName Application -Source "PSMonitor"
        }#end if
        #$DClist = (Get-ADGroupMember -Identity 'Domain Controllers').name  #For RWDCs only, RODCs are not in this group.
        $PDCEmulator = (Get-ADDomainController -Discover -Service PrimaryDC).name
        $ExternalTimeSvr = $ConfigFile.ExternalTimeSvr
        $MaxTimeDrift = $ConfigFile.MaxExtTimeDrift
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
            #attempt to automatically fix the issue
            Invoke-Command -ComputerName $server -ScriptBlock { 'w32tm /resync' }
            Write-eventlog -logname "Application" -Source "PSMonitor" -EventID 17045 -EntryType Information -message "Remediation script repair was attempted `r`n " -category "17045"
            CurrentFailure = $true
            Send-Mail $emailOutput
            Write-Verbose "Sending Slack Alert"
            New-SlackPost "Alert - External Time drift above max threashold - $emailOutput"
        }#end if
        If (!$CurrentFailure) {
            Write-Verbose "No Issues found in this run"
            $InError = Get-EventLog application -After (Get-Date).AddHours(-24) | where {($_.InstanceID -Match "17040")} 
            $errtext = $InError |out-string
            If ($errtext -like "*$server*") {
                Write-Verbose "Previous Errors Seen"
                #Previous run had an alert
                #No errors foun during this test so send email that the previous error(s) have cleared
                Send-AlertCleared
                Write-Verbose "Sending Slack Message - Alert Cleared"
                New-SlackPost "The previous alert, for AD External Time Sync, has cleared."
                #Write-Output $InError
            }#End if
        }#End if
    }#End Process
    End {
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
    $Domain = (Get-ADDomain).DNSRoot
    $smtpServer = $ConfigFile.SMTPServer
    $smtp = new-object Net.Mail.SmtpClient($smtpServer)
    $msg = new-object Net.Mail.MailMessage

    #Send to list:    
    $emailCount = ($ConfigFile.Email).Count
    If ($emailCount -gt 0) {
        $Emails = $ConfigFile.Email
        foreach ($target in $Emails) {
            Write-Verbose "email will be sent to $target"
            $msg.To.Add("$target")
        }
    }
    Else {
        Write-Verbose "No email addresses defined"
        Write-eventlog -logname "Application" -Source "PSMonitor" -EventID 17040 -EntryType Error -message "ALERT - No email addresses defined.  Alert email can't be sent!" -category "17040"
    }
    
    #Message:
    $msg.From = "ADExternalTimeSync-$NBN@$Domain"
    $msg.ReplyTo = "ADExternalTimeSync-$NBN@$Domain"
    $msg.subject = "$NBN AD External Time Sync Alert!"
    $msg.body = @"
        Time of Event: $((get-date))`r`n $emailOutput
        See the following support article $SupportArticle
"@

    #Send it
    $smtp.Send($msg)
}


function Send-AlertCleared {
    Param($InError)
    Write-Verbose "Sending Email"
    Write-Verbose "Output is --  $InError"
    
    #Mail Server Config
    $NBN = (Get-ADDomain).NetBIOSName
    $Domain = (Get-ADDomain).DNSRoot
    $smtpServer = $ConfigFile.SMTPServer
    $smtp = new-object Net.Mail.SmtpClient($smtpServer)
    $msg = new-object Net.Mail.MailMessage

    #Send to list:    
    $emailCount = ($ConfigFile.Email).Count
    If ($emailCount -gt 0) {
        $Emails = $ConfigFile.Email
        foreach ($target in $Emails) {
            Write-Verbose "email will be sent to $target"
            $msg.To.Add("$target")
        }
    }
    Else {
        Write-Verbose "No email addresses defined"
        Write-eventlog -logname "Application" -Source "PSMonitor" -EventID 17030 -EntryType Error -message "ALERT - No email addresses defined.  Alert email can't be sent!" -category "17030"
    }
    #Message:
    $msg.From = "ADExternalTimeSync-$NBN@$Domain"
    $msg.ReplyTo = "ADExternalTimeSync-$NBN@$Domain"
    $msg.subject = "$NBN AD External Time Sync - Alert Cleared!"
    $msg.body = @"
        The previous alert for AD External Time Sync has now cleared.

        Thanks.
"@
    #Send it
    $smtp.Send($msg)
}

function New-SlackPost {
    param ($issue)
    $payload = @{
        "channel"    = "#psmonitor";
        "text"       = "$issue";
        "icon_emoji" = ":bomb:";
        "username"   = "PSMonitor";
    }
    Write-Verbose "Sending Slack Message"
    Invoke-WebRequest `
        -Uri "https://hooks.slack.com/services/$SlackToken" `
        -Method "POST" `
        -Body (ConvertTo-Json -Compress -InputObject $payload)         
}


Test-ADExternalTimeSync #-Verbose