# Test-ExternalDNSServers.ps1
Function Test-ExternalDNSServers {
    [cmdletBinding()]
    Param()

    begin {
        Import-Module ActiveDirectory
        #Creates a global $configuration variable
        $null = Get-ADConfig
    }

    process {
        $DClist = (get-adgroupmember "Domain Controllers").name
        $ExternalDNSServers = $Configuration.ExternalDNSServers 

        ForEach ($server in $DClist){

            ForEach ($DNSServer in $ExternalDNSServers) {
                
            if  ((!(Invoke-Command -ComputerName $Server {Test-Connection -ComputerName $DNSServer -quiet -count 1})))
                {
                    
                    $Subject = "External DNS $DNSServer is unreachable"
                    $EmailBody = @"
        
        
                    A Test connection from <font color="Red"><b> $Server </b></font> to $DNSServer was unsuccessful!
                    Time of Event: <font color="Red"><b> """$((get-date))"""</b></font><br/>
                    <br/>
                    THIS EMAIL WAS AUTO-GENERATED. PLEASE DO NOT REPLY TO THIS EMAIL.
"@
         
                    $mailParams = @{
                        To = $Configuration.MailTo
                        From = $Configuration.MailFrom
                        SmtpServer = $Configuration.SmtpServer
                        Subject = $Subject
                        Body = $EmailBody
                        BodyAsHtml = $true
                    }

                    Send-MailMessage @mailParams

                } #End if
            
            }# End Foreach (DCLIst)
        
        } # End ForEach (ExternalDNSServers)

    }

    end {}
}