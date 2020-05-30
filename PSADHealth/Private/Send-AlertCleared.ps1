function Send-AlertCleared {
    <#
    .SYNOPSIS
        Take InError as input and determines calling function to send email to notify that a formerly failing problem has cleared

    .DESCRIPTION
        Take InError as input and determines calling function to send email to notify that a formerly failing problem has cleared
        
    .EXAMPLE
        PS C:\> Send-AlertCleared -InError <TextBlock>
        Loads configuration from the parent scope $Configuration and then sends an SMTP email with the InError text as part of the body

    .NOTES
        Updated: 05/29/2020
            Cleaned up formatting a little bit
            Added #Requires -Modules ActiveDirectory
            Added a Comment Help section
            Made this an advance function by adding [cmdletbinding()] so that Verbose will work
            This function was written for Test-ADInternalTimeSync function but is being used by 3 other functions currently (Test-ADObjectReplication, Test-ADReplication, Test-SysvolReplication)
                I defined $CallingFunction by getting the name of the function that called Send-AlertCleared (Get-Variable -Name MyInvocation -Scope 1).Value.MyCommand.Name
                I then modified the email subject and body to utilize this variable so that the clear message will make more sense. I also include the $InError parameter in the body of the email

    #>
    [cmdletbinding()]
    Param($InError)
    #Requires -Modules ActiveDirectory
    $CallingFunction = (Get-Variable -Name MyInvocation -Scope 1).Value.MyCommand.Name
    Write-Verbose -Message "Calling Function: $CallingFunction"
    Write-Verbose -Message "Sending Email"
    Write-Verbose -Message "Output is --  $InError"
    
    #Mail Server Config
    $NBN = (Get-ADDomain).NetBIOSName
    Write-Verbose -Message "NetBIOSName: $NBN"
    $Domain = (Get-ADDomain).DNSRoot
    Write-Verbose -Message "Domain     : $Domain"
    $smtpServer = $Configuration.SMTPServer
    Write-Verbose -Message "SMTPServer : $smtpServer"
    $smtp = new-object Net.Mail.SmtpClient($smtpServer)
    $msg = new-object Net.Mail.MailMessage

    #Send to list:    
    $emailCount = ($Configuration.MailTo).Count
    If ($emailCount -gt 0){
        $Emails = $Configuration.MailTo
        foreach ($target in $Emails){
            Write-Verbose -Message "email will be sent to $target"
            $msg.To.Add("$target")
        }
    }
    Else{
        Write-Verbose -Message "No email addresses defined"
        Write-eventlog -logname "Application" -Source "PSMonitor" -EventID 17030 -EntryType Error -message "ALERT - No email addresses defined.  Alert email can't be sent!" -category "17030"
    }
    #Message:
    $msg.From = $Configuration.MailFrom
    $msg.ReplyTo = $Configuration.MailFrom
    $msg.subject = "$NBN - $CallingFunction - Alert Cleared!"
    $msg.body = @"
        $InError
        The previous $CallingFunction alert has now cleared.

        Thanks.
"@
    #Send it
    $smtp.Send($msg)
}
