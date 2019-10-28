# Test-ADServices.ps1
function Test-ADServices {
    [cmdletBinding()]
    Param()

    begin {
        Import-Module ActiveDirectory
        #Creates a global $configuration variable
        $null = Get-ADConfig
    }

    process {
        $DClist = (get-adgroupmember "Domain Controllers").name
        $collection = @('ADWS',
                        'DHCPServer',
                        'DNS',
                        'DFS',
                        'DFSR',
                        'Eventlog',
                        'EventSystem',
                        'KDC',
                        'LanManWorkstation',
                        'LanManServer',
                        'NetLogon',
                        'NTDS',
                        'RPCSS',
                        'SAMSS',
                        'W32Time')

        

        forEach ($server in $DClist){
            
            forEach ($service in $collection){
                try {
                   $s = Get-CimInstance Win32_Service -filter "name='$service'" -Computername $server -ErrorAction Stop
                   $s
                }
                
                catch {
                    Out-Null
                }


                if($s.State -eq "Stopped"){


                    $Subject = "Windows Service: $($s.Displayname), is stopped on $server "
                    
                    $EmailBody = @"
                                Service named <font color=Red><b>$($s.Displayname)</b></font> is stopped!
                                Time of Event: <font color=Red><b>"""$((get-date))"""</b></font><br/>
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
                
                } #End If

            } #Service Foreach
        
        } #DCList Foreach
    
    } #Process

} #function
