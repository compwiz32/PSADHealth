function Test-ADConfigMailer {


    begin { $null = Get-ADConfig }


    process {

        $mailParams = @{
            To = $Configuration.MailTo
            From = $Configuration.MailFrom
            SmtpServer = $Configuration.SmtpServer
            Subject = "Testing PSADHealth Mail Capability"
            Body = "If you can read this, your scripts can alert via email!"
            BodyAsHtml = $true
        }

        Send-MailMessage @mailParams
    }
    
}