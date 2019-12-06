# Test-ADServices.ps1
function Test-ADServices {
    [cmdletBinding()]
    Param()
    <#
    .SYNOPSIS
    Monitor AD Domain Controller Services

    .DESCRIPTION
    This function is used to Monitor AD Domain Controller services and send alerts if any identified services are stopped

    .EXAMPLE
    Run as a scheduled task on a tool server to remotely monitor service status on all DCs in a specified domain.


    .NOTES
    Authors: Mike Kanakos, Greg Onstot
    Version: 0.0.5
    Version Date: 10/30/2019

#>
    begin {
        Import-Module ActiveDirectory
        #Creates a global $configuration variable
        $null = Get-ADConfig
        $DClist = (Get-ADGroupMember "Domain Controllers").name
        $Collection = @('ADWS',
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
        $ServiceFilter = ($Collection | ForEach-Object { "name='$_'" }) -join " OR "
        $ServiceFilter = "State='Stopped' and ($ServiceFilter)"
    }

    process {
        try {
            $services = Get-CimInstance Win32_Service -filter $ServiceFilter -Computername $DClist -ErrorAction Stop
        }
        catch {
            Out-Null
        }

        foreach ($service in $services) {
            $Subject = "Windows Service: $($service.Displayname), is stopped on $service.PSComputerName "
                $EmailBody = @"
                            Service named <font color=Red><b>$($service.Displayname)</b></font> is stopped!
                            Time of Event: <font color=Red><b>"""$((get-date))"""</b></font><br/>
                            <br/>
                            THIS EMAIL WAS AUTO-GENERATED. PLEASE DO NOT REPLY TO THIS EMAIL.
"@
                $mailParams = @{
                    To         = $Configuration.MailTo
                    From       = $Configuration.MailFrom
                    SmtpServer = $Configuration.SmtpServer
                    Subject    = $Subject
                    Body       = $EmailBody
                    BodyAsHtml = $true
                }
                Send-MailMessage @mailParams
        }
    } #Process
} #function
