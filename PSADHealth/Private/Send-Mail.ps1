function Send-Mail {
    [cmdletBinding()]
    Param(
        [Parameter(Mandatory,ValueFromPipeline)]
        [String]
        $emailOutput
    )
    
    Write-Verbose "Sending Email"
    Write-eventlog -logname "Application" -Source "PSMonitor" -EventID 17034 -EntryType Information -message "ALERT Email Sent" -category "17034"
    Write-Verbose "Output is --  $emailOutput"
    
    #Mail Server Config
    $NBN = (Get-ADDomain).NetBIOSName
    $Domain = (Get-ADDomain).DNSRoot
  

    #Send to list:    
    $emailCount = ($Configuration.MailTo).Count

    If ($emailCount -gt 0){
        $Emails = $Configuration.MailTo
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
    $mail = @{

        To = $Configuration.MailTo
        From = $Configuration.MailFrom
        ReplyTo = $Configuration.MailFrom
        SMTPServer = $Configuration.SMTPServer
        Subject = "$NBN AD Internal Time Sync Alert!"
        Body = @"
        Time of Event: $((get-date))`r`n $emailOutput
        See the following support article $SupportArticle
"@
        BodyAsHtml = $true

    }

    Send-MailMessage @mail
   
}