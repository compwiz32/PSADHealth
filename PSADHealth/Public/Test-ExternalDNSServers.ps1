# Test-ExternalDNSServers.ps1
Function Test-ExternalDNSServers {
    <#
    .SYNOPSIS
        Queries external DNS servers from each domain controller to verify access
    .DESCRIPTION
        Queries external DNS servers from each domain controller to verify access
        Default tests query OpenDNS servers and verify access. Basic test is a ping test.
        If Ping fails, TCP-53 is tested to see if perhaps ICMP is disallowed but the DNS server would otherwise work
    .EXAMPLE
        PS C:\> Test-ExternalDNSServers
        
        This will silently test from all Domain Controllers and only email notification if there is a failure
        In the event of a Ping and/or TCP-53 test failure, there will be a warning messages displayed in the console when interactive
    .EXAMPLE
        PS C:\> Test-ExternalDNSServers -Verbose
        
        This will provide a status while testing from all Domain Controllers and only email notification if there is a failure
        In the event of a Ping and/or TCP-53 test failure, there will be a warning messages displayed in the console when interactive
    .EXAMPLE
        PS C:\> $trigger = New-JobTrigger -Once -At 6:00AM -RepetitionInterval (New-TimeSpan -Hours 1) -RepeatIndefinitely
        PS C:\> $cred = Get-Credential DOMAIN\ServiceAccount
        PS C:\> $opt = New-ScheduledJobOption -RunElevated -RequireNetwork
        PS C:\> Register-ScheduledJob -Name Test-ExternalDNSServers -Trigger $trigger -Credential $cred -ScriptBlock {(Import-Module -Name PSADHealth); Test-ExternalDNSServers} -MaxResultCount 5 -ScheduledJobOption $opt

        Creates a scheduled task to run Test-ExternalDNSServers on an hourly basis. NOTE: Service account needs to be a Domain Admin or equivalent (Tier0) and must have the RunAsBatch and RunAsService privilege
    .NOTES
        Functionality Updates:
            Sometimes ping fails to an otherwise working DNS server (Azure VM that is a DC may not be able to ping out to the Internet)
            Added a warning and followup check that uses Test-NetConnection to verify TCP-53 access is working and considering that a pass
            Updated email notification to include this additional functionality in the notification
        Added Comment based help section (and these notes)
        Verbosity Updates:
            Silenced the import of ActiveDirectory module because we don't really want to see that
            Added "Silently loaded ActiveDirectory module" statement in its place
            Added Verbose statement to display server and external DNS being worked on (showing progress)
    #>
    [cmdletBinding()]
    Param()

    begin {
        Import-Module ActiveDirectory -Verbose:$false
        Write-Verbose -Message "Silently loaded ActiveDirectory module"
        #Creates a global $configuration variable
        $null = Get-ADConfig
    }

    process {
        $DClist = (get-adgroupmember "Domain Controllers").name
        Write-Verbose -Message "DCList: $DCList"
        $ExternalDNSServers = $Configuration.ExternalDNSServers
        Write-Verbose -Message "ExternalDNSServers: $ExternalDNSServers"

        ForEach ($server in $DClist){
            Write-Verbose -Message "Testing $server External DNS access"

            ForEach ($DNSServer in $ExternalDNSServers) {
                Write-Verbose -Message "--Testing $DNSServer External DNS access"
                
                If  ((-not (Invoke-Command -ComputerName $server -ScriptBlock { Test-Connection $args[0] -Quiet -Count 1} -ArgumentList $DNSServer))) {

                    #This server can't ping the necessary DNS server, but maybe it can access them via TCP53?
                    Write-Warning -Message "----DC ($server) cannot ping the DNS Server: $DNSServer; testing TCP/53 access"
                    If ((-not (Invoke-Command -ComputerName $server -ScriptBlock { Test-NetConnection -ComputerName $args[0] -Port 53 } -ArgumentList $DNSServer))) {
                        Write-Warning -Message "----$server cannot connect to port 53 for DNS Server: $DNSServer; External DNS access is failing"

                    
                        $Subject = "External DNS $DNSServer is unreachable"
                        $EmailBody = @"
            
            
                        A Test connection from <font color="Red"><b> $Server </b></font> to $DNSServer was unsuccessful!
                        A Test connection via TCP-53 from <font color="Red"><b> $server </b></font> to $DNSServer was unsuccessful as well!
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
                        Write-Verbose -Message "Sent email notification for external DNS test from $server to $DNSServer"
                    } #end if TCP53

                } #End if Ping
            
            }# End Foreach (DCLIst)
        
        } # End ForEach (ExternalDNSServers)

    }

    end {
        Write-Verbose -Message "Finished testing External DNS Servers for all DCs"
    }
}
