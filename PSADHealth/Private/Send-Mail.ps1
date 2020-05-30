function Send-Mail {
    <#
    .SYNOPSIS
        Takes provided text block and sends an email using configuration values
    .DESCRIPTION
        Takes provided text block and sends an email using configuration values
    .EXAMPLE
        PS C:\> Send-Mail -emailOutput <TextBlock>
        Will email a message to configured recipients with provided <textblock> in the body of the message
    .NOTES
        Updated: 05/29/2020
            Cleaned up formatting a little bit
            Added #Requires -Modules ActiveDirectory
            Addded Comment Help section
            This function was written for AD Internal Time Sync function but is being used by 3 other functions currently (Test-ADObjectReplication, Test-ADReplication, Test-SysvolReplication)
                I defined $CallingFunction by getting the name of the function that called Send-AlertCleared (Get-Variable -Name MyInvocation -Scope 1).Value.MyCommand.Name
                I then modified the email subject and body to utilize this variable so that the clear message will make more sense. I also include the $InError parameter in the body of the email
    #>
    [cmdletBinding()]
    Param(
        [Parameter(Mandatory,ValueFromPipeline)]
        [String]
        $emailOutput
    )
    
    #Requires -Modules ActiveDirectory
    $CallingFunction = (Get-Variable -Name MyInvocation -Scope 1).Value.MyCommand.Name
    Write-Verbose -Message "Calling Function: $CallingFunction"
    Write-Verbose -Message "Sending Email"
    Write-eventlog -logname "Application" -Source "PSMonitor" -EventID 17034 -EntryType Information -message "ALERT Email Sent" -category "17034"
    Write-Verbose -Message "Output is --  $emailOutput"
    
    #Mail Server Config
    $NBN = (Get-ADDomain).NetBIOSName
    Write-Verbose -Message "NetBIOSName: $NBN"
    $Domain = (Get-ADDomain).DNSRoot
    Write-Verbose -Message "Domain     : $Domain"
  

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
    $mail = @{

        To = $Configuration.MailTo
        From = $Configuration.MailFrom
        ReplyTo = $Configuration.MailFrom
        SMTPServer = $Configuration.SMTPServer
        Subject = "$NBN - $CallingFunction Alert!"
        Body = @"
        Time of Event: $((get-date))`r`n $emailOutput
        See the following support article $SupportArticle
"@
        BodyAsHtml = $true

    }

    Send-MailMessage @mail
   
}