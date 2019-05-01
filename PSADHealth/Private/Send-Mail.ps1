function Send-Mail {
    Param($emailOutput)
    
    begin { $null = Get-ADConfig }
    
    process {
    Write-Verbose "Sending Email"
    Write-eventlog -logname "Application" -Source "PSMonitor" -EventID 17034 -EntryType Information -message "ALERT Email Sent" -category "17034"
    Write-Verbose "Output is --  $emailOutput"
    
    #Mail Server Config
    $NBN = (Get-ADDomain).NetBIOSName
    $Domain = (Get-ADDomain).DNSRoot
    $smtpServer = $Configuration.SMTPServer
    $smtp = new-object Net.Mail.SmtpClient($smtpServer)
    $msg = new-object Net.Mail.MailMessage

    #Send to list:    
    $emailCount = ($Configuration.Email).Count

    If ($emailCount -gt 0){
        $Emails = $Configuration.Email
        foreach ($target in $Emails){
        Write-Verbose "email will be sent to $target"
        $msg.To.Add("$target")
        }
    }
    
    Else{
        Write-Verbose "No email addresses defined"
        Write-eventlog -logname "Application" -Source "PSMonitor" -EventID 17030 -EntryType Error -message "ALERT - No email addresses defined.  Alert email can't be sent!" -category "17030"
    }
    
    #Message:
    $msg.From = "ADInternalTimeSync-$NBN@$Domain"
    $msg.ReplyTo = "ADInternalTimeSync-$NBN@$Domain"
    $msg.subject = "$NBN AD Internal Time Sync Alert!"
    $msg.body = @"
        Time of Event: $((get-date))`r`n $emailOutput
        See the following support article $SupportArticle
"@

    #Send it
    $smtp.Send($msg)

    }
    
}
